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
  (ref) => DocumentRepository(ref.watch(appDatabaseProvider)),
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

final localProfileProvider = StreamProvider<LocalProfile?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(profileRepositoryProvider).watch(uid);
});

final practiceRecordsProvider = StreamProvider<List<PracticeRecord>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(progressRepositoryProvider).watchRecords(uid);
});

/// Saved sessions that count toward progress (developer/test excluded).
final genuineRecordsProvider = Provider<List<PracticeRecord>>((ref) {
  final records = ref.watch(practiceRecordsProvider).valueOrNull ?? const [];
  return [
    for (final r in records)
      if (!r.isTest) r,
  ];
});

final pendingSyncCountProvider = StreamProvider<int>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(0);
  return ref.watch(progressRepositoryProvider).watchPendingCount(uid);
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
  final profile = ref.watch(localProfileProvider).valueOrNull;
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

/// Saved local feedback for a session (null if analyzed on another device).
final sessionReportProvider = FutureProvider.family<FeedbackReport?, String>((
  ref,
  sessionId,
) async {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  final detail = await ref
      .watch(progressRepositoryProvider)
      .detail(uid, sessionId);
  return detail == null ? null : AnalysisCodec.decodeReport(detail.reportJson);
});
