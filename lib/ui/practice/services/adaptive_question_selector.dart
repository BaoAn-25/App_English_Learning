import 'dart:math';

import '../../../data/models/question.dart';
import '../models/adaptive_plan_models.dart';

/// Đơn vị câu hỏi: một câu đơn lẻ hoặc một cụm các câu hỏi gắn liền với bài đọc (passage)
class _QuestionUnit {
  final String? passageId;
  final List<Question> questions;

  const _QuestionUnit({required this.passageId, required this.questions});

  int get length => questions.length;
  bool get isPassage =>
      passageId != null && passageId!.isNotEmpty && questions.length > 1;

  /// Độ khó trung bình của đơn vị câu hỏi
  double get averageDifficulty {
    if (questions.isEmpty) return 1.0;
    final sum = questions.fold(0, (acc, q) => acc + q.difficulty);
    return sum / questions.length;
  }
}

/// Service chuyên chọn lọc câu hỏi thích ứng từ ngân hàng câu hỏi
class AdaptiveQuestionSelector {
  final Random _random;

  AdaptiveQuestionSelector({int? seed}) : _random = Random(seed);

  /// Chọn bộ câu hỏi thích ứng theo yêu cầu cá nhân hóa
  ///
  /// - [bank]: Toàn bộ ngân hàng câu hỏi (hoặc tập hợp câu hỏi khả dụng)
  /// - [targetType]: Loại câu hỏi cần chọn (nếu null thì chọn tự do từ bank)
  /// - [requestedCount]: Số lượng câu hỏi mong muốn (mặc định 10)
  /// - [seenQuestionIds]: Tập hợp ID câu hỏi học sinh đã từng làm
  /// - [lastSeenTimestamps]: Ánh xạ ID câu hỏi -> timestamp lần làm gần nhất
  /// - [preferredDifficulty]: Độ khó ưu tiên nếu có (1, 2, 3), fallback linh hoạt nếu thiếu
  /// - [referenceTimeMs]: Thời điểm tham chiếu hiện tại (ms) để tính khoảng cách thời gian
  AdaptiveQuestionSelectionResult selectQuestions({
    required List<Question> bank,
    String? targetType,
    int requestedCount = 10,
    Set<String> seenQuestionIds = const {},
    Map<String, int> lastSeenTimestamps = const {},
    int? preferredDifficulty,
    int? referenceTimeMs,
  }) {
    if (bank.isEmpty || requestedCount <= 0) {
      return const AdaptiveQuestionSelectionResult(
        questions: [],
        requestedCount: 0,
        unseenCount: 0,
        recycledCount: 0,
        isPassagePreserved: true,
      );
    }

    final now = referenceTimeMs ?? DateTime.now().millisecondsSinceEpoch;

    // 1. Lọc theo targetType nếu có và khử trùng lặp questionId trong ngân hàng đầu vào
    final filtered = <Question>[];
    final seenBankIds = <String>{};
    for (final q in bank) {
      if (targetType != null && q.type != targetType) continue;
      if (seenBankIds.add(q.id)) {
        filtered.add(q);
      }
    }

    if (filtered.isEmpty) {
      return AdaptiveQuestionSelectionResult(
        questions: [],
        requestedCount: requestedCount,
        unseenCount: 0,
        recycledCount: 0,
        isPassagePreserved: true,
      );
    }

    // 2. Gom nhóm câu hỏi thành các QuestionUnit (bảo toàn cụm passageId)
    final units = _groupIntoUnits(filtered);

    // 3. Phân loại các units thành Unseen (chưa làm) và Seen (đã làm)
    final unseenUnits = <_QuestionUnit>[];
    final seenUnits = <_QuestionUnit>[];

    for (final unit in units) {
      final unseenInUnit = unit.questions
          .where((q) => !seenQuestionIds.contains(q.id))
          .length;

      if (unseenInUnit > 0) {
        unseenUnits.add(unit);
      } else {
        seenUnits.add(unit);
      }
    }

    // 4. Sắp xếp ưu tiên trong nhóm Unseen
    unseenUnits.shuffle(_random);
    unseenUnits.sort((a, b) {
      if (preferredDifficulty != null) {
        final aDiffMatch = (a.averageDifficulty - preferredDifficulty).abs();
        final bDiffMatch = (b.averageDifficulty - preferredDifficulty).abs();
        if (aDiffMatch != bDiffMatch) {
          return aDiffMatch.compareTo(bDiffMatch);
        }
      }
      // Ưu tiên cụm có nhiều câu chưa làm hơn
      final aUnseen = a.questions
          .where((q) => !seenQuestionIds.contains(q.id))
          .length;
      final bUnseen = b.questions
          .where((q) => !seenQuestionIds.contains(q.id))
          .length;
      if (bUnseen != aUnseen) {
        return bUnseen.compareTo(aUnseen);
      }
      return a.questions.first.id.compareTo(b.questions.first.id);
    });

    // 5. Sắp xếp trong nhóm Seen:
    seenUnits.shuffle(_random);
    seenUnits.sort((a, b) {
      final aOldest = _getOldestTimestamp(a.questions, lastSeenTimestamps, now);
      final bOldest = _getOldestTimestamp(b.questions, lastSeenTimestamps, now);

      // So sánh: timestamp nhỏ hơn (làm lâu hơn) đứng trước
      if (aOldest != bOldest) {
        return aOldest.compareTo(bOldest);
      }
      return a.questions.first.id.compareTo(b.questions.first.id);
    });

    // 6. Ghép danh sách candidate units: Unseen trước, sau đó bổ sung Seen
    final candidateUnits = <_QuestionUnit>[...unseenUnits, ...seenUnits];

    // 7. Thuật toán chọn câu hỏi bảo toàn cụm passage
    final selectedUnits = <_QuestionUnit>[];
    int currentCount = 0;

    for (int i = 0; i < candidateUnits.length; i++) {
      if (currentCount >= requestedCount) break;

      final unit = candidateUnits[i];
      final unitLen = unit.length;

      if (currentCount + unitLen <= requestedCount) {
        // Vừa khít hoặc chưa vượt quá requestedCount: nhận luôn
        selectedUnits.add(unit);
        currentCount += unitLen;
      } else {
        // Vượt quá requestedCount:
        if (currentCount == 0) {
          // Trường hợp đặc biệt: Chưa chọn được câu nào (ví dụ requestedCount = 3 nhưng passage có 5 câu)
          // Bắt buộc nhận trọn vẹn cụm passage này để không bỏ rơi bài đọc
          selectedUnits.add(unit);
          currentCount += unitLen;
          break;
        } else if (unit.isPassage) {
          // Đã có một số câu trước đó và cụm này là passage:
          // Nếu phần vượt quá nhỏ (<= 2 câu) và hiện tại chưa đạt 80% requestedCount: cho phép nhận trọn cụm
          if (currentCount + unitLen <= requestedCount + 2 &&
              currentCount < requestedCount) {
            selectedUnits.add(unit);
            currentCount += unitLen;
            break;
          }
          // Nếu dôi ra quá nhiều: bỏ qua cụm passage này, tìm cụm nhỏ hơn hoặc câu đơn lẻ phía sau
          continue;
        } else {
          // Câu đơn lẻ: nhận vào cho đến khi đủ
          selectedUnits.add(unit);
          currentCount += unitLen;
        }
      }
    }

    // 8. Trích xuất danh sách câu hỏi và thống kê
    final selectedQuestions = <Question>[];
    final selectedIdSet = <String>{};
    int unseenCount = 0;
    int recycledCount = 0;

    for (final unit in selectedUnits) {
      for (final q in unit.questions) {
        if (selectedIdSet.add(q.id)) {
          selectedQuestions.add(q);
          if (seenQuestionIds.contains(q.id)) {
            recycledCount++;
          } else {
            unseenCount++;
          }
        }
      }
    }

    return AdaptiveQuestionSelectionResult(
      questions: selectedQuestions,
      requestedCount: requestedCount,
      unseenCount: unseenCount,
      recycledCount: recycledCount,
      isPassagePreserved: true,
    );
  }

  /// Gom nhóm danh sách câu hỏi thành các QuestionUnit (bảo toàn passageId)
  List<_QuestionUnit> _groupIntoUnits(List<Question> input) {
    final passageMap = <String, List<Question>>{};
    final units = <_QuestionUnit>[];

    for (final q in input) {
      final pid = q.passageId;
      if (pid == null || pid.isEmpty) {
        units.add(_QuestionUnit(passageId: null, questions: [q]));
      } else {
        passageMap.putIfAbsent(pid, () => []).add(q);
      }
    }

    for (final entry in passageMap.entries) {
      final passageQuestions = entry.value
        ..sort(
          (a, b) => a.id.compareTo(b.id),
        ); // Giữ đúng thứ tự câu trong bài đọc
      units.add(
        _QuestionUnit(passageId: entry.key, questions: passageQuestions),
      );
    }

    return units;
  }

  /// Lấy timestamp làm bài xa nhất trong quá khứ của một danh sách câu
  int _getOldestTimestamp(
    List<Question> questions,
    Map<String, int> timestamps,
    int now,
  ) {
    int oldest = now;
    for (final q in questions) {
      final t = timestamps[q.id];
      if (t != null && t < oldest) {
        oldest = t;
      }
    }
    return oldest;
  }
}
