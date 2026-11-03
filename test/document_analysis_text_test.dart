import 'dart:convert';

import 'package:app_builder_hackathon/core/errors/analysis_failure.dart';
import 'package:app_builder_hackathon/features/documents/services/document_analysis_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts readable Unicode scripts and rejects noise', () {
    expect(
      DocumentAnalysisText.isUnreadable(
        'Malinaw na pananalita at paghahanda ang paksa natin.',
      ),
      isFalse,
    );
    expect(
      DocumentAnalysisText.isUnreadable('学生演讲练习可以帮助他们建立自信并改善表达能力。'),
      isFalse,
    );
    expect(
      DocumentAnalysisText.isUnreadable('�@###!? �@###!? �@###!? �@###!?'),
      isTrue,
    );
    expect(DocumentAnalysisText.isUnreadable('short'), isTrue);
  });

  test('UTF8 excerpt stays within context budget and preserves Unicode', () {
    final source = 'Opening ${'学生演讲练习🙂 ' * 150} ending';
    final excerpt = DocumentAnalysisText.excerpt(source, 600);
    expect(utf8.encode(excerpt).length, lessThanOrEqualTo(600));
    expect(excerpt, startsWith('Opening'));
    expect(excerpt, endsWith(' ending'));
    expect(excerpt, contains('[...sampled passage...]'));
    expect(excerpt, isNot(contains('�')));
    expect(
      DocumentAnalysisText.excerpt('A readable short document.', 600),
      'A readable short document.',
    );
  });

  test('parses markdown headings and None without inventing weak topics', () {
    final result = DocumentAnalysisText.parse('''
## COVERED TOPICS
- Conserving water
**MISSING OR WEAK TOPICS:**
None.
SPEECH IMPROVEMENTS
1. Pause after the introduction.
''');
    expect(result.covered, ['Conserving water']);
    expect(result.weak, isEmpty);
    expect(result.improvements, ['Pause after the introduction.']);
  });

  test('does not silently accept empty or truncated model feedback', () {
    expect(
      () => DocumentAnalysisText.parse(''),
      throwsA(isA<AnalysisFailure>()),
    );
    expect(
      () => DocumentAnalysisText.parse('COVERED TOPICS\n- Water'),
      throwsA(isA<AnalysisFailure>()),
    );
    expect(
      () => DocumentAnalysisText.parse(
        'COVERED TOPICS\nNone\nMISSING OR WEAK TOPICS\nNone\nSPEECH IMPROVEMENTS\nNone',
      ),
      throwsA(isA<AnalysisFailure>()),
    );
  });
}
