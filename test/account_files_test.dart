import 'dart:io';

import 'package:app_builder_hackathon/data/storage/account_files_io.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'deletion removes referenced account files and retains other data',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'pipspeak-files-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final documents = await Directory('${directory.path}/documents').create();
      Future<File> file(String name) =>
          File(name).writeAsString('private data');
      final owned = await file('${documents.path}/practice_100.wav');
      final other = await file('${documents.path}/practice_200.wav');
      final photo = await file('${documents.path}/profile_alice.jpg');
      final otherPhoto = await file('${documents.path}/profile_bob.jpg');
      final model = await file('${documents.path}/qwen-model.gguf');
      final original = await file('${documents.path}/original_speech.wav');
      final outside = await file('${directory.path}/practice_300.wav');

      await deleteOwnedAccountFiles(
        documentsDirectory: documents.path,
        userId: 'alice',
        audioPaths: [owned.path, outside.path, original.path],
        photoPath: photo.path,
      );
      expect(await owned.exists(), isFalse);
      expect(await photo.exists(), isFalse);
      for (final retained in [other, otherPhoto, model, original, outside]) {
        expect(await retained.exists(), isTrue, reason: retained.path);
      }
      // Retrying a partial deletion is harmless when files are already gone.
      await deleteOwnedAccountFiles(
        documentsDirectory: documents.path,
        userId: 'alice',
        audioPaths: [owned.path],
        photoPath: photo.path,
      );
    },
  );

  test(
    'deletion never follows a recording symlink',
    () async {
      final directory = await Directory.systemTemp.createTemp('pipspeak-link-');
      addTearDown(() => directory.delete(recursive: true));
      final original = await File('${directory.path}/speech.txt')
          .writeAsString('original');
      final link = await Link('${directory.path}/practice_400.wav')
          .create(original.path);
      await deleteOwnedAccountFiles(
        documentsDirectory: directory.path,
        userId: 'alice',
        audioPaths: [link.path],
      );
      expect(await original.exists(), isTrue);
      expect(await link.exists(), isTrue);
    },
    skip: Platform.isWindows
        ? 'Creating symlinks requires Windows Developer Mode or elevation.'
        : false,
  );
}
