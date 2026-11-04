import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/feedback_report.dart';
import '../core/models/practice_session.dart';
import '../data/codecs/analysis_codec.dart';
import '../core/models/user_profile.dart';
import '../data/local/app_database.dart';
import '../data/repositories/account_guard.dart';
import '../data/repositories/document_repository.dart';
import '../data/repositories/profile_repository.dart';
import '../data/repositories/progress_repository.dart';
import '../features/auth/services/auth_service.dart';
import '../features/progress/services/level_service.dart';
import 'theme/theme_controller.dart';

// --------------------------------------------------------------- Storage
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (_) => FirebaseAuth.instance,
);
final firestoreProvider = Provider<FirebaseFirestore>(
  (_) => FirebaseFirestore.instance,
);

final accountGuardProvider = Provider<AccountGuard>(
  (ref) => AccountGuard(ref.watch(firebaseAuthProvider)),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(
    database: ref.watch(appDatabaseProvider),
    firestore: ref.watch(firestoreProvider),
    guard: ref.watch(accountGuardProvider),
  ),
);

final progressRepositoryProvider = Provider<ProgressRepository>(
  (ref) => ProgressRepository(
    database: ref.watch(appDatabaseProvider),
    firestore: ref.watch(firestoreProvider),
    guard: ref.watch(accountGuardProvider),
    profiles: ref.watch(profileRepositoryProvider),
  ),
);

final documentRepositoryProvider = Provider<DocumentRepository>(
  (ref) => DocumentRepository(
    ref.watch(appDatabaseProvider),
    guard: ref.watch(accountGuardProvider),
  ),
);

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(
    auth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firestoreProvider),
    profiles: ref.watch(profileRepositoryProvider),
    database: ref.watch(appDatabaseProvider),
  ),
);

// ------------------------------------------------------------------ Theme
final themeModeProvider = StateNotifierProvider<ThemeModeController, ThemeMode>(
  (ref) => ThemeModeController(ref.watch(appDatabaseProvider)),
);

// ---------------------------------------------------------------- Account
final authUserProvider = StreamProvider<User?>(
  (ref) => ref.watch(firebaseAuthProvider).authStateChanges(),
);

/// Firebase UID of the signed-in account; every query is scoped to it.
final currentUidProvider = Provider<String?>(
  (ref) => ref.watch(authUserProvider).valueOrNull?.uid,
);

// Key each stream by UID. A single rebuilding StreamProvider can retain its
// previous AsyncData while refreshing, briefly exposing the old account.
final _profilesForUidProvider = StreamProvider.family<LocalProfile?, String>(
  (ref, uid) => ref.watch(profileRepositoryProvider).watch(uid),
);
final localProfileProvider = Provider<AsyncValue<LocalProfile?>>((ref) {
  final uid = ref.watch(currentUidProvider);
  return uid == null
      ? const AsyncData(null)
      : ref.watch(_profilesForUidProvider(uid));
});

final _recordsForUidProvider =
    StreamProvider.family<List<PracticeRecord>, String>(
      (ref, uid) => ref.watch(progressRepositoryProvider).watchRecords(uid),
    );
final practiceRecordsProvider = Provider<AsyncValue<List<PracticeRecord>>>((
  ref,
) {
  final uid = ref.watch(currentUidProvider);
  return uid == null
      ? const AsyncData([])
      : ref.watch(_recordsForUidProvider(uid));
});

/// Saved sessions that count toward progress (developer/test excluded).
final genuineRecordsProvider = Provider<List<PracticeRecord>>((ref) {
  final records = ref.watch(practiceRecordsProvider).valueOrNull ?? const [];
  return [
    for (final r in records)
      if (!r.isTest) r,
  ];
});

final _pendingForUidProvider = StreamProvider.family<int, String>(
  (ref, uid) => ref.watch(progressRepositoryProvider).watchPendingCount(uid),
);
final pendingSyncCountProvider = Provider<AsyncValue<int>>((ref) {
  final uid = ref.watch(currentUidProvider);
  return uid == null
      ? const AsyncData(0)
      : ref.watch(_pendingForUidProvider(uid));
});

