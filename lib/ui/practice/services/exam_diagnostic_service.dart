import '../../../data/models/attempt_answer.dart';
import '../../../data/models/question.dart';

/// Kết quả phân tích hiệu suất của một dạng bài cụ thể
class TypePerformance {
  final String type;
  final String typeTitle;
  final int total;
  final int correct;
  final int wrong;
  final int unanswered;

  const TypePerformance({
    required this.type,
    required this.typeTitle,
    required this.total,
    required this.correct,
    required this.wrong,
    required this.unanswered,
  });

  /// Tỷ lệ trả lời đúng (%)
  double get accuracy => total == 0 ? 0.0 : (correct / total * 100);

  /// Đánh giá xem dạng bài có quá ít câu hỏi (<= 2 câu) để kết luận chắc chắn hay không
  bool get isSmallSample => total <= 2;

  @override
  String toString() =>
      'TypePerformance($type: $correct/$total, accuracy: ${accuracy.toStringAsFixed(1)}%)';
}

/// Tổng hợp kết quả chẩn đoán và phân tích điểm mạnh / điểm yếu bài thi
class ExamDiagnosticResult {
  final List<TypePerformance> breakdown;
  final TypePerformance? weakestType;
  final bool isPerfectScore;
  final int totalQuestions;
  final int totalCorrect;

  const ExamDiagnosticResult({
    required this.breakdown,
    required this.weakestType,
    required this.isPerfectScore,
    required this.totalQuestions,
    required this.totalCorrect,
  });

  double get overallAccuracy =>
      totalQuestions == 0 ? 0.0 : (totalCorrect / totalQuestions * 100);

  bool get hasData => breakdown.isNotEmpty;
}

/// Service phân tích kết quả bài thi theo từng dạng bài và phát hiện điểm yếu
class ExamDiagnosticService {
  static const Map<String, String> typeTitles = {
    'grammar': 'Ngữ pháp',
    'arrange': 'Sắp xếp câu',
    'vocab': 'Từ vựng',
    'synonym_antonym': 'Đồng - Trái nghĩa',
    'communication': 'Giao tiếp',
    'signs': 'Biển báo',
    'cloze': 'Điền từ',
    'reading': 'Đọc hiểu',
  };

  static String getTitleForType(String type) {
    return typeTitles[type] ?? type;
  }

  /// Phân tích từ danh sách câu hỏi và danh sách đáp án đã chọn (selectedAnswers dạng `List<int?>`)
  static ExamDiagnosticResult analyze({
    required List<Question> questions,
    required List<int?> selectedAnswers,
  }) {
    if (questions.isEmpty) {
      return const ExamDiagnosticResult(
        breakdown: [],
        weakestType: null,
        isPerfectScore: false,
        totalQuestions: 0,
        totalCorrect: 0,
      );
    }

    // 1. Nhóm câu hỏi theo dạng bài thực sự xuất hiện trong đề
    final Map<String, List<int>> typeIndices = {};
    for (int i = 0; i < questions.length; i++) {
      final type = questions[i].type;
      typeIndices.putIfAbsent(type, () => []).add(i);
    }

    int overallCorrect = 0;
    final List<TypePerformance> breakdown = [];

    // 2. Tính toán chi tiết cho từng dạng bài
    for (final entry in typeIndices.entries) {
      final type = entry.key;
      final indices = entry.value;

      int typeCorrect = 0;
      int typeWrong = 0;
      int typeUnanswered = 0;

      for (final i in indices) {
        final chosen = i < selectedAnswers.length ? selectedAnswers[i] : null;
        if (chosen == null || chosen < 0) {
          typeUnanswered++;
        } else if (chosen == questions[i].correctIndex) {
          typeCorrect++;
          overallCorrect++;
        } else {
          typeWrong++;
        }
      }

      breakdown.add(
        TypePerformance(
          type: type,
          typeTitle: getTitleForType(type),
          total: indices.length,
          correct: typeCorrect,
          wrong: typeWrong,
          unanswered: typeUnanswered,
        ),
      );
    }

    // Sắp xếp danh sách hiển thị: dạng bài có nhiều câu hơn đứng trước
    breakdown.sort((a, b) {
      final countCompare = b.total.compareTo(a.total);
      if (countCompare != 0) return countCompare;
      return a.typeTitle.compareTo(b.typeTitle);
    });

    final isPerfect = overallCorrect == questions.length;
    TypePerformance? weakest;

    if (!isPerfect && breakdown.isNotEmpty) {
      // Quy tắc xác định điểm yếu nhất:
      // 1. Tỷ lệ đúng thấp nhất (accuracy tăng dần)
      // 2. Nếu bằng nhau: Số câu hỏng (sai + bỏ trống) nhiều hơn
      // 3. Nếu bằng nhau: Tổng số câu nhiều hơn (mẫu thử lớn hơn)
      // 4. Nếu vẫn bằng nhau: Sắp xếp theo mã type chữ cái (tính ổn định cao)
      final candidates = List<TypePerformance>.from(breakdown);
      candidates.sort((a, b) {
        final accCompare = a.accuracy.compareTo(b.accuracy);
        if (accCompare != 0) return accCompare;

        final missedA = a.wrong + a.unanswered;
        final missedB = b.wrong + b.unanswered;
        final missedCompare = missedB.compareTo(missedA);
        if (missedCompare != 0) return missedCompare;

        final totalCompare = b.total.compareTo(a.total);
        if (totalCompare != 0) return totalCompare;

        return a.type.compareTo(b.type);
      });

      // Chỉ chọn điểm yếu nếu tỷ lệ đúng dưới 100%
      if (candidates.first.accuracy < 100) {
        weakest = candidates.first;
      }
    }

    return ExamDiagnosticResult(
      breakdown: breakdown,
      weakestType: weakest,
      isPerfectScore: isPerfect,
      totalQuestions: questions.length,
      totalCorrect: overallCorrect,
    );
  }

  /// Phân tích từ danh sách câu hỏi và danh sách AttemptAnswer (dùng cho màn xem lại bài)
  static ExamDiagnosticResult analyzeFromAttemptAnswers({
    required List<Question> questions,
    required List<AttemptAnswer> answers,
  }) {
    final Map<String, int> answerMap = {
      for (final a in answers) a.questionId: a.chosenIndex,
    };

    final selectedAnswers = questions.map((q) => answerMap[q.id]).toList();

    return analyze(
      questions: questions,
      selectedAnswers: selectedAnswers,
    );
  }
}
