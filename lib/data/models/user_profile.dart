class UserProfile {
  final String id;
  final String displayName;
  final String email;
  final String avatarUrl;
  final double? targetScore;
  final bool isTargetScoreConfirmed;
  final String examDate;
  final int dailyMinutes;
  final bool reminderEnabled;
  final String reminderTime;
  final List<String> favoriteTopics;
  final bool isLoggedIn;
  final int streakDays;
  final int xp;
  final String authProvider; // 'guest' | 'email' | 'google'
  final String role; // 'student' | 'teacher' | 'admin'
  final bool emailVerified;
  final bool isLocked;
  final String lockedReason;

  bool get isGuest => authProvider == 'guest' || !isLoggedIn;
  bool get isStudent => role == 'student';
  bool get isTeacher => role == 'teacher';
  bool get isAdmin => role == 'admin';
  bool get hasConfirmedTargetScore =>
      isTargetScoreConfirmed && targetScore != null && targetScore! > 0;

  String get roleDisplayName {
    switch (role) {
      case 'admin':
        return 'Quản trị viên (Admin)';
      case 'teacher':
        return 'Giáo viên (Teacher)';
      default:
        return isGuest ? 'Khách học thử' : 'Học viên (Student)';
    }
  }

  const UserProfile({
    this.id = 'guest_user',
    this.displayName = 'Khách',
    this.email = '',
    this.avatarUrl = '',
    this.targetScore,
    this.isTargetScoreConfirmed = false,
    this.examDate = '',
    this.dailyMinutes = 20,
    this.reminderEnabled = false,
    this.reminderTime = '20:00',
    this.favoriteTopics = const [],
    this.isLoggedIn = false,
    this.streakDays = 0,
    this.xp = 0,
    this.authProvider = 'guest',
    this.role = 'student',
    this.emailVerified = false,
    this.isLocked = false,
    this.lockedReason = '',
  });

  UserProfile copyWith({
    String? id,
    String? displayName,
    String? email,
    String? avatarUrl,
    double? targetScore,
    bool? isTargetScoreConfirmed,
    String? examDate,
    int? dailyMinutes,
    bool? reminderEnabled,
    String? reminderTime,
    List<String>? favoriteTopics,
    bool? isLoggedIn,
    int? streakDays,
    int? xp,
    String? authProvider,
    String? role,
    bool? emailVerified,
    bool? isLocked,
    String? lockedReason,
  }) {
    return UserProfile(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      targetScore: targetScore ?? this.targetScore,
      isTargetScoreConfirmed:
          isTargetScoreConfirmed ?? this.isTargetScoreConfirmed,
      examDate: examDate ?? this.examDate,
      dailyMinutes: dailyMinutes ?? this.dailyMinutes,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderTime: reminderTime ?? this.reminderTime,
      favoriteTopics: favoriteTopics ?? this.favoriteTopics,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      streakDays: streakDays ?? this.streakDays,
      xp: xp ?? this.xp,
      authProvider: authProvider ?? this.authProvider,
      role: role ?? this.role,
      emailVerified: emailVerified ?? this.emailVerified,
      isLocked: isLocked ?? this.isLocked,
      lockedReason: lockedReason ?? this.lockedReason,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'displayName': displayName,
      'email': email,
      'avatarUrl': avatarUrl,
      'targetScore': targetScore,
      'isTargetScoreConfirmed': isTargetScoreConfirmed ? 1 : 0,
      'examDate': examDate,
      'dailyMinutes': dailyMinutes,
      'reminderEnabled': reminderEnabled ? 1 : 0,
      'reminderTime': reminderTime,
      'favoriteTopics': favoriteTopics.join(','),
      'isLoggedIn': isLoggedIn ? 1 : 0,
      'streakDays': streakDays,
      'xp': xp,
      'authProvider': authProvider,
      'role': role,
      'emailVerified': emailVerified ? 1 : 0,
      'isLocked': isLocked ? 1 : 0,
      'lockedReason': lockedReason,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    final confirmed =
        map['isTargetScoreConfirmed'] == 1 ||
        map['isTargetScoreConfirmed'] == true;
    final rawTarget = (map['targetScore'] as num?)?.toDouble();
    return UserProfile(
      id: map['id'] as String? ?? 'guest_user',
      displayName: map['displayName'] as String? ?? 'Khách',
      email: map['email'] as String? ?? '',
      avatarUrl: map['avatarUrl'] as String? ?? '',
      targetScore: confirmed ? rawTarget : null,
      isTargetScoreConfirmed: confirmed,
      examDate: map['examDate'] as String? ?? '',
      dailyMinutes: (map['dailyMinutes'] as num?)?.toInt() ?? 20,
      reminderEnabled:
          (map['reminderEnabled'] == 1 || map['reminderEnabled'] == true),
      reminderTime: map['reminderTime'] as String? ?? '20:00',
      favoriteTopics: (map['favoriteTopics'] as String? ?? '')
          .split(',')
          .where((e) => e.trim().isNotEmpty)
          .toList(),
      isLoggedIn: (map['isLoggedIn'] == 1 || map['isLoggedIn'] == true),
      streakDays: (map['streakDays'] as num?)?.toInt() ?? 0,
      xp: (map['xp'] as num?)?.toInt() ?? 0,
      authProvider: map['authProvider'] as String? ?? 'guest',
      role: map['role'] as String? ?? 'student',
      emailVerified:
          (map['emailVerified'] == 1 || map['emailVerified'] == true),
      isLocked: (map['isLocked'] == 1 || map['isLocked'] == true),
      lockedReason: map['lockedReason'] as String? ?? '',
    );
  }
}
