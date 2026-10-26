import 'package:flutter_test/flutter_test.dart';
import 'package:thpt_english/data/models/daily_stat.dart';
import 'package:thpt_english/ui/stats/learning_summary.dart';

DailyStat day(
  String date, {
  int questions = 10,
  int correct = 8,
  int xp = 20,
  int minutes = 5,
}) => DailyStat(
  date: date,
  xp: xp,
  questionsDone: questions,
  correct: correct,
  minutes: minutes,
);

void main() {
  final now = DateTime(2026, 1, 2, 12);
  test('empty summary has seven calendar days and no invented accuracy', () {
    final result = LearningSummary.fromStats([], now: now);
    expect(result.totalQuestions, 0);
    expect(result.accuracy, isNull);
    expect(result.streak, 0);
    expect(result.week.length, 7);
    expect(result.week.first.date, '2025-12-27');
    expect(result.week.last.date, '2026-01-02');
    expect(result.today.questionsDone, 0);
  });
  test('totals use all past data, accuracy is weighted, week fills gaps', () {
    final result = LearningSummary.fromStats([
      day('2025-12-01', questions: 90, correct: 45, xp: 90),
      day('2026-01-02', questions: 10, correct: 10, xp: 10),
      day('2026-01-03', questions: 100, correct: 100),
    ], now: now);
    expect(result.totalQuestions, 100);
    expect(result.totalXp, 100);
    expect(result.totalMinutes, 10);
    expect(result.accuracy, 0.55);
    expect(result.week.where((d) => d.questionsDone > 0).length, 1);
    expect(result.today.questionsDone, 10);
  });
  test('streak crosses year and counts yesterday when today is unfinished', () {
    final result = LearningSummary.fromStats([
      day('2025-12-30'),
      day('2025-12-31'),
      day('2026-01-01'),
    ], now: now);
    expect(result.streak, 3);
    final withToday = LearningSummary.fromStats([
      ...result.week,
      day('2026-01-02'),
    ], now: now);
    expect(withToday.streak, 4);
  });
  test(
    'streak resets at a gap and does not count xp without answered questions',
    () {
      expect(
        LearningSummary.fromStats([day('2025-12-31')], now: now).streak,
        0,
      );
      expect(
        LearningSummary.fromStats([
          day('2025-12-30'),
          day('2026-01-01', questions: 0, correct: 0),
          day('2026-01-02'),
        ], now: now).streak,
        1,
      );
    },
  );
  test('calendar days work across leap day', () {
    final result = LearningSummary.fromStats([
      day('2024-02-28'),
      day('2024-02-29'),
      day('2024-03-01'),
    ], now: DateTime(2024, 3, 1));
    expect(result.streak, 3);
    expect(result.week[5].date, '2024-02-29');
  });
}