final levelStatusProvider = Provider<LevelStatus>((ref) {
  final total = ref
      .watch(genuineRecordsProvider)
      .fold<int>(0, (total, r) => total + r.starsEarned);
  return LevelService.fromTotalStars(total);
});

/// Consecutive local calendar days (ending today or yesterday) with practice.
int practiceStreak(List<PracticeRecord> records, DateTime now) {
  final days = {
    for (final r in records) DateUtils.dateOnly(r.completedAt.toLocal()),
  };
  var day = DateUtils.dateOnly(now);
  if (!days.contains(day)) day = day.subtract(const Duration(days: 1));
  var streak = 0;
  while (days.contains(day)) {
    streak++;
    day = day.subtract(const Duration(days: 1));
  }
  return streak;
}

/// The signed-in account as shown across the app, built from SQLite.
final currentUserProvider = Provider<UserProfile?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  final candidate = ref.watch(localProfileProvider).valueOrNull;
  final profile = candidate?.userId == uid ? candidate : null;
  final firebaseUser = ref.watch(authUserProvider).valueOrNull;
  final records = ref.watch(genuineRecordsProvider);
  final level = ref.watch(levelStatusProvider);
  final fallbackName = firebaseUser?.displayName?.trim().isNotEmpty == true
      ? firebaseUser!.displayName!
      : 'Speaker';
  return UserProfile(
    uid: uid,
    name: profile?.fullName ?? fallbackName,
    nickname: profile?.nickname ?? fallbackName.split(' ').first,
    email: firebaseUser?.email ?? profile?.email ?? '',
    username: profile?.username ?? '',
    photoPath: profile?.photoPath,
    level: level.level,
    stars: level.starsIntoLevel,
    streakDays: practiceStreak(records, DateTime.now()),
    totalSessions: records.length,
    school: profile?.school ?? '',
    language: profile?.language ?? 'English (US)',
    goal: profile?.practicePurpose ?? 'Class Presentation',
  );
});

PracticeSession practiceSessionFromRecord(
  PracticeRecord record, {
  PracticeRecord? previous,
}) {
  return PracticeSession(
    id: record.id,
    date: record.completedAt.toLocal(),
    title: record.topic.isNotEmpty ? record.topic : record.practicePurpose,
    duration: Duration(seconds: record.durationSeconds),
    avgWpm: (record.wordsPerMinute ?? 0).round(),
    fillerCount: record.fillerCount ?? 0,
    eyeContactPct: null, // Pose landmarks do not measure eye contact.
    paceScore: (record.overallScore ?? 0).round(),
    starsEarned: record.starsEarned,
    improved: record.starsEarned > 0,
    goal: record.practicePurpose,
  );
}

/// Saved practice history, newest first.
final sessionHistoryProvider = Provider<List<PracticeSession>>((ref) {
  return [
    for (final r in ref.watch(genuineRecordsProvider))
      practiceSessionFromRecord(r),
  ];
});

/// Key detail requests by account as well as session ID. Refreshing the same
/// session in a different account must never retain the previous AsyncData.
final _sessionReportForOwnerProvider =
    FutureProvider.family<FeedbackReport?, (String, String)>((
      ref,
      owner,
    ) async {
      final detail = await ref
          .watch(progressRepositoryProvider)
          .detail(owner.$1, owner.$2);
      return detail == null
          ? null
          : AnalysisCodec.decodeReport(detail.reportJson);
    });

/// Saved local feedback (null if analyzed on another device).
final sessionReportProvider =
    Provider.family<AsyncValue<FeedbackReport?>, String>((ref, sessionId) {
      final uid = ref.watch(currentUidProvider);
      return uid == null
          ? const AsyncData(null)
          : ref.watch(_sessionReportForOwnerProvider((uid, sessionId)));
    });
