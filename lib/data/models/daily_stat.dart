class DailyStat {
  final String date; // yyyy-MM-dd
  final String? ownerId;
  final int xp;
  final int questionsDone;
  final int correct;
  final int minutes;

  const DailyStat({
    required this.date,
    this.ownerId,
    required this.xp,
    required this.questionsDone,
    required this.correct,
    required this.minutes,
  });

  factory DailyStat.fromMap(Map<String, dynamic> map) {
    return DailyStat(
      date: map['date'] as String,
      ownerId: map['ownerId'] as String?,
      xp: (map['xp'] as num).toInt(),
      questionsDone: (map['questionsDone'] as num).toInt(),
      correct: (map['correct'] as num).toInt(),
      minutes: (map['minutes'] as num).toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'date': date,
      'xp': xp,
      'questionsDone': questionsDone,
      'correct': correct,
      'minutes': minutes,
    };
    if (ownerId != null && ownerId!.isNotEmpty) {
      map['ownerId'] = ownerId;
    }
    return map;
  }
}
