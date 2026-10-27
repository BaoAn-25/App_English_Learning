import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thpt_english/data/models/question.dart';
import 'package:thpt_english/data/models/topic.dart';
import 'package:thpt_english/ui/vocab/topic_quiz_screen.dart';

void main() {
  testWidgets('TopicQuizScreen loads and displays questions cleanly', (WidgetTester tester) async {
    const testTopic = Topic(
      id: 'topic_12_u1',
      grade: 12,
      title: 'Life Stories & Success',
      order: 1,
    );

    const testQuestion = Question(
      id: 'q_test_01',
      grade: 12,
      type: 'vocab',
      stem: 'She showed great ______ by continuing to study.',
      options: ['laziness', 'perseverance', 'ignorance', 'hesitation'],
      correctIndex: 1,
      explanation: "'Perseverance' means continuing despite difficulties.",
      topicId: 'topic_12_u1',
      difficulty: 1,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: TopicQuizScreen(
          topic: testTopic,
          initialQuestions: [testQuestion],
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Kiem tra tieu de App Bar
    expect(find.text('Kiểm tra: Life Stories & Success'), findsOneWidget);

    // Kiem tra nut Kiem tra dap an
    expect(find.text('Kiểm tra đáp án'), findsOneWidget);

    // Kiem tra 4 lua chon A, B, C, D
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
    expect(find.text('D'), findsOneWidget);

    // Chon lua chon A
    await tester.tap(find.text('A'));
    await tester.pump(const Duration(milliseconds: 100));

    // Nhan nut Kiem tra dap an
    await tester.tap(find.text('Kiểm tra đáp án'));
    await tester.pump(const Duration(milliseconds: 100));

    // Kiem tra xuat hien hop Giai thich chi tiet
    expect(find.text('Giải thích chi tiết:'), findsOneWidget);
  });
}
