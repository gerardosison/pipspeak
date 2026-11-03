import 'dart:io';
// Standalone regression runner intentionally works before pub dependency resolution.
// ignore_for_file: avoid_relative_lib_imports
// Runs production text-analysis and feedback code without Flutter or model weights.
// dart --disable-dart-dev scripts/test_ai_features.dart
import 'dart:convert';

import '../lib/features/documents/services/document_analysis_text.dart';
import '../lib/features/ai/feedback/local_llm_service.dart';
import '../lib/features/ai/feedback/rule_based_feedback.dart';
import '../lib/core/models/speech_metrics.dart';
import '../lib/core/models/pose_metrics.dart';

class FailingModel implements LocalLlmService {
  FailingModel(this.isLoaded);
  @override
  final bool isLoaded;
  int calls = 0;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #buildCoachingPrompt) {
      return 'Measured coaching';
    }
    if (invocation.memberName == #generateResponse) {
      calls++;
      return Future<String>.error(StateError('Native failed'));
    }
    return super.noSuchMethod(invocation);
  }
}

void check(bool result, String name) {
  if (!result) throw StateError(name);
  stdout.writeln('PASS $name');
}

Future<void> main() async {
  check(
    !DocumentAnalysisText.isUnreadable(
      'Malinaw na pananalita at paghahanda ang paksa natin.',
    ),
    'Filipino readable',
  );
  check(
    !DocumentAnalysisText.isUnreadable('学生演讲练习可以帮助他们建立自信并改善表达能力。'),
    'Unicode readable',
  );
  check(
    DocumentAnalysisText.isUnreadable('�@###!? �@###!? �@###!? �@###!?'),
    'corrupt noise rejected',
  );
  final source = 'Opening ${'学生演讲练习🙂 ' * 150} ending';
  final excerpt = DocumentAnalysisText.excerpt(source, 600);
  check(
    utf8.encode(excerpt).length <= 600 &&
        excerpt.startsWith('Opening') &&
        excerpt.endsWith(' ending') &&
        !excerpt.contains('�'),
    'Unicode byte-budget sampling',
  );
  final result = DocumentAnalysisText.parse(
    '## COVERED TOPICS\n- Water\n**MISSING OR WEAK TOPICS:**\nNone.\nSPEECH IMPROVEMENTS\n1. Pause.',
  );
  check(
    result.covered.single == 'Water' &&
        result.weak.isEmpty &&
        result.improvements.single == 'Pause.',
    'structured markdown parsed',
  );
  var incompleteRejected = false;
  try {
    DocumentAnalysisText.parse('COVERED TOPICS\nWater');
  } catch (_) {
    incompleteRejected = true;
  }
  check(incompleteRejected, 'truncated output rejected');

  final failing = FailingModel(true);
  final report = await RuleBasedFeedbackEngine(
    llmService: failing,
  ).generate(speech: SpeechMetrics.sample(), speakingGoal: 'Presentation');
  check(
    report.overallScore > 0 &&
        report.evidenceList.isNotEmpty &&
        report.llmResponse == null &&
        failing.calls == 1,
    'native inference failure preserves measured feedback',
  );
  final unloaded = FailingModel(false);
  final baseline = await RuleBasedFeedbackEngine(
    llmService: unloaded,
  ).generate(speech: SpeechMetrics.sample(), speakingGoal: 'Presentation');
  check(
    baseline.llmResponse == null && unloaded.calls == 0,
    'unloaded model not reported as AI output',
  );
  var rejected = false;
  try {
    await RuleBasedFeedbackEngine().generate(
      speech: SpeechMetrics.empty(),
      speakingGoal: 'Presentation',
    );
  } catch (_) {
    rejected = true;
  }
  check(rejected, 'empty capture cannot invent score');
  final poseReport = await RuleBasedFeedbackEngine().generate(
    speech: SpeechMetrics.sample(),
    pose: PoseMetrics.sampleGood(),
    speakingGoal: 'Presentation',
  );
  check(
    poseReport.evidenceList.any(
          (e) => e.measuredValue.contains('% frame-width'),
        ) &&
        !poseReport.evidenceList.any(
          (e) => e.measuredValue.contains('cm sway'),
        ),
    'pose feedback describes image-relative movement',
  );
  stdout.writeln('10 AI feature checks passed.');
}
