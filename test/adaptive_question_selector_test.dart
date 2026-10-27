import 'package:flutter_test/flutter_test.dart';

import 'package:thpt_english/data/models/question.dart';
import 'package:thpt_english/ui/practice/services/adaptive_question_selector.dart';

Question _makeQ(
  String id,
  String type, {
  int difficulty = 1,
  String? passageId,
}) {
  return Question(
    id: id,
    type: type,
    difficulty: difficulty,
    grade: 12,
    stem: 'Stem $id',
    options: const ['A', 'B', 'C', 'D'],
    correctIndex: 0,
    explanation: 'Explanation $id',
    passageId: passageId,
  );
}

void main() {
  final selector = AdaptiveQuestionSelector(seed: 42);
  final fixedNow = DateTime(2026, 10, 27, 12, 0, 0).millisecondsSinceEpoch;

  group('AdaptiveQuestionSelector - Unit Tests', () {
    test(
      '1. Ngân hàng rỗng hoặc requestedCount <= 0: trả về kết quả rỗng an toàn',
      () {
        final res1 = selector.selectQuestions(bank: [], requestedCount: 10);
        expect(res1.questions, isEmpty);
        expect(res1.actualCount, 0);

        final res2 = selector.selectQuestions(
          bank: [_makeQ('q1', 'grammar')],
          requestedCount: 0,
        );
        expect(res2.questions, isEmpty);
        expect(res2.actualCount, 0);
      },
    );

    test(
      '2. Ưu tiên tuyệt đối câu chưa làm (unseen) trước câu đã làm (seen)',
      () {
        final bank = [
          _makeQ('q_seen_1', 'grammar'),
          _makeQ('q_seen_2', 'grammar'),
          _makeQ('q_unseen_1', 'grammar'),
          _makeQ('q_unseen_2', 'grammar'),
        ];

        final res = selector.selectQuestions(
          bank: bank,
          targetType: 'grammar',
          requestedCount: 2,
          seenQuestionIds: {'q_seen_1', 'q_seen_2'},
          referenceTimeMs: fixedNow,
        );

        expect(res.actualCount, 2);
        expect(res.unseenCount, 2);
        expect(res.recycledCount, 0);
        expect(
          res.questions.map((q) => q.id).toSet(),
          containsAll(['q_unseen_1', 'q_unseen_2']),
        );
      },
    );

    test(
      '3. Chọn lại câu cũ khi ngân hàng thiếu câu mới (Recycled fallback)',
      () {
        final bank = [
          _makeQ('q_seen_1', 'vocab'),
          _makeQ('q_seen_2', 'vocab'),
          _makeQ('q_unseen_1', 'vocab'),
        ];

        // Yêu cầu 3 câu nhưng chỉ có 1 câu unseen
        final res = selector.selectQuestions(
          bank: bank,
          targetType: 'vocab',
          requestedCount: 3,
          seenQuestionIds: {'q_seen_1', 'q_seen_2'},
          referenceTimeMs: fixedNow,
        );

        expect(res.actualCount, 3);
        expect(res.unseenCount, 1);
        expect(res.recycledCount, 2);
        expect(res.questions.first.id, 'q_unseen_1'); // Câu mới đứng đầu
      },
    );

    test(
      '4. Hạn chế câu vừa làm: ưu tiên câu cũ làm từ lâu nhất trong quá khứ',
      () {
        final bank = [
          _makeQ('q_recent', 'grammar'), // vừa làm cách đây 1 giờ
          _makeQ('q_medium', 'grammar'), // làm cách đây 10 ngày
          _makeQ('q_oldest', 'grammar'), // làm cách đây 40 ngày
        ];

        final oneHourAgo = fixedNow - const Duration(hours: 1).inMilliseconds;
        final tenDaysAgo = fixedNow - const Duration(days: 10).inMilliseconds;
        final fortyDaysAgo = fixedNow - const Duration(days: 40).inMilliseconds;

        final lastSeen = {
          'q_recent': oneHourAgo,
          'q_medium': tenDaysAgo,
          'q_oldest': fortyDaysAgo,
        };

        // Chọn 1 câu cũ
        final res = selector.selectQuestions(
          bank: bank,
          targetType: 'grammar',
          requestedCount: 1,
          seenQuestionIds: {'q_recent', 'q_medium', 'q_oldest'},
          lastSeenTimestamps: lastSeen,
          referenceTimeMs: fixedNow,
        );

        expect(res.actualCount, 1);
        // Câu làm từ lâu nhất (40 ngày trước) phải được chọn trước
        expect(res.questions.first.id, 'q_oldest');
      },
    );

    test('5. Không tạo câu hỏi trùng ID trong cùng một lần chọn', () {
      final bank = [
        _makeQ('q1', 'grammar'),
        _makeQ('q1', 'grammar'), // Trùng ID trong ngân hàng đầu vào
        _makeQ('q2', 'grammar'),
      ];

      final res = selector.selectQuestions(
        bank: bank,
        targetType: 'grammar',
        requestedCount: 3,
        referenceTimeMs: fixedNow,
      );

      expect(res.actualCount, 2);
      final idSet = res.questions.map((q) => q.id).toSet();
      expect(idSet.length, res.questions.length);
    });

    test(
      '6. Bảo toàn cụm bài đọc (passage): toàn bộ câu chung passageId đi liền nhau',
      () {
        final bank = [
          _makeQ('r_single_1', 'reading'),
          _makeQ('r_p1_q1', 'reading', passageId: 'p1'),
          _makeQ('r_p1_q2', 'reading', passageId: 'p1'),
          _makeQ('r_p1_q3', 'reading', passageId: 'p1'),
          _makeQ('r_single_2', 'reading'),
        ];

        final res = selector.selectQuestions(
          bank: bank,
          targetType: 'reading',
          requestedCount: 3,
          referenceTimeMs: fixedNow,
        );

        // Cụm p1 gồm 3 câu vừa khớp 3 câu yêu cầu
        expect(res.actualCount, 3);
        final p1Questions = res.questions
            .where((q) => q.passageId == 'p1')
            .toList();
        expect(p1Questions.length, 3);
        expect(p1Questions[0].id, 'r_p1_q1');
        expect(p1Questions[1].id, 'r_p1_q2');
        expect(p1Questions[2].id, 'r_p1_q3');
        expect(res.isPassagePreserved, isTrue);
      },
    );

    test(
      '7. Cụm bài đọc vượt số câu yêu cầu: bốc trọn cụm để bảo toàn ngữ cảnh bài đọc',
      () {
        // Bài đọc gồm 5 câu, yêu cầu chỉ 3 câu
        final bank = [
          _makeQ('r_p1_q1', 'reading', passageId: 'p1'),
          _makeQ('r_p1_q2', 'reading', passageId: 'p1'),
          _makeQ('r_p1_q3', 'reading', passageId: 'p1'),
          _makeQ('r_p1_q4', 'reading', passageId: 'p1'),
          _makeQ('r_p1_q5', 'reading', passageId: 'p1'),
        ];

        final res = selector.selectQuestions(
          bank: bank,
          targetType: 'reading',
          requestedCount: 3,
          referenceTimeMs: fixedNow,
        );

        // Quy tắc bảo toàn cụm: không cắt vụn bài đọc -> bốc trọn 5 câu
        expect(res.actualCount, 5);
        expect(res.countDifference, 2);
        expect(res.isPassagePreserved, isTrue);
      },
    );

    test(
      '8. Không bắt buộc difficulty 3: tự động fallback an toàn khi thiếu độ khó',
      () {
        // Ngân hàng chỉ có difficulty 1 và 2 (không có difficulty 3)
        final bank = [
          _makeQ('q1', 'cloze', difficulty: 1),
          _makeQ('q2', 'cloze', difficulty: 2),
          _makeQ('q3', 'cloze', difficulty: 2),
        ];

        final res = selector.selectQuestions(
          bank: bank,
          targetType: 'cloze',
          requestedCount: 3,
          preferredDifficulty: 3, // Yêu cầu mức 3
          referenceTimeMs: fixedNow,
        );

        // Vẫn lấy đủ 3 câu bình thường bằng cách fallback linh hoạt
        expect(res.actualCount, 3);
      },
    );

    test(
      '9. Deterministic: Cùng đầu vào và seed cho kết quả giống hệt nhau',
      () {
        final bank = List.generate(
          15,
          (i) => _makeQ('q_$i', 'grammar', difficulty: (i % 3) + 1),
        );

        final selectorA = AdaptiveQuestionSelector(seed: 123);
        final selectorB = AdaptiveQuestionSelector(seed: 123);

        final resA = selectorA.selectQuestions(
          bank: bank,
          targetType: 'grammar',
          requestedCount: 5,
          referenceTimeMs: fixedNow,
        );

        final resB = selectorB.selectQuestions(
          bank: bank,
          targetType: 'grammar',
          requestedCount: 5,
          referenceTimeMs: fixedNow,
        );

        expect(resA.actualCount, equals(resB.actualCount));
        for (int i = 0; i < resA.actualCount; i++) {
          expect(resA.questions[i].id, equals(resB.questions[i].id));
        }
      },
    );
  });
}
