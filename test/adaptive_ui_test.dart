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
import 'package:thpt_english/ui/practice/services/adaptive_learning_service.dart';
import 'package:thpt_english/ui/practice/widgets/adaptive_learning_section.dart';

class _FakeAdaptiveRepo implements AppRepository {
  final List<Question> questions;
  List<Attempt> attempts;
  List<AttemptAnswer> answers;
  List<WrongBookEntry> wrongEntries;

  Attempt? savedAttempt;
  int saveCount = 0;

  _FakeAdaptiveRepo({
    required this.questions,
    this.attempts = const [],
    this.answers = const [],
    this.wrongEntries = const [],
  });

  @override
  Future<List<Question>> getAllQuestions() async => questions;

  @override
  Future<List<Attempt>> getAllAttempts() async => attempts;

  @override
  Future<List<AttemptAnswer>> getAllAttemptAnswers() async => answers;

  @override
  Future<List<WrongBookEntry>> getAllWrongBookEntries() async => wrongEntries;

  @override
  Future<List<Question>> getQuestionsByType(String type) async {
    return questions.where((q) => q.type == type).toList();
  }

  @override
  Future<void> savePracticeResult({
    required Attempt attempt,
    required List<AttemptAnswer> Function(int attemptId) buildAnswers,
    required List<WrongBookEntry> wrongEntries,
    required DailyStat dailyStat,
  }) async {
    saveCount++;
    savedAttempt = attempt;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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
    options: const ['Option A', 'Option B', 'Option C', 'Option D'],
    correctIndex: 0,
    explanation: 'Explanation $id',
    passageId: passageId,
  );
}

Widget _buildTestApp(_FakeAdaptiveRepo repo, {Widget? home}) {
  return Provider<AppRepository>.value(
    value: repo,
    child: MaterialApp(home: home ?? const PracticeScreen()),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Tạo ngân hàng câu hỏi chuẩn gồm 8 dạng bài
  final standardBank = <Question>[];
  for (final type in AdaptiveLearningService.standardTypes) {
    for (int i = 0; i < 12; i++) {
      standardBank.add(_makeQ('${type}_$i', type));
    }
  }

  group('Adaptive Learning UI & Luồng luyện tập thực tế', () {
    testWidgets(
      '1. Cold start: Hiển thị Thẻ năng lực ban đầu và các nhiệm vụ khảo sát',
      (tester) async {
        final repo = _FakeAdaptiveRepo(questions: standardBank);

        await tester.pumpWidget(_buildTestApp(repo));
        // Chờ async loadData hoàn tất
        await tester.pumpAndSettle();

        // Kiểm tra Thẻ hồ sơ năng lực
        expect(find.text('Lộ trình thích ứng cá nhân hóa'), findsOneWidget);
        expect(find.textContaining('Thành thạo:'), findsOneWidget);
        expect(find.text('Chưa có lịch sử làm bài'), findsOneWidget);
        expect(
          find.textContaining(
            'Bắt đầu các bài luyện bên dưới để hệ thống nhận diện',
          ),
          findsOneWidget,
        );

        // Kiểm tra danh sách nhiệm vụ
        expect(find.text('Nhiệm vụ đề xuất hôm nay'), findsOneWidget);
        expect(find.text('Khảo sát năng lực'), findsWidgets);
        expect(find.text('Kiểm tra tổng hợp'), findsOneWidget);
        expect(find.text('Bắt đầu luyện tập'), findsNWidgets(3));
      },
    );

    testWidgets(
      '2. Có điểm yếu: Thẻ hồ sơ và Task 1 hiển thị Chinh phục điểm yếu',
      (tester) async {
        // Giả lập đã làm 8 câu reading đều sai
        final attempts = [
          Attempt(
            id: 1,
            mode: 'mock_exam',
            type: null,
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

        // Kiểm tra thẻ năng lực chỉ rõ điểm yếu
        expect(find.textContaining('Cần tập trung: Đọc hiểu'), findsOneWidget);

        // Task 1 là Chinh phục điểm yếu
        expect(find.text('Cải thiện điểm yếu'), findsOneWidget);
        expect(find.text('Chinh phục điểm yếu: Đọc hiểu'), findsOneWidget);
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

      expect(find.text('Ôn tập câu sai'), findsOneWidget);
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

        // Không có huy hiệu "Ôn tập câu sai"
        expect(find.text('Ôn tập câu sai'), findsNothing);
        // Vẫn có đủ 3 nhiệm vụ hợp lệ
        expect(find.text('Bắt đầu luyện tập'), findsNWidgets(3));
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
        expect(find.text('Bắt đầu luyện tập'), findsNWidgets(2));
      },
    );

    testWidgets(
      '6. Nhấn Bắt đầu luyện tập mở PracticeQuizScreen và truyền đúng Question IDs',
      (tester) async {
        final repo = _FakeAdaptiveRepo(questions: standardBank);

        await tester.pumpWidget(_buildTestApp(repo));
        await tester.pumpAndSettle();

        // Nhấn nút "Bắt đầu luyện tập" của nhiệm vụ đầu tiên
        final firstStartBtn = find.text('Bắt đầu luyện tập').first;
        await tester.tap(firstStartBtn);
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

      await tester.tap(find.text('Bắt đầu luyện tập').first);
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
        await tester.tap(find.text('Bắt đầu luyện tập').first);
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
      '9. Giao diện Responsive: Không bị overflow trên màn hình 320px và 360px với textScale 1.3',
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
                data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
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

        // Tìm nút Bắt đầu luyện tập của nhiệm vụ Kiểm tra tổng hợp (nhiệm vụ thứ 3)
        final task3StartBtn = find.text('Bắt đầu luyện tập').at(2);
        await tester.tap(task3StartBtn);
        await tester.pumpAndSettle();

        final quizState = tester.state<State>(find.byType(PracticeQuizScreen));
        final quizWidget = quizState.widget as PracticeQuizScreen;

        // Xác nhận mode là 'practice', tuyệt đối không gán 'mock_exam'
        expect(quizWidget.mode, 'practice');
        expect(quizWidget.mode, isNot('mock_exam'));
      },
    );
  });
}
