// Offline, dependency-free smoke checks for the actual production calculators.
// Run: dart scripts/test_speech_pose.dart
import '../lib/core/models/pose_metrics.dart';
import '../lib/core/models/speech_metrics.dart';
import '../lib/features/ai/speech/speech_metrics_calculator.dart';
import '../lib/features/ai/vision/pose_metrics_calculator.dart';

void expect(bool result, String message) {
  if (!result) throw StateError(message);
}

void main() {
  var checks = 0;
  void check(bool result, String message) {
    expect(result, message);
    checks++;
  }

  final pose = PoseMetricsCalculator();
  check(
    pose.calculatePostureScore(
          shoulderDx: -0.4,
          shoulderDy: 0,
          headOffset: 0,
        ) ==
        100,
    'Horizontal reversed shoulders must not receive zero posture.',
  );
  check(
    pose.calculatePostureScore(
          shoulderDx: 0.4,
          shoulderDy: 0.02,
          headOffset: 0.01,
        ) ==
        pose.calculatePostureScore(
          shoulderDx: -0.4,
          shoulderDy: -0.02,
          headOffset: -0.01,
        ),
    'Mirrored shoulder/head coordinates must preserve posture.',
  );
  check(
    (pose.calculateNormalizedSway([0.4, 0.6]) - 0.1).abs() < 1e-10,
    'Sway must use normalized image coordinates.',
  );
  check(
    pose.calculateNormalizedSway([0.5, 0.5]) == 0,
    'Stationary torso must have zero variation.',
  );
  check(
    pose.calculateNormalizedSway([double.nan, -1, 2]) == 0,
    'Malformed positions must not contaminate sway.',
  );
  check(
    PoseMetrics.sampleHighSway().swayWidthPercent == 4.9,
    'Legacy sway storage must expose percentage units.',
  );

  final speech = SpeechMetricsCalculator();
  SpeechMetrics measure(
    String text, {
    double duration = 10,
    double timer = 10,
    String language = 'en',
    List<TranscriptSegment> segments = const [],
  }) => speech.calculate(
    transcription: TranscriptionResult(
      text: text,
      durationSeconds: duration,
      detectedLanguage: language,
      segments: segments,
    ),
    durationSeconds: timer,
  );
  check(
    measure('one two three four five', timer: 20).wordsPerMinute == 30,
    'WPM must use the measured audio duration.',
  );
  check(
    measure('one two', duration: 0, timer: 0).wordsPerMinute == 0,
    'Missing timing must not invent a recording length.',
  );
  check(measure(' \n  ').wordCount == 0, 'Whitespace is not a word.');
  check(
    measure('No timestamps here.').pauseCount == 0,
    'Missing timestamps must not invent pauses.',
  );
  final gap = measure(
    'hello world',
    segments: const [
      TranscriptSegment(id: 0, startSeconds: 0, endSeconds: 1, text: 'hello'),
      TranscriptSegment(id: 1, startSeconds: 2.5, endSeconds: 3, text: 'world'),
    ],
  );
  check(
    gap.pauseCount == 1 && gap.avgPauseDurationSeconds == 1.5,
    'Pause estimates must come from genuine segment gaps.',
  );
  final overlapping = measure(
    'hello world',
    segments: const [
      TranscriptSegment(id: 0, startSeconds: 0, endSeconds: 5, text: 'hello'),
      TranscriptSegment(id: 1, startSeconds: 1, endSeconds: 2, text: 'world'),
      TranscriptSegment(id: 2, startSeconds: 4, endSeconds: 6, text: 'hello'),
    ],
  );
  check(
    overlapping.pauseCount == 0,
    'Nested/overlapping intervals must not create fictional gaps.',
  );
  check(
    measure('Um, I like it so much. Uh.').totalFillers == 2,
    'Meaningful words must not automatically be classified as fillers.',
  );
  check(
    measure('Um livro', language: 'pt-BR').totalFillers == 0,
    'English hesitation rules must not classify Portuguese articles.',
  );
  print('PASS: $checks production speech/pose checks.');
}
