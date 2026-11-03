import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../../core/models/pose_metrics.dart';
import '../../../core/services/pose_analysis_service.dart';
import 'pose_metrics_calculator.dart';

/// On-device pose detection for camera frames using Google ML Kit.
///
/// The camera screen should call [processImage] for each camera frame, then
/// call [finishSession] when the practice ends. No separate .task model asset
/// is used by this ML Kit implementation.
class MediaPipePoseServiceImpl implements PoseAnalysisService {
  bool _isInitialized = false;
  PoseDetector? _detector;
  final Map<String, List<PoseFrameData>> _sessions = {};
  final List<PoseFrameData> _activeFrames = [];

  @override
  Future<bool> isModelInitialized() async {
    return _isInitialized;
  }

  Future<void> initializeModel() async {
    _detector ??= PoseDetector(
      options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
    );
    _isInitialized = _detector != null;
  }

  @override
  Future<PoseMetrics?> analyzeSession(String sessionId) async {
    final frames = _sessions.remove(sessionId);
    if (frames == null || frames.isEmpty) {
      return PoseMetrics.unavailable(
        reason: 'No camera frames were received for session "$sessionId".',
      );
    }
    return analyzeFrames(frames);
  }

  /// Starts collecting frame results for a practice session.
  void startSession() => _activeFrames.clear();

  /// Runs real on-device pose detection on one camera frame and stores its
  /// landmarks for session feedback. Construct [InputImage] from the camera
  /// frame using the camera plugin's image format, rotation, and row stride.
  Future<PoseFrameData> processImage(
    InputImage image, {
    int? timestampMs,
  }) async {
    await initializeModel();
    final size = image.metadata?.size;
    if (size == null || size.width <= 0 || size.height <= 0) {
      throw ArgumentError(
        'Camera InputImage metadata must include a valid frame size.',
      );
    }
    final poses = await _detector!.processImage(image);
    // Android ML Kit reports points in the rotation-corrected image, whereas
    // InputImage metadata still describes the original camera-buffer size.
    final rotation = image.metadata!.rotation;
    final swapsAxes =
        defaultTargetPlatform == TargetPlatform.android &&
        (rotation == InputImageRotation.rotation90deg ||
            rotation == InputImageRotation.rotation270deg);
    final width = swapsAxes ? size.height : size.width;
    final height = swapsAxes ? size.width : size.height;
    final frame = PoseFrameData(
      timestampMs: timestampMs ?? DateTime.now().millisecondsSinceEpoch,
      landmarks: poses.isEmpty
          ? const {}
          : _toMediaPipeIndices(poses.first, width, height),
      isPersonDetected: poses.isNotEmpty,
      hasMultiplePeople: poses.length > 1,
      imageAspectRatio: width / height,
    );
    _activeFrames.add(frame);
    return frame;
  }

  /// Ends collection and returns measured posture, sway, and gesture metrics.
  Future<PoseMetrics> finishSession(String sessionId) async {
    final frames = List<PoseFrameData>.unmodifiable(_activeFrames);
    _sessions[sessionId] = frames;
    _activeFrames.clear();
    return (await analyzeSession(sessionId)) ??
        PoseMetrics.unavailable(
          reason: 'Pose analysis did not return a result.',
        );
  }

  Future<void> dispose() async {
    await _detector?.close();
    _detector = null;
    _isInitialized = false;
    _activeFrames.clear();
    _sessions.clear();
  }

  Map<int, PoseLandmarkPoint> _toMediaPipeIndices(
    Pose pose,
    double width,
    double height,
  ) {
    const indices = <PoseLandmarkType, int>{
      PoseLandmarkType.nose: 0,
      PoseLandmarkType.leftShoulder: 11,
      PoseLandmarkType.rightShoulder: 12,
      PoseLandmarkType.leftWrist: 15,
      PoseLandmarkType.rightWrist: 16,
    };
    final result = <int, PoseLandmarkPoint>{};
    for (final entry in indices.entries) {
      final landmark = pose.landmarks[entry.key];
      if (landmark == null) continue;
      result[entry.value] = PoseLandmarkPoint(
        x: landmark.x / width,
        y: landmark.y / height,
        z: landmark.z,
        visibility: landmark.likelihood,
      );
    }
    return result;
  }

  static bool _usable(PoseLandmarkPoint point) =>
      point.isVisible &&
      point.x.isFinite &&
      point.y.isFinite &&
      point.x >= 0 &&
      point.x <= 1 &&
      point.y >= 0 &&
      point.y <= 1;

