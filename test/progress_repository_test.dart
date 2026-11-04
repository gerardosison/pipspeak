import 'package:app_builder_hackathon/core/models/feedback_report.dart';
import 'package:app_builder_hackathon/core/models/speech_metrics.dart';
import 'package:app_builder_hackathon/data/local/app_database.dart';
import 'package:app_builder_hackathon/data/repositories/account_guard.dart';
import 'package:app_builder_hackathon/data/repositories/profile_repository.dart';
import 'package:app_builder_hackathon/data/repositories/progress_repository.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

FeedbackReport report(double score) => FeedbackReport(
  overallScore: score,
  summary: 'summary',
  strengths: const [],
  improvements: const [],
  evidenceList: const [],
  limitations: const [],
  generatedAt: DateTime.utc(2026, 1, 1),
);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late FakeFirebaseFirestore firestore;
  late MockFirebaseAuth auth;
  late ProgressRepository progress;
  late ProfileRepository profiles;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    firestore = FakeFirebaseFirestore();
    auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'alice', email: 'a@x.com'),
    );
    final guard = AccountGuard(auth);
    profiles = ProfileRepository(
      database: db,
      firestore: firestore,
      guard: guard,
    );
    progress = ProgressRepository(
      database: db,
      firestore: firestore,
      guard: guard,
      profiles: profiles,
    );
    await profiles.save(
      userId: 'alice',
      fullName: 'Alice A',
      nickname: 'Alice',
      language: 'en-US',
      practicePurpose: 'presentation',
      onboardingComplete: true,
    );
  });

  tearDown(() => db.close());

  Future<PracticeRecord> save(
    String id,
    double score, {
    String uid = 'alice',
    bool isTest = false,
  }) => progress.saveCompletedPractice(
    userId: uid,
    sessionId: id,
    practicePurpose: 'presentation',
    language: 'en-US',
    topic: 'Topic',
    durationSeconds: 60,
    report: report(score),
    isTest: isTest,
  );

  test('first session is a baseline; improvement earns stars once', () async {
    final first = await save('s1', 60);
    expect(first.starsEarned, 0);
    expect(first.needsUpload, isTrue);
    final second = await save('s2', 66);
    expect(second.starsEarned, 2);
    final retry = await save('s2', 99);
    expect(retry.starsEarned, 2, reason: 'retry must not re-award');
    expect(await db.pendingRecords('alice'), hasLength(2));
  });

  test('full feedback is stored locally and decoded', () async {
    await save('s1', 70);
    final detail = await progress.detail('alice', 's1');
    expect(detail, isNotNull);
    expect(detail!.reportJson, contains('summary'));
  });

  test('test sessions do not count as compatible history', () async {
    await save('t1', 40, isTest: true);
    final real = await save('s1', 80);
    expect(real.starsEarned, 0, reason: 'still the genuine baseline');
  });

  test('records are scoped to the account', () async {
    await save('s1', 70);
    expect(await db.pendingRecords('bob'), isEmpty);
    expect(await progress.record('bob', 's1'), isNull);
  });

  test(
    'invalid optional metrics do not prevent saving or synchronizing',
    () async {
      final saved = await progress.saveCompletedPractice(
        userId: 'alice',
        sessionId: 'invalid-metrics',
        practicePurpose: 'presentation',
        language: 'en-US',
        topic: 'Speech',
        durationSeconds: 60,
        report: report(70),
        speech: SpeechMetrics.sample(
          transcript: 'A genuine transcript',
          wpm: double.infinity,
          fillers: -3,
        ),
      );
      expect(saved.wordsPerMinute, isNull);
      expect(saved.fillerCount, isNull);
      expect(
        (await progress.detail('alice', saved.id))!.transcript,
        'A genuine transcript',
      );
      await progress.sync('alice');
      final cloud =
          (await firestore.doc('users/alice/sessions/${saved.id}').get())
              .data()!;
      expect(cloud.containsKey('wordsPerMinute'), isFalse);
      expect(cloud.containsKey('fillerCount'), isFalse);
      expect((await progress.record('alice', saved.id))!.needsUpload, isFalse);
    },
  );

  test('sync uploads summaries only and marks them uploaded', () async {
    await save('s1', 70);
    await progress.sync('alice');
    final cloud = await firestore.doc('users/alice/sessions/s1').get();
    expect(cloud.exists, isTrue);
    expect(cloud.data()!.containsKey('transcript'), isFalse);
    expect(cloud.data()!['userId'], 'alice');
    expect(await db.pendingRecords('alice'), isEmpty);
    // Retrying is idempotent.
    await progress.sync('alice');
    final all = await firestore.collection('users/alice/sessions').get();
    expect(all.docs, hasLength(1));
  });

  test('sync for a different signed-in account is refused', () async {
    await save('s1', 70);
    await auth.signOut();
    await expectLater(progress.sync('alice'), throwsA(anything));
    expect(await db.pendingRecords('alice'), hasLength(1));
  });

  test('cloud summaries download without overwriting local data', () async {
    await firestore.doc('users/alice/sessions/remote').set({
      'userId': 'alice',
      'completedAt': DateTime.utc(2026, 1, 2),
      'practicePurpose': 'presentation',
      'language': 'en-US',
      'durationSeconds': 30,
      'starsEarned': 1,
      'scoringVersion': 'v1',
      'isTest': false,
      'overallScore': 75.0,
    });
    await save('s1', 70);
    await progress.sync('alice');
    final remote = await progress.record('alice', 'remote');
    expect(remote, isNotNull);
    expect(remote!.hasLocalDetails, isFalse);
    expect((await progress.record('alice', 's1'))!.overallScore, 70);
  });
}
