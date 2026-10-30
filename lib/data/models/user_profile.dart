class UserProfile {
  final String id;
  final String displayName;
  final String email;
  final String avatarUrl;
  final double targetScore;
  final String examDate;
  final int dailyMinutes;
  final bool reminderEnabled;
  final String reminderTime;
  final List<String> favoriteTopics;
  final bool isLoggedIn;
  final int streakDays;
  final int xp;
  final String authProvider; // 'guest' | 'email' | 'google'

  const UserProfile({
    this.id = 'guest_user',
    this.displayName = 'Học sinh Prep12',
    this.email = 'student@prep12.app',
    this.avatarUrl = '',
    this.targetScore = 8.0,
    this.examDate = '2026-06-27',
    this.dailyMinutes = 20,
    this.reminderEnabled = true,
    this.reminderTime = '20:00',
    this.favoriteTopics = const ['Công nghệ', 'Môi trường', 'Khoa học'],
    this.isLoggedIn = false,
    this.streakDays = 3,
    this.xp = 120,
    this.authProvider = 'guest',
  });

  UserProfile copyWith({
    String? id,
    String? displayName,
    String? email,
    String? avatarUrl,
    double? targetScore,
    String? examDate,
    int? dailyMinutes,
    bool? reminderEnabled,
    String? reminderTime,
    List<String>? favoriteTopics,
    bool? isLoggedIn,
    int? streakDays,
    int? xp,
    String? authProvider,
  }) {
    return UserProfile(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      targetScore: targetScore ?? this.targetScore,
      examDate: examDate ?? this.examDate,
      dailyMinutes: dailyMinutes ?? this.dailyMinutes,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderTime: reminderTime ?? this.reminderTime,
      favoriteTopics: favoriteTopics ?? this.favoriteTopics,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      streakDays: streakDays ?? this.streakDays,
      xp: xp ?? this.xp,
      authProvider: authProvider ?? this.authProvider,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'displayName': displayName,
      'email': email,
      'avatarUrl': avatarUrl,
      'targetScore': targetScore,
      'examDate': examDate,
      'dailyMinutes': dailyMinutes,
      'reminderEnabled': reminderEnabled ? 1 : 0,
      'reminderTime': reminderTime,
      'favoriteTopics': favoriteTopics.join(','),
      'isLoggedIn': isLoggedIn ? 1 : 0,
      'streakDays': streakDays,
      'xp': xp,
      'authProvider': authProvider,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String? ?? 'guest_user',
      displayName: map['displayName'] as String? ?? 'Học sinh Prep12',
      email: map['email'] as String? ?? '',
      avatarUrl: map['avatarUrl'] as String? ?? '',
      targetScore: (map['targetScore'] as num?)?.toDouble() ?? 8.0,
      examDate: map['examDate'] as String? ?? '2026-06-27',
      dailyMinutes: (map['dailyMinutes'] as num?)?.toInt() ?? 20,
      reminderEnabled: (map['reminderEnabled'] == 1 || map['reminderEnabled'] == true),
      reminderTime: map['reminderTime'] as String? ?? '20:00',
      favoriteTopics: (map['favoriteTopics'] as String? ?? '')
          .split(',')
          .where((e) => e.trim().isNotEmpty)
          .toList(),
      isLoggedIn: (map['isLoggedIn'] == 1 || map['isLoggedIn'] == true),
      streakDays: (map['streakDays'] as num?)?.toInt() ?? 3,
      xp: (map['xp'] as num?)?.toInt() ?? 120,
      authProvider: map['authProvider'] as String? ?? 'guest',
    );
  }
}

