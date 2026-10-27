import 'package:flutter_test/flutter_test.dart';
import 'package:thpt_english/data/models/daily_stat.dart';
import 'package:thpt_english/ui/home/streak_calculator.dart';

void main() {
  group('StreakCalculator Tests', () {
    test('1. Không có dữ liệu -> streak = 0 và level = 1', () {
      final streak = StreakCalculator.calculateStreak([]);
      expect(streak, 0);

      final level = StreakCalculator.calculateLevel(0);
      expect(level, 1);
    });

    test('2. Hôm nay chưa học nhưng hôm qua có học -> vẫn giữ streak', () {
      final today = DateTime(2026, 10, 27);
      final stats = [
        const DailyStat(date: '2026-10-26', xp: 50, questionsDone: 10, correct: 9, minutes: 15),
        const DailyStat(date: '2026-10-25', xp: 60, questionsDone: 12, correct: 10, minutes: 18),
      ];

      final streak = StreakCalculator.calculateStreak(stats, referenceDate: today);
      expect(streak, 2);
    });

    test('3. Hôm nay có học và các ngày trước có học liên tiếp', () {
      final today = DateTime(2026, 10, 27);
      final stats = [
        const DailyStat(date: '2026-10-27', xp: 40, questionsDone: 8, correct: 7, minutes: 12),
        const DailyStat(date: '2026-10-26', xp: 50, questionsDone: 10, correct: 9, minutes: 15),
        const DailyStat(date: '2026-10-25', xp: 60, questionsDone: 12, correct: 10, minutes: 18),
      ];

      final streak = StreakCalculator.calculateStreak(stats, referenceDate: today);
      expect(streak, 3);
    });

    test('4. Bỏ ngày giữa chừng -> streak chỉ tính chuỗi liên tiếp gần nhất', () {
      final today = DateTime(2026, 10, 27);
      final stats = [
        const DailyStat(date: '2026-10-27', xp: 50, questionsDone: 10, correct: 8, minutes: 15),
        const DailyStat(date: '2026-10-26', xp: 40, questionsDone: 8, correct: 7, minutes: 10),
        // Ngày 2026-10-25 bị bỏ lỡ
        const DailyStat(date: '2026-10-24', xp: 50, questionsDone: 10, correct: 8, minutes: 15),
        const DailyStat(date: '2026-10-23', xp: 50, questionsDone: 10, correct: 8, minutes: 15),
      ];

      final streak = StreakCalculator.calculateStreak(stats, referenceDate: today);
      expect(streak, 2);
    });

    test('5. Chuyển giao qua tháng và qua năm', () {
      // Ngày tham chiếu: 02/01/2026
      final today = DateTime(2026, 1, 2);
      final stats = [
        const DailyStat(date: '2026-01-02', xp: 20, questionsDone: 5, correct: 4, minutes: 8),
        const DailyStat(date: '2026-01-01', xp: 20, questionsDone: 5, correct: 4, minutes: 8),
        const DailyStat(date: '2025-12-31', xp: 30, questionsDone: 6, correct: 5, minutes: 10),
        const DailyStat(date: '2025-12-30', xp: 30, questionsDone: 6, correct: 5, minutes: 10),
      ];

      final streak = StreakCalculator.calculateStreak(stats, referenceDate: today);
      expect(streak, 4);
    });

    test('6. Tính cấp độ (Level) từ tổng XP', () {
      expect(StreakCalculator.calculateLevel(0), 1);
      expect(StreakCalculator.calculateLevel(50), 1);
      expect(StreakCalculator.calculateLevel(100), 2);
      expect(StreakCalculator.calculateLevel(250), 3);
      expect(StreakCalculator.calculateLevel(999), 10);
    });

    test('7. Gộp dữ liệu local và API (mergeStats)', () {
      final local = [
        const DailyStat(date: '2026-10-26', xp: 50, questionsDone: 10, correct: 8, minutes: 15),
        const DailyStat(date: '2026-10-27', xp: 30, questionsDone: 5, correct: 4, minutes: 10),
      ];
      final remote = [
        // Ngày 26 trên server cập nhật cao hơn do đã làm trên máy khác
        const DailyStat(date: '2026-10-26', xp: 80, questionsDone: 15, correct: 14, minutes: 20),
        // Ngày 25 chỉ có trên server
        const DailyStat(date: '2026-10-25', xp: 40, questionsDone: 8, correct: 7, minutes: 12),
      ];

      final merged = StreakCalculator.mergeStats(local, remote);
      expect(merged.length, 3);

      final stat26 = merged.firstWhere((e) => e.date == '2026-10-26');
      expect(stat26.xp, 80);
      expect(stat26.questionsDone, 15);

      final stat27 = merged.firstWhere((e) => e.date == '2026-10-27');
      expect(stat27.xp, 30);
    });
  });
}
