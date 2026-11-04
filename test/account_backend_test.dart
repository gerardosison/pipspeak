import 'package:app_builder_hackathon/app/account_providers.dart';
import 'package:app_builder_hackathon/core/models/document_result.dart';
import 'package:app_builder_hackathon/data/codecs/analysis_codec.dart';
import 'package:app_builder_hackathon/data/local/app_database.dart';
import 'package:app_builder_hackathon/data/repositories/account_guard.dart';
import 'package:app_builder_hackathon/data/repositories/profile_repository.dart';
import 'package:app_builder_hackathon/data/repositories/progress_repository.dart';
import 'package:app_builder_hackathon/data/repositories/document_repository.dart';
import 'package:app_builder_hackathon/features/auth/services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _testUid = StateProvider<String?>((_) => 'alice');
void main() {
  late AppDatabase db;
  late FakeFirebaseFirestore cloud;
  late MockFirebaseAuth auth;
  late AccountGuard guard;
  late ProfileRepository profiles;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    cloud = FakeFirebaseFirestore();
    auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'alice', email: 'alice@example.com'),
    );
    guard = AccountGuard(auth);
    profiles = ProfileRepository(database: db, firestore: cloud, guard: guard);
    await profiles.save(
      userId: 'alice',
      fullName: 'Alice Santos',
      nickname: 'Alice',
      language: 'en-US',
      practicePurpose: 'Debate',
      onboardingComplete: true,
      username: 'alice',
      email: 'alice@example.com',
    );
  });
  tearDown(() => db.close());

  test('profile edits count as pending synchronization', () async {
    expect(await db.watchPendingCount('alice').first, 1);
    expect(await db.watchPendingCount('bob').first, 0);
    await profiles.sync('alice');
    expect(await db.watchPendingCount('alice').first, 0);
  });
  test('profile and document writes refuse another account', () async {
    await expectLater(
      profiles.save(
        userId: 'bob',
        fullName: 'Bob',
        nickname: 'B',
        language: 'en-US',
        practicePurpose: 'Debate',
        onboardingComplete: true,
      ),
      throwsA(isA<AccountChangedException>()),
    );
    await expectLater(
      DocumentRepository(db, guard: guard).save(
        'bob',
        const DocumentResult(
          documentId: 'd',
          title: 'Test',
          extractedText: 'text',
        ),
      ),
      throwsA(isA<AccountChangedException>()),
    );
  });
  test('username reservations never expose emails', () async {
    await profiles.reserveUsername(
      userId: 'alice',
      username: 'alice',
      email: 'alice@example.com',
    );
    final data = (await cloud.doc('usernames/alice').get()).data()!;
    expect(data, {'uid': 'alice'});
    expect(await profiles.emailForUsername('alice'), 'alice@example.com');
    expect(await profiles.emailForUsername('unknown'), isNull);
  });
  test(
    'failed first profile download cannot overwrite cloud with defaults',
    () async {
      await db.deleteAccountData('alice');
      await cloud.doc('users/alice').set({
        'fullName': 'Cloud Alice',
        'nickname': 'Cloud',
        'language': 'fil-PH',
        'practicePurpose': 'Debate',
        'onboardingComplete': true,
        'revision': 'cloud-r1',
      });
      final unavailable = _UnavailableProfiles(
        database: db,
        firestore: cloud,
        guard: guard,
      );
      await expectLater(
        AuthService(
          auth: auth,
          firestore: cloud,
          profiles: unavailable,
          database: db,
        ).signIn('alice@example.com', 'password123'),
        throwsA(isA<AuthFailure>()),
      );
      expect(await profiles.get('alice'), isNull);
      await profiles.sync('alice');
      expect((await profiles.get('alice'))!.fullName, 'Cloud Alice');
      expect(
        (await cloud.doc('users/alice').get()).data()!['fullName'],
        'Cloud Alice',
      );
    },
  );
  test(
    'a cached profile remains usable without a cloud profile read',
    () async {
      final unavailable = _UnavailableProfiles(
        database: db,
        firestore: cloud,
        guard: guard,
      );
      final user = await AuthService(
        auth: auth,
        firestore: cloud,
        profiles: unavailable,
        database: db,
      ).signIn('alice@example.com', 'password123');
      expect(user.uid, 'alice');
      expect((await profiles.get(user.uid))!.fullName, 'Alice Santos');
    },
  );
  test(
    'generated nicknames fit cloud limits without splitting Unicode',
    () async {
      await profiles.save(
        userId: 'alice',
        fullName: List.filled(40, '😀').join(),
        nickname: '',
        language: 'en-US',
        practicePurpose: 'Debate',
        onboardingComplete: true,
      );
      final nickname = (await profiles.get('alice'))!.nickname;
      expect(nickname.length, 40);
      expect(nickname.runes.length, 20);
      await profiles.sync('alice');
      expect(await db.watchPendingCount('alice').first, 0);
    },
  );
  test('text-only analysis mode survives database encoding', () async {
    final saved = await DocumentRepository(db, guard: guard).save(
      'alice',
      const DocumentResult(
        documentId: 'doc',
        title: 'Script',
        extractedText: 'Original text',
        aiAnalyzed: false,
      ),
    );
    expect(saved.aiAnalyzed, isFalse);
    final row = await db.select(db.localDocuments).getSingle();
    expect(AnalysisCodec.decodeDocument(row.resultJson).aiAnalyzed, isFalse);
  });
  test(
    'account switching does not retain previous profile AsyncData',
    () async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          firebaseAuthProvider.overrideWithValue(auth),
          firestoreProvider.overrideWithValue(cloud),
          currentUidProvider.overrideWith((ref) => ref.watch(_testUid)),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(localProfileProvider, (_, _) {});
      addTearDown(subscription.close);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        container.read(localProfileProvider).valueOrNull?.fullName,
        'Alice Santos',
      );
      container.read(_testUid.notifier).state = 'bob';
      expect(container.read(localProfileProvider).valueOrNull, isNull);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(container.read(localProfileProvider).valueOrNull, isNull);
    },
  );
  test('a detail refresh cannot expose another account report', () async {
    await db
        .into(db.sessionDetails)
        .insert(
          SessionDetailsCompanion.insert(
            sessionId: 'same-session',
            userId: 'alice',
            reportJson:
                '{"overallScore":70,"summary":"Alice private feedback"}',
          ),
        );
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        firebaseAuthProvider.overrideWithValue(auth),
        firestoreProvider.overrideWithValue(cloud),
        currentUidProvider.overrideWith((ref) => ref.watch(_testUid)),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      sessionReportProvider('same-session'),
      (_, _) {},
    );
    addTearDown(subscription.close);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(
      container
          .read(sessionReportProvider('same-session'))
          .valueOrNull
          ?.summary,
      'Alice private feedback',
    );
    container.read(_testUid.notifier).state = 'bob';
    expect(
      container.read(sessionReportProvider('same-session')).valueOrNull,
      isNull,
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(
      container.read(sessionReportProvider('same-session')).valueOrNull,
      isNull,
    );
  });
  test('malformed cloud metrics are rejected', () {
    final data = <String, dynamic>{
      'userId': 'alice',
      'completedAt': Timestamp.now(),
      'practicePurpose': 'Debate',
      'durationSeconds': 60,
      'starsEarned': 1,
      'scoringVersion': 'v2',
      'overallScore': double.nan,
    };
    expect(ProgressRepository.parseCloudSummary('alice', 's', data), isNull);
    data['overallScore'] = 70;
    data['wordsPerMinute'] = -1;
    expect(ProgressRepository.parseCloudSummary('alice', 's', data), isNull);
  });
  test(
    'interrupted file cleanup leaves deletion retryable and blocks uploads',
    () async {
      await cloud.doc('users/alice').set({'name': 'Alice'});
      await cloud.doc('usernames/alice').set({'uid': 'alice'});
      await expectLater(
        AuthService(
          auth: auth,
          firestore: cloud,
          profiles: profiles,
          database: db,
          cleanupLocalFiles: (_) async =>
              throw StateError('simulated disk failure'),
        ).deleteAccount('password123'),
        throwsA(isA<AuthFailure>()),
      );
      expect(await db.setting('deleting:alice'), 'true');
      expect(await profiles.get('alice'), isNotNull);
      expect(guard.isDeleting('alice'), isTrue);
      expect(auth.currentUser, isNotNull);
      await AuthService(
        auth: auth,
        firestore: cloud,
        profiles: profiles,
        database: db,
        cleanupLocalFiles: (_) async {},
      ).deleteAccount('password123');
      expect(await profiles.get('alice'), isNull);
      expect(await db.setting('deleting:alice'), isNull);
    },
  );
  test(
    'deletion handles more than one batch and prevents later uploads',
    () async {
      for (var i = 0; i < 505; i++) {
        await cloud.doc('users/alice/sessions/s$i').set({'id': i});
      }
      await cloud.doc('users/alice').set({'name': 'Alice'});
      await cloud.doc('usernames/alice').set({'uid': 'alice'});
      await AuthService(
        auth: auth,
        firestore: cloud,
        profiles: profiles,
        database: db,
        cleanupLocalFiles: (_) async {},
      ).deleteAccount('password123');
      expect(
        (await cloud.collection('users/alice/sessions').get()).docs,
        isEmpty,
      );
      expect((await cloud.doc('users/alice').get()).exists, isFalse);
      expect(await profiles.get('alice'), isNull);
      expect(guard.isDeleting('alice'), isTrue);
    },
  );
}

class _UnavailableProfiles extends ProfileRepository {
  _UnavailableProfiles({
    required super.database,
    required super.firestore,
    required super.guard,
  });
  @override
  Future<void> sync(String userId) async {
    throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
  }
}
