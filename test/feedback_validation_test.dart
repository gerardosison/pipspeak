import 'package:flutter_test/flutter_test.dart';
import 'package:app_builder_hackathon/core/models/speech_metrics.dart';
import 'package:app_builder_hackathon/core/models/pose_metrics.dart';
import 'package:app_builder_hackathon/features/ai/feedback/rule_based_feedback.dart';
import 'package:app_builder_hackathon/features/ai/feedback/feedback_validator.dart';
import 'package:app_builder_hackathon/features/ai/feedback/local_llm_service.dart';

void main() {
  test('optional inference failure preserves measured feedback', () async {
    final model = _FailingLocalModel(isLoaded: true);
    final engine = RuleBasedFeedbackEngine(llmService: model);
    final report = await engine.generate(
      speech: SpeechMetrics.sample(wpm: 140, fillers: 0),
      speakingGoal: 'Class presentation',
    );
    expect(report.overallScore, greaterThan(0));
    expect(report.evidenceList, isNotEmpty);
    expect(report.llmResponse, isNull);
    expect(
      report.limitations,
      contains(contains('Additional local AI coaching could not finish')),
    );
    expect(model.generationCalls, 1);
  });

  test(
    'unloaded optional model is not used as successful AI feedback',
    () async {
      final model = _FailingLocalModel(isLoaded: false);
      final report = await RuleBasedFeedbackEngine(
        llmService: model,
      ).generate(speech: SpeechMetrics.sample(), speakingGoal: 'Presentation');
      expect(report.llmResponse, isNull);
      expect(model.generationCalls, 0);
      expect(
        report.limitations,
        contains(contains('language model unavailable')),
      );
    },
  );

  test('empty capture cannot receive a fabricated score', () async {
    await expectLater(
      RuleBasedFeedbackEngine().generate(
        speech: SpeechMetrics.empty(),
        speakingGoal: 'Presentation',
      ),
      throwsA(isA<StateError>()),
    );
  });

  group('Member 4: Feedback Validation Tests', () {
    late RuleBasedFeedbackEngine engine;
    late FeedbackValidator validator;

    setUp(() {
      engine = RuleBasedFeedbackEngine();
      validator = FeedbackValidator();
    });

    test('Feedback Report generates valid scores and items without forbidden words', () async {
      final report = await engine.generate(
        speech: SpeechMetrics.sample(wpm: 140.0, fillers: 1),
        pose: PoseMetrics.sampleGood(),
        speakingGoal: 'Project Pitch',
      );

      expect(report.overallScore, greaterThanOrEqualTo(0));
      expect(report.overallScore, lessThanOrEqualTo(100));
      expect(validator.validateReport(report), isTrue);
    });
  });
}

class _FailingLocalModel implements LocalLlmService {
  _FailingLocalModel({required this.isLoaded});

  @override
  final bool isLoaded;
  int generationCalls = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #buildCoachingPrompt)
      return 'Measured speech coaching';
    if (invocation.memberName == #generateResponse) {
      generationCalls++;
      return Future<String>.error(StateError('Native model failed'));
    }
    return super.noSuchMethod(invocation);
  }
}
