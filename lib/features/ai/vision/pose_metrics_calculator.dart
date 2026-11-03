import 'dart:math' as math;

/// Image-relative pose heuristics; these are not calibrated physical distances.
class PoseMetricsCalculator {
  /// Standard deviation of normalized torso-center X (fraction of frame width).
  double calculateNormalizedSway(List<double> torsoXPositions) {
    final valid = torsoXPositions
        .where((x) => x.isFinite && x >= 0 && x <= 1)
        .toList();
    if (valid.length < 2) return 0;
    final mean = valid.reduce((a, b) => a + b) / valid.length;
    final variance =
        valid.fold<double>(0, (sum, x) => sum + (x - mean) * (x - mean)) /
        valid.length;
    return math.sqrt(variance);
  }

  /// Legacy storage scale, retained for database/report compatibility.
  /// Despite the historic name, the result is NOT centimeters. Divide by 200
  /// for normalized sway, or by 2 for percentage of image width.
  double calculateBodySwayCm(List<double> torsoXPositions) =>
      calculateNormalizedSway(torsoXPositions) * 200;

  /// Shoulder horizontal-alignment heuristic, independent of mirroring and
  /// shoulder ordering. Inputs use the same coordinate units on both axes.
  double calculatePostureScore({
    required double shoulderDx,
    required double shoulderDy,
    required double headOffset,
  }) {
    if (!shoulderDx.isFinite ||
        !shoulderDy.isFinite ||
        !headOffset.isFinite ||
        (shoulderDx == 0 && shoulderDy == 0)) {
      return 0;
    }
    final angleDeg =
        math.atan2(shoulderDy.abs(), shoulderDx.abs()) * 180 / math.pi;
    final score = 100 - angleDeg * 5 - headOffset.abs() * 80;
    return double.parse(score.clamp(0.0, 100.0).toStringAsFixed(1));
  }
}
