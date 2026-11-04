import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../local/app_database.dart';
import '../sync/cloud_deadline.dart';
import 'account_guard.dart';

class UsernameTakenException implements Exception {
  const UsernameTakenException();

  @override
  String toString() => 'That username is already taken.';
}

/// Local-first profile storage with revision-checked Firestore sync.
class ProfileRepository {
  ProfileRepository({
    required this.database,
    required this.firestore,
    required this.guard,
  });

  final AppDatabase database;
  final FirebaseFirestore firestore;
  final AccountGuard guard;

  static final _usernamePattern = RegExp(r'^[a-z0-9_.]{3,20}$');

  static String normalizeUsername(String value) => value.trim().toLowerCase();

  static bool isValidUsername(String value) =>
      _usernamePattern.hasMatch(normalizeUsername(value));

  Stream<LocalProfile?> watch(String userId) {
    return (database.select(
      database.userProfiles,
    )..where((row) => row.userId.equals(userId))).watchSingleOrNull();
  }

  Future<LocalProfile?> get(String userId) {
    return (database.select(
      database.userProfiles,
    )..where((row) => row.userId.equals(userId))).getSingleOrNull();
  }

  static String _nicknameFrom(String name) {
    final short = StringBuffer();
    for (final rune in name.split(' ').first.runes) {
      final character = String.fromCharCode(rune);
      if (short.length + character.length > 40) break;
      short.write(character);
    }
    return short.toString();
  }

  /// Saves the profile locally and marks it for upload.
  Future<void> save({
    required String userId,
    required String fullName,
    required String nickname,
    required String language,
    required String practicePurpose,
    required bool onboardingComplete,
    String? username,
    String? email,
    String? school,
    Value<String?> photoPath = const Value.absent(),
  }) async {
    guard.check(userId);
    final name = fullName.trim();
    final nick = nickname.trim();
    if (userId.isEmpty || name.isEmpty || name.length > 80) {
      throw ArgumentError('Enter your full name (up to 80 characters).');
    }
    if (nick.length > 40) {
      throw ArgumentError('Nickname must be 40 characters or fewer.');
    }
    if (language.trim().isEmpty ||
        language.length > 40 ||
        practicePurpose.trim().isEmpty ||
        practicePurpose.length > 120 ||
        (school != null && school.trim().length > 80) ||
        (username != null &&
            username.isNotEmpty &&
            !isValidUsername(username))) {
      throw ArgumentError(
        'Choose a valid language, practice goal, school and username.',
      );
    }
    guard.check(userId);
    await database
        .into(database.userProfiles)
        .insertOnConflictUpdate(
          UserProfilesCompanion(
            userId: Value(userId),
            fullName: Value(name),
            nickname: Value(nick.isEmpty ? _nicknameFrom(name) : nick),
            language: Value(language),
            practicePurpose: Value(practicePurpose),
            onboardingComplete: Value(onboardingComplete),
            revision: Value(const Uuid().v4()),
            needsUpload: const Value(true),
            username: username == null
                ? const Value.absent()
                : Value(normalizeUsername(username)),
            email: email == null ? const Value.absent() : Value(email),
            school: school == null
                ? const Value.absent()
                : Value(school.trim()),
            photoPath: photoPath,
          ),
        );
  }

  /// Updates device-local fields that are never uploaded.
  Future<void> setPhotoPath(String userId, String? path) async {
    guard.check(userId);
    await (database.update(database.userProfiles)
          ..where((row) => row.userId.equals(userId)))
        .write(UserProfilesCompanion(photoPath: Value(path)));
  }

