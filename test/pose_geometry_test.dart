import 'package:app_builder_hackathon/core/models/pose_metrics.dart';
import 'package:app_builder_hackathon/features/ai/vision/mediapipe_pose_service.dart';
import 'package:app_builder_hackathon/features/ai/vision/pose_metrics_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final calculator = PoseMetricsCalculator();

  PoseFrameData frame({
    double center = 0.5,
    double tilt = 0,
    bool mirrored = false,
    bool multiple = false,
    double aspectRatio = 1,
  }) {
    final direction = mirrored ? -1 : 1;
    return PoseFrameData(
      timestampMs: 0,
      hasMultiplePeople: multiple,
      imageAspectRatio: aspectRatio,
      landmarks: {
        0: PoseLandmarkPoint(x: center, y: 0.2, visibility: 1),
        11: PoseLandmarkPoint(
          x: center - direction * 0.2,
          y: 0.4 - direction * tilt / 2,
          visibility: 1,
        ),
        12: PoseLandmarkPoint(
          x: center + direction * 0.2,
          y: 0.4 + direction * tilt / 2,
          visibility: 1,
        ),
      },
    );
  }

  test('horizontal shoulders score equally for either shoulder ordering', () {
    for (final dx in [-0.4, 0.4]) {
      expect(
        calculator.calculatePostureScore(
          shoulderDx: dx,
          shoulderDy: 0,
          headOffset: 0,
        ),
        100,
      );
    }
  });

  test('reflection and head-offset sign do not change tilt score', () {
    final normal = calculator.calculatePostureScore(
      shoulderDx: 0.4,
      shoulderDy: 0.03,
      headOffset: 0.02,
    );
    final reversed = calculator.calculatePostureScore(
      shoulderDx: -0.4,
      shoulderDy: -0.03,
      headOffset: -0.02,
    );
    expect(normal, reversed);
    expect(normal, inExclusiveRange(0, 100));
  });

  test('malformed and coincident points never produce a perfect posture', () {
    expect(
      calculator.calculatePostureScore(
        shoulderDx: 0,
        shoulderDy: 0,
        headOffset: 0,
      ),
      0,
    );
    expect(
      calculator.calculatePostureScore(
        shoulderDx: double.nan,
        shoulderDy: 0,
        headOffset: 0,
      ),
      0,
    );
  });

  test(
    'sway is normalized image variation without a centimeter conversion',
    () {
      expect(
        calculator.calculateNormalizedSway([0.4, 0.6]),
        closeTo(0.1, 1e-10),
      );
      expect(calculator.calculateNormalizedSway([0.5, 0.5]), 0);
      expect(calculator.calculateNormalizedSway([double.nan, -1, 2]), 0);
    },
  );

  test('live frame analysis is invariant to shoulder reflection', () async {
    final service = MediaPipePoseServiceImpl();
    final normal = await service.analyzeFrames(
      List.generate(5, (_) => frame(tilt: 0.03)),
    );
    final mirror = await service.analyzeFrames(
      List.generate(5, (_) => frame(tilt: 0.03, mirrored: true)),
    );
    expect(normal.postureScore, mirror.postureScore);
    expect(normal.postureScore, greaterThan(0));
    expect(normal.qualityLimitations.join(' '), contains('not a distance'));
  });

  test(
    'non-square frame aspect ratio is applied before computing tilt',
    () async {
      final result = await MediaPipePoseServiceImpl().analyzeFrames(
        List.generate(5, (_) => frame(tilt: 0.03, aspectRatio: 2)),
      );
      final expected = calculator.calculatePostureScore(
        shoulderDx: 0.8,
        shoulderDy: 0.03,
        headOffset: 0,
      );
      expect(result.postureScore, expected);
    },
  );

  test(
    'out-of-frame and multiple-person observations are not scored',
    () async {
      final result = await MediaPipePoseServiceImpl().analyzeFrames([
        frame(multiple: true),
        frame(center: -0.5),
        frame(center: double.nan),
      ]);
      expect(result.analysisQuality, AnalysisQuality.unavailable);
      expect(result.isPersonInFrame, isFalse);
    },
  );

  test(
    'legacy storage field exposes image-width units through getters',
    () async {
      final result = await MediaPipePoseServiceImpl().analyzeFrames([
        frame(center: 0.4),
        frame(center: 0.6),
      ]);
      expect(result.normalizedSway, closeTo(0.1, 1e-10));
      expect(result.swayWidthPercent, closeTo(10, 1e-8));
      expect(result.analysisQuality, AnalysisQuality.low);
      expect(result.qualityLimitations.join(' '), contains('camera'));
    },
  );
}
