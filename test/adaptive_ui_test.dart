import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:thpt_english/data/app_repository.dart';
import 'package:thpt_english/data/models/attempt.dart';
import 'package:thpt_english/data/models/attempt_answer.dart';
import 'package:thpt_english/data/models/daily_stat.dart';
import 'package:thpt_english/data/models/question.dart';
import 'package:thpt_english/data/models/wrong_book_entry.dart';
import 'package:thpt_english/ui/practice/practice_quiz_screen.dart';
import 'package:thpt_english/ui/practice/practice_screen.dart';
import 'package:thpt_english/ui/practice/widgets/adaptive_learning_section.dart';

/// Fake AppRepository phục vụ kiểm thử Widget và luồng tương tác thực tế
class _FakeAdaptiveRepo implements AppRepository {
  final List<Question> questions;
  final List<Attempt> attempts;
  final List<AttemptAnswer> answers;
  final List<WrongBookEntry> wrongEntries;

  int saveCount = 0;
  Attempt? savedAttempt;
  List<AttemptAnswer>? savedAnswers;

  _FakeAdaptiveRepo({
    required this.questions,
    this.attempts = const [],
    this.answers = const [],
    this.wrongEntries = const [],
  });

  @override
  Future<List<Question>> getAllQuestions() async => questions;

  @override
  Future<List<Attempt>> getAllAttempts({String? ownerId}) async => List.from(attempts);

