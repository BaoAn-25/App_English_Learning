class DailyStat {
  final String date; // yyyy-MM-dd
  final int xp;
  final int questionsDone;
  final int correct;
  final int minutes;

  const DailyStat({
    required this.date,
    required this.xp,
    required this.questionsDone,
    required this.correct,
    required this.minutes,
  });

  factory DailyStat.fromMap(Map<String, dynamic> map) {
    return DailyStat(
      date: map['date'] as String,
      xp: (map['xp'] as num).toInt(),
      questionsDone: (map['questionsDone'] as num).toInt(),
      correct: (map['correct'] as num).toInt(),
      minutes: (map['minutes'] as num).toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'xp': xp,
      'questionsDone': questionsDone,
      'correct': correct,
      'minutes': minutes,
    };
  }
}
