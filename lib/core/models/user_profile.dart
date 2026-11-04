/// Signed-in user's profile + gamification state from Firebase identity and SQLite.
class UserProfile {
  const UserProfile({
    required this.name,
    required this.nickname,
    required this.email,
    required this.level,
    required this.stars,
    required this.streakDays,
    required this.totalSessions,
    required this.school,
    this.language = 'English (US)',
    this.goal = 'Class Presentation',
    this.uid = '',
    this.username = '',
    this.photoPath,
  });

  /// Shown briefly while the signed-in profile loads from SQLite.
  const UserProfile.placeholder()
    : this(
        name: 'Speaker',
        nickname: 'Speaker',
        email: '',
        level: 1,
        stars: 0,
        streakDays: 0,
        totalSessions: 0,
        school: '',
      );

  final String uid;
  final String username;

  /// Device-local profile photo path (not synchronized).
  final String? photoPath;

  final String name;
  final String nickname;
  final String email;
  final int level;
  final int stars;
  final int streakDays;
  final int totalSessions;
  final String school;
  final String language;
  final String goal;

  /// Business rule: level n needs 10*n stars for the next level.
  int get starsForNextLevel => 10 * level;
  double get levelProgress => (stars / starsForNextLevel).clamp(0.0, 1.0);

  UserProfile copyWith({
    String? name,
    String? nickname,
    String? email,
    int? level,
    int? stars,
    int? streakDays,
    int? totalSessions,
    String? school,
    String? language,
    String? goal,
  }) => UserProfile(
    name: name ?? this.name,
    nickname: nickname ?? this.nickname,
    email: email ?? this.email,
    level: level ?? this.level,
    stars: stars ?? this.stars,
    streakDays: streakDays ?? this.streakDays,
    totalSessions: totalSessions ?? this.totalSessions,
    school: school ?? this.school,
    language: language ?? this.language,
    goal: goal ?? this.goal,
    uid: uid,
    username: username,
    photoPath: photoPath,
  );
}
