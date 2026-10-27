import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:thpt_english/data/app_repository.dart';
import 'package:thpt_english/data/models/attempt.dart';
import 'package:thpt_english/data/models/attempt_answer.dart';
import 'package:thpt_english/data/models/daily_stat.dart';
import 'package:thpt_english/data/models/question.dart';
import 'package:thpt_english/data/models/wrong_book_entry.dart';
import 'package:thpt_english/ui/practice/mock_exam_quiz_screen.dart';

class _MockRepo implements AppRepository {
  final List<Question> questions;
  Attempt? lastAttempt;

  _MockRepo(this.questions);

  @override
  Future<List<Question>> getAllQuestions() async => questions;

  @override
  Future<void> savePracticeResult({
    required Attempt attempt,
    required List<AttemptAnswer> Function(int attemptId) buildAnswers,
    required List<WrongBookEntry> wrongEntries,
    required DailyStat dailyStat,
  }) async {
    lastAttempt = attempt;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Question _testQ(int i) {
  return Question(
    id: 'q_test_$i',
    stem: 'Question stem $i',
    options: ['Option A $i', 'Option B $i', 'Option C $i', 'Option D $i'],
    correctIndex: 0,
    explanation: 'Explanation $i',
    type: 'grammar',
    grade: 12,
    difficulty: 1,
  );
}

Widget _wrap(Widget child, _MockRepo repo) {
  return Provider<AppRepository>.value(
    value: repo,
    child: MaterialApp(home: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tính năng Cắm cờ xem lại (Mark for Review)', () {
    testWidgets('Bật và tắt cắm cờ câu hỏi', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final questions = [_testQ(1), _testQ(2)];
      final repo = _MockRepo(questions);

      await tester.pumpWidget(
        _wrap(
          MockExamQuizScreen(
            questions: questions,
            durationMinutes: 10,
          ),
          repo,
        ),
      );
      await tester.pumpAndSettle();

      // Ban đầu: nút hiển thị "Cắm cờ"
      expect(find.text('Cắm cờ'), findsOneWidget);
      expect(find.text('Đã cắm cờ'), findsNothing);

      // Bật cắm cờ
      await tester.tap(find.text('Cắm cờ'));
      await tester.pumpAndSettle();
      expect(find.text('Đã cắm cờ'), findsOneWidget);

      // Bấm lần nữa để tắt cắm cờ
      await tester.tap(find.text('Đã cắm cờ'));
      await tester.pumpAndSettle();
      expect(find.text('Cắm cờ'), findsOneWidget);
      expect(find.text('Đã cắm cờ'), findsNothing);
    });

    testWidgets('Trạng thái cắm cờ được bảo toàn khi chuyển câu qua lại', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final questions = [_testQ(1), _testQ(2)];
      final repo = _MockRepo(questions);

      await tester.pumpWidget(
        _wrap(
          MockExamQuizScreen(
            questions: questions,
            durationMinutes: 10,
          ),
          repo,
        ),
      );
      await tester.pumpAndSettle();

      // Cắm cờ ở câu 1
      await tester.tap(find.text('Cắm cờ'));
      await tester.pumpAndSettle();
      expect(find.text('Đã cắm cờ'), findsOneWidget);

      // Chuyển sang câu 2
      await tester.tap(find.text('Câu tiếp'));
      await tester.pumpAndSettle();
      expect(find.text('Câu 2/2'), findsOneWidget);
      expect(find.text('Cắm cờ'), findsOneWidget); // Câu 2 chưa cắm

      // Quay lại câu 1
      await tester.tap(find.text('Câu trước'));
      await tester.pumpAndSettle();
      expect(find.text('Câu 1/2'), findsOneWidget);
      expect(find.text('Đã cắm cờ'), findsOneWidget); // Câu 1 vẫn giữ trạng thái
    });

    testWidgets('Hộp thoại nộp bài cảnh báo cả câu chưa làm và câu cắm cờ', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final questions = [_testQ(1), _testQ(2), _testQ(3)];
      final repo = _MockRepo(questions);

      await tester.pumpWidget(
        _wrap(
          MockExamQuizScreen(
            questions: questions,
            durationMinutes: 10,
          ),
          repo,
        ),
      );
      await tester.pumpAndSettle();

      // Cắm cờ câu 1 và chọn đáp án
      await tester.tap(find.text('Cắm cờ'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Option A 1'));
      await tester.pumpAndSettle();

      // Bấm Nộp bài (còn 2 câu chưa làm và 1 câu cắm cờ)
      await tester.tap(find.text('Nộp bài'));
      await tester.pumpAndSettle();

      // Kiểm tra nội dung cảnh báo trong AlertDialog
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Còn 2 câu chưa trả lời.'), findsOneWidget);
      expect(find.text('Còn 1 câu đang cắm cờ xem lại.'), findsOneWidget);

      // Đóng dialog
      await tester.tap(find.text('Tiếp tục làm'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  group('Tính năng Bộ lọc & Lưới danh sách câu hỏi', () {
    testWidgets('Mở BottomSheet hiển thị đủ số lượng trên 3 chip lọc', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final questions = [_testQ(1), _testQ(2), _testQ(3), _testQ(4)];
      final repo = _MockRepo(questions);

      await tester.pumpWidget(
        _wrap(
          MockExamQuizScreen(
            questions: questions,
            durationMinutes: 10,
          ),
          repo,
        ),
      );
      await tester.pumpAndSettle();

      // Trả lời câu 1 và cắm cờ câu 1
      await tester.tap(find.textContaining('Option A 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cắm cờ'));
      await tester.pumpAndSettle();

      // Mở BottomSheet từ nút trên AppBar
      await tester.tap(find.byTooltip('Danh sách câu hỏi'));
      await tester.pumpAndSettle();

      // Kiểm tra tiêu đề BottomSheet
      expect(find.text('Danh sách câu hỏi'), findsOneWidget);

      // Kiểm tra 3 chip lọc
      expect(find.text('Tất cả (4)'), findsOneWidget);
      expect(find.text('Chưa làm (3)'), findsOneWidget);
      expect(find.text('Đã cắm cờ (1)'), findsOneWidget);

      // Đóng sheet
      await tester.tap(find.byTooltip('Đóng'));
      await tester.pumpAndSettle();
    });

    testWidgets('Lọc danh sách và chuyển chính xác đến câu được chọn', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final questions = [_testQ(1), _testQ(2), _testQ(3), _testQ(4), _testQ(5)];
      final repo = _MockRepo(questions);

      await tester.pumpWidget(
        _wrap(
          MockExamQuizScreen(
            questions: questions,
            durationMinutes: 10,
          ),
          repo,
        ),
      );
      await tester.pumpAndSettle();

      // Trả lời câu 1
      await tester.tap(find.textContaining('Option A 1'));
      await tester.pumpAndSettle();

      // Mở BottomSheet bằng nút ở subheader
      await tester.tap(find.textContaining('Đã làm: 1/5'));
      await tester.pumpAndSettle();

      // Chuyển sang bộ lọc "Chưa làm (4)"
      await tester.tap(find.text('Chưa làm (4)'));
      await tester.pumpAndSettle();

      // Ô câu 1 không có trong danh sách lọc "Chưa làm"
      // Nhấn vào ô câu 4
      await tester.tap(find.text('4'));
      await tester.pumpAndSettle();

      // BottomSheet đóng và màn hình chuyển đúng sang Câu 4/5
      expect(find.text('Câu 4/5'), findsOneWidget);
      expect(find.textContaining('Question stem 4'), findsOneWidget);
    });

    testWidgets('Trạng thái trống khi bộ lọc không có câu hỏi phù hợp', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final questions = [_testQ(1), _testQ(2)];
      final repo = _MockRepo(questions);

      await tester.pumpWidget(
        _wrap(
          MockExamQuizScreen(
            questions: questions,
            durationMinutes: 10,
          ),
          repo,
        ),
      );
      await tester.pumpAndSettle();

      // Mở BottomSheet khi chưa cắm cờ câu nào
      await tester.tap(find.byTooltip('Danh sách câu hỏi'));
      await tester.pumpAndSettle();

      // Bấm bộ lọc "Đã cắm cờ (0)"
      await tester.tap(find.text('Đã cắm cờ (0)'));
      await tester.pumpAndSettle();

      // Thấy thông báo trạng thái trống
      expect(find.text('Chưa có câu hỏi nào được cắm cờ xem lại.'), findsOneWidget);
    });
  });
}
