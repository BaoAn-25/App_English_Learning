import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:thpt_english/data/app_repository.dart';
import 'package:thpt_english/data/models/attempt.dart';
import 'package:thpt_english/data/models/attempt_answer.dart';
import 'package:thpt_english/data/models/daily_stat.dart';
import 'package:thpt_english/data/models/question.dart';
import 'package:thpt_english/data/models/wrong_book_entry.dart';
import 'package:thpt_english/ui/practice/models/adaptive_models.dart';
import 'package:thpt_english/ui/practice/models/adaptive_plan_models.dart';
import 'package:thpt_english/ui/practice/practice_quiz_screen.dart';
import 'package:thpt_english/ui/practice/practice_screen.dart';
import 'package:thpt_english/ui/practice/services/adaptive_learning_service.dart';
import 'package:thpt_english/ui/practice/services/adaptive_plan_generator.dart';
import 'package:thpt_english/ui/practice/services/adaptive_question_selector.dart';
import 'package:thpt_english/ui/practice/widgets/adaptive_learning_section.dart';

/// Fake repository mô phỏng SQLite đầy đủ cho kiểm thử Feedback Loop
class _FeedbackLoopFakeRepo implements AppRepository {
  final List<Question> questions;
  List<Attempt> attempts;
  List<AttemptAnswer> answers;
  List<WrongBookEntry> wrongEntries;

  int saveCount = 0;
  Attempt? lastSavedAttempt;
  List<AttemptAnswer>? lastSavedAnswers;

  _FeedbackLoopFakeRepo({
    required this.questions,
    List<Attempt>? attempts,
    List<AttemptAnswer>? answers,
    List<WrongBookEntry>? wrongEntries,
  }) : attempts = attempts ?? [],
       answers = answers ?? [],
       wrongEntries = wrongEntries ?? [];

  @override
  Future<List<Question>> getAllQuestions() async => List.from(questions);

  @override
  Future<List<Attempt>> getAllAttempts({String? ownerId}) async => List.from(attempts);

  @override
  Future<List<AttemptAnswer>> getAllAttemptAnswers() async =>
      List.from(answers);

  @override
  Future<List<WrongBookEntry>> getAllWrongBookEntries({String? ownerId}) async =>
      List.from(wrongEntries);

