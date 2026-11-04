class DocumentResult {
  final String documentId;
  final String title;
  final String extractedText;
  final bool isReadable;
  final bool aiAnalyzed;
  final List<String> keySections;
  final String? rejectionReason;
  final List<String> coveredTopics;
  final List<String> missingOrWeakTopics;
  final List<String> speechImprovements;
  final int wordCount;
  final double estimatedMinutes;

  const DocumentResult({
    required this.documentId,
    required this.title,
    required this.extractedText,
    this.isReadable = true,
    this.aiAnalyzed = true,
    this.keySections = const [],
    this.rejectionReason,
    this.coveredTopics = const [],
    this.missingOrWeakTopics = const [],
    this.speechImprovements = const [],
    this.wordCount = 0,
    this.estimatedMinutes = 0,
  });

  factory DocumentResult.empty() {
    return const DocumentResult(
      documentId: '',
      title: '',
      extractedText: '',
      isReadable: false,
      rejectionReason: 'No document uploaded',
    );
  }
}
