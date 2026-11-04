import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Synchronized practice summary. Detailed local-only analysis lives in
/// [SessionDetails].
@DataClassName('PracticeRecord')
class PracticeRecords extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  DateTimeColumn get completedAt => dateTime()();
  TextColumn get practicePurpose => text()();
  IntColumn get durationSeconds =>
      integer().customConstraint('NOT NULL CHECK (duration_seconds >= 0)')();
  IntColumn get starsEarned =>
      integer().customConstraint('NOT NULL CHECK (stars_earned >= 0)')();
  TextColumn get baselineSessionId => text().nullable()();
  TextColumn get scoringVersion => text().withDefault(const Constant('v1'))();
  BoolColumn get needsUpload => boolean().withDefault(const Constant(true))();
  BoolColumn get isTest => boolean().withDefault(const Constant(false))();

  // Added in schema v5.
  TextColumn get language => text().withDefault(const Constant('en-US'))();
  TextColumn get topic => text().withDefault(const Constant(''))();
  RealColumn get overallScore => real().nullable()();
  RealColumn get wordsPerMinute => real().nullable()();
  IntColumn get fillerCount => integer().nullable()();
  IntColumn get pauseCount => integer().nullable()();
  RealColumn get postureScore => real().nullable()();
  RealColumn get bodySwayCm => real().nullable()();
  RealColumn get gestureScore => real().nullable()();
  BoolColumn get hasLocalDetails =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LocalProfile')
class UserProfiles extends Table {
  TextColumn get userId => text()();
  TextColumn get fullName => text()();
  TextColumn get nickname => text()();
  TextColumn get language => text()();
  TextColumn get practicePurpose => text()();
  BoolColumn get onboardingComplete =>
      boolean().withDefault(const Constant(false))();
  TextColumn get revision => text()();
  BoolColumn get needsUpload => boolean().withDefault(const Constant(true))();

  // Added in schema v5.
  TextColumn get username => text().withDefault(const Constant(''))();
  TextColumn get email => text().withDefault(const Constant(''))();
  TextColumn get school => text().withDefault(const Constant(''))();

  /// Device-local file path; never synchronized.
  TextColumn get photoPath => text().nullable()();

  @override
  Set<Column> get primaryKey => {userId};
}

/// Local-only detailed analysis for a session recorded on this device.
@DataClassName('SessionDetail')
class SessionDetails extends Table {
  TextColumn get sessionId => text()();
  TextColumn get userId => text()();
  TextColumn get transcript => text().withDefault(const Constant(''))();
  TextColumn get reportJson => text()();
  TextColumn get audioPath => text().nullable()();

  @override
  Set<Column> get primaryKey => {sessionId};
}

