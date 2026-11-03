/// One completed practice take with its headline metrics.
class PracticeSession {
  const PracticeSession({
    required this.id,
    required this.date,
    required this.title,
    required this.duration,
    required this.avgWpm,
    required this.fillerCount,
    required this.eyeContactPct,
    required this.paceScore,
    required this.starsEarned,
    required this.improved,
    this.goal,
  });

  final String id;
  final DateTime date;
  final String title;
  final Duration duration;
  final int avgWpm;
  final int fillerCount;

  /// Reserved for a future validated gaze measurement. Null means unavailable;
  /// body alignment must never be substituted for eye contact.
  final int? eyeContactPct;
  final int paceScore; // 0-100
  final int starsEarned;
  final bool improved;
  final String? goal;
}
