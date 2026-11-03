/// Result of comparing a new session against earlier compatible sessions.
class StarAward {
  const StarAward({required this.stars, required this.baselineSessionId});

  final int stars;

  /// The first compatible session; null when this session is the baseline.
  final String? baselineSessionId;

  bool get isBaseline => baselineSessionId == null;
}

/// Earlier session used for comparison (newest first).
class ScoredSession {
  const ScoredSession({required this.id, required this.score});

  final String id;
  final double score;
}

/// Deterministic star rule (scoring version [version]).
///
/// Sessions are compatible when they share practice purpose, language and
/// scoring version, and are genuine (not test) sessions with a score. The
/// first compatible session is the baseline and earns 0 stars. Later
/// sessions compare their overall score with the mean of up to the
/// [window] most recent compatible scores:
///   +2 points → 1 star, +5 → 2 stars, +10 → 3 stars, otherwise 0.
class ScoringService {
  const ScoringService();

  // Corrected hesitation/pose measurements are not comparable to legacy v1.
  static const version = 'v2';
  static const window = 3;

  StarAward award({
    required double score,
    required List<ScoredSession> previousCompatible,
  }) {
    if (previousCompatible.isEmpty) {
      return const StarAward(stars: 0, baselineSessionId: null);
    }
    final recent = previousCompatible.take(window).toList();
    final reference =
        recent.map((s) => s.score).reduce((a, b) => a + b) / recent.length;
    return StarAward(
      stars: starsForImprovement(score - reference),
      baselineSessionId: previousCompatible.last.id,
    );
  }

  static int starsForImprovement(double delta) {
    if (delta >= 10) return 3;
    if (delta >= 5) return 2;
    if (delta >= 2) return 1;
    return 0;
  }
}