  @override
  Future<void> savePracticeResult({
    required Attempt attempt,
    required List<AttemptAnswer> Function(int attemptId) buildAnswers,
    required List<WrongBookEntry> wrongEntries,
    required DailyStat dailyStat,
    String? ownerId,
  }) async {
    saveCount++;
    final assignedId = attempts.length + 1;
    final savedAttemptWithId = Attempt(
      id: assignedId,
      mode: attempt.mode,
      type: attempt.type,
      score: attempt.score,
      total: attempt.total,
      durationSec: attempt.durationSec,
      startedAt: attempt.startedAt,
    );
    attempts.add(savedAttemptWithId);
    lastSavedAttempt = savedAttemptWithId;

    final built = buildAnswers(assignedId);
    answers.addAll(built);
    lastSavedAnswers = built;

    // Cập nhật wrongEntries
    this.wrongEntries = List.from(wrongEntries);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Question _createQuestion(
  String id,
  String type, {
  int difficulty = 1,
  String? passageId,
  int correctIndex = 0,
}) {
  return Question(
    id: id,
    type: type,
    grade: 12,
    difficulty: difficulty,
    stem: 'Stem for question $id',
    options: const ['Option A', 'Option B', 'Option C', 'Option D'],
    correctIndex: correctIndex,
    explanation: 'Explanation for $id',
    passageId: passageId,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final baseTime = DateTime(2026, 10, 27, 10, 0, 0);
  final baseTimeMs = baseTime.millisecondsSinceEpoch;

  // Ngân hàng chuẩn gồm 8 dạng câu hỏi THPT
  final testBank = <Question>[
    for (int i = 0; i < 6; i++)
      _createQuestion('grammar_$i', 'grammar', difficulty: (i % 2) + 1),
    for (int i = 0; i < 6; i++)
      _createQuestion('vocab_$i', 'vocab', difficulty: 2),
    for (int i = 0; i < 5; i++)
      _createQuestion(
        'reading_$i',
        'reading',
        difficulty: 2,
        passageId: 'passage_reading_1',
      ),
    for (int i = 0; i < 5; i++)
      _createQuestion(
        'cloze_$i',
        'cloze',
        difficulty: 1,
        passageId: 'passage_cloze_1',
      ),
    for (int i = 0; i < 6; i++)
      _createQuestion('arrange_$i', 'arrange', difficulty: 2),
    for (int i = 0; i < 6; i++)
      _createQuestion('synonym_antonym_$i', 'synonym_antonym', difficulty: 1),
    for (int i = 0; i < 6; i++)
      _createQuestion('communication_$i', 'communication', difficulty: 1),
    for (int i = 0; i < 6; i++)
      _createQuestion('signs_$i', 'signs', difficulty: 1),
  ];

  group('Adaptive Feedback Loop - 12 Yêu cầu cốt lõi', () {
    // -----------------------------------------------------------------------
    // 1. Làm sai nhiều ở một chuyên đề -> Chuyên đề được ưu tiên khi đủ dữ liệu
    // -----------------------------------------------------------------------
    test(
      '1. Làm sai nhiều ở grammar -> grammar là primaryWeakness và được ưu tiên trong Task 1',
      () {
        final List<Attempt> attempts = [
          Attempt(
            id: 1,
            mode: 'practice',
            type: 'grammar',
            score: 0,
            total: 6,
            durationSec: 120,
            startedAt: baseTimeMs - 200000,
          ),
        ];

        final answers = [
          for (int i = 0; i < 6; i++)
            AttemptAnswer(
              attemptId: 1,
              questionId: 'grammar_$i',
              chosenIndex: 1, // sai (correctIndex là 0)
              isCorrect: false,
            ),
        ];

        final profile = AdaptiveLearningService.evaluateStudentProfile(
          questions: testBank,
          attempts: attempts,
          answers: answers,
          referenceTime: baseTime,
        );

        final grammarSkill = profile.skills.firstWhere(
          (s) => s.type == 'grammar',
        );
        expect(grammarSkill.level, equals(AdaptiveSkillLevel.weak));
        expect(profile.primaryWeakness?.type, equals('grammar'));

        final plan = AdaptivePlanGenerator(seed: 42).generatePlan(
          profile: profile,
          allQuestions: testBank,
          allAnswers: answers,
          allAttempts: attempts,
          referenceTime: baseTime,
        );

        expect(plan.tasks.isNotEmpty, isTrue);
        final task1 = plan.tasks.first;
        expect(task1.type, equals(AdaptiveTaskType.weaknessRemediation));
        expect(task1.targetType, equals('grammar'));
        expect(task1.title, contains('Ngữ pháp'));
      },
    );

    // -----------------------------------------------------------------------
    // 2. Người dùng tiến bộ -> Mức đánh giá và thứ tự ưu tiên thay đổi hợp lý
    // -----------------------------------------------------------------------
    test(
      '2. Người dùng tiến bộ ở grammar -> không còn là điểm yếu, ưu tiên tự động chuyển dịch',
      () {
        // Ban đầu grammar yếu
        final List<Attempt> initialAttempts = [
          Attempt(
            id: 1,
            mode: 'practice',
            type: 'grammar',
            score: 0,
            total: 5,
            durationSec: 100,
            startedAt: baseTimeMs - 500000,
          ),
        ];
        final initialAnswers = [
          for (int i = 0; i < 5; i++)
            AttemptAnswer(
              attemptId: 1,
              questionId: 'grammar_$i',
              chosenIndex: 1,
              isCorrect: false,
            ),
        ];

        final initialProfile = AdaptiveLearningService.evaluateStudentProfile(
          questions: testBank,
          attempts: initialAttempts,
          answers: initialAnswers,
          referenceTime: baseTime,
        );
        expect(initialProfile.primaryWeakness?.type, equals('grammar'));

        // Sau đó làm bài đạt 100% đúng liên tục (tiến bộ vượt bậc)
        final List<Attempt> improvedAttempts = [
          ...initialAttempts,
          Attempt(
            id: 2,
            mode: 'practice',
            type: 'grammar',
            score: 5,
            total: 5,
            durationSec: 80,
            startedAt: baseTimeMs - 100000,
          ),
          Attempt(
            id: 3,
            mode: 'practice',
            type: 'grammar',
            score: 5,
            total: 5,
            durationSec: 70,
            startedAt: baseTimeMs - 40000,
          ),
        ];
        final improvedAnswers = [
          ...initialAnswers,
          for (int i = 0; i < 5; i++) ...[
            AttemptAnswer(
              attemptId: 2,
              questionId: 'grammar_$i',
              chosenIndex: 0,
              isCorrect: true,
            ),
            AttemptAnswer(
              attemptId: 3,
              questionId: 'grammar_$i',
              chosenIndex: 0,
              isCorrect: true,
            ),
          ],
        ];

        final updatedProfile = AdaptiveLearningService.evaluateStudentProfile(
          questions: testBank,
          attempts: improvedAttempts,
          answers: improvedAnswers,
          referenceTime: baseTime,
        );

        final updatedGrammar = updatedProfile.skills.firstWhere(
          (s) => s.type == 'grammar',
        );
        // Mastery phải tăng mạnh so với trước
        expect(
          updatedGrammar.masteryScore,
          greaterThan(
            initialProfile.skills
                .firstWhere((s) => s.type == 'grammar')
                .masteryScore,
          ),
        );
        // Không còn bị dán nhãn weak
        expect(updatedGrammar.level, isNot(equals(AdaptiveSkillLevel.weak)));
        // Điểm yếu nhất không còn là grammar
        expect(updatedProfile.primaryWeakness?.type, isNot(equals('grammar')));
      },
    );

    // -----------------------------------------------------------------------
    // 3. Chưa đủ dữ liệu -> Hệ thống khảo sát, không gắn nhãn yếu
    // -----------------------------------------------------------------------
    test(
      '3. Chỉ mới làm 1-2 câu reading -> level là insufficientData, task là surveyUnassessed',
      () {
        final List<Attempt> attempts = [
          Attempt(
            id: 1,
            mode: 'practice',
            type: 'reading',
            score: 0,
            total: 2,
            durationSec: 60,
            startedAt: baseTimeMs - 50000,
          ),
        ];
        final answers = [
          AttemptAnswer(
            attemptId: 1,
            questionId: 'reading_0',
            chosenIndex: 1,
            isCorrect: false,
          ),
          AttemptAnswer(
            attemptId: 1,
            questionId: 'reading_1',
            chosenIndex: 1,
            isCorrect: false,
          ),
        ];

        final profile = AdaptiveLearningService.evaluateStudentProfile(
          questions: testBank,
          attempts: attempts,
          answers: answers,
          referenceTime: baseTime,
        );

        final readingSkill = profile.skills.firstWhere(
          (s) => s.type == 'reading',
        );
        expect(readingSkill.level, equals(AdaptiveSkillLevel.insufficientData));

        final plan = AdaptivePlanGenerator(seed: 42).generatePlan(
          profile: profile,
          allQuestions: testBank,
          allAnswers: answers,
          allAttempts: attempts,
          referenceTime: baseTime,
        );

        // Task 1 phải là surveyUnassessed (Khảo sát năng lực), không quy chụp là weak
        final task1 = plan.tasks.first;
        expect(task1.type, equals(AdaptiveTaskType.surveyUnassessed));
        expect(task1.title, contains('Khảo sát năng lực'));
        expect(task1.reasoning, contains('chưa có đủ dữ liệu'));
      },
    );

    // -----------------------------------------------------------------------
    // 4. Có Wrong Book -> Ưu tiên câu sai theo 3 tầng dữ liệu SQLite
    // -----------------------------------------------------------------------
    test(
      '4. Wrong Book review ưu tiên: 1. Đến hạn ôn, 2. Sai nhiều lần, 3. Chưa ôn gần đây',
      () {
        // w1: Đến hạn ôn (nextReviewAt <= now)
        final w1 = WrongBookEntry(
          questionId: 'cloze_0',
          wrongCount: 1,
          lastWrongAt: baseTimeMs - 50000,
          nextReviewAt: baseTimeMs - 1000, // Đến hạn
        );

        // w2: Sai nhiều lần (wrongCount = 5), chưa đến hạn
        final w2 = WrongBookEntry(
          questionId: 'vocab_2',
          wrongCount: 5,
          lastWrongAt: baseTimeMs - 20000,
          nextReviewAt: baseTimeMs + 500000, // Chưa đến hạn
        );

        // w3: Sai 2 lần, chưa đến hạn, lastWrongAt cũ hơn (lâu chưa ôn)
        final w3 = WrongBookEntry(
          questionId: 'arrange_1',
          wrongCount: 2,
          lastWrongAt: baseTimeMs - 80000, // Cũ hơn
          nextReviewAt: baseTimeMs + 500000,
        );

        // w4: Sai 2 lần, chưa đến hạn, lastWrongAt mới hơn w3
        final w4 = WrongBookEntry(
          questionId: 'arrange_2',
          wrongCount: 2,
          lastWrongAt: baseTimeMs - 10000, // Mới hơn
          nextReviewAt: baseTimeMs + 500000,
        );

        final wrongEntries = [w4, w3, w2, w1];

        final profile = AdaptiveLearningService.evaluateStudentProfile(
          questions: testBank,
          attempts: [],
          answers: [],
          wrongEntries: wrongEntries,
          referenceTime: baseTime,
        );

        final plan = AdaptivePlanGenerator(seed: 42).generatePlan(
          profile: profile,
          allQuestions: testBank,
          wrongBookEntries: wrongEntries,
          referenceTime: baseTime,
        );

        // Task 2 phải là Wrong Book Review
        final task2 = plan.tasks.firstWhere(
          (t) => t.type == AdaptiveTaskType.wrongBookReview,
        );
        expect(task2, isNotNull);

        final ids = task2.questions.map((q) => q.id).toList();
        // w1 phải đứng trước vì đến hạn ôn
        expect(ids.indexOf('cloze_0'), lessThan(ids.indexOf('vocab_2')));
        // w2 phải đứng trước w3 vì wrongCount lớn hơn (5 > 2)
        expect(ids.indexOf('vocab_2'), lessThan(ids.indexOf('arrange_1')));
        // w3 phải đứng trước w4 vì lastWrongAt cũ hơn (lâu chưa ôn)
        expect(ids.indexOf('arrange_1'), lessThan(ids.indexOf('arrange_2')));
      },
    );

    // -----------------------------------------------------------------------
    // 5. Câu vừa làm -> Hạn chế xuất hiện lại nếu còn câu phù hợp khác (Cooldown 24h)
    // -----------------------------------------------------------------------
    test(
      '5. Cooldown 24h: Câu vừa làm trong 24h chỉ xuất hiện làm fallback khi hết câu',
      () {
        final selector = AdaptiveQuestionSelector(seed: 42);

        // 4 câu grammar: g0, g1 vừa làm 2 giờ trước; g2, g3 làm 3 ngày trước
        final grammarBank = [
          _createQuestion('grammar_0', 'grammar'),
          _createQuestion('grammar_1', 'grammar'),
          _createQuestion('grammar_2', 'grammar'),
          _createQuestion('grammar_3', 'grammar'),
        ];

        final timestamps = {
          'grammar_0': baseTimeMs - (2 * 60 * 60 * 1000), // 2h trước (< 24h)
          'grammar_1': baseTimeMs - (1 * 60 * 60 * 1000), // 1h trước (< 24h)
          'grammar_2':
              baseTimeMs - (72 * 60 * 60 * 1000), // 3 ngày trước (> 24h)
          'grammar_3':
              baseTimeMs - (80 * 60 * 60 * 1000), // > 3 ngày trước (> 24h)
        };

        final seenIds = {'grammar_0', 'grammar_1', 'grammar_2', 'grammar_3'};

        // Yêu cầu chọn 2 câu: Phải ưu tiên grammar_2 và grammar_3, không lấy grammar_0, grammar_1
        final res2 = selector.selectQuestions(
          bank: grammarBank,
          targetType: 'grammar',
          requestedCount: 2,
          seenQuestionIds: seenIds,
          lastSeenTimestamps: timestamps,
          referenceTimeMs: baseTimeMs,
        );

        expect(res2.questions.length, equals(2));
        final pickedIds = res2.questions.map((q) => q.id).toSet();
        expect(pickedIds.contains('grammar_2'), isTrue);
        expect(pickedIds.contains('grammar_3'), isTrue);
        expect(pickedIds.contains('grammar_0'), isFalse);
        expect(pickedIds.contains('grammar_1'), isFalse);

        // Yêu cầu chọn 4 câu: Khi hết câu > 24h, fallback hợp lý lấy thêm cả câu < 24h mà không crash
        final res4 = selector.selectQuestions(
          bank: grammarBank,
          targetType: 'grammar',
          requestedCount: 4,
          seenQuestionIds: seenIds,
          lastSeenTimestamps: timestamps,
          referenceTimeMs: baseTimeMs,
        );

        expect(res4.questions.length, equals(4));
      },
    );

    // -----------------------------------------------------------------------
    // 6. Ngân hàng câu hỏi nhỏ -> Fallback không crash
    // -----------------------------------------------------------------------
    test(
      '6. Ngân hàng chỉ có 3 câu, yêu cầu 10 câu -> Trả về 3 câu, không crash',
      () {
        final selector = AdaptiveQuestionSelector(seed: 42);
        final tinyBank = [
          _createQuestion('small_1', 'signs'),
          _createQuestion('small_2', 'signs'),
          _createQuestion('small_3', 'signs'),
        ];

        final res = selector.selectQuestions(
          bank: tinyBank,
          targetType: 'signs',
          requestedCount: 10,
        );

        expect(res.questions.length, equals(3));
        expect(res.requestedCount, equals(10));
      },
    );

    // -----------------------------------------------------------------------
    // 7. Passage group -> Không bị tách hoặc trùng ID
    // -----------------------------------------------------------------------
    test(
      '7. Đoạn văn reading có 5 câu -> Luôn nhận trọn cụm 5 câu, không bị tách rời',
      () {
        final selector = AdaptiveQuestionSelector(seed: 42);
        final readingQuestions = [
          _createQuestion('r1', 'reading', passageId: 'p_main'),
          _createQuestion('r2', 'reading', passageId: 'p_main'),
          _createQuestion('r3', 'reading', passageId: 'p_main'),
          _createQuestion('r4', 'reading', passageId: 'p_main'),
          _createQuestion('r5', 'reading', passageId: 'p_main'),
        ];

        final res = selector.selectQuestions(
          bank: readingQuestions,
          targetType: 'reading',
          requestedCount: 5,
        );

        expect(res.questions.length, equals(5));
        expect(res.isPassagePreserved, isTrue);
        // Kiểm tra tất cả câu đều chung 1 bài đọc
        final passageIds = res.questions.map((q) => q.passageId).toSet();
        expect(passageIds, equals({'p_main'}));
        // Không bị trùng ID
        expect(res.questions.map((q) => q.id).toSet().length, equals(5));
      },
    );

    // -----------------------------------------------------------------------
    // 8. Không có câu difficulty = 3 -> Fallback hợp lệ
    // -----------------------------------------------------------------------
    test(
      '8. Ngân hàng chỉ có difficulty 1 & 2, yêu cầu preferredDifficulty = 3 -> Tự động fallback',
      () {
        final selector = AdaptiveQuestionSelector(seed: 42);
        final bankWithoutDiff3 = [
          _createQuestion('d1_1', 'vocab', difficulty: 1),
          _createQuestion('d1_2', 'vocab', difficulty: 1),
          _createQuestion('d2_1', 'vocab', difficulty: 2),
          _createQuestion('d2_2', 'vocab', difficulty: 2),
        ];

        final res = selector.selectQuestions(
          bank: bankWithoutDiff3,
          targetType: 'vocab',
          requestedCount: 2,
          preferredDifficulty: 3, // Thử thách cao
        );

        // Phải chọn được 2 câu và ưu tiên câu có difficulty = 2 gần nhất với 3
        expect(res.questions.length, equals(2));
        expect(res.questions.every((q) => q.difficulty == 2), isTrue);
      },
    );

    // -----------------------------------------------------------------------
    // 9. Hoàn thành bài -> SQLite được lưu và plan được cập nhật
    // -----------------------------------------------------------------------
    testWidgets(
      '9. Nộp bài thành công: Lưu vào AppRepository và cập nhật lộ trình',
      (tester) async {
        final fakeRepo = _FeedbackLoopFakeRepo(questions: testBank);

        await tester.pumpWidget(
          Provider<AppRepository>.value(
            value: fakeRepo,
            child: const MaterialApp(home: PracticeScreen()),
          ),
        );

        // Chờ AdaptiveLearningSection load xong
        await tester.pumpAndSettle();
        expect(find.byType(AdaptiveLearningSection), findsOneWidget);

        // Nhấn nút bắt đầu trên Hero Card để mở PracticeQuizScreen
        final startBtn = find.text('Bắt đầu').evaluate().isNotEmpty
            ? find.text('Bắt đầu')
            : find.text('Học ngay');
        expect(startBtn, findsOneWidget);
        await tester.tap(startBtn);
        await tester.pumpAndSettle();

        // Kiểm tra đã sang PracticeQuizScreen
        expect(find.byType(PracticeQuizScreen), findsOneWidget);

        // Chọn đáp án A cho câu đầu tiên
        final optionA = find.text('Option A').first;
        await tester.tap(optionA);
        await tester.pumpAndSettle();

        // Chuyển sang các câu tiếp theo và chọn đáp án
        for (int i = 0; i < 9; i++) {
          final nextBtn = find.text('Câu tiếp');
          if (nextBtn.evaluate().isNotEmpty) {
            await tester.tap(nextBtn);
            await tester.pumpAndSettle();
            await tester.tap(find.text('Option A').first);
            await tester.pumpAndSettle();
          }
        }

        // Nhấn "Nộp bài" trên thanh điều hướng dưới
        final submitBtn = find.widgetWithText(FilledButton, 'Nộp bài');
        expect(submitBtn, findsOneWidget);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        // Xác nhận dialog nộp bài
        final confirmSubmit = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Nộp bài'),
        );
        expect(confirmSubmit, findsOneWidget);
        await tester.tap(confirmSubmit);
        await tester.pumpAndSettle();

        // Xác nhận kết quả đã lưu vào SQLite FakeRepo
        expect(fakeRepo.saveCount, equals(1));
        expect(fakeRepo.attempts.length, equals(1));
        expect(fakeRepo.answers.isNotEmpty, isTrue);

        // Nhấn nút Back trên AppBar để quay lại PracticeScreen
        final backButton = find.byType(BackButton);
        expect(backButton, findsOneWidget);
        await tester.tap(backButton);
        await tester.pumpAndSettle();

        // Đã quay về PracticeScreen
        expect(find.byType(PracticeScreen), findsOneWidget);
        expect(find.byType(AdaptiveLearningSection), findsOneWidget);
      },
    );

    // -----------------------------------------------------------------------
    // 10. Thoát giữa chừng -> Không lưu attempt giả
    // -----------------------------------------------------------------------
    testWidgets(
      '10. Thoát màn hình làm bài giữa chừng mà không nộp -> Không lưu attempt',
      (tester) async {
        final fakeRepo = _FeedbackLoopFakeRepo(questions: testBank);

        await tester.pumpWidget(
          Provider<AppRepository>.value(
            value: fakeRepo,
            child: const MaterialApp(home: PracticeScreen()),
          ),
        );

        await tester.pumpAndSettle();

        // Mở PracticeQuizScreen
        final startBtn = find.text('Bắt đầu').evaluate().isNotEmpty
            ? find.text('Bắt đầu')
            : find.text('Học ngay');
        await tester.tap(startBtn);
        await tester.pumpAndSettle();
        expect(find.byType(PracticeQuizScreen), findsOneWidget);

        // Trả lời 1 câu nhưng KHÔNG nộp bài
        await tester.tap(find.text('Option A').first);
        await tester.pumpAndSettle();

        // Nhấn nút Back trên AppBar để thoát
        final backBtn = find.byTooltip('Back');
        if (backBtn.evaluate().isNotEmpty) {
          await tester.tap(backBtn);
        } else {
          // Fallback pop
          final nav = tester.state<NavigatorState>(find.byType(Navigator));
          nav.pop();
        }
        await tester.pumpAndSettle();

        // Xác nhận không có lượt lưu attempt nào
        expect(fakeRepo.saveCount, equals(0));
        expect(fakeRepo.attempts.isEmpty, isTrue);
      },
    );

    // -----------------------------------------------------------------------
    // 11. Lịch sử Practice, Wrong Book và Mock Exam truyền thống không bị ảnh hưởng
    // -----------------------------------------------------------------------
    test('11. Chế độ (mode) của các nhiệm vụ Adaptive phân định chuẩn xác', () {
      final profile = AdaptiveLearningService.evaluateStudentProfile(
        questions: testBank,
        attempts: [],
        answers: [],
        wrongEntries: [
          WrongBookEntry(
            questionId: 'grammar_0',
            wrongCount: 2,
            lastWrongAt: baseTimeMs - 1000,
            nextReviewAt: baseTimeMs - 100,
          ),
        ],
        referenceTime: baseTime,
      );

      final plan = AdaptivePlanGenerator(seed: 42).generatePlan(
        profile: profile,
        allQuestions: testBank,
        wrongBookEntries: [
          WrongBookEntry(
            questionId: 'grammar_0',
            wrongCount: 2,
            lastWrongAt: baseTimeMs - 1000,
            nextReviewAt: baseTimeMs - 100,
          ),
        ],
        referenceTime: baseTime,
      );

      for (final task in plan.tasks) {
        if (task.type == AdaptiveTaskType.wrongBookReview) {
          // Ôn tập câu sai: targetType = wrong_review
          expect(task.targetType, equals('wrong_review'));
        } else if (task.type == AdaptiveTaskType.comprehensiveCheck) {
          // Comprehensive test: targetType = mixed, không gắn cờ 'mock_exam'
          expect(task.targetType, equals('mixed'));
        }
      }
    });

    // -----------------------------------------------------------------------
    // 12. Chạy nhiều lượt liên tiếp -> Không bị trùng dữ liệu hoặc race condition
    // -----------------------------------------------------------------------
    testWidgets(
      '12. Gọi reload liên tiếp trong AdaptiveLearningSection không bị race condition',
      (tester) async {
        final fakeRepo = _FeedbackLoopFakeRepo(questions: testBank);
        final sectionKey = GlobalKey<AdaptiveLearningSectionState>();

        await tester.pumpWidget(
          Provider<AppRepository>.value(
            value: fakeRepo,
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: AdaptiveLearningSection(key: sectionKey),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Kích hoạt reload 5 lần liên tiếp đồng thời
        sectionKey.currentState?.reload();
        sectionKey.currentState?.reload();
        sectionKey.currentState?.reload();
        sectionKey.currentState?.reload();
        sectionKey.currentState?.reload();

        await tester.pumpAndSettle();

        // UI hiển thị bình thường, không crash, không xuất hiện thông báo lỗi
        expect(find.byType(AdaptiveLearningSection), findsOneWidget);
        expect(find.textContaining('Không thể tải lộ trình'), findsNothing);
      },
    );

    // =======================================================================
    // REGRESSION TESTS - BƯỚC 5 CODE REVIEW
    // =======================================================================
    group('Task 3 Fallback & Deduplication Regression', () {
      test(
        'A. Ngân hàng đủ câu (>= 10 câu chưa dùng): Task 3 không trùng câu với Task 1 và Task 2',
        () {
          final profile = AdaptiveLearningService.evaluateStudentProfile(
            questions: testBank,
            attempts: [],
            answers: [],
            referenceTime: baseTime,
          );

          final plan = AdaptivePlanGenerator(seed: 42).generatePlan(
            profile: profile,
            allQuestions: testBank,
            referenceTime: baseTime,
          );

          expect(plan.tasks.length, greaterThanOrEqualTo(2));
          final task1Ids = plan.tasks[0].questions.map((q) => q.id).toSet();
          final task2Ids = plan.tasks.length > 1
              ? plan.tasks[1].questions.map((q) => q.id).toSet()
              : <String>{};
          final task3 = plan.tasks.firstWhere(
            (t) => t.type == AdaptiveTaskType.comprehensiveCheck,
          );
          final task3Ids = task3.questions.map((q) => q.id).toSet();

          // Không trùng Question ID giữa Task 3 và Task 1/Task 2
          for (final id in task3Ids) {
            expect(
              task1Ids.contains(id),
              isFalse,
              reason: 'Task 3 câu $id không được trùng với Task 1',
            );
            expect(
              task2Ids.contains(id),
              isFalse,
              reason: 'Task 3 câu $id không được trùng với Task 2',
            );
          }

          // Không có câu hỏi nào bị trùng lặp bên trong Task 3
          expect(task3.questions.length, equals(task3Ids.length));
          expect(task3.questions.length, equals(10));
        },
      );

      test(
        'B. Ngân hàng thiếu câu (< 10 câu chưa dùng): Ưu tiên tối đa câu chưa dùng, không trùng câu bên trong Task 3, bảo toàn passage',
        () {
          // Tạo ngân hàng nhỏ gồm 14 câu
          // 5 câu reading (chung passage p_sub), 3 câu grammar, 2 vocab, 2 cloze, 2 signs
          final limitedBank = <Question>[
            _createQuestion('r1', 'reading', passageId: 'p_sub'),
            _createQuestion('r2', 'reading', passageId: 'p_sub'),
            _createQuestion('r3', 'reading', passageId: 'p_sub'),
            _createQuestion('r4', 'reading', passageId: 'p_sub'),
            _createQuestion('r5', 'reading', passageId: 'p_sub'),
            _createQuestion('g1', 'grammar'),
            _createQuestion('g2', 'grammar'),
            _createQuestion('g3', 'grammar'),
            _createQuestion('v1', 'vocab'),
            _createQuestion('v2', 'vocab'),
            _createQuestion('c1', 'cloze'),
            _createQuestion('c2', 'cloze'),
            _createQuestion('s1', 'signs'),
            _createQuestion('s2', 'signs'),
          ];

          // Giả sử Task 1 và Task 2 sử dụng các câu grammar/vocab/cloze...
          // Số câu chưa dùng còn lại chỉ có 6 câu (r1..r5, s2) < 10 câu

          final profile = AdaptiveLearningService.evaluateStudentProfile(
            questions: limitedBank,
            attempts: [],
            answers: [],
            referenceTime: baseTime,
          );

          final plan = AdaptivePlanGenerator(seed: 42).generatePlan(
            profile: profile,
            allQuestions: limitedBank,
            referenceTime: baseTime,
          );

          final task3 = plan.tasks.firstWhere(
            (t) => t.type == AdaptiveTaskType.comprehensiveCheck,
          );

          final task3Questions = task3.questions;
          final task3Ids = task3Questions.map((q) => q.id).toSet();

          // 1. Không trùng lặp bất kỳ câu nào bên trong Task 3
          expect(task3Questions.length, equals(task3Ids.length));
          expect(task3Questions.length, equals(10));

          // 2. Bảo toàn cụm bài đọc p_sub (cả 5 câu reading phải đi liền nhau hoặc cùng xuất hiện)
          final readingInTask3 = task3Questions
              .where((q) => q.passageId == 'p_sub')
              .toList();
          expect(readingInTask3.length, equals(5));

          // 3. Ưu tiên tối đa số câu chưa dùng (s2 và r1..r5 đều được chọn)
          expect(task3Ids.contains('s2'), isTrue);
          for (int i = 1; i <= 5; i++) {
            expect(task3Ids.contains('r$i'), isTrue);
          }
        },
      );

      test(
        'C. Ngân hàng cực nhỏ (< 10 câu toàn bộ): Fallback an toàn, không crash, không trùng lặp',
        () {
          final tinyBank = <Question>[
            _createQuestion('t1', 'grammar'),
            _createQuestion('t2', 'vocab'),
            _createQuestion('t3', 'signs'),
            _createQuestion('t4', 'communication'),
          ];

          final profile = AdaptiveLearningService.evaluateStudentProfile(
            questions: tinyBank,
            attempts: [],
            answers: [],
            referenceTime: baseTime,
          );

          final plan = AdaptivePlanGenerator(seed: 42).generatePlan(
            profile: profile,
            allQuestions: tinyBank,
            referenceTime: baseTime,
          );

          final task3 = plan.tasks.firstWhere(
            (t) => t.type == AdaptiveTaskType.comprehensiveCheck,
          );

          expect(task3.questions.isNotEmpty, isTrue);
          expect(task3.questions.length, equals(tinyBank.length));
          expect(
            task3.questions.map((q) => q.id).toSet().length,
            equals(tinyBank.length),
          );
        },
      );
    });

    group('AdaptiveLearningSection Pending Refresh Regression', () {
      testWidgets(
        'D. Khi đang fetch dở, yêu cầu reload được giữ lại và tự kích hoạt để nạp kết quả mới nhất',
        (tester) async {
          // Dùng danh sách câu hỏi chuẩn
          final initialBank = List<Question>.from(testBank);
          final fakeRepo = _FeedbackLoopFakeRepo(questions: initialBank);
          final sectionKey = GlobalKey<AdaptiveLearningSectionState>();

          await tester.pumpWidget(
            Provider<AppRepository>.value(
              value: fakeRepo,
              child: MaterialApp(
                home: Scaffold(
                  body: SingleChildScrollView(
                    child: AdaptiveLearningSection(key: sectionKey),
                  ),
                ),
              ),
            ),
          );

          await tester.pumpAndSettle();
          expect(find.byType(AdaptiveLearningSection), findsOneWidget);

          // Ban đầu chưa có attempt nào
          expect(find.text('0 câu hỏi'), findsNothing);

          // Thêm một attempt mới vào repo
          final newAttempt = Attempt(
            id: 99,
            mode: 'practice',
            type: 'grammar',
            score: 8,
            total: 10,
            durationSec: 150,
            startedAt: baseTimeMs,
          );
          fakeRepo.attempts.add(newAttempt);
          for (int i = 0; i < 10; i++) {
            fakeRepo.answers.add(
              AttemptAnswer(
                attemptId: 99,
                questionId: 'grammar_${i % 6}',
                chosenIndex: 0,
                isCorrect: true,
              ),
            );
          }

          // Gọi reload 2 lần liên tiếp: lượt 2 sẽ rơi vào pending refresh
          sectionKey.currentState?.reload();
          sectionKey.currentState?.reload();

          await tester.pumpAndSettle();

          // Kết quả mới nhất được hiển thị trên giao diện:
          // Đã ghi nhận attempt, không còn là cold start "Bắt đầu" mà chuyển sang "Học ngay"
          expect(find.text('Học ngay'), findsOneWidget);
          expect(find.text('Bắt đầu'), findsNothing);
        },
      );
    });
  });
}
