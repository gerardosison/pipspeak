import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart' show Value;

import '../../../data/local/app_database.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../data/storage/account_files.dart';

/// User-facing authentication error.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Firebase email/password authentication. Firebase keeps the session on
/// the device, so a signed-in user can reopen the app offline.
class AuthService {
  AuthService({
    required this.auth,
    required this.firestore,
    required this.profiles,
    required this.database,
    this.cleanupLocalFiles,
  });

  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final ProfileRepository profiles;
  final AppDatabase database;
  final Future<void> Function(String userId)? cleanupLocalFiles;
  final Map<String, Future<void>> _openingProfiles = {};

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static bool isValidEmail(String value) =>
      _emailPattern.hasMatch(value.trim());

  /// Signs in with an email address or a registered username.
  Future<User> signIn(String identifier, String password) async {
    final id = identifier.trim();
    if (id.isEmpty || password.isEmpty) {
      throw const AuthFailure('Enter your email or username and password.');
    }
    var email = id;
    if (!id.contains('@')) {
      try {
        email = await profiles.emailForUsername(id) ?? '';
      } on FirebaseException catch (error) {
        debugPrint('emailForUsername failed: ${error.code} ${error.message}');
        throw const AuthFailure(
          'Could not look up that username. Check your connection or sign '
          'in with your email.',
        );
      }
      if (email.isEmpty) {
        throw const AuthFailure(
          'Use your email the first time you sign in on this device. Username sign-in is available after your profile is saved here.',
        );
      }
    }
    try {
      final credential = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user!;
      await ensureLocalProfile(user);
      return user;
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_message(error));
    }
  }

  Future<User> register({
    required String fullName,
    required String nickname,
    required String username,
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim();
    if (fullName.trim().isEmpty ||
        fullName.trim().length > 80 ||
        nickname.trim().length > 40) {
      throw const AuthFailure(
        'Use a full name up to 80 characters and nickname up to 40 characters.',
      );
    }
    if (!isValidEmail(cleanEmail)) {
      throw const AuthFailure('Enter a valid email address.');
    }
    if (!ProfileRepository.isValidUsername(username)) {
      throw const AuthFailure(
        'Usernames use 3–20 lowercase letters, numbers, dots or underscores.',
      );
    }
    if (password.length < 8) {
      throw const AuthFailure('Use at least 8 characters for your password.');
    }

    final UserCredential credential;
    try {
      credential = await auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      debugPrint('createUser failed: ${error.code} ${error.message}');
      throw AuthFailure(_message(error));
    }
    final user = credential.user!;
    try {
      await profiles.reserveUsername(
        userId: user.uid,
        username: username,
        email: cleanEmail,
      );
    } on Object catch (error, stack) {
      // Shows the real cause in the terminal (e.g. permission-denied).
      debugPrint('reserveUsername failed: $error\n$stack');
      // Roll back the account so the user can retry with another username.
      await user.delete().catchError((_) {});
      if (error is UsernameTakenException) {
        throw const AuthFailure('That username is already taken.');
      }
      if (error is FirebaseException) {
        throw AuthFailure(
          'Could not reserve your username (${error.code}). '
          'Check your connection and retry.',
        );
      }
      throw const AuthFailure(
        'Could not reserve your username. Check your connection and retry.',
      );
    }
    await user.updateDisplayName(fullName.trim()).catchError((_) {});
    await profiles.save(
      userId: user.uid,
      fullName: fullName,
      nickname: nickname,
      language: 'English (US)',
      practicePurpose: 'Class Presentation',
      onboardingComplete: false,
      username: username,
      email: cleanEmail,
    );
    return user;
  }

  Future<void> sendPasswordReset(String email) async {
    if (!isValidEmail(email)) {
      throw const AuthFailure('Enter the email address for your account.');
    }
    try {
      await auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_message(error));
    }
  }

  Future<void> changePassword(String current, String next) async {
    final user = auth.currentUser;
    if (user == null || user.email == null) {
      throw const AuthFailure('Sign in again to change your password.');
    }
    if (next.length < 8) {
      throw const AuthFailure('Use at least 8 characters for your password.');
    }
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: user.email!, password: current),
      );
      await user.updatePassword(next);
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_message(error));
    }
  }

  /// Deletes cloud data, the Firebase account and this device's local data.
  /// Requires a network connection and the current password.
  Future<void> deleteAccount(String password) async {
    final user = auth.currentUser;
    if (user == null || user.email == null) {
      throw const AuthFailure('Sign in again to delete your account.');
    }
    final uid = user.uid;
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: user.email!, password: password),
      );
      await database.setSetting('deleting:$uid', 'true');
      profiles.guard.pauseForDeletion(uid);
      final userDoc = firestore.collection('users').doc(uid);
      // Paginate; a Firestore batch cannot contain an unbounded account history.
      while (true) {
        final sessions = await userDoc
            .collection('sessions')
            .limit(250)
            .get(const GetOptions(source: Source.server));
        if (sessions.docs.isEmpty) break;
        final batch = firestore.batch();
        for (final doc in sessions.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
      final profile = await profiles.get(uid);
      final username = profile?.username ?? '';
      if (username.isNotEmpty) {
        final reservation = firestore.collection('usernames').doc(username);
        final snapshot = await reservation.get(
          const GetOptions(source: Source.server),
        );
        if (snapshot.exists && snapshot.data()?['uid'] == uid) {
          await reservation.delete();
        }
      }
      await userDoc.delete();
      // Erase account-owned recordings before removing the credentials needed
      // to retry deletion. Database rows remain until all cleanup succeeds.
      await (cleanupLocalFiles?.call(uid) ?? removeAccountFiles(database, uid));
      await user.delete();
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_message(error));
    } on FirebaseException catch (error) {
      throw AuthFailure(
        'Could not delete cloud data (${error.code}). Check your '
        'connection and try again.',
      );
    } on Object {
      throw const AuthFailure(
        'Account deletion did not finish. Your remaining local data is preserved. Retry deletion while connected.',
      );
    }
    await database.deleteAccountData(uid);
    await database.removeSetting('deleting:$uid');
  }

  Future<void> signOut() => auth.signOut();

  /// Opens a cached profile immediately, including offline. A device without a
  /// cached profile must confirm the cloud state before creating local defaults.
  Future<void> ensureLocalProfile(User user) =>
      _openingProfiles[user.uid] ??= _openLocalProfile(user).whenComplete(() {
        _openingProfiles.remove(user.uid);
      });

  Future<void> _openLocalProfile(User user) async {
    profiles.guard.check(user.uid);
    final existing = await profiles.get(user.uid);
    profiles.guard.check(user.uid);
    if (existing != null) {
      await _cacheEmail(user);
      return;
    }
    try {
      await profiles.sync(user.uid);
    } on Object {
      profiles.guard.check(user.uid);
      throw const AuthFailure(
        'Connect to the internet to load your saved profile on this device, then retry. Your cloud profile has not been replaced.',
      );
    }
    profiles.guard.check(user.uid);
    final downloaded = await profiles.get(user.uid);
    profiles.guard.check(user.uid);
    if (downloaded != null) {
      await _cacheEmail(user);
      return;
    }
    final name = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!
        : (user.email ?? 'Speaker').split('@').first;
    await profiles.save(
      userId: user.uid,
      fullName: name,
      nickname: '',
      language: 'English (US)',
      practicePurpose: 'Class Presentation',
      onboardingComplete: false,
      email: user.email,
    );
  }

  Future<void> _cacheEmail(User user) async {
    profiles.guard.check(user.uid);
    if (user.email == null) return;
    await (database.update(database.userProfiles)
          ..where((row) => row.userId.equals(user.uid)))
        .write(UserProfilesCompanion(email: Value(user.email!)));
  }

  static String _message(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email/username or password.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'Choose a stronger password.';
      case 'too-many-requests':
        return 'Too many attempts. Wait a moment and try again.';
      case 'network-request-failed':
        return 'No connection. Connect to the internet and try again.';
      case 'requires-recent-login':
        return 'Please sign in again and retry.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled for this Firebase '
            'project.';
      default:
        return error.message ?? 'Authentication failed (${error.code}).';
    }
  }
}
