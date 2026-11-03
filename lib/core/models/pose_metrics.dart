enum FramingStatus {
  centered,
  offCenterLeft,
  offCenterRight,
  outOfFrame,
  multiplePeople,
  occluded;

  String get label {
    switch (this) {
      case FramingStatus.centered:
        return 'Centered in Frame';
      case FramingStatus.offCenterLeft:
        return 'Off-Center (Left)';
      case FramingStatus.offCenterRight:
        return 'Off-Center (Right)';
      case FramingStatus.outOfFrame:
        return 'Person Out of Frame';
      case FramingStatus.multiplePeople:
        return 'Multiple People Detected';
      case FramingStatus.occluded:
        return 'Body Occluded / Obstructed';
    }
  }
}

enum AnalysisQuality {
  high,
  medium,
  low,
  unavailable;

  String get label {
    switch (this) {
      case AnalysisQuality.high:
        return 'High landmark availability';
      case AnalysisQuality.medium:
        return 'Medium Quality (partial lighting / minor occlusion)';
      case AnalysisQuality.low:
        return 'Low Quality (frequent landmark drops)';
      case AnalysisQuality.unavailable:
        return 'Analysis Unavailable (camera off or frame blocked)';
    }
  }
}

class PoseLandmarkPoint {
  final double x; // 0.0 to 1.0 (normalized)
  final double y; // 0.0 to 1.0 (normalized)
  final double z; // Depth coordinate
  final double visibility; // 0.0 to 1.0 confidence score

  const PoseLandmarkPoint({
    required this.x,
    required this.y,
    this.z = 0.0,
    required this.visibility,
  });

  bool get isVisible => visibility >= 0.5;
}

class PoseFrameData {
  final int timestampMs;
  final Map<int, PoseLandmarkPoint>
  landmarks; // Keyed by MediaPipe Landmark Index (0..32)
  final bool isPersonDetected;
  final bool isOccluded;
  final bool hasMultiplePeople;

  /// Width/height of the image coordinates used to normalize these landmarks.
  /// Converts normalized X and Y to equal units for shoulder tilt estimates.
  final double imageAspectRatio;

  const PoseFrameData({
    required this.timestampMs,
    required this.landmarks,
    this.isPersonDetected = true,
    this.isOccluded = false,
    this.hasMultiplePeople = false,
    this.imageAspectRatio = 1.0,
  });
}

class PoseMetrics {
  final int totalFrames;
  final int validFrameCount;
  final FramingStatus framingStatus;

  /// Legacy database/report field: 200 times the standard deviation of
  /// normalized torso X. NOT a calibrated distance in centimeters.
  final double bodySwayCm;
  final double upperBodyMovementScore; // 0 - 100
  final double postureScore; // 0 - 100 (head/shoulder alignment)
  final double handGestureActivityScore; // 0 - 100
  final bool isPersonInFrame;
  final AnalysisQuality analysisQuality;
  final List<String> qualityLimitations;

  const PoseMetrics({
    required this.totalFrames,
    required this.validFrameCount,
    required this.framingStatus,
    required this.bodySwayCm,
    required this.upperBodyMovementScore,
    required this.postureScore,
    required this.handGestureActivityScore,
    required this.isPersonInFrame,
    required this.analysisQuality,
    required this.qualityLimitations,
  });

  /// Lateral torso variation as a fraction of the image width.
  double get normalizedSway => bodySwayCm / 200;

  /// Lateral torso variation as a percentage of the image width.
  double get swayWidthPercent => normalizedSway * 100;

  double get validFramePercentage =>
      totalFrames == 0 ? 0.0 : (validFrameCount / totalFrames) * 100.0;

  factory PoseMetrics.unavailable({
    String reason = 'Camera disabled or unavailable.',
  }) {
    return PoseMetrics(
      totalFrames: 0,
      validFrameCount: 0,
      framingStatus: FramingStatus.outOfFrame,
      bodySwayCm: 0.0,
      upperBodyMovementScore: 0.0,
      postureScore: 0.0,
      handGestureActivityScore: 0.0,
      isPersonInFrame: false,
      analysisQuality: AnalysisQuality.unavailable,
      qualityLimitations: [reason],
    );
  }

  factory PoseMetrics.sampleGood() {
    return const PoseMetrics(
      totalFrames: 300,
      validFrameCount: 290,
      framingStatus: FramingStatus.centered,
      bodySwayCm: 2.1,
      upperBodyMovementScore: 72.0,
      postureScore: 94.0,
      handGestureActivityScore: 68.0,
      isPersonInFrame: true,
      analysisQuality: AnalysisQuality.high,
      qualityLimitations: [],
    );
  }

  factory PoseMetrics.sampleHighSway() {
    return const PoseMetrics(
      totalFrames: 300,
      validFrameCount: 280,
      framingStatus: FramingStatus.centered,
      bodySwayCm: 9.8,
      upperBodyMovementScore: 35.0,
      postureScore: 76.0,
      handGestureActivityScore: 25.0,
      isPersonInFrame: true,
      analysisQuality: AnalysisQuality.high,
      qualityLimitations: ['Noticeable side-to-side torso sway detected.'],
    );
  }

  factory PoseMetrics.sampleExcessiveSway() => PoseMetrics.sampleHighSway();
}
