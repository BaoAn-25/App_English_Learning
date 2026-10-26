import '../../data/models/daily_stat.dart';

String dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class LearningSummary {
  final int totalXp;
  final int totalQuestions;
  final int totalCorrect;
  final int totalMinutes;
  final int streak;
  final List<DailyStat> week;

  const LearningSummary._({
    required this.totalXp,
    required this.totalQuestions,
    required this.totalCorrect,
    required this.totalMinutes,
    required this.streak,
    required this.week,
  });

  DailyStat get today => week.last;
  double? get accuracy =>
      totalQuestions == 0 ? null : totalCorrect / totalQuestions;

  factory LearningSummary.fromStats(
    List<DailyStat> stats, {
    required DateTime now,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final todayKey = dateKey(today);
    final byDate = <String, DailyStat>{};
    for (final stat in stats) {
      final parsed = DateTime.tryParse(stat.date);
      if (parsed != null &&
          dateKey(parsed) == stat.date &&
          stat.date.compareTo(todayKey) <= 0) {
        byDate[stat.date] = stat;
      }
    }
    final week = List.generate(7, (index) {
      final key = dateKey(
        DateTime(today.year, today.month, today.day - 6 + index),
      );
      return byDate[key] ??
          DailyStat(date: key, xp: 0, questionsDone: 0, correct: 0, minutes: 0);
    });
    var cursor = today;
    if ((byDate[todayKey]?.questionsDone ?? 0) == 0) {
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    var streak = 0;
    while ((byDate[dateKey(cursor)]?.questionsDone ?? 0) > 0) {
      streak++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    return LearningSummary._(
      totalXp: byDate.values.fold(0, (sum, day) => sum + day.xp),
      totalQuestions: byDate.values.fold(
        0,
        (sum, day) => sum + day.questionsDone,
      ),
      totalCorrect: byDate.values.fold(0, (sum, day) => sum + day.correct),
      totalMinutes: byDate.values.fold(0, (sum, day) => sum + day.minutes),
      streak: streak,
      week: List.unmodifiable(week),
    );
  }
}
