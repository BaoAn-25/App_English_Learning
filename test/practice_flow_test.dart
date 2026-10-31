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
import 'package:thpt_english/ui/practice/mock_exam_screen.dart';
import 'package:thpt_english/ui/practice/practice_quiz_screen.dart';
import 'package:thpt_english/ui/practice/practice_review_screen.dart';

/// Repository giả: ghi lại dữ liệu lưu để kiểm tra luồng làm bài end-to-end.
class RecordingRepository extends AppRepository {
  final List<Question> bank;
  RecordingRepository(this.bank);

  Attempt? savedAttempt;
  List<AttemptAnswer> savedAnswers = [];
  List<WrongBookEntry> savedWrong = [];
  DailyStat? savedStat;
  int saveCalls = 0;

  @override
  Future<List<Question>> getQuestionsByGrade(int grade) async => bank;

  @override
  Future<List<Question>> getAllQuestions() async => bank;

  @override
  Future<void> savePracticeResult({
    required Attempt attempt,
    required List<AttemptAnswer> Function(int attemptId) buildAnswers,
    required List<WrongBookEntry> wrongEntries,
    required DailyStat dailyStat,
    String? ownerId,
  }) async {
    saveCalls++;
    savedAttempt = Attempt(
      id: 1,
      mode: attempt.mode,
      type: attempt.type,
      startedAt: attempt.startedAt,
      durationSec: attempt.durationSec,
      score: attempt.score,
      total: attempt.total,
    );
    savedAnswers = buildAnswers(1);
    savedWrong = wrongEntries;
    savedStat = dailyStat;
  }

  @override
  Future<List<Attempt>> getAllAttempts({String? ownerId}) async =>
      savedAttempt == null ? [] : [savedAttempt!];

  @override
  Future<List<AttemptAnswer>> getAttemptAnswers(int attemptId) async =>
      savedAnswers.where((a) => a.attemptId == attemptId).toList();
}

Question _q(int i, {int correct = 1, String type = 'grammar'}) => Question(
      id: 'q_12_$i',
      grade: 12,
      type: type,
      stem: 'Stem number $i _____ blank.',
      options: ['opt${i}a', 'opt${i}b', 'opt${i}c', 'opt${i}d'],
      correctIndex: correct,
      explanation: 'Giải thích câu $i',
      difficulty: 1,
    );

Widget _app(RecordingRepository repo, Widget home) => Provider<AppRepository>.value(
      value: repo,
      child: MaterialApp(home: home),
    );

