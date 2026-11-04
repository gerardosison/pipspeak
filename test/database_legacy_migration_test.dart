import 'dart:io';

import 'package:app_builder_hackathon/data/local/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  test(
    'legacy v5 columns are repaired without losing pending sessions/details',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'pipspeak-legacy-',
      );
      final file = File('${directory.path}/app.sqlite');
      final old = sqlite.sqlite3.open(file.path);
      old.execute('''CREATE TABLE practice_records (
      id TEXT NOT NULL PRIMARY KEY, user_id TEXT NOT NULL,
      completed_at INTEGER NOT NULL, practice_purpose TEXT NOT NULL,
      duration_seconds INTEGER NOT NULL, stars_earned INTEGER NOT NULL,
      baseline_session_id TEXT, scoring_version TEXT NOT NULL DEFAULT 'v1',
      needs_upload INTEGER NOT NULL DEFAULT 1, is_test INTEGER NOT NULL DEFAULT 0,
      words_per_minute REAL, filler_count INTEGER, overall_score REAL,
      comparison_score REAL, local_analysis_json TEXT)''');
      old.execute(
        'INSERT INTO practice_records (id,user_id,completed_at,practice_purpose,duration_seconds,stars_earned,local_analysis_json) VALUES (?,?,?,?,?,?,?)',
        [
          'session-a',
          'alice',
          1700000000,
          'Debate',
          60,
          2,
          '{"report":{"overallScore":75,"summary":"Saved feedback"},"transcript":"My saved speech"}',
        ],
      );
      old.execute('PRAGMA user_version = 5');
      old.close();
      var database = AppDatabase.forTesting(NativeDatabase(file));
      final records = await database.pendingRecords('alice');
      expect(records.single.id, 'session-a');
      expect(records.single.starsEarned, 2);
      expect(records.single.needsUpload, isTrue);
      expect(records.single.hasLocalDetails, isTrue);
      final detail = await database.select(database.sessionDetails).getSingle();
      expect(detail.transcript, 'My saved speech');
      expect(detail.reportJson, contains('Saved feedback'));
      expect(await database.pendingRecords('bob'), isEmpty);
      await database.close();
      database = AppDatabase.forTesting(NativeDatabase(file));
      expect((await database.pendingRecords('alice')).single.id, 'session-a');
      await database.close();
      await directory.delete(recursive: true);
    },
  );

  test('current v5 history also upgrades idempotently', () async {
    final directory = await Directory.systemTemp.createTemp(
      'pipspeak-current-',
    );
    final file = File('${directory.path}/app.sqlite');
    var database = AppDatabase.forTesting(NativeDatabase(file));
    await database.setSetting('theme', 'dark');
    await database.close();
    final old = sqlite.sqlite3.open(file.path);
    old.execute('PRAGMA user_version = 5');
    old.close();
    database = AppDatabase.forTesting(NativeDatabase(file));
    expect(await database.setting('theme'), 'dark');
    await database.close();
    await directory.delete(recursive: true);
  });
}