  @override
  Future<PoseMetrics> analyzeFrames(List<PoseFrameData> frames) async {
    if (frames.isEmpty) {
      return PoseMetrics.unavailable(reason: 'No camera frames received.');
    }

    int totalFrames = frames.length;
    int validFrames = 0;
    int occludedFrames = 0;
    int multiplePeopleFrames = 0;
    int outOfFrameCount = 0;

    List<double> torsoXPositions = [];
    List<double> postureScores = [];
    List<double> handGestures = [];

    int leftCount = 0;
    int rightCount = 0;
    int centerCount = 0;

    for (var f in frames) {
      if (!f.isPersonDetected) {
        outOfFrameCount++;
        continue;
      }
      if (f.hasMultiplePeople) {
        multiplePeopleFrames++;
        continue; // Never score an arbitrary person from a multi-person frame.
      }
      if (f.isOccluded) {
        occludedFrames++;
        continue;
      }

      final lm = f.landmarks;
      final leftShoulder = lm[11];
      final rightShoulder = lm[12];
      final nose = lm[0];

      if (leftShoulder == null ||
          rightShoulder == null ||
          !_usable(leftShoulder) ||
          !_usable(rightShoulder) ||
          !f.imageAspectRatio.isFinite ||
          f.imageAspectRatio <= 0 ||
          (rightShoulder.x - leftShoulder.x).abs() +
                  (rightShoulder.y - leftShoulder.y).abs() <
              0.02) {
        occludedFrames++;
        continue;
      }

      validFrames++;
      double torsoX = (leftShoulder.x + rightShoulder.x) / 2.0;
      torsoXPositions.add(torsoX);

      if (torsoX < 0.35) {
        leftCount++;
      } else if (torsoX > 0.65) {
        rightCount++;
      } else {
        centerCount++;
      }

      // Normalize both axes to frame-height units so non-square frames do
      // not distort shoulder tilt. Shoulder ordering/mirroring is irrelevant.
      final framePosture = PoseMetricsCalculator().calculatePostureScore(
        shoulderDx: (rightShoulder.x - leftShoulder.x) * f.imageAspectRatio,
        shoulderDy: rightShoulder.y - leftShoulder.y,
        headOffset: nose != null && _usable(nose) ? nose.x - torsoX : 0,
      );
      postureScores.add(framePosture);

      // Hand gesture estimation
      final leftWrist = lm[15];
      final rightWrist = lm[16];
      double gesture = 0.0;
      if (leftWrist != null &&
          _usable(leftWrist) &&
          leftWrist.y < leftShoulder.y + 0.15) {
        gesture += 50.0;
      }
      if (rightWrist != null &&
          _usable(rightWrist) &&
          rightWrist.y < rightShoulder.y + 0.15) {
        gesture += 50.0;
      }
      handGestures.add(gesture);
    }

    if (validFrames == 0) {
      return PoseMetrics.unavailable(
        reason: 'Person out of frame or occluded.',
      );
    }

    // Image-relative variation only; camera movement and distance affect it.
    final normalizedSway = PoseMetricsCalculator().calculateNormalizedSway(
      torsoXPositions,
    );
    final legacySway = normalizedSway * 200;

    double avgPosture =
        postureScores.reduce((a, b) => a + b) / postureScores.length;
    double avgGesture =
        handGestures.reduce((a, b) => a + b) / handGestures.length;
    double upperBodyScore = (avgPosture * 0.4) + (avgGesture * 0.6);

    FramingStatus status = FramingStatus.centered;
    if (outOfFrameCount > totalFrames * 0.4) {
      status = FramingStatus.outOfFrame;
    } else if (multiplePeopleFrames > totalFrames * 0.3) {
      status = FramingStatus.multiplePeople;
    } else if (leftCount > centerCount && leftCount > rightCount) {
      status = FramingStatus.offCenterLeft;
    } else if (rightCount > centerCount && rightCount > leftCount) {
      status = FramingStatus.offCenterRight;
    }

    AnalysisQuality quality = AnalysisQuality.high;
    List<String> limitations = [
      'Sway is image-relative torso variation, not a distance in centimeters; '
          'camera movement and subject distance affect it.',
      'Posture and raised-hand scores are heuristics, not validated measures '
          'of confidence, eye contact, or gesture quality.',
    ];
    if (validFrames < 5 || validFrames < totalFrames * 0.6) {
      quality = AnalysisQuality.low;
      limitations.add(
        'Too few reliable shoulder observations for a strong movement estimate.',
      );
    } else if (occludedFrames > 0) {
      quality = AnalysisQuality.medium;
      limitations.add(
        '$occludedFrames frames had unusable shoulder landmarks.',
      );
    }

    if (normalizedSway > 0.04) {
      limitations.add(
        'Torso position varied by ${(normalizedSway * 100).toStringAsFixed(1)}% '
        'of image width; this may include camera motion.',
      );
    }
    if (multiplePeopleFrames > 0) {
      limitations.add(
        '$multiplePeopleFrames multi-person frames were excluded.',
      );
    }

    return PoseMetrics(
      totalFrames: totalFrames,
      validFrameCount: validFrames,
      framingStatus: status,
      bodySwayCm: legacySway,
      upperBodyMovementScore: double.parse(
        upperBodyScore.clamp(0.0, 100.0).toStringAsFixed(1),
      ),
      postureScore: double.parse(
        avgPosture.clamp(0.0, 100.0).toStringAsFixed(1),
      ),
      handGestureActivityScore: double.parse(
        avgGesture.clamp(0.0, 100.0).toStringAsFixed(1),
      ),
      isPersonInFrame: validFrames > 0,
      analysisQuality: quality,
      qualityLimitations: limitations,
    );
  }
}
