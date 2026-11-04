import 'dart:convert';

import '../../core/models/document_result.dart';
import '../../core/models/feedback_report.dart';

/// JSON encoding for local-only analysis records stored in SQLite.
class AnalysisCodec {
  const AnalysisCodec._();

  static String encodeReport(FeedbackReport report) => jsonEncode({
    'overallScore': report.overallScore,
    'summary': report.summary,
    'strengths': report.strengths.map(_item).toList(),
    'improvements': report.improvements.map(_item).toList(),
    'evidence': report.evidenceList
        .map(
          (e) => {
            'metricName': e.metricName,
            'measuredValue': e.measuredValue,
            'targetRange': e.targetRange,
            'status': e.status.name,
            'category': e.category,
          },
        )
        .toList(),
    'limitations': report.limitations,
    'generatedAt': report.generatedAt.toUtc().toIso8601String(),
    'llmResponse': report.llmResponse,
    'starsEarned': report.starsEarned,
    'leveledUp': report.leveledUp,
  });

  static FeedbackReport decodeReport(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    return FeedbackReport(
      overallScore: (json['overallScore'] as num?)?.toDouble() ?? 0,
      summary: json['summary'] as String? ?? '',
      strengths: _items(json['strengths']),
      improvements: _items(json['improvements']),
      evidenceList: [
        for (final e in (json['evidence'] as List? ?? const []))
          EvidencePoint(
            metricName: e['metricName'] as String? ?? '',
            measuredValue: e['measuredValue'] as String? ?? '',
            targetRange: e['targetRange'] as String? ?? '',
            status: EvidenceStatus.values.firstWhere(
              (s) => s.name == e['status'],
              orElse: () => EvidenceStatus.values.first,
            ),
            category: e['category'] as String? ?? 'system',
          ),
      ],
      limitations: [
        for (final l in (json['limitations'] as List? ?? const [])) '$l',
      ],
      generatedAt:
          DateTime.tryParse(json['generatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      llmResponse: json['llmResponse'] as String?,
      starsEarned: (json['starsEarned'] as num?)?.toInt() ?? 0,
      leveledUp: json['leveledUp'] as bool? ?? false,
    );
  }

  static Map<String, Object?> _item(FeedbackItem item) => {
    'id': item.id,
    'title': item.title,
    'description': item.description,
    'category': item.category,
    'measuredEvidence': item.measuredEvidence,
    'actionableTip': item.actionableTip,
    'isStrength': item.isStrength,
  };

  static List<FeedbackItem> _items(Object? raw) => [
    for (final i in (raw as List? ?? const []))
      FeedbackItem(
        id: i['id'] as String? ?? '',
        title: i['title'] as String? ?? '',
        description: i['description'] as String? ?? '',
        category: i['category'] as String? ?? 'combined',
        measuredEvidence: i['measuredEvidence'] as String? ?? '',
        actionableTip: i['actionableTip'] as String? ?? '',
        isStrength: i['isStrength'] as bool? ?? false,
      ),
  ];

  static String encodeDocument(DocumentResult doc) => jsonEncode({
    'documentId': doc.documentId,
    'aiAnalyzed': doc.aiAnalyzed,
    'title': doc.title,
    'extractedText': doc.extractedText,
    'keySections': doc.keySections,
    'coveredTopics': doc.coveredTopics,
    'missingOrWeakTopics': doc.missingOrWeakTopics,
    'speechImprovements': doc.speechImprovements,
    'wordCount': doc.wordCount,
    'estimatedMinutes': doc.estimatedMinutes,
  });

  static DocumentResult decodeDocument(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    List<String> list(String key) => [
      for (final v in (json[key] as List? ?? const [])) '$v',
    ];
    return DocumentResult(
      documentId: json['documentId'] as String? ?? '',
      aiAnalyzed: json['aiAnalyzed'] != false,
      title: json['title'] as String? ?? '',
      extractedText: json['extractedText'] as String? ?? '',
      keySections: list('keySections'),
      coveredTopics: list('coveredTopics'),
      missingOrWeakTopics: list('missingOrWeakTopics'),
      speechImprovements: list('speechImprovements'),
      wordCount: (json['wordCount'] as num?)?.toInt() ?? 0,
      estimatedMinutes: (json['estimatedMinutes'] as num?)?.toDouble() ?? 0,
    );
  }
}
