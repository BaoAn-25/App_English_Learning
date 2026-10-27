import 'dart:math';

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
import 'package:thpt_english/ui/practice/practice_quiz_screen.dart';
import 'package:thpt_english/ui/practice/practice_review_screen.dart';
import 'package:thpt_english/ui/practice/services/option_shuffler.dart';

class _MockRepo extends AppRepository {
  Attempt? lastAttempt;
  List<AttemptAnswer> lastAnswers = [];
  List<WrongBookEntry> lastWrong = [];
  final List<Question> questions;

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
    lastAttempt = Attempt(
      id: 99,
      mode: attempt.mode,
      type: attempt.type,
      startedAt: attempt.startedAt,
      durationSec: attempt.durationSec,
      score: attempt.score,
      total: attempt.total,
    );
    lastAnswers = buildAnswers(99);
    lastWrong = wrongEntries;
  }

  @override
  Future<List<Attempt>> getAllAttempts() async =>
      lastAttempt == null ? [] : [lastAttempt!];

  @override
  Future<List<AttemptAnswer>> getAttemptAnswers(int attemptId) async =>
      lastAnswers;
}

Question _testQuestion({
  required String id,
  required int correctIndex,
  List<String>? options,
}) {
  return Question(
    id: id,
    grade: 12,
    type: 'grammar',
    stem: 'Stem of $id',
    options: options ?? ['Opt A (idx 0)', 'Opt B (idx 1)', 'Opt C (idx 2)', 'Opt D (idx 3)'],
    correctIndex: correctIndex,
    explanation: 'Giải thích chi tiết cho $id',
    difficulty: 1,
  );
}

