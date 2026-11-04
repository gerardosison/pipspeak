import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/models/document_result.dart';
import '../codecs/analysis_codec.dart';
import '../local/app_database.dart';
import 'account_guard.dart';

/// Device-local document analysis history. Raw documents and extracted
/// text are never uploaded.
class DocumentRepository {
  DocumentRepository(this.database, {required this.guard});

  final AppDatabase database;
  final AccountGuard guard;

  Future<DocumentResult> save(String userId, DocumentResult result) async {
    guard.check(userId);
    if (userId.isEmpty) throw ArgumentError('Sign in to save documents.');
    var id = result.documentId.isEmpty ? const Uuid().v4() : result.documentId;
    final existing = await (database.select(
      database.localDocuments,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (existing != null && existing.userId != userId) id = const Uuid().v4();
    guard.check(userId);
    final stored = DocumentResult(
      documentId: id,
      aiAnalyzed: result.aiAnalyzed,
      isReadable: result.isReadable,
      rejectionReason: result.rejectionReason,
      title: result.title,
      extractedText: result.extractedText,
      keySections: result.keySections,
      coveredTopics: result.coveredTopics,
      missingOrWeakTopics: result.missingOrWeakTopics,
      speechImprovements: result.speechImprovements,
      wordCount: result.wordCount,
      estimatedMinutes: result.estimatedMinutes,
    );
    await database
        .into(database.localDocuments)
        .insertOnConflictUpdate(
          LocalDocumentsCompanion.insert(
            id: id,
            userId: userId,
            title: result.title,
            wordCount: Value(result.wordCount),
            resultJson: AnalysisCodec.encodeDocument(stored),
            createdAt: DateTime.now().toUtc(),
          ),
        );
    return stored;
  }

  Stream<List<LocalDocument>> watch(String userId) {
    return (database.select(database.localDocuments)
          ..where((row) => row.userId.equals(userId))
          ..orderBy([(row) => OrderingTerm.desc(row.createdAt)]))
        .watch();
  }

  Future<void> remove(String userId, String id) async {
    guard.check(userId);
    await (database.delete(
      database.localDocuments,
    )..where((row) => row.userId.equals(userId) & row.id.equals(id))).go();
  }
}
