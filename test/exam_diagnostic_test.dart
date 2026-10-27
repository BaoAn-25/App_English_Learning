import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:thpt_english/data/models/attempt_answer.dart';
import 'package:thpt_english/data/models/question.dart';
import 'package:thpt_english/ui/practice/services/exam_diagnostic_service.dart';
import 'package:thpt_english/ui/practice/widgets/exam_diagnostic_card.dart';

Question _makeQ(String id, String type, {int correctIndex = 0}) {
  return Question(
    id: id,
    type: type,
    difficulty: 1,
    grade: 12,
    stem: 'Question stem $id',
    options: const ['A', 'B', 'C', 'D'],
    correctIndex: correctIndex,
    explanation: 'Explanation $id',
  );
}

void main() {
  group('ExamDiagnosticService - Unit Tests', () {
    test('Xử lý an toàn khi danh sách câu hỏi rỗng', () {
      final result = ExamDiagnosticService.analyze(
        questions: [],
        selectedAnswers: [],
      );

      expect(result.hasData, isFalse);
      expect(result.breakdown, isEmpty);
      expect(result.weakestType, isNull);
      expect(result.isPerfectScore, isFalse);
      expect(result.totalQuestions, 0);
      expect(result.totalCorrect, 0);
      expect(result.overallAccuracy, 0.0);
    });

    test('Phân tích chính xác câu đúng, câu sai, câu bỏ trống theo từng dạng bài', () {
      final questions = [
        _makeQ('q1', 'grammar', correctIndex: 0),
        _makeQ('q2', 'grammar', correctIndex: 1),
        _makeQ('q3', 'grammar', correctIndex: 2),
        _makeQ('q4', 'vocab', correctIndex: 0),
        _makeQ('q5', 'vocab', correctIndex: 3),
        _makeQ('q6', 'reading', correctIndex: 1),
      ];

      // q1: đúng (0 == 0)
      // q2: sai (0 != 1)
      // q3: bỏ trống (null)
      // q4: đúng (0 == 0)
      // q5: sai (1 != 3)
      // q6: đúng (1 == 1)
      final selectedAnswers = [0, 0, null, 0, 1, 1];

      final result = ExamDiagnosticService.analyze(
        questions: questions,
        selectedAnswers: selectedAnswers,
      );

      expect(result.hasData, isTrue);
      expect(result.totalQuestions, 6);
      expect(result.totalCorrect, 3);
      expect(result.overallAccuracy, closeTo(50.0, 0.01));
      expect(result.isPerfectScore, isFalse);

      final grammar = result.breakdown.firstWhere((e) => e.type == 'grammar');
      expect(grammar.total, 3);
      expect(grammar.correct, 1);
      expect(grammar.wrong, 1);
      expect(grammar.unanswered, 1);
      expect(grammar.accuracy, closeTo(33.33, 0.1));
      expect(grammar.isSmallSample, isFalse);

      final vocab = result.breakdown.firstWhere((e) => e.type == 'vocab');
      expect(vocab.total, 2);
      expect(vocab.correct, 1);
      expect(vocab.wrong, 1);
      expect(vocab.unanswered, 0);
      expect(vocab.accuracy, 50.0);
      expect(vocab.isSmallSample, isTrue);

      final reading = result.breakdown.firstWhere((e) => e.type == 'reading');
      expect(reading.total, 1);
      expect(reading.correct, 1);
      expect(reading.wrong, 0);
      expect(reading.unanswered, 0);
      expect(reading.accuracy, 100.0);
      expect(reading.isSmallSample, isTrue);

      // Điểm yếu nhất phải là grammar (33.3% < 50% < 100%)
      expect(result.weakestType?.type, 'grammar');
    });

    test('Xử lý trường hợp đạt 100% điểm tuyệt đối: không có điểm yếu', () {
      final questions = [
        _makeQ('q1', 'grammar', correctIndex: 0),
        _makeQ('q2', 'vocab', correctIndex: 1),
      ];

      final selectedAnswers = [0, 1];

      final result = ExamDiagnosticService.analyze(
        questions: questions,
        selectedAnswers: selectedAnswers,
      );

      expect(result.isPerfectScore, isTrue);
      expect(result.weakestType, isNull);
      expect(result.overallAccuracy, 100.0);
    });

    test('Quy tắc chọn điểm yếu khi bằng tỷ lệ đúng (Tie-breaking)', () {
      // Dạng A: 1/2 câu đúng (50%), hỏng 1 câu
      // Dạng B: 2/4 câu đúng (50%), hỏng 2 câu -> B hỏng nhiều hơn nên yếu hơn
      final questions = [
        _makeQ('q1', 'signs', correctIndex: 0),
        _makeQ('q2', 'signs', correctIndex: 0),
        _makeQ('q3', 'vocab', correctIndex: 0),
        _makeQ('q4', 'vocab', correctIndex: 0),
        _makeQ('q5', 'vocab', correctIndex: 0),
        _makeQ('q6', 'vocab', correctIndex: 0),
      ];

      // signs: 1 đúng, 1 sai (accuracy: 50%, missed: 1)
      // vocab: 2 đúng, 2 sai (accuracy: 50%, missed: 2)
      final selectedAnswers = [0, 1, 0, 0, 1, 1];

      final result = ExamDiagnosticService.analyze(
        questions: questions,
        selectedAnswers: selectedAnswers,
      );

      // Cả 2 đều 50%, nhưng vocab hỏng 2 câu còn signs hỏng 1 câu
      expect(result.weakestType?.type, 'vocab');
    });

    test('Tie-break khi cả tỷ lệ và số câu hỏng bằng nhau: chọn dạng có tổng câu nhiều hơn', () {
      // Dạng cloze: 0/1 câu (0%), hỏng 1 câu
      // Dạng arrange: 0/2 câu (0%), hỏng 2 câu -> arrange hỏng nhiều hơn
      // Giờ giả sử cloze 0/2 câu (hỏng 2), arrange 0/2 câu (hỏng 2) -> bằng nhau cả 2 -> sắp theo chữ cái arrange < cloze
      final questions = [
        _makeQ('q1', 'cloze', correctIndex: 0),
        _makeQ('q2', 'cloze', correctIndex: 0),
        _makeQ('q3', 'arrange', correctIndex: 0),
        _makeQ('q4', 'arrange', correctIndex: 0),
      ];

      final selectedAnswers = [1, 1, 1, 1];

      final result = ExamDiagnosticService.analyze(
        questions: questions,
        selectedAnswers: selectedAnswers,
      );

      expect(result.weakestType?.type, 'arrange'); // 'arrange' đứng trước 'cloze'
    });

    test('analyzeFromAttemptAnswers đồng nhất với analyze', () {
      final questions = [
        _makeQ('q1', 'grammar', correctIndex: 0),
        _makeQ('q2', 'grammar', correctIndex: 1),
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
          chosenIndex: -1,
          isCorrect: false,
        ),
      ];

      final result = ExamDiagnosticService.analyzeFromAttemptAnswers(
        questions: questions,
        answers: answers,
      );

      expect(result.totalQuestions, 2);
      expect(result.totalCorrect, 1);
      final g = result.breakdown.first;
      expect(g.correct, 1);
      expect(g.unanswered, 1);
      expect(g.wrong, 0);
      expect(result.weakestType?.type, 'grammar');
    });
  });

  group('ExamDiagnosticCard - Widget Tests', () {
    testWidgets('Hiển thị thông báo khi không có dữ liệu', (tester) async {
      const diagnostic = ExamDiagnosticResult(
        breakdown: [],
        weakestType: null,
        isPerfectScore: false,
        totalQuestions: 0,
        totalCorrect: 0,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ExamDiagnosticCard(diagnostic: diagnostic),
          ),
        ),
      );

      expect(find.text('Không có dữ liệu phân tích dạng bài.'), findsOneWidget);
    });

    testWidgets('Hiển thị biểu đồ thanh ngang và card điểm cần cải thiện', (tester) async {
      final diagnostic = ExamDiagnosticService.analyze(
        questions: [
          _makeQ('q1', 'grammar', correctIndex: 0),
          _makeQ('q2', 'grammar', correctIndex: 1),
          _makeQ('q3', 'vocab', correctIndex: 0),
          _makeQ('q4', 'vocab', correctIndex: 0),
        ],
        selectedAnswers: [0, 0, 0, 0], // grammar: 1/2 (50%), vocab: 2/2 (100%)
      );

      String? clickedType;
      String? clickedTitle;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ExamDiagnosticCard(
                diagnostic: diagnostic,
                onStartRemediation: (type, title) async {
                  clickedType = type;
                  clickedTitle = title;
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Phân tích theo dạng bài'), findsOneWidget);
      expect(find.text('Ngữ pháp'), findsOneWidget);
      expect(find.text('Từ vựng'), findsOneWidget);
      expect(find.text('1/2 câu (50%)'), findsOneWidget);
      expect(find.text('2/2 câu (100%)'), findsOneWidget);

      // Card gợi ý điểm yếu
      expect(find.text('Điểm cần cải thiện: Ngữ pháp'), findsOneWidget);
      expect(find.text('Luyện tập ngay dạng Ngữ pháp'), findsOneWidget);

      // Nhấn nút luyện tập
      await tester.tap(find.text('Luyện tập ngay dạng Ngữ pháp'));
      await tester.pump();

      expect(clickedType, 'grammar');
      expect(clickedTitle, 'Ngữ pháp');
    });

    testWidgets('Hiển thị card chúc mừng khi đạt điểm tuyệt đối 100%', (tester) async {
      final diagnostic = ExamDiagnosticService.analyze(
        questions: [
          _makeQ('q1', 'grammar', correctIndex: 0),
          _makeQ('q2', 'vocab', correctIndex: 1),
        ],
        selectedAnswers: [0, 1],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExamDiagnosticCard(diagnostic: diagnostic),
          ),
        ),
      );

      expect(find.text('Xuất sắc! Điểm số tuyệt đối'), findsOneWidget);
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
      expect(find.textContaining('Điểm cần cải thiện'), findsNothing);
    });
  });
}
