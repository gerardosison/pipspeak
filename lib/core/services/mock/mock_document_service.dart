import 'dart:typed_data';

import '../../errors/analysis_failure.dart';
import '../../models/document_result.dart';
import '../document_service.dart';

/// Lightweight fixture service for UI previews; production uses LocalDocumentService.
class MockDocumentService implements DocumentService {
  @override
  Future<DocumentResult> analyze(
    String fileName,
    Uint8List bytes, {
    void Function(String status)? onProgress,
  }) async {
    onProgress?.call('Reading your script…');
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (fileName.toLowerCase().contains('scan') ||
        fileName.toLowerCase().contains('image')) {
      throw const DocumentUnreadableException();
    }
    return DocumentResult(
      documentId: 'mock-document',
      title: fileName,
      extractedText: 'Sample presentation content for a UI preview.',
      wordCount: 7,
      estimatedMinutes: 0.1,
      coveredTopics: const ['Sample topic (preview data)'],
    );
  }
}