void main() {
  group('QuestionOptionMapping Unit Tests', () {
    test('Khởi tạo identity giữ nguyên thứ tự', () {
      final mapping = QuestionOptionMapping.identity(4);
      expect(mapping.displayToOriginal, [0, 1, 2, 3]);
      expect(mapping.originalIndexAt(0), 0);
      expect(mapping.slotOfOriginal(2), 2);
      expect(mapping.displayLetterOfOriginal(0), 'A');
      expect(mapping.displayLetterOfOriginal(3), 'D');
    });

    test('Xáo trộn shuffled tạo hoán vị đầy đủ không trùng lặp', () {
      final mapping = QuestionOptionMapping.shuffled(4, random: Random(42));
      expect(mapping.length, 4);
      expect(mapping.displayToOriginal.toSet(), {0, 1, 2, 3});
    });

    test('Ánh xạ 2 chiều chính xác khi hoán vị', () {
      // Giả sử slot 0 hiển thị option 3, slot 1 hiển thị option 0, v.v.
      final mapping = QuestionOptionMapping([3, 0, 1, 2]);

      // Vị trí A (slot 0) -> originalIndex 3
      expect(mapping.originalIndexAt(0), 3);
      // Vị trí B (slot 1) -> originalIndex 0
      expect(mapping.originalIndexAt(1), 0);

      // originalIndex 0 đang nằm ở slot 1 (B)
      expect(mapping.slotOfOriginal(0), 1);
      expect(mapping.displayLetterOfOriginal(0), 'B');

      // originalIndex 3 đang nằm ở slot 0 (A)
      expect(mapping.slotOfOriginal(3), 0);
      expect(mapping.displayLetterOfOriginal(3), 'A');
    });
  });

  group('PracticeQuizScreen với Option Shuffling', () {
    testWidgets('Tích hợp xáo trộn: chọn slot hiển thị nhưng chấm điểm & lưu index gốc',
        (tester) async {
      // Câu hỏi có đáp án đúng gốc là A (correctIndex = 0)
      final q1 = _testQuestion(id: 'q1', correctIndex: 0);
      // Cố định ánh xạ: slot 0 hiển thị opt 2 (C), slot 1 hiển thị opt 0 (A), slot 2 hiển thị opt 3 (D), slot 3 hiển thị opt 1 (B)
      final mapping1 = QuestionOptionMapping([2, 0, 3, 1]);

      final repo = _MockRepo([q1]);

      await tester.pumpWidget(
        Provider<AppRepository>.value(
          value: repo,
          child: MaterialApp(
            home: PracticeQuizScreen(
              title: 'Luyện tập',
              questions: [q1],
              optionMappings: [mapping1],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Trên màn hình:
      // Slot 0 (A) hiển thị 'Opt C (idx 2)'
      // Slot 1 (B) hiển thị 'Opt A (idx 0)'
      // Người dùng chọn Slot B (bấm vào text 'Opt A (idx 0)')
      await tester.tap(find.text('Opt A (idx 0)'));
      await tester.pumpAndSettle();

      // Nộp bài
      await tester.tap(find.text('Nộp bài'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Nộp bài'),
      ));
      await tester.pumpAndSettle();

      // 1. Điểm số: Đúng 1/1 vì đã chọn đúng originalIndex 0
      expect(repo.lastAttempt!.score, 1);
      expect(repo.lastAnswers[0].chosenIndex, 0); // Lưu index gốc = 0!
      expect(repo.lastAnswers[0].isCorrect, isTrue);
      expect(repo.lastWrong, isEmpty);

      // 2. Màn hình sau khi nộp: Hiển thị đúng đáp án đúng theo slot hiển thị
      // Vì originalIndex 0 đang ở slot B, nên badge hiển thị 'Đáp án đúng: B'
      expect(find.text('Đáp án đúng: B'), findsOneWidget);
    });

    testWidgets('Chọn sai slot khi xáo trộn -> tính sai và lưu wrong_book chính xác',
        (tester) async {
      final q1 = _testQuestion(id: 'q1', correctIndex: 0);
      // Slot 0 hiển thị opt 3, Slot 1 hiển thị opt 0
      final mapping1 = QuestionOptionMapping([3, 0, 1, 2]);

      final repo = _MockRepo([q1]);

      await tester.pumpWidget(
        Provider<AppRepository>.value(
          value: repo,
          child: MaterialApp(
            home: PracticeQuizScreen(
              title: 'Luyện tập',
              questions: [q1],
              optionMappings: [mapping1],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Người dùng chọn Slot 0 (bấm vào 'Opt D (idx 3)')
      await tester.tap(find.text('Opt D (idx 3)'));
      await tester.pumpAndSettle();

      // Nộp bài
      await tester.tap(find.text('Nộp bài'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Nộp bài'),
      ));
      await tester.pumpAndSettle();

      // Chấm sai: điểm 0/1
      expect(repo.lastAttempt!.score, 0);
      // chosenIndex lưu vào SQLite là index gốc 3!
      expect(repo.lastAnswers[0].chosenIndex, 3);
      expect(repo.lastAnswers[0].isCorrect, isFalse);
      expect(repo.lastWrong.length, 1);
      expect(repo.lastWrong[0].questionId, 'q1');
    });

    testWidgets('Thứ tự hiển thị phương án ổn định khi chuyển câu qua lại',
        (tester) async {
      final q1 = _testQuestion(id: 'q1', correctIndex: 0);
      final q2 = _testQuestion(id: 'q2', correctIndex: 1);

      final repo = _MockRepo([q1, q2]);

      await tester.pumpWidget(
        Provider<AppRepository>.value(
          value: repo,
          child: MaterialApp(
            home: PracticeQuizScreen(
              title: 'Luyện tập',
              questions: [q1, q2],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Lưu lại text hiển thị ở câu 1
      expect(find.textContaining('Opt A (idx 0)'), findsOneWidget);

      // Sang câu 2
      await tester.tap(find.text('Câu tiếp'));
      await tester.pumpAndSettle();
      expect(find.textContaining('q2'), findsOneWidget);

      // Quay lại câu 1 và kiểm tra vẫn hiển thị ổn định
      await tester.tap(find.text('Câu trước'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Opt A (idx 0)'), findsOneWidget);
    });
  });

  group('MockExamQuizScreen với Option Shuffling', () {
    testWidgets('Thi thử: xáo trộn đáp án nhưng lưu index gốc và xem lại chính xác',
        (tester) async {
      final q1 = _testQuestion(id: 'q1', correctIndex: 0);
      final mapping1 = QuestionOptionMapping([1, 2, 0, 3]); // opt 0 ở slot 2 (C)

      final repo = _MockRepo([q1]);

      await tester.pumpWidget(
        Provider<AppRepository>.value(
          value: repo,
          child: MaterialApp(
            home: MockExamQuizScreen(
              questions: [q1],
              durationMinutes: 10,
              optionMappings: [mapping1],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Bấm vào opt 0 đang ở slot C
      await tester.tap(find.text('Opt A (idx 0)'));
      await tester.pumpAndSettle();

      // Nộp bài thi
      await tester.tap(find.text('Nộp bài'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Nộp bài'),
      ));
      await tester.pumpAndSettle();

      // Điểm số & SQLite: chính xác
      expect(repo.lastAttempt!.score, 1);
      expect(repo.lastAnswers[0].chosenIndex, 0);

      // Mở màn xem lại bài làm PracticeReviewScreen
      await tester.tap(find.text('Xem lại bài thi'));
      await tester.pumpAndSettle();

      // Màn xem lại hiển thị theo thứ tự gốc nhất quán:
      expect(find.byType(PracticeReviewScreen), findsOneWidget);
      expect(find.textContaining('A. Opt A (idx 0)'), findsWidgets);
    });
  });
}
