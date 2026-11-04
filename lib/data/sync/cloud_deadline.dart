import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore writes may stay queued indefinitely while offline. Stop waiting in
/// the foreground UI without clearing the durable SQLite upload flag. A late
/// server acknowledgement is safe: retries use the same immutable session ID.
Future<T> withCloudDeadline<T>(Future<T> operation) => operation.timeout(
  const Duration(seconds: 20),
  onTimeout: () => throw FirebaseException(
    plugin: 'cloud_firestore',
    code: 'deadline-exceeded',
    message: 'Cloud unreachable. Changes remain saved on this device.',
  ),
);
