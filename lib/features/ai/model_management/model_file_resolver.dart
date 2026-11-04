import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// Android copies and verifies assets using bounded native buffers, so loading
/// a several-hundred-MB model does not duplicate it in the Dart heap.
Future<String> resolveQwenModel() async {
  if (kIsWeb || !Platform.isAndroid) {
    throw UnsupportedError(
      'The bundled Qwen runtime requires a supported 64-bit Android device.',
    );
  }
  const channel = MethodChannel('com.hawkabuild.app/ai');
  final path = await channel.invokeMethod<String>('prepareQwenModel');
  if (path == null || path.isEmpty) {
    throw StateError('The Android runtime did not provide a Qwen model path.');
  }
  await validateGgufHeader(File(path));
  return path;
}

/// Cheap format check after the native resolver has checked the full artifact's
/// trusted SHA-256 and size. This alone is not an integrity/authenticity check.
Future<void> validateGgufHeader(File file) async {
  if (!await file.exists()) {
    throw StateError('Qwen model file is missing: ${file.path}');
  }
  final input = await file.open();
  try {
    final length = await input.length();
    final header = await input.read(24);
    if (length < 1024 * 1024 || header.length != 24) {
      throw const FormatException(
        'Qwen model is incomplete or is a placeholder.',
      );
    }
    final bytes = ByteData.sublistView(header);
    final magic = String.fromCharCodes(header.take(4));
    final version = bytes.getUint32(4, Endian.little);
    final tensors = bytes.getUint64(8, Endian.little);
    final metadata = bytes.getUint64(16, Endian.little);
    if (magic != 'GGUF' ||
        (version != 2 && version != 3) ||
        tensors == 0 ||
        tensors > 100000 ||
        metadata == 0 ||
        metadata > 100000) {
      throw const FormatException(
        'Qwen model has an invalid or unsupported GGUF header. '
        'Prepare the official Qwen3 0.6B Q8_0 artifact again.',
      );
    }
  } finally {
    await input.close();
  }
}
