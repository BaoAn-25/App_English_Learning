import 'package:flutter_test/flutter_test.dart';

import 'package:thpt_english/data/models/attempt.dart';
import 'package:thpt_english/data/models/attempt_answer.dart';
import 'package:thpt_english/data/models/question.dart';
import 'package:thpt_english/data/models/wrong_book_entry.dart';
import 'package:thpt_english/ui/practice/models/adaptive_models.dart';
import 'package:thpt_english/ui/practice/services/adaptive_learning_service.dart';

Question _makeQ(
  String id,
  String type, {
  int difficulty = 1,
  int correctIndex = 0,
}) {
  return Question(
    id: id,
    type: type,
    difficulty: difficulty,
    grade: 12,
    stem: 'Stem $id',
    options: const ['A', 'B', 'C', 'D'],
    correctIndex: correctIndex,
    explanation: 'Explanation $id',
  );
}

Attempt _makeAttempt({
  required int id,
  required int startedAt,
  String mode = 'practice',
}) {
  return Attempt(
    id: id,
    mode: mode,
    type: null,
    startedAt: startedAt,
    durationSec: 300,
    score: 0,
    total: 0,
  );
}

void main() {
  final fixedNow = DateTime(2026, 10, 27, 12, 0, 0);

  group('AdaptiveLearningService - Unit Tests', () {
    test(
      '1. Không có lịch sử: trả về đầy đủ 8 dạng bài ở trạng thái insufficientData',
      () {
        final questions = [_makeQ('q1', 'grammar'), _makeQ('q2', 'vocab')];

        final profile = AdaptiveLearningService.evaluateStudentProfile(
          questions: questions,
          attempts: [],
          answers: [],
          referenceTime: fixedNow,
        );

        expect(profile.skills.length, 8);
        expect(profile.totalQuestionsDone, 0);
        expect(profile.hasAnyHistory, isFalse);
        expect(profile.unassessedSkills.length, 8);
        expect(profile.primaryWeakness, isNull);
        expect(profile.primaryStrength, isNull);
        expect(profile.overallMastery, AdaptiveConfig.priorMastery);

        for (final s in profile.skills) {
          expect(s.totalAttempts, 0);
          expect(s.rawAccuracy, 0.0);
          expect(s.confidence, 0.0);
          expect(s.masteryScore, AdaptiveConfig.priorMastery);
          expect(s.level, AdaptiveSkillLevel.insufficientData);
          expect(s.practicePriority, greaterThan(70.0));
        }
      },
    );

    test(
      '2. Một câu đúng: không bị vọt lên 100% mastery và không bị gán strong',
      () {
        final questions = [_makeQ('q1', 'grammar')];
        final attempts = [
          _makeAttempt(id: 1, startedAt: fixedNow.millisecondsSinceEpoch),
        ];
        final answers = [
          const AttemptAnswer(
            attemptId: 1,
            questionId: 'q1',
            chosenIndex: 0,
            isCorrect: true,
          ),
        ];

        final profile = AdaptiveLearningService.evaluateStudentProfile(
          questions: questions,
          attempts: attempts,
          answers: answers,
          referenceTime: fixedNow,
        );

        final grammar = profile.findSkill('grammar')!;
        expect(grammar.totalAttempts, 1);
        expect(grammar.totalCorrect, 1);
        expect(grammar.rawAccuracy, 100.0);
        expect(grammar.confidence, closeTo(1 / 8, 0.01));
        // Điểm mastery mượt Bayes nằm trong khoảng 55-65, không thể đạt 100
        expect(grammar.masteryScore, greaterThan(50.0));
        expect(grammar.masteryScore, lessThan(65.0));
        // Vì mẫu ít nên bắt buộc là insufficientData, không được kết luận strong
        expect(grammar.level, AdaptiveSkillLevel.insufficientData);
      },
    );

    test('3. Một câu sai: không bị rớt xuống 0% mastery', () {
      final questions = [_makeQ('q1', 'vocab')];
      final attempts = [
        _makeAttempt(id: 1, startedAt: fixedNow.millisecondsSinceEpoch),
      ];
      final answers = [
        const AttemptAnswer(
          attemptId: 1,
          questionId: 'q1',
          chosenIndex: 1,
          isCorrect: false,
        ),
      ];

      final profile = AdaptiveLearningService.evaluateStudentProfile(
        questions: questions,
        attempts: attempts,
        answers: answers,
        referenceTime: fixedNow,
      );

      final vocab = profile.findSkill('vocab')!;
      expect(vocab.totalAttempts, 1);
      expect(vocab.totalWrong, 1);
      expect(vocab.rawAccuracy, 0.0);
      expect(vocab.confidence, closeTo(1 / 8, 0.01));
      // Điểm mượt Bayes nằm trong khoảng 35-45, không bị tụt về 0
      expect(vocab.masteryScore, greaterThan(35.0));
      expect(vocab.masteryScore, lessThan(50.0));
      expect(vocab.level, AdaptiveSkillLevel.insufficientData);
    });

    test('4. Tất cả câu đúng khi đủ mẫu: level = strong, confidence = 1.0', () {
      final questions = List.generate(
        10,
        (i) => _makeQ('g_$i', 'grammar', difficulty: 2),
      );
      final attempts = [
        _makeAttempt(id: 1, startedAt: fixedNow.millisecondsSinceEpoch),
      ];
      final answers = List.generate(
        10,
        (i) => AttemptAnswer(
          attemptId: 1,
          questionId: 'g_$i',
          chosenIndex: 0,
          isCorrect: true,
        ),
      );

      final profile = AdaptiveLearningService.evaluateStudentProfile(
        questions: questions,
        attempts: attempts,
        answers: answers,
        referenceTime: fixedNow,
      );

      final grammar = profile.findSkill('grammar')!;
      expect(grammar.totalCorrect, 10);
      expect(grammar.uniqueQuestionsSeen, 10);
      expect(grammar.confidence, 1.0);
      expect(grammar.rawAccuracy, 100.0);
      expect(grammar.masteryScore, greaterThan(85.0));
      expect(grammar.level, AdaptiveSkillLevel.strong);
      expect(profile.primaryStrength?.type, 'grammar');
    });

    test('5. Tất cả câu sai khi đủ mẫu: level = weak, masteryScore thấp', () {
      final questions = List.generate(
        8,
        (i) => _makeQ('r_$i', 'reading', difficulty: 2),
      );
      final attempts = [
        _makeAttempt(id: 1, startedAt: fixedNow.millisecondsSinceEpoch),
      ];
      final answers = List.generate(
        8,
        (i) => AttemptAnswer(
          attemptId: 1,
          questionId: 'r_$i',
          chosenIndex: 1,
          isCorrect: false,
        ),
      );

      final profile = AdaptiveLearningService.evaluateStudentProfile(
        questions: questions,
        attempts: attempts,
        answers: answers,
        referenceTime: fixedNow,
      );

      final reading = profile.findSkill('reading')!;
      expect(reading.totalWrong, 8);
      expect(reading.uniqueQuestionsSeen, 8);
      expect(reading.confidence, 1.0);
      expect(reading.rawAccuracy, 0.0);
      expect(reading.masteryScore, lessThan(30.0));
      expect(reading.level, AdaptiveSkillLevel.weak);
      expect(profile.primaryWeakness?.type, 'reading');
    });

    test(
      '6. Câu bỏ trống: tính vào totalUnanswered và không được tính là đúng',
      () {
        final questions = [_makeQ('q1', 'signs'), _makeQ('q2', 'signs')];
        final attempts = [
          _makeAttempt(id: 1, startedAt: fixedNow.millisecondsSinceEpoch),
        ];
        final answers = [
          const AttemptAnswer(
            attemptId: 1,
            questionId: 'q1',
            chosenIndex: 0,
            isCorrect: true,
          ),
          const AttemptAnswer(
            attemptId: 1,
            questionId: 'q2',
            chosenIndex: -1, // Bỏ trống
            isCorrect: false,
          ),
        ];

        final profile = AdaptiveLearningService.evaluateStudentProfile(
          questions: questions,
          attempts: attempts,
          answers: answers,
          referenceTime: fixedNow,
        );

        final signs = profile.findSkill('signs')!;
        expect(signs.totalAttempts, 2);
        expect(signs.totalCorrect, 1);
        expect(signs.totalUnanswered, 1);
        expect(signs.totalWrong, 0);
        expect(signs.rawAccuracy, 50.0);
      },
    );

    test(
      '7. Chỉ có lịch sử của một dạng bài: các dạng khác vẫn giữ insufficientData',
      () {
        final questions = List.generate(5, (i) => _makeQ('c_$i', 'cloze'));
        final attempts = [
          _makeAttempt(id: 1, startedAt: fixedNow.millisecondsSinceEpoch),
        ];
        final answers = List.generate(
          5,
          (i) => AttemptAnswer(
            attemptId: 1,
            questionId: 'c_$i',
            chosenIndex: 0,
            isCorrect: true,
          ),
        );

        final profile = AdaptiveLearningService.evaluateStudentProfile(
          questions: questions,
          attempts: attempts,
          answers: answers,
          referenceTime: fixedNow,
        );

        expect(profile.skills.length, 8);
        final cloze = profile.findSkill('cloze')!;
        expect(cloze.totalAttempts, 5);

        final otherSkills = profile.skills
            .where((s) => s.type != 'cloze')
            .toList();
        expect(otherSkills.length, 7);
        for (final s in otherSkills) {
          expect(s.totalAttempts, 0);
          expect(s.level, AdaptiveSkillLevel.insufficientData);
        }
      },
    );

    test(
      '8. Anti-grinding test: Một câu làm lặp 20 lần không chi phối bất hợp lý năng lực',
      () {
        final questions = [_makeQ('q1', 'grammar')];

        // Kịch bản A: Học sinh làm đúng 1 câu duy nhất 20 lần
        final attemptsA = List.generate(
          20,
          (i) => _makeAttempt(
            id: i + 1,
            startedAt: fixedNow
                .subtract(Duration(minutes: (20 - i) * 10))
                .millisecondsSinceEpoch,
          ),
        );
        final answersA = List.generate(
          20,
          (i) => AttemptAnswer(
            attemptId: i + 1,
            questionId: 'q1',
            chosenIndex: 0,
            isCorrect: true,
          ),
        );

        final profileA = AdaptiveLearningService.evaluateStudentProfile(
          questions: questions,
          attempts: attemptsA,
          answers: answersA,
          referenceTime: fixedNow,
        );

        final skillA = profileA.findSkill('grammar')!;
        expect(skillA.totalAttempts, 20);
        expect(skillA.uniqueQuestionsSeen, 1);
        // Dù làm đúng 20 lần, confidence vẫn bị chặn bởi số câu duy nhất (1/8)
        expect(skillA.confidence, closeTo(1 / 8, 0.01));
        // Level bắt buộc vẫn là insufficientData, không thể trở thành strong
        expect(skillA.level, AdaptiveSkillLevel.insufficientData);
        // Điểm mastery không thể vượt quá 65% do trọng số lặp lại bị giới hạn
        expect(skillA.masteryScore, lessThan(65.0));

        // Kịch bản B: Học sinh làm 8 câu KHÁC NHAU, mỗi câu 1 lần
        final questionsB = List.generate(8, (i) => _makeQ('g_$i', 'grammar'));
        final attemptsB = [
          _makeAttempt(id: 100, startedAt: fixedNow.millisecondsSinceEpoch),
        ];
        final answersB = List.generate(
          8,
          (i) => AttemptAnswer(
            attemptId: 100,
            questionId: 'g_$i',
            chosenIndex: 0,
            isCorrect: true,
          ),
        );

        final profileB = AdaptiveLearningService.evaluateStudentProfile(
          questions: questionsB,
          attempts: attemptsB,
          answers: answersB,
          referenceTime: fixedNow,
        );

        final skillB = profileB.findSkill('grammar')!;
        // Dù số lần làm (8) ít hơn nhiều so với 20, nhưng vì là 8 câu khác nhau nên độ tin cậy và mastery vượt trội
        expect(skillB.uniqueQuestionsSeen, 8);
        expect(skillB.confidence, 1.0);
        expect(skillB.masteryScore, greaterThan(skillA.masteryScore + 20.0));
        expect(skillB.level, AdaptiveSkillLevel.strong);
      },
    );

    test('9. Lịch sử cũ vs Lịch sử mới & Xu hướng tiến bộ (isImproving)', () {
      final questions = List.generate(8, (i) => _makeQ('v_$i', 'vocab'));

      // 4 câu làm cách đây 45 ngày: sai cả 4
      final oldAttempt = _makeAttempt(
        id: 1,
        startedAt: fixedNow
            .subtract(const Duration(days: 45))
            .millisecondsSinceEpoch,
      );
      final oldAnswers = List.generate(
        4,
        (i) => AttemptAnswer(
          attemptId: 1,
          questionId: 'v_$i',
          chosenIndex: 1,
          isCorrect: false,
        ),
      );

      // 4 câu làm hôm nay: đúng cả 4
      final newAttempt = _makeAttempt(
        id: 2,
        startedAt: fixedNow.millisecondsSinceEpoch,
      );
      final newAnswers = List.generate(
        4,
        (i) => AttemptAnswer(
          attemptId: 2,
          questionId: 'v_${i + 4}',
          chosenIndex: 0,
          isCorrect: true,
        ),
      );

      final profile = AdaptiveLearningService.evaluateStudentProfile(
        questions: questions,
        attempts: [oldAttempt, newAttempt],
        answers: [...oldAnswers, ...newAnswers],
        referenceTime: fixedNow,
      );

      final vocab = profile.findSkill('vocab')!;
      // Phong độ gần đây (100%) tốt hơn quá khứ (0%) -> isImproving = true
      expect(vocab.isImproving, isTrue);
      // Do trọng số thời gian (mới = 1.0, cũ = 0.5), điểm mastery sẽ lớn hơn 50%
      expect(vocab.masteryScore, greaterThan(50.0));
    });

    test(
      '10. Trọng số độ khó: Đúng câu khó (Diff 3) cho điểm cao hơn câu dễ (Diff 1)',
      () {
        final qEasy = [_makeQ('q_easy', 'grammar', difficulty: 1)];
        final qHard = [_makeQ('q_hard', 'grammar', difficulty: 3)];

        final attempt = _makeAttempt(
          id: 1,
          startedAt: fixedNow.millisecondsSinceEpoch,
        );

        // Profile 1: đúng 1 câu dễ
        final pEasy = AdaptiveLearningService.evaluateStudentProfile(
          questions: qEasy,
          attempts: [attempt],
          answers: [
            const AttemptAnswer(
              attemptId: 1,
              questionId: 'q_easy',
              chosenIndex: 0,
              isCorrect: true,
            ),
          ],
          referenceTime: fixedNow,
        );

        // Profile 2: đúng 1 câu khó
        final pHard = AdaptiveLearningService.evaluateStudentProfile(
          questions: qHard,
          attempts: [attempt],
          answers: [
            const AttemptAnswer(
              attemptId: 1,
              questionId: 'q_hard',
              chosenIndex: 0,
              isCorrect: true,
            ),
          ],
          referenceTime: fixedNow,
        );

        final scoreEasy = pEasy.findSkill('grammar')!.masteryScore;
        final scoreHard = pHard.findSkill('grammar')!.masteryScore;

        expect(scoreHard, greaterThan(scoreEasy));
      },
    );

    test(
      '11. Dữ liệu thiếu hoặc questionId không tồn tại: xử lý an toàn không crash',
      () {
        final questions = [_makeQ('q1', 'grammar')];
        final attempt = _makeAttempt(
          id: 1,
          startedAt: fixedNow.millisecondsSinceEpoch,
        );
        final answers = [
          const AttemptAnswer(
            attemptId: 1,
            questionId: 'non_existent_id',
            chosenIndex: 0,
            isCorrect: true,
          ),
        ];

        final profile = AdaptiveLearningService.evaluateStudentProfile(
          questions: questions,
          attempts: [attempt],
          answers: answers,
          referenceTime: fixedNow,
        );

        expect(profile.skills.length, 8);
        // Câu hỏi không hợp lệ bị bỏ qua an toàn
        expect(profile.totalQuestionsDone, 0);
      },
    );

    test(
      '12. Không chia cho 0, không NaN hoặc Infinity, điểm luôn trong [0, 100]',
      () {
        final questions = List.generate(
          8,
          (i) => _makeQ('q_$i', 'communication'),
        );
        final attempt = _makeAttempt(
          id: 1,
          startedAt: fixedNow.millisecondsSinceEpoch,
        );

        // Test mảng rỗng
        final p0 = AdaptiveLearningService.evaluateStudentProfile(
          questions: [],
          attempts: [],
          answers: [],
          referenceTime: fixedNow,
        );
        expect(p0.overallMastery.isNaN, isFalse);
        expect(p0.overallMastery.isInfinite, isFalse);
        expect(p0.overallMastery, inInclusiveRange(0.0, 100.0));

        // Test 8 câu đúng
        final p1 = AdaptiveLearningService.evaluateStudentProfile(
          questions: questions,
          attempts: [attempt],
          answers: List.generate(
            8,
            (i) => AttemptAnswer(
              attemptId: 1,
              questionId: 'q_$i',
              chosenIndex: 0,
              isCorrect: true,
            ),
          ),
          referenceTime: fixedNow,
        );
        for (final s in p1.skills) {
          expect(s.masteryScore.isNaN, isFalse);
          expect(s.masteryScore.isInfinite, isFalse);
          expect(s.masteryScore, inInclusiveRange(0.0, 100.0));
        }

        // Test 8 câu sai
        final p2 = AdaptiveLearningService.evaluateStudentProfile(
          questions: questions,
          attempts: [attempt],
          answers: List.generate(
            8,
            (i) => AttemptAnswer(
              attemptId: 1,
              questionId: 'q_$i',
              chosenIndex: 1,
              isCorrect: false,
            ),
          ),
          referenceTime: fixedNow,
        );
        for (final s in p2.skills) {
          expect(s.masteryScore.isNaN, isFalse);
          expect(s.masteryScore.isInfinite, isFalse);
          expect(s.masteryScore, inInclusiveRange(0.0, 100.0));
        }
      },
    );

    test(
      '13. Kết quả deterministic: Cùng đầu vào và referenceTime cho kết quả giống hệt nhau',
      () {
        final questions = [
          _makeQ('q1', 'grammar'),
          _makeQ('q2', 'grammar'),
          _makeQ('q3', 'vocab'),
        ];
        final attempt = _makeAttempt(
          id: 1,
          startedAt: fixedNow.millisecondsSinceEpoch,
        );
        final answers = [
          const AttemptAnswer(
            attemptId: 1,
            questionId: 'q1',
            chosenIndex: 0,
            isCorrect: true,
          ),
          const AttemptAnswer(
            attemptId: 1,
            questionId: 'q2',
            chosenIndex: 1,
            isCorrect: false,
          ),
          const AttemptAnswer(
            attemptId: 1,
            questionId: 'q3',
            chosenIndex: 0,
            isCorrect: true,
          ),
        ];

        final run1 = AdaptiveLearningService.evaluateStudentProfile(
          questions: questions,
          attempts: [attempt],
          answers: answers,
          referenceTime: fixedNow,
        );

        final run2 = AdaptiveLearningService.evaluateStudentProfile(
          questions: questions,
          attempts: [attempt],
          answers: answers,
          referenceTime: fixedNow,
        );

        expect(run1.overallMastery, equals(run2.overallMastery));
        for (int i = 0; i < 8; i++) {
          expect(
            run1.skills[i].masteryScore,
            equals(run2.skills[i].masteryScore),
          );
          expect(run1.skills[i].confidence, equals(run2.skills[i].confidence));
          expect(
            run1.skills[i].practicePriority,
            equals(run2.skills[i].practicePriority),
          );
          expect(run1.skills[i].level, equals(run2.skills[i].level));
        }
      },
    );

    test('14. Wrong Book count làm tăng Practice Priority của dạng bài', () {
      final questions = [_makeQ('q1', 'arrange')];
      final attempt = _makeAttempt(
        id: 1,
        startedAt: fixedNow.millisecondsSinceEpoch,
      );
      final answers = [
        const AttemptAnswer(
          attemptId: 1,
          questionId: 'q1',
          chosenIndex: 1,
          isCorrect: false,
        ),
      ];

      // Trường hợp không có wrong book
      final pWithoutWrong = AdaptiveLearningService.evaluateStudentProfile(
        questions: questions,
        attempts: [attempt],
        answers: answers,
        wrongEntries: [],
        referenceTime: fixedNow,
      );

      // Trường hợp có 3 câu sai trong wrong book
      final pWithWrong = AdaptiveLearningService.evaluateStudentProfile(
        questions: questions,
        attempts: [attempt],
        answers: answers,
        wrongEntries: [
          WrongBookEntry(
            questionId: 'q1',
            wrongCount: 3,
            lastWrongAt: fixedNow.millisecondsSinceEpoch,
            nextReviewAt: fixedNow.millisecondsSinceEpoch,
          ),
        ],
        referenceTime: fixedNow,
      );

      final priorityNormal = pWithoutWrong
          .findSkill('arrange')!
          .practicePriority;
      final priorityWithWrong = pWithWrong
          .findSkill('arrange')!
          .practicePriority;

      expect(priorityWithWrong, greaterThan(priorityNormal));
    });
  });
}
