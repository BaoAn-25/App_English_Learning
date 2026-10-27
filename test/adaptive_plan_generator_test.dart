import 'package:flutter_test/flutter_test.dart';

import 'package:thpt_english/data/models/attempt.dart';
import 'package:thpt_english/data/models/attempt_answer.dart';
import 'package:thpt_english/data/models/question.dart';
import 'package:thpt_english/data/models/wrong_book_entry.dart';
import 'package:thpt_english/ui/practice/models/adaptive_plan_models.dart';
import 'package:thpt_english/ui/practice/services/adaptive_learning_service.dart';
import 'package:thpt_english/ui/practice/services/adaptive_plan_generator.dart';

Question _makeQ(String id, String type, {int difficulty = 1}) {
  return Question(
    id: id,
    type: type,
    difficulty: difficulty,
    grade: 12,
    stem: 'Stem $id',
    options: const ['A', 'B', 'C', 'D'],
    correctIndex: 0,
    explanation: 'Explanation $id',
  );
}

void main() {
  final fixedNow = DateTime(2026, 10, 27, 12, 0, 0);

  // Tạo ngân hàng câu hỏi mẫu đa dạng 8 dạng bài
  final fullBank = <Question>[];
  for (final type in AdaptiveLearningService.standardTypes) {
    for (int i = 0; i < 15; i++) {
      fullBank.add(_makeQ('${type}_$i', type, difficulty: (i % 3) + 1));
    }
  }

  final generator = AdaptivePlanGenerator(seed: 42);

  group('AdaptivePlanGenerator - Unit Tests', () {
    test(
      '1. Cold start (Chưa có lịch sử): Sinh 3 nhiệm vụ hợp lý, không có task rỗng',
      () {
        final profile = AdaptiveLearningService.evaluateStudentProfile(
          questions: fullBank,
          attempts: [],
          answers: [],
          referenceTime: fixedNow,
        );

        final plan = generator.generatePlan(
          profile: profile,
          allQuestions: fullBank,
          wrongBookEntries: [],
          referenceTime: fixedNow,
        );

        expect(plan.hasTasks, isTrue);
        expect(plan.tasks.length, 3);

        // Task 1: Khảo sát năng lực chuyên đề đầu tiên
        final task1 = plan.tasks[0];
        expect(task1.priorityOrder, 1);
        expect(task1.type, AdaptiveTaskType.surveyUnassessed);
        expect(task1.isValid, isTrue);
        expect(task1.questionCount, 10);

        // Task 2: Khảo sát chuyên đề thứ hai (khác với dạng bài ở Task 1)
        final task2 = plan.tasks[1];
        expect(task2.priorityOrder, 2);
        expect(task2.type, AdaptiveTaskType.surveyUnassessed);
        expect(task2.targetType, isNot(equals(task1.targetType)));
        expect(task2.isValid, isTrue);

        // Task 3: Kiểm tra tổng hợp 10 câu
        final task3 = plan.tasks[2];
        expect(task3.priorityOrder, 3);
        expect(task3.type, AdaptiveTaskType.comprehensiveCheck);
        expect(task3.targetType, 'mixed');
        expect(task3.questionCount, 10);
      },
    );

    test('2. Có điểm yếu rõ rệt: Task 1 tập trung Chinh phục điểm yếu', () {
      // Giả lập học sinh làm 8 câu reading đều sai -> điểm yếu
      final attempts = [
        Attempt(
          id: 1,
          mode: 'mock_exam',
          type: null,
          startedAt: fixedNow.millisecondsSinceEpoch,
          durationSec: 300,
          score: 0,
          total: 8,
        ),
      ];
      final answers = List.generate(
        8,
        (i) => AttemptAnswer(
          attemptId: 1,
          questionId: 'reading_$i',
          chosenIndex: 1,
          isCorrect: false,
        ),
      );

      final profile = AdaptiveLearningService.evaluateStudentProfile(
        questions: fullBank,
        attempts: attempts,
        answers: answers,
        referenceTime: fixedNow,
      );

      expect(profile.primaryWeakness?.type, 'reading');

      final plan = generator.generatePlan(
        profile: profile,
        allQuestions: fullBank,
        allAnswers: answers,
        allAttempts: attempts,
        referenceTime: fixedNow,
      );

      final task1 = plan.tasks.first;
      expect(task1.type, AdaptiveTaskType.weaknessRemediation);
      expect(task1.targetType, 'reading');
      expect(task1.title, contains('Đọc hiểu'));
      expect(task1.reasoning, contains('độ chính xác thấp nhất'));
      expect(task1.isValid, isTrue);
    });

    test('3. Sổ câu sai có dữ liệu: Task 2 ưu tiên Ôn tập sổ câu sai', () {
      final profile = AdaptiveLearningService.evaluateStudentProfile(
        questions: fullBank,
        attempts: [],
        answers: [],
        referenceTime: fixedNow,
      );

      final wrongEntries = [
        WrongBookEntry(
          questionId: 'grammar_0',
          wrongCount: 3,
          lastWrongAt: fixedNow.millisecondsSinceEpoch,
          nextReviewAt: fixedNow.millisecondsSinceEpoch,
        ),
        WrongBookEntry(
          questionId: 'vocab_1',
          wrongCount: 1,
          lastWrongAt: fixedNow.millisecondsSinceEpoch,
          nextReviewAt: fixedNow.millisecondsSinceEpoch,
        ),
      ];

      final plan = generator.generatePlan(
        profile: profile,
        allQuestions: fullBank,
        wrongBookEntries: wrongEntries,
        referenceTime: fixedNow,
      );

      expect(plan.tasks.length, 3);
      final task2 = plan.tasks[1];
      expect(task2.type, AdaptiveTaskType.wrongBookReview);
      expect(task2.title, 'Ôn tập sổ câu sai');
      expect(task2.questionCount, 2);
      expect(
        task2.questions.map((q) => q.id),
        containsAll(['grammar_0', 'vocab_1']),
      );
    });

    test('4. Sổ câu sai rỗng: Task 2 tự động fallback sang Củng cố kỹ năng', () {
      final profile = AdaptiveLearningService.evaluateStudentProfile(
        questions: fullBank,
        attempts: [],
        answers: [],
        referenceTime: fixedNow,
      );

      // wrongBookEntries rỗng
      final plan = generator.generatePlan(
        profile: profile,
        allQuestions: fullBank,
        wrongBookEntries: [],
        referenceTime: fixedNow,
      );

      expect(plan.tasks.length, 3);
      final task2 = plan.tasks[1];
      // Không bị tạo task rỗng, mà chuyển sang khảo sát/củng cố chuyên đề khác
      expect(task2.type, isNot(AdaptiveTaskType.wrongBookReview));
      expect(task2.isValid, isTrue);
      expect(task2.questionCount, greaterThan(0));
    });

    test(
      '5. Tất cả dạng bài đều mạnh (Strong): Task 1 là Duy trì phong độ',
      () {
        // Giả lập làm 8 câu đúng cho cả 8 dạng bài
        final attempts = [
          Attempt(
            id: 1,
            mode: 'mock_exam',
            type: null,
            startedAt: fixedNow.millisecondsSinceEpoch,
            durationSec: 600,
            score: 64,
            total: 64,
          ),
        ];
        final answers = <AttemptAnswer>[];
        for (final type in AdaptiveLearningService.standardTypes) {
          for (int i = 0; i < 8; i++) {
            answers.add(
              AttemptAnswer(
                attemptId: 1,
                questionId: '${type}_$i',
                chosenIndex: 0,
                isCorrect: true,
              ),
            );
          }
        }

        final profile = AdaptiveLearningService.evaluateStudentProfile(
          questions: fullBank,
          attempts: attempts,
          answers: answers,
          referenceTime: fixedNow,
        );

        expect(profile.primaryWeakness, isNull);

        final plan = generator.generatePlan(
          profile: profile,
          allQuestions: fullBank,
          allAnswers: answers,
          allAttempts: attempts,
          referenceTime: fixedNow,
        );

        final task1 = plan.tasks.first;
        expect(task1.type, AdaptiveTaskType.masteryMaintenance);
        expect(task1.title, contains('Duy trì phong độ'));
        expect(task1.isValid, isTrue);
      },
    );

    test(
      '6. Ngân hàng câu hỏi hạn chế (chỉ có 2 câu): Báo cáo số câu thực tế, không crash',
      () {
        final miniBank = [_makeQ('g_1', 'grammar'), _makeQ('g_2', 'grammar')];

        final profile = AdaptiveLearningService.evaluateStudentProfile(
          questions: miniBank,
          attempts: [],
          answers: [],
          referenceTime: fixedNow,
        );

        final plan = generator.generatePlan(
          profile: profile,
          allQuestions: miniBank,
          wrongBookEntries: [],
          referenceTime: fixedNow,
        );

        expect(plan.hasTasks, isTrue);
        final task1 = plan.tasks.first;
        expect(task1.questionCount, 2);
        expect(task1.isValid, isTrue);
      },
    );

    test(
      '7. Không tạo nhiệm vụ trùng lặp targetType giữa Task 1 và Task 2',
      () {
        final profile = AdaptiveLearningService.evaluateStudentProfile(
          questions: fullBank,
          attempts: [],
          answers: [],
          referenceTime: fixedNow,
        );

        final plan = generator.generatePlan(
          profile: profile,
          allQuestions: fullBank,
          wrongBookEntries: [],
          referenceTime: fixedNow,
        );

        final task1 = plan.tasks[0];
        final task2 = plan.tasks[1];

        expect(task1.targetType, isNot(equals(task2.targetType)));
      },
    );

    test(
      '8. Tính xác định (Deterministic): Cùng seed và input cho ra plan y hệt nhau',
      () {
        final profile = AdaptiveLearningService.evaluateStudentProfile(
          questions: fullBank,
          attempts: [],
          answers: [],
          referenceTime: fixedNow,
        );

        final genA = AdaptivePlanGenerator(seed: 999);
        final genB = AdaptivePlanGenerator(seed: 999);

        final planA = genA.generatePlan(
          profile: profile,
          allQuestions: fullBank,
          referenceTime: fixedNow,
        );

        final planB = genB.generatePlan(
          profile: profile,
          allQuestions: fullBank,
          referenceTime: fixedNow,
        );

        expect(planA.tasks.length, equals(planB.tasks.length));
        for (int i = 0; i < planA.tasks.length; i++) {
          expect(planA.tasks[i].id, equals(planB.tasks[i].id));
          expect(planA.tasks[i].type, equals(planB.tasks[i].type));
          expect(planA.tasks[i].title, equals(planB.tasks[i].title));
          expect(
            planA.tasks[i].questionCount,
            equals(planB.tasks[i].questionCount),
          );
        }
      },
    );
  });
}