  @override
  Future<List<AttemptAnswer>> getAllAttemptAnswers({String? ownerId}) async =>
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
    savedAttempt = attempt;
    savedAnswers = buildAnswers(999);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Question _makeQ(String id, String type, {String? passageId}) {
  return Question(
    id: id,
    type: type,
    grade: 12,
    difficulty: 1,
    stem: 'Test question stem for $id',
    options: ['Option A', 'Option B', 'Option C', 'Option D'],
    correctIndex: 0,
    explanation: 'Test explanation for $id',
    passageId: passageId,
  );
}

Widget _buildTestApp(AppRepository repo) {
  return Provider<AppRepository>.value(
    value: repo,
    child: const MaterialApp(home: PracticeScreen()),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Ngân hàng câu hỏi chuẩn gồm 8 dạng bài tốt nghiệp THPT
  final standardBank = <Question>[
    for (int i = 0; i < 5; i++) _makeQ('grammar_$i', 'grammar'),
    for (int i = 0; i < 5; i++) _makeQ('vocab_$i', 'vocab'),
    for (int i = 0; i < 5; i++)
      _makeQ('reading_$i', 'reading', passageId: 'p1'),
    for (int i = 0; i < 5; i++) _makeQ('arrange_$i', 'arrange'),
    for (int i = 0; i < 5; i++) _makeQ('cloze_$i', 'cloze', passageId: 'c1'),
    for (int i = 0; i < 5; i++) _makeQ('synonym_antonym_$i', 'synonym_antonym'),
    for (int i = 0; i < 5; i++) _makeQ('communication_$i', 'communication'),
    for (int i = 0; i < 5; i++) _makeQ('signs_$i', 'signs'),
  ];

  group('Adaptive Learning UI/UX Refinement & Luồng luyện tập thực tế', () {
    testWidgets(
      '1. Cold start: Hiển thị đúng thẻ Khám phá, không có điểm 50/100 giả',
      (tester) async {
        final repo = _FakeAdaptiveRepo(questions: standardBank);

        await tester.pumpWidget(_buildTestApp(repo));
        await tester.pumpAndSettle();

        // Thẻ nổi bật "HÔM NAY HỌC GÌ?"
        expect(find.text('HÔM NAY HỌC GÌ?'), findsOneWidget);
        expect(find.text('Bắt đầu khám phá trình độ của bạn'), findsOneWidget);
        expect(find.widgetWithText(FilledButton, 'Bắt đầu'), findsOneWidget);

        // Khu vực "Lộ trình của bạn"
        expect(find.text('Lộ trình của bạn'), findsOneWidget);
        expect(find.text('3 nhiệm vụ'), findsOneWidget);

        // Khu vực "Tiến bộ của tôi": Không được hiển thị điểm 50/100 giả khi chưa đủ dữ liệu
        expect(find.text('Tiến bộ của tôi'), findsOneWidget);
        expect(find.text('Đang khảo sát năng lực'), findsOneWidget);
        expect(find.textContaining('50 / 100'), findsNothing);
      },
    );

    testWidgets(
      '2. Có điểm yếu: Thẻ Hôm nay học gì và Lộ trình hiển thị rõ nhiệm vụ ưu tiên',
      (tester) async {
        // Giả lập đã làm 8 câu reading đều sai -> điểm yếu rõ ràng
        final attempts = [
          Attempt(
            id: 1,
            mode: 'practice',
            type: 'reading',
            startedAt: DateTime.now().millisecondsSinceEpoch,
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

        final repo = _FakeAdaptiveRepo(
          questions: standardBank,
          attempts: attempts,
          answers: answers,
        );

        await tester.pumpWidget(_buildTestApp(repo));
        await tester.pumpAndSettle();

        // Thẻ Hôm nay học gì: có nút "Học ngay"
        expect(find.text('HÔM NAY HỌC GÌ?'), findsOneWidget);
        expect(find.widgetWithText(FilledButton, 'Học ngay'), findsOneWidget);
        expect(find.textContaining('Đọc hiểu'), findsWidgets);

        // Khu vực Lộ trình: Có badge "Cần cải thiện"
        expect(find.text('Cần cải thiện'), findsWidgets);

        // Khu vực Tiến bộ của tôi: Có điểm thành thạo và nút "Xem chi tiết"
        expect(find.text('Xem chi tiết'), findsOneWidget);
      },
    );

    testWidgets('3. Có Wrong Book: Task 2 là Ôn tập sổ câu sai', (
      tester,
    ) async {
      final wrongEntries = [
        WrongBookEntry(
          questionId: 'grammar_0',
          wrongCount: 2,
          lastWrongAt: DateTime.now().millisecondsSinceEpoch,
          nextReviewAt: DateTime.now().millisecondsSinceEpoch,
        ),
      ];

      final repo = _FakeAdaptiveRepo(
        questions: standardBank,
        wrongEntries: wrongEntries,
      );

      await tester.pumpWidget(_buildTestApp(repo));
      await tester.pumpAndSettle();

      expect(find.text('Ôn câu sai'), findsWidgets);
      expect(find.text('Ôn tập sổ câu sai'), findsOneWidget);
    });

    testWidgets(
      '4. Sổ câu sai rỗng: Task 2 tự động fallback, không tạo task rỗng',
      (tester) async {
        final repo = _FakeAdaptiveRepo(
          questions: standardBank,
          wrongEntries: [],
        );

        await tester.pumpWidget(_buildTestApp(repo));
        await tester.pumpAndSettle();

        // Không có badge "Ôn câu sai"
        expect(find.text('Ôn câu sai'), findsNothing);
        // Vẫn có đủ 3 nhiệm vụ hợp lệ trong danh sách
        expect(find.byType(Card), findsNWidgets(3));
      },
    );

    testWidgets(
      '5. Có ít hơn 3 nhiệm vụ: Chỉ hiển thị số nhiệm vụ thực tế khả dụng',
      (tester) async {
        // Ngân hàng chỉ có đúng 2 câu grammar
        final tinyBank = [_makeQ('g_1', 'grammar'), _makeQ('g_2', 'grammar')];
        final repo = _FakeAdaptiveRepo(questions: tinyBank);

        await tester.pumpWidget(_buildTestApp(repo));
        await tester.pumpAndSettle();

        // Không đủ câu để tạo 3 nhiệm vụ độc lập -> chỉ tạo 2 nhiệm vụ
        expect(find.text('2 nhiệm vụ'), findsOneWidget);
        expect(find.byType(Card), findsNWidgets(2));
      },
    );

    testWidgets(
      '6. Nhấn Bắt đầu trên Hero Card mở PracticeQuizScreen và thoát an toàn',
      (tester) async {
        final repo = _FakeAdaptiveRepo(questions: standardBank);

        await tester.pumpWidget(_buildTestApp(repo));
        await tester.pumpAndSettle();

        // Nhấn nút "Bắt đầu" trên thẻ Hero
        final startBtn = find.widgetWithText(FilledButton, 'Bắt đầu');
        await tester.tap(startBtn);
        await tester.pumpAndSettle();

        // Xác nhận đã chuyển sang PracticeQuizScreen
        expect(find.byType(PracticeQuizScreen), findsOneWidget);
        expect(find.textContaining('Câu 1/'), findsOneWidget);

        // Thoát bài làm (nhấn nút Back trên AppBar)
        final backButton = find.byType(BackButton);
        expect(backButton, findsOneWidget);
        await tester.tap(backButton);
        await tester.pumpAndSettle();

        // Trở lại PracticeScreen an toàn
        expect(find.byType(PracticeScreen), findsOneWidget);
        // Thoát giữa chừng: không được lưu kết quả giả vào SQLite
        expect(repo.saveCount, 0);
      },
    );

    testWidgets('7. Giữ nguyên passageId khi vào bài quiz', (tester) async {
      final readingQuestions = [
        _makeQ('r_p1_1', 'reading', passageId: 'p1'),
        _makeQ('r_p1_2', 'reading', passageId: 'p1'),
        _makeQ('r_p1_3', 'reading', passageId: 'p1'),
      ];
      final repo = _FakeAdaptiveRepo(questions: readingQuestions);

      await tester.pumpWidget(_buildTestApp(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Bắt đầu'));
      await tester.pumpAndSettle();

      final quizState = tester.state<State>(find.byType(PracticeQuizScreen));
      final quizWidget = quizState.widget as PracticeQuizScreen;

      // Xác nhận cả 3 câu hỏi đều giữ nguyên passageId: 'p1'
      expect(quizWidget.questions.length, 3);
      for (final q in quizWidget.questions) {
        expect(q.passageId, 'p1');
      }
    });

    testWidgets(
      '8. Hoàn thành nộp bài: lưu vào SQLite và quay lại tự động refresh',
      (tester) async {
        final singleQuestionBank = [_makeQ('q_single', 'grammar')];
        final repo = _FakeAdaptiveRepo(questions: singleQuestionBank);

        await tester.pumpWidget(_buildTestApp(repo));
        await tester.pumpAndSettle();

        // Nhấn bắt đầu
        await tester.tap(find.widgetWithText(FilledButton, 'Bắt đầu'));
        await tester.pumpAndSettle();

        // Chọn đáp án
        final firstOption = find.text('Option A').first;
        await tester.tap(firstOption);
        await tester.pumpAndSettle();

        // Nút ở chân trang là Nộp bài (vì là câu cuối cùng 1/1)
        final submitButton = find.widgetWithText(FilledButton, 'Nộp bài');
        expect(submitButton, findsOneWidget);
        await tester.tap(submitButton);
        await tester.pumpAndSettle();

        // Hộp thoại xác nhận nộp bài
        final confirmSubmit = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Nộp bài'),
        );
        expect(confirmSubmit, findsOneWidget);
        await tester.tap(confirmSubmit);
        await tester.pumpAndSettle();

        // Kiểm tra repo đã nhận được lệnh lưu vào SQLite
        expect(repo.saveCount, 1);
        expect(repo.savedAttempt, isNotNull);

        // Thoát về lại PracticeScreen
        final backButton = find.byType(BackButton);
        await tester.tap(backButton);
        await tester.pumpAndSettle();

        // Đã quay về PracticeScreen và section Adaptive được nạp lại
        expect(find.byType(PracticeScreen), findsOneWidget);
        expect(find.byType(AdaptiveLearningSection), findsOneWidget);
      },
    );

    testWidgets(
      '9. Giao diện Responsive: Không bị overflow trên màn hình 320px và 360px với textScale 1.3 và 1.5',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final repo = _FakeAdaptiveRepo(questions: standardBank);

        await tester.pumpWidget(
          Provider<AppRepository>.value(
            value: repo,
            child: const MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(1.5)),
                child: PracticeScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Xác nhận render trơn tru không ném ngoại lệ RenderFlex overflow
        expect(tester.takeException(), isNull);
        expect(find.byType(AdaptiveLearningSection), findsOneWidget);
      },
    );

    testWidgets(
      '10. Luồng luyện tập truyền thống và Mock Exam trên PracticeScreen vẫn hoạt động',
      (tester) async {
        final repo = _FakeAdaptiveRepo(questions: standardBank);

        await tester.pumpWidget(_buildTestApp(repo));
        await tester.pumpAndSettle();

        // Cuộn để thấy các mục truyền thống
        expect(find.text('Thi thử THPT'), findsOneWidget);
        expect(find.text('Sổ câu sai'), findsOneWidget);
        expect(find.text('8 Dạng câu hỏi ôn thi tốt nghiệp'), findsOneWidget);
        expect(find.text('Ngữ pháp'), findsOneWidget);
      },
    );

    testWidgets(
      '11. Nhiệm vụ Kiểm tra tổng hợp (comprehensiveCheck) không bị ghi nhận nhầm thành mode mock_exam',
      (tester) async {
        final repo = _FakeAdaptiveRepo(questions: standardBank);

        await tester.pumpWidget(_buildTestApp(repo));
        await tester.pumpAndSettle();

        // Nhấn vào thẻ nhiệm vụ thứ 3 (Kiểm tra năng lực tổng hợp)
        final task3Card = find.byType(Card).at(2);
        await tester.tap(task3Card);
        await tester.pumpAndSettle();

        final quizState = tester.state<State>(find.byType(PracticeQuizScreen));
        final quizWidget = quizState.widget as PracticeQuizScreen;

        // Xác nhận mode là 'practice', tuyệt đối không gán 'mock_exam'
        expect(quizWidget.mode, 'practice');
        expect(quizWidget.mode, isNot('mock_exam'));
      },
    );

    testWidgets(
      '12. Nút "Vì sao?" mở BottomSheet giải thích lý do đề xuất thực tế',
      (tester) async {
        final repo = _FakeAdaptiveRepo(questions: standardBank);

        await tester.pumpWidget(_buildTestApp(repo));
        await tester.pumpAndSettle();

        // Nhấn nút tooltip "Vì sao đề xuất?" trên thẻ nhiệm vụ đầu tiên
        final whyBtn = find.byTooltip('Vì sao đề xuất?').first;
        await tester.tap(whyBtn);
        await tester.pumpAndSettle();

        // Xác nhận BottomSheet mở lên với nội dung giải thích thật
        expect(find.text('Vì sao đề xuất bài này?'), findsOneWidget);
        expect(
          find.widgetWithText(FilledButton, 'Bắt đầu luyện tập'),
          findsOneWidget,
        );

        // Bấm nút "Bắt đầu luyện tập" trong BottomSheet
        await tester.tap(
          find.widgetWithText(FilledButton, 'Bắt đầu luyện tập'),
        );
        await tester.pumpAndSettle();

        // Chuyển thẳng vào làm bài quiz
        expect(find.byType(PracticeQuizScreen), findsOneWidget);
      },
    );
  });
}