  Future<void> sync(String userId) async {
    guard.check(userId);
    final document = firestore.collection('users').doc(userId);
    final local = await get(userId);

    if (local != null && local.needsUpload) {
      guard.check(userId);
      final data = <String, Object?>{
        'fullName': local.fullName,
        'nickname': local.nickname,
        'username': local.username,
        'language': local.language,
        'practicePurpose': local.practicePurpose,
        'school': local.school,
        'onboardingComplete': local.onboardingComplete,
        'revision': local.revision,
        'updatedAt': FieldValue.serverTimestamp(),
      }..removeWhere((_, value) => value == null);
      await withCloudDeadline(document.set(data));
      guard.check(userId);
      // Only clear the flag if no newer local edit happened meanwhile.
      await (database.update(database.userProfiles)..where(
            (row) =>
                row.userId.equals(userId) & row.revision.equals(local.revision),
          ))
          .write(const UserProfilesCompanion(needsUpload: Value(false)));
      return;
    }

    final snapshot = await withCloudDeadline(
      document.get(const GetOptions(source: Source.server)),
    );
    guard.check(userId);
    final root = snapshot.data();
    if (root == null) return;
    final legacy = root['profile'];
    final data = root['fullName'] is String
        ? root
        : (legacy is Map ? Map<String, dynamic>.from(legacy) : root);
    String text(String key, [String fallback = '']) =>
        data[key] is String ? data[key] as String : fallback;
    final fullName = text('fullName').trim();
    final nickname = text('nickname', fullName).trim();
    final revision = text('revision');
    final language = text('language', 'English (US)');
    final purpose = text('practicePurpose', 'Class Presentation');
    final school = text('school');
    final username = text('username');
    if (fullName.isEmpty ||
        fullName.length > 80 ||
        nickname.length > 40 ||
        revision.isEmpty ||
        revision.length > 64 ||
        language.isEmpty ||
        language.length > 40 ||
        purpose.isEmpty ||
        purpose.length > 120 ||
        school.length > 80 ||
        username.length > 20) {
      return;
    }
    // The read and replacement must share the SQLite transaction. Otherwise a
    // local edit between a preliminary check and the write could be lost.
    await database.transaction(() async {
      guard.check(userId);
      final latest = await get(userId);
      if (latest != null && latest.needsUpload) return;
      guard.check(userId);
      await database
          .into(database.userProfiles)
          .insertOnConflictUpdate(
            UserProfilesCompanion(
              userId: Value(userId),
              fullName: Value(fullName),
              nickname: Value(nickname),
              username: Value(username),
              language: Value(language),
              practicePurpose: Value(purpose),
              school: Value(school),
              onboardingComplete: Value(data['onboardingComplete'] == true),
              revision: Value(revision),
              // Migrate the older nested profile format on the next upload.
              needsUpload: Value(!identical(data, root)),
            ),
          );
    });
  }

  /// A cloud reservation exposes UID only, never an account email.
  Future<void> reserveUsername({
    required String userId,
    required String username,
    required String email,
  }) async {
    guard.check(userId);
    final name = normalizeUsername(username);
    if (!isValidUsername(name)) {
      throw ArgumentError(
        'Usernames use 3–20 lowercase letters, numbers, dots or underscores.',
      );
    }
    final document = firestore.collection('usernames').doc(name);
    await firestore.runTransaction((transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> existing;
      try {
        existing = await transaction.get(document);
      } on FirebaseException catch (error) {
        if (error.code == 'permission-denied') {
          throw const UsernameTakenException();
        }
        rethrow;
      }
      guard.check(userId);
      if (existing.exists && existing.data()?['uid'] != userId) {
        throw const UsernameTakenException();
      }
      // Also removes the email field from an owned legacy reservation.
      transaction.set(document, {'uid': userId});
    });
  }

  Future<bool> isUsernameAvailable(String username) async {
    final name = normalizeUsername(username);
    if (!isValidUsername(name)) return false;
    try {
      final snapshot = await firestore.collection('usernames').doc(name).get();
      return !snapshot.exists;
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') return false;
      rethrow;
    }
  }

  /// Convenience for a previously used account on this device only. On a new
  /// device, email is required; no public username-to-email directory is queried.
  Future<String?> emailForUsername(String username) async {
    final name = normalizeUsername(username);
    if (!isValidUsername(name)) return null;
    final rows = await (database.select(
      database.userProfiles,
    )..where((row) => row.username.equals(name))).get();
    final emails = rows
        .map((row) => row.email)
        .where((email) => email.isNotEmpty)
        .toSet();
    return emails.length == 1 ? emails.single : null;
  }
}
