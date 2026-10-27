import 'package:flutter_test/flutter_test.dart';
import 'package:thpt_english/data/models/daily_stat.dart';
import 'package:thpt_english/data/models/question.dart';
import 'package:thpt_english/data/models/attempt_answer.dart';
import 'package:thpt_english/ui/stats/stats_calculator.dart';

void main() {
  group('StatsCalculator Tests', () {
    test('1. Không có dữ liệu -> các chỉ số về 0 an toàn không crash', () {
      final summary = StatsCalculator.calculateOverallSummary(
        stats: [],
        attempts: [],
        answers: [],
        questions: [],
        rangeDays: 7,
      );

      expect(summary.totalQuestions, 0);
      expect(summary.totalCorrect, 0);
      expect(summary.overallAccuracy, 0.0);
      expect(summary.totalMinutes, 0);
      expect(summary.rangeStats.length, 7);
      expect(summary.typeSummaries.length, 8); // Đủ 8 dạng bài
      expect(summary.weakestType, isNull);
    });

    test('2. Tính toán chính xác tổng số câu, độ chính xác trong 7 ngày', () {
      final ref = DateTime(2026, 10, 27);
      final stats = [
        const DailyStat(date: '2026-10-27', xp: 50, questionsDone: 20, correct: 18, minutes: 25),
        const DailyStat(date: '2026-10-26', xp: 40, questionsDone: 10, correct: 7, minutes: 15),
        const DailyStat(date: '2026-10-25', xp: 60, questionsDone: 10, correct: 5, minutes: 20),
      ];

      final summary = StatsCalculator.calculateOverallSummary(
        stats: stats,
        attempts: [],
        answers: [],
        questions: [],
        rangeDays: 7,
        referenceDate: ref,
      );

      expect(summary.totalQuestions, 40);
      expect(summary.totalCorrect, 30);
      expect(summary.overallAccuracy, 75.0); // 30 / 40 * 100%
      expect(summary.totalMinutes, 60);
      expect(summary.rangeStats.length, 7);
    });

    test('3. Phân loại theo 8 dạng câu hỏi và tìm dạng yếu nhất', () {
      final questions = [
        const Question(
          id: 'q1',
          grade: 12,
          type: 'vocab',
          stem: 'vocab question',
          options: ['A', 'B'],
          correctIndex: 0,
          explanation: '',
          difficulty: 1,
        ),
        const Question(
          id: 'q2',
          grade: 12,
          type: 'reading',
          stem: 'reading question',
          options: ['A', 'B'],
          correctIndex: 1,
          explanation: '',
          difficulty: 2,
        ),
      ];

      final answers = [
        const AttemptAnswer(attemptId: 1, questionId: 'q1', chosenIndex: 0, isCorrect: true),
        const AttemptAnswer(attemptId: 1, questionId: 'q1', chosenIndex: 0, isCorrect: true),
        const AttemptAnswer(attemptId: 1, questionId: 'q2', chosenIndex: 0, isCorrect: false),
        const AttemptAnswer(attemptId: 1, questionId: 'q2', chosenIndex: 1, isCorrect: true),
      ];

      final summary = StatsCalculator.calculateOverallSummary(
        stats: [],
        attempts: [],
        answers: answers,
        questions: questions,
      );

      final vocabStat = summary.typeSummaries.firstWhere((t) => t.type == 'vocab');
      expect(vocabStat.totalQuestions, 2);
      expect(vocabStat.correctQuestions, 2);
      expect(vocabStat.accuracy, 100.0);

      final readingStat = summary.typeSummaries.firstWhere((t) => t.type == 'reading');
      expect(readingStat.totalQuestions, 2);
      expect(readingStat.correctQuestions, 1);
      expect(readingStat.accuracy, 50.0);

      // Dạng yếu nhất phải là reading (50% < 100%)
      expect(summary.weakestType, isNotNull);
      expect(summary.weakestType!.type, 'reading');
    });

    test('4. Hòa giải dữ liệu chênh lệch giữa local và server (ưu tiên giá trị cao hơn)', () {
      final local = [
        const DailyStat(date: '2026-10-27', xp: 50, questionsDone: 20, correct: 18, minutes: 25),
      ];
      final remote = [
        const DailyStat(date: '2026-10-27', xp: 70, questionsDone: 25, correct: 20, minutes: 30),
      ];

      final reconciled = StatsCalculator.reconcileDailyStats(local, remote);
      expect(reconciled.length, 1);
      expect(reconciled.first.xp, 70);
      expect(reconciled.first.questionsDone, 25);
      expect(reconciled.first.correct, 20);
      expect(reconciled.first.minutes, 30);
    });
  });
}