void main() {
  void setSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(400 * 2, 900 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('Luồng luyện tập', () {
    testWidgets('Chọn đáp án, nộp bài, tính điểm, lưu SQLite, hiện giải thích, ghi câu sai',
        (tester) async {
      setSize(tester);
      final questions = [_q(1, correct: 1), _q(2, correct: 1)];
      final repo = RecordingRepository(questions);

      await tester.pumpWidget(_app(
        repo,
        PracticeQuizScreen(title: 'Luyện ngữ pháp', questions: questions),
      ));
      await tester.pumpAndSettle();

      // Câu 1: chọn đúng (B)
      await tester.tap(find.text('opt1b'));
      await tester.pumpAndSettle();
      expect(find.text('Đã chọn 1/2'), findsOneWidget);

      await tester.tap(find.text('Câu tiếp'));
      await tester.pumpAndSettle();

      // Câu 2: chọn sai (A)
      await tester.tap(find.text('opt2a'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nộp bài'));
      await tester.pumpAndSettle();
      // Hộp thoại xác nhận
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Nộp bài'),
        ),
      );
      await tester.pumpAndSettle();

      expect(repo.saveCalls, 1);
      expect(repo.savedAttempt!.mode, 'practice');
      expect(repo.savedAttempt!.type, 'grammar');
      expect(repo.savedAttempt!.score, 1);
      expect(repo.savedAttempt!.total, 2);
      expect(repo.savedAnswers.length, 2);
      expect(repo.savedAnswers[0].isCorrect, isTrue);
      expect(repo.savedAnswers[1].isCorrect, isFalse);
      expect(repo.savedAnswers[1].chosenIndex, 0);
      expect(repo.savedWrong.map((e) => e.questionId), ['q_12_2']);
      expect(repo.savedStat!.correct, 1);
      expect(repo.savedStat!.questionsDone, 2);

      // Hiển thị kết quả + lời giải
      expect(find.textContaining('Kết quả: 1/2'), findsOneWidget);
      expect(find.text('Lời giải chi tiết'), findsOneWidget);
      expect(find.text('Giải thích câu 2'), findsOneWidget);
    });

    testWidgets('Không lưu hai lần khi bấm nộp bài lặp lại', (tester) async {
      setSize(tester);
      final questions = [_q(1)];
      final repo = RecordingRepository(questions);
      await tester.pumpWidget(_app(
        repo,
        PracticeQuizScreen(title: 'T', questions: questions),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('opt1b'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nộp bài'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Nộp bài'),
      ));
      await tester.pumpAndSettle();
      expect(repo.saveCalls, 1);
      expect(find.text('Nộp bài'), findsNothing);
    });
  });

  group('Luồng thi thử', () {
    testWidgets('Đồng hồ đếm ngược và tự nộp bài khi hết giờ', (tester) async {
      setSize(tester);
      var now = DateTime(2026, 1, 1, 10, 0, 0);
      final questions = [_q(1), _q(2), _q(3)];
      final repo = RecordingRepository(questions);

      await tester.pumpWidget(_app(
        repo,
        MockExamQuizScreen(
          questions: questions,
          durationMinutes: 10,
          clock: () => now,
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('10:00'), findsWidgets);

      // Chọn đúng câu 1 rồi để trống các câu còn lại
      await tester.tap(find.text('opt1b'));
      await tester.pump();

      // Đếm ngược 65 giây
      now = now.add(const Duration(seconds: 65));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('08:55'), findsWidgets);
      expect(repo.saveCalls, 0);

      // Hết giờ -> tự nộp
      now = now.add(const Duration(minutes: 10));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(repo.saveCalls, 1);
      expect(repo.savedAttempt!.mode, 'mock_exam');
      expect(repo.savedAttempt!.durationSec, 600);
      expect(repo.savedAttempt!.score, 1);
      expect(repo.savedAttempt!.total, 3);
      expect(repo.savedAnswers.map((a) => a.chosenIndex), [1, -1, -1]);
      expect(repo.savedWrong.map((e) => e.questionId), ['q_12_2', 'q_12_3']);
      expect(find.text('Hoàn thành bài thi thử!'), findsOneWidget);
      expect(find.text('10:00'), findsOneWidget); // thời gian đã dùng
      expect(find.text('Xem lại bài thi'), findsOneWidget);
    });

    testWidgets('Nộp bài thủ công, lưu kết quả và xem lại đáp án + giải thích',
        (tester) async {
      setSize(tester);
      var now = DateTime(2026, 1, 1, 10, 0, 0);
      final questions = [_q(1), _q(2)];
      final repo = RecordingRepository(questions);

      await tester.pumpWidget(_app(
        repo,
        MockExamQuizScreen(
          questions: questions,
          durationMinutes: 20,
          clock: () => now,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('opt1b'));
      await tester.pump();
      await tester.tap(find.text('Câu tiếp'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('opt2d')); // sai
      await tester.pump();

      now = now.add(const Duration(minutes: 3, seconds: 7));
      await tester.tap(find.text('Nộp bài'));
      await tester.pumpAndSettle();
      expect(find.textContaining('2/2'), findsWidgets);
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Nộp bài'),
      ));
      await tester.pumpAndSettle();

      expect(repo.saveCalls, 1);
      expect(repo.savedAttempt!.durationSec, 187);
      expect(repo.savedAttempt!.score, 1);
      expect(find.text('Hoàn thành bài thi thử!'), findsOneWidget);
      expect(find.text('03:07'), findsOneWidget);

      await tester.tap(find.text('Xem lại bài thi'));
      await tester.pumpAndSettle();

      expect(find.byType(PracticeReviewScreen), findsOneWidget);
      expect(find.text('Xem lại bài làm'), findsOneWidget);
      expect(find.text('1/2'), findsWidgets);
    });

    testWidgets('MockExamScreen ghép đúng số câu và thời gian của 3 chế độ',
        (tester) async {
      setSize(tester);
      final types = [
        'grammar', 'vocab', 'synonym_antonym', 'communication',
        'signs', 'arrange', 'cloze', 'reading',
      ];
      final bank = <Question>[];
      var id = 1;
      for (final t in types) {
        for (var k = 0; k < 10; k++) {
          bank.add(_q(id++, type: t));
        }
      }
      final repo = RecordingRepository(bank);

      for (final entry in {
        'Thi nhanh': [10, 10],
        'Thi thử rút gọn': [20, 20],
      }.entries) {
        await tester.pumpWidget(_app(repo, const MockExamScreen()));
        await tester.pumpAndSettle();
        final mode = find.widgetWithText(InkWell, entry.key);
        await tester.ensureVisible(mode);
        await tester.tap(mode);
        await tester.pumpAndSettle();
        final start = find.text('Bắt đầu làm bài (${entry.value[0]} câu)');
        await tester.ensureVisible(start);
        await tester.tap(start);
        await tester.pumpAndSettle();

        final quiz = tester.widget<MockExamQuizScreen>(
          find.byType(MockExamQuizScreen),
        );
        expect(quiz.questions.length, entry.value[0]);
        expect(quiz.durationMinutes, entry.value[1]);
        expect(quiz.questions.map((q) => q.id).toSet().length, entry.value[0]);

        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      }

      // Chế độ 50 câu / 60 phút (ngân hàng 80 câu)
      await tester.pumpWidget(_app(repo, const MockExamScreen()));
      await tester.pumpAndSettle();
      final modeThpt = find.widgetWithText(InkWell, 'Thi thử THPT');
      await tester.ensureVisible(modeThpt);
      await tester.tap(modeThpt);
      await tester.pumpAndSettle();
      final start = find.text('Bắt đầu làm bài (50 câu)');
      await tester.ensureVisible(start);
      await tester.tap(start);
      await tester.pumpAndSettle();
      final quiz =
          tester.widget<MockExamQuizScreen>(find.byType(MockExamQuizScreen));
      expect(quiz.questions.length, 50);
      expect(quiz.durationMinutes, 60);
      expect(quiz.questions.map((q) => q.id).toSet().length, 50);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });
}
