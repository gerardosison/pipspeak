import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../local/app_database.dart';

Future<void> removeAccountFiles(AppDatabase database, String userId) async {
  final details = await (database.select(
    database.sessionDetails,
  )..where((row) => row.userId.equals(userId))).get();
  final profile = await (database.select(
    database.userProfiles,
  )..where((row) => row.userId.equals(userId))).getSingleOrNull();
  await deleteOwnedAccountFiles(
    documentsDirectory: (await getApplicationDocumentsDirectory()).path,
    userId: userId,
    audioPaths: details.map((row) => row.audioPath).whereType<String>(),
    photoPath: profile?.photoPath,
  );
}

/// Only remove referenced, app-created files in private application storage.
/// A malformed legacy path must never delete a user-selected original file or
/// another account's recording. Shared model weights are retained.
Future<void> deleteOwnedAccountFiles({
  required String documentsDirectory,
  required String userId,
  required Iterable<String> audioPaths,
  String? photoPath,
}) async {
  final root = p.normalize(p.absolute(documentsDirectory));
  final targets = <String>{};
  for (final path in audioPaths) {
    if (RegExp(r'^practice_\d+\.wav$').hasMatch(p.basename(path))) {
      targets.add(path);
    }
  }
  if (photoPath != null &&
      !photoPath.startsWith('data:') &&
      p.basename(photoPath) == 'profile_$userId.jpg') {
    targets.add(photoPath);
  }
  for (final path in targets) {
    final normalized = p.normalize(p.absolute(path));
    if (p.dirname(normalized) != root) continue;
    // Do not follow links, even when their names look like application files.
    final type = await FileSystemEntity.type(normalized, followLinks: false);
    if (type == FileSystemEntityType.file) await File(normalized).delete();
  }
}
