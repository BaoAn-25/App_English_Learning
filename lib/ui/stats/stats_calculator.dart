import 'package:intl/intl.dart';
import '../../data/models/attempt.dart';
import '../../data/models/attempt_answer.dart';
import '../../data/models/daily_stat.dart';
import '../../data/models/question.dart';
import '../strings.dart';

/// Thống kê chi tiết cho một dạng câu hỏi THPT
class TypeAccuracySummary {
  final String type;
  final String displayName;
  final int totalQuestions;
  final int correctQuestions;

  const TypeAccuracySummary({
    required this.type,
    required this.displayName,
    required this.totalQuestions,
    required this.correctQuestions,
  });

  double get accuracy =>
      totalQuestions > 0 ? (correctQuestions / totalQuestions) * 100.0 : 0.0;
}

/// Tổng hợp số liệu tiến độ cho màn hình Thống kê
class OverallStatsSummary {
  final int totalQuestions;
  final int totalCorrect;
  final double overallAccuracy;
  final int totalMinutes;
  final List<DailyStat> rangeStats;
  final List<TypeAccuracySummary> typeSummaries;
  final TypeAccuracySummary? weakestType;

  const OverallStatsSummary({
    required this.totalQuestions,
    required this.totalCorrect,
    required this.overallAccuracy,
    required this.totalMinutes,
    required this.rangeStats,
    required this.typeSummaries,
    this.weakestType,
  });
}

/// Các hàm thuần Dart tổng hợp và tính toán số liệu thống kê.
class StatsCalculator {
  StatsCalculator._();

  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  /// 8 dạng bài thi tốt nghiệp THPT chuẩn môn tiếng Anh
  static const List<String> standardQuestionTypes = [
    'vocab',
    'grammar',
    'synonym_antonym',
    'communication',
    'signs',
    'arrange',
    'cloze',
    'reading',
  ];

  /// Tính toán số liệu tổng hợp trong khoảng [rangeDays] ngày (mặc định 7 hoặc 30 ngày)
  static OverallStatsSummary calculateOverallSummary({
    required List<DailyStat> stats,
    required List<Attempt> attempts,
    required List<AttemptAnswer> answers,
    required List<Question> questions,
    int rangeDays = 7,
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();

    // 1. Tạo danh sách các ngày trong khoảng rangeDays tính ngược từ ngày tham chiếu
    final targetDates = <String>[];
    for (int i = rangeDays - 1; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      targetDates.add(_dateFormat.format(d));
    }

    // Map các DailyStat theo ngày
    final statMap = <String, DailyStat>{};
    for (final s in stats) {
      statMap[s.date] = s;
    }

    // Đảm bảo đủ các ngày trong khoảng (ngày nào chưa có dữ liệu thì điền 0)
    final rangeStats = <DailyStat>[];
    int totalQuestions = 0;
    int totalCorrect = 0;
    int totalMinutes = 0;

    for (final dateStr in targetDates) {
      final s = statMap[dateStr] ??
          DailyStat(
            date: dateStr,
            xp: 0,
            questionsDone: 0,
            correct: 0,
            minutes: 0,
          );
      rangeStats.add(s);
      totalQuestions += s.questionsDone;
      totalCorrect += s.correct;
      totalMinutes += s.minutes;
    }

    final double overallAccuracy =
        totalQuestions > 0 ? (totalCorrect / totalQuestions) * 100.0 : 0.0;

    // 2. Thống kê theo 8 dạng câu hỏi THPT
    // Map questionId -> Question
    final questionMap = <String, Question>{};
    for (final q in questions) {
      questionMap[q.id] = q;
    }

    // Đếm số câu và số câu đúng cho từng dạng
    final typeTotals = <String, int>{};
    final typeCorrects = <String, int>{};
    for (final t in standardQuestionTypes) {
      typeTotals[t] = 0;
      typeCorrects[t] = 0;
    }

    for (final ans in answers) {
      final q = questionMap[ans.questionId];
      if (q != null) {
        final qType = q.type.toLowerCase();
        if (typeTotals.containsKey(qType)) {
          typeTotals[qType] = (typeTotals[qType] ?? 0) + 1;
          if (ans.isCorrect) {
            typeCorrects[qType] = (typeCorrects[qType] ?? 0) + 1;
          }
        }
      }
    }

    // Nếu chưa có chi tiết attempt_answers, phân tích từ Attempt.type
    if (answers.isEmpty && attempts.isNotEmpty) {
      for (final att in attempts) {
        if (att.type != null) {
          final t = att.type!.toLowerCase();
          if (typeTotals.containsKey(t)) {
            typeTotals[t] = (typeTotals[t] ?? 0) + att.total;
            typeCorrects[t] = (typeCorrects[t] ?? 0) + att.score;
          }
        }
      }
    }

    final typeSummaries = <TypeAccuracySummary>[];
    for (final t in standardQuestionTypes) {
      typeSummaries.add(
        TypeAccuracySummary(
          type: t,
          displayName: AppStrings.questionTypeName(t),
          totalQuestions: typeTotals[t] ?? 0,
          correctQuestions: typeCorrects[t] ?? 0,
        ),
      );
    }

    // 3. Tìm dạng yếu nhất (có làm > 0 câu và có tỷ lệ đúng thấp nhất)
    TypeAccuracySummary? weakest;
    final attemptedTypes = typeSummaries.where((t) => t.totalQuestions > 0).toList();
    if (attemptedTypes.isNotEmpty) {
      attemptedTypes.sort((a, b) => a.accuracy.compareTo(b.accuracy));
      weakest = attemptedTypes.first;
    }

    return OverallStatsSummary(
      totalQuestions: totalQuestions,
      totalCorrect: totalCorrect,
      overallAccuracy: overallAccuracy,
      totalMinutes: totalMinutes,
      rangeStats: rangeStats,
      typeSummaries: typeSummaries,
      weakestType: weakest,
    );
  }

  /// Quy tắc hòa giải (Reconciliation) dữ liệu Local và Remote:
  /// - Ưu tiên bản có tổng số câu (questionsDone) hoặc XP lớn hơn.
  /// - Đảm bảo dữ liệu người dùng làm bài offline không bao giờ bị ghi đè mất mát.
  static List<DailyStat> reconcileDailyStats(
    List<DailyStat> localStats,
    List<DailyStat> remoteStats,
  ) {
    final Map<String, DailyStat> map = {};

    for (final s in localStats) {
      map[s.date] = s;
    }

    for (final r in remoteStats) {
      if (!map.containsKey(r.date)) {
        map[r.date] = r;
      } else {
        final l = map[r.date]!;
        map[r.date] = DailyStat(
          date: r.date,
          xp: r.xp > l.xp ? r.xp : l.xp,
          questionsDone: r.questionsDone > l.questionsDone ? r.questionsDone : l.questionsDone,
          correct: r.correct > l.correct ? r.correct : l.correct,
          minutes: r.minutes > l.minutes ? r.minutes : l.minutes,
        );
      }
    }

    final list = map.values.toList();
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }
}
