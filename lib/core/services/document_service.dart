import 'dart:typed_data';

import '../errors/analysis_failure.dart';
import '../models/document_result.dart';

/// PDF/DOCX/TXT extraction + structural analysis of uploaded scripts.
/// Throws [DocumentUnreadableException] when the file can't be parsed.
abstract class DocumentService {
  Future<DocumentResult> analyze(
    String fileName,
    Uint8List bytes, {
    void Function(String status)? onProgress,
  });
}
