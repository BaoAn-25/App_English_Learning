import 'package:intl/intl.dart';
import '../../data/models/daily_stat.dart';

/// Các hàm thuần Dart tính toán Streak, Level từ XP và gộp dữ liệu Offline/Online.
class StreakCalculator {
  StreakCalculator._();

  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  /// Tính số ngày học liên tiếp (Streak) có `questionsDone > 0`.
  /// Streak được tính nếu hôm nay hoặc hôm qua có học (nếu hôm nay chưa học thì streak vẫn tính đến hôm qua).
  /// Xử lý chính xác việc chuyển ngày, chuyển tháng và chuyển năm.
  static int calculateStreak(List<DailyStat> stats, {DateTime? referenceDate}) {
    if (stats.isEmpty) return 0;

    // Lọc và tạo Set chứa các ngày đã hoàn thành bài tập (questionsDone > 0)
    final activeDates = <String>{};
    for (final s in stats) {
      if (s.questionsDone > 0) {
        activeDates.add(s.date);
      }
    }

    if (activeDates.isEmpty) return 0;

    final now = referenceDate ?? DateTime.now();
    final todayStr = _formatDate(now);
    final yesterdayStr = _formatDate(now.subtract(const Duration(days: 1)));

    // Xác định điểm bắt đầu đếm chuỗi:
    // Nếu hôm nay đã học -> bắt đầu từ hôm nay
    // Nếu hôm nay chưa học nhưng hôm qua đã học -> bắt đầu từ hôm qua
    // Nếu cả hôm nay và hôm qua đều chưa học -> streak = 0
    DateTime currentCheck;
    if (activeDates.contains(todayStr)) {
      currentCheck = now;
    } else if (activeDates.contains(yesterdayStr)) {
      currentCheck = now.subtract(const Duration(days: 1));
    } else {
      return 0;
    }

    int streak = 0;
    while (activeDates.contains(_formatDate(currentCheck))) {
      streak++;
      currentCheck = currentCheck.subtract(const Duration(days: 1));
    }

    return streak;
  }

  /// Tính cấp độ (Level) từ tổng điểm kinh nghiệm XP.
  /// Cấp 1: 0 - 99 XP
  /// Cấp 2: 100 - 199 XP
  /// Cấp n: (n - 1) * 100 XP
  static int calculateLevel(int totalXp) {
    if (totalXp <= 0) return 1;
    return (totalXp ~/ 100) + 1;
  }

  /// Tính phần trăm tiến độ đến cấp tiếp theo (0.0 -> 1.0)
  static double calculateLevelProgress(int totalXp) {
    if (totalXp <= 0) return 0.0;
    final xpInCurrentLevel = totalXp % 100;
    return xpInCurrentLevel / 100.0;
  }

  /// Gộp dữ liệu thống kê từ SQLite cục bộ và API đám mây:
  /// Nếu trùng ngày (date), ưu tiên bản có giá trị cao hơn (hoặc bản mới hơn)
  /// để không bao giờ làm mất điểm số hay số câu học sinh đã luyện tập.
  static List<DailyStat> mergeStats(
    List<DailyStat> localStats,
    List<DailyStat> remoteStats,
  ) {
    final Map<String, DailyStat> map = {};

    for (final stat in localStats) {
      map[stat.date] = stat;
    }

    for (final r in remoteStats) {
      if (!map.containsKey(r.date)) {
        map[r.date] = r;
      } else {
        final l = map[r.date]!;
        // Quy tắc hòa giải (reconciliation): lấy giá trị lớn nhất của từng chỉ số
        map[r.date] = DailyStat(
          date: r.date,
          xp: r.xp > l.xp ? r.xp : l.xp,
          questionsDone: r.questionsDone > l.questionsDone ? r.questionsDone : l.questionsDone,
          correct: r.correct > l.correct ? r.correct : l.correct,
          minutes: r.minutes > l.minutes ? r.minutes : l.minutes,
        );
      }
    }

    final result = map.values.toList();
    result.sort((a, b) => a.date.compareTo(b.date));
    return result;
  }

  static String _formatDate(DateTime dt) {
    return _dateFormat.format(dt);
  }
}