/// Local-only metadata and analysis results for imported documents.
@DataClassName('LocalDocument')
class LocalDocuments extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get title => text()();
  IntColumn get wordCount => integer().withDefault(const Constant(0))();
  TextColumn get resultJson => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class DeviceSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    PracticeRecords,
    UserProfiles,
    DeviceSettings,
    SessionDetails,
    LocalDocuments,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase()
    : super(
        driftDatabase(
          name: 'hawkabuild',
          web: DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js'),
          ),
        ),
      );

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      // Different earlier branches both used version 5 for different schemas.
      // Inspect actual tables/columns; never reset the database to repair them.
      for (final table in allTables) {
        final exists = await customSelect(
          'SELECT name FROM sqlite_master WHERE type = ? AND name = ?',
          variables: [
            Variable.withString('table'),
            Variable.withString(table.actualTableName),
          ],
        ).get();
        if (exists.isEmpty) {
          await migrator.createTable(table);
          continue;
        }
        final columns = await customSelect(
          'PRAGMA table_info("${table.actualTableName}")',
        ).get();
        final names = columns.map((row) => row.read<String>('name')).toSet();
        for (final column in table.$columns) {
          if (!names.contains(column.$name)) {
            await migrator.addColumn(table, column);
          }
        }
      }
      await customStatement(
        'UPDATE practice_records SET is_test = 1 WHERE practice_purpose = ?',
        ['Database test'],
      );
      await _recoverLegacyDetails();
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _recoverLegacyDetails() async {
    final columns = await customSelect('PRAGMA table_info(practice_records)')
        .get();
    if (!columns.any(
      (row) => row.read<String>('name') == 'local_analysis_json',
    )) {
      return;
    }
    final rows = await customSelect(
      'SELECT id, user_id, local_analysis_json FROM practice_records WHERE local_analysis_json IS NOT NULL',
    ).get();
    for (final row in rows) {
      try {
        final decoded = jsonDecode(row.read<String>('local_analysis_json'));
        if (decoded is! Map) continue;
        final report = decoded['report'] is Map
            ? decoded['report'] as Map
            : decoded;
        if (report['summary'] is! String || report['overallScore'] is! num) {
          continue;
        }
        final transcript = decoded['transcript'];
        final audio = decoded['audioPath'];
        await into(sessionDetails).insert(
          SessionDetailsCompanion.insert(
            sessionId: row.read<String>('id'),
            userId: row.read<String>('user_id'),
            reportJson: jsonEncode(report),
            transcript: Value(transcript is String ? transcript : ''),
            audioPath: Value(audio is String ? audio : null),
          ),
          mode: InsertMode.insertOrIgnore,
        );
        await (update(
          practiceRecords,
        )..where((r) => r.id.equals(row.read<String>('id')))).write(
          const PracticeRecordsCompanion(hasLocalDetails: Value(true)),
        );
      } on FormatException {
        // Preserve an unrecognized original payload; malformed legacy data must
        // not prevent the rest of the account history from opening.
      }
    }
  }

  Stream<List<PracticeRecord>> watchRecords(String userId) {
    return (select(practiceRecords)
          ..where((row) => row.userId.equals(userId))
          ..orderBy([(row) => OrderingTerm.desc(row.completedAt)]))
        .watch();
  }

  Future<List<PracticeRecord>> pendingRecords(String userId) {
    return (select(practiceRecords)..where(
          (row) => row.userId.equals(userId) & row.needsUpload.equals(true),
        ))
        .get();
  }

  /// Counts every account-owned pending change, including profile edits.
  Stream<int> watchPendingCount(String userId) {
    return customSelect(
      'SELECT '
      '(SELECT COUNT(*) FROM practice_records WHERE user_id = ? AND needs_upload = 1) + '
      '(SELECT COUNT(*) FROM user_profiles WHERE user_id = ? AND needs_upload = 1) AS pending_total',
      variables: [Variable.withString(userId), Variable.withString(userId)],
      readsFrom: {practiceRecords, userProfiles},
    ).watchSingle().map((row) => row.read<int>('pending_total'));
  }

  Future<void> markUploaded(String userId, String id) async {
    await (update(practiceRecords)
          ..where((row) => row.userId.equals(userId) & row.id.equals(id)))
        .write(const PracticeRecordsCompanion(needsUpload: Value(false)));
  }

  /// Inserts a downloaded summary without touching an existing local row.
  Future<void> insertDownloaded(PracticeRecordsCompanion record) async {
    await into(practiceRecords).insert(record, mode: InsertMode.insertOrIgnore);
  }

  Future<String?> setting(String key) async {
    final row = await (select(
      deviceSettings,
    )..where((row) => row.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setSetting(String key, String value) async {
    await into(deviceSettings).insertOnConflictUpdate(
      DeviceSettingsCompanion.insert(key: key, value: value),
    );
  }

  Future<void> removeSetting(String key) async {
    await (delete(deviceSettings)..where((row) => row.key.equals(key))).go();
  }

  /// Removes every local row owned by [userId].
  Future<void> deleteAccountData(String userId) async {
    await transaction(() async {
      await (delete(
        sessionDetails,
      )..where((row) => row.userId.equals(userId))).go();
      await (delete(
        practiceRecords,
      )..where((row) => row.userId.equals(userId))).go();
      await (delete(
        localDocuments,
      )..where((row) => row.userId.equals(userId))).go();
      await (delete(
        userProfiles,
      )..where((row) => row.userId.equals(userId))).go();
    });
  }
}
