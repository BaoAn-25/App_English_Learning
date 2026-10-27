import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:thpt_english/data/app_repository.dart';
import 'package:thpt_english/data/models/question.dart';
import 'package:thpt_english/ui/practice/mock_exam_quiz_screen.dart';
import 'package:thpt_english/ui/practice/mock_exam_screen.dart';
import 'package:thpt_english/ui/practice/practice_quiz_screen.dart';

class FakeAppRepository extends AppRepository {
  final List<Question> fakeQuestions;
  FakeAppRepository(this.fakeQuestions);

  @override
  Future<List<Question>> getQuestionsByGrade(int grade) async => fakeQuestions;
}

void main() {
  const dummyQuestions = [
    Question(
      id: 'mock_1',
      grade: 12,
      type: 'grammar',
      stem: 'If I had studied harder, I _______ the exam yesterday.',
      options: ['would pass', 'would have passed', 'will pass', 'had passed'],
      correctIndex: 1,
      explanation:
          'Câu điều kiện loại 3 diễn tả giả định trái ngược với quá khứ.',
      difficulty: 2,
    ),
    Question(
      id: 'mock_2',
      grade: 12,
      type: 'arrange',
      stem:
          'Arrange the sentences into a meaningful email:\n'
          'a. First, I would like to thank you for inviting me to the annual conference.\n'
          'b. In addition, I have attached my presentation slides for your review.\n'
          'c. Dear Mr. Smith,\n'
          'd. Please let me know if you need any further information before tomorrow.\n'
          'e. I look forward to meeting you and your colleagues in Hanoi.',
      options: [
        'c - a - b - d - e',
        'c - b - a - d - e',
        'a - c - b - e - d',
        'c - a - d - b - e',
      ],
      correctIndex: 0,
      explanation:
          'Thư bắt đầu bằng lời chào (c), cảm ơn (a), thông tin bổ sung (b), yêu cầu phản hồi (d) và kết thư (e).',
      difficulty: 3,
    ),
    Question(
      id: 'mock_3',
      grade: 12,
      type: 'vocab',
      stem: 'The new regulations will take _______ next month.',
      options: ['effect', 'affect', 'action', 'force'],
      correctIndex: 0,
      explanation: 'Cụm từ take effect: có hiệu lực.',
      difficulty: 1,
    ),
  ];

  group('MockExamScreen - Kiểm tra 3 chế độ thi và giao diện lựa chọn', () {
    testWidgets(
      'Hiển thị đầy đủ 3 chế độ thi và cập nhật thông số khi chọn chế độ',
      (tester) async {
        // Giả lập 25 câu hỏi lớp 12
        final questions25 = List.generate(
          25,
          (i) => Question(
            id: 'q_$i',
            grade: 12,
            type: 'grammar',
            stem: 'Question stem $i',
            options: const ['A', 'B', 'C', 'D'],
            correctIndex: 0,
            explanation: 'Explanation $i',
            difficulty: 2,
          ),
        );

        tester.view.physicalSize = const Size(400 * 2, 1000 * 2);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final fakeRepo = FakeAppRepository(questions25);

        await tester.pumpWidget(
          Provider<AppRepository>.value(
            value: fakeRepo,
            child: const MaterialApp(home: MockExamScreen()),
          ),
        );

        await tester.pumpAndSettle();

        // 1. Kiểm tra hiển thị tiêu đề và 3 chế độ thi
        expect(find.text('Chọn chế độ thi'), findsOneWidget);
        expect(find.text('Thi nhanh'), findsOneWidget);
        expect(find.text('Thi thử rút gọn'), findsOneWidget);
        expect(find.text('Thi thử THPT'), findsNWidgets(2));

        // 2. Mặc định là chế độ Thi nhanh (10 câu / 10 phút)
        expect(find.text('10 câu'), findsOneWidget);
        expect(find.text('10 phút'), findsOneWidget);
        expect(find.text('Bắt đầu làm bài (10 câu)'), findsOneWidget);

        // 3. Chọn chế độ "Thi thử rút gọn" (20 câu / 20 phút)
        final modeRutGon = find.widgetWithText(InkWell, 'Thi thử rút gọn');
        await tester.ensureVisible(modeRutGon);
        await tester.tap(modeRutGon);
        await tester.pumpAndSettle();

        expect(find.text('20 câu'), findsOneWidget);
        expect(find.text('20 phút'), findsOneWidget);
        expect(find.text('Bắt đầu làm bài (20 câu)'), findsOneWidget);

        // 4. Chọn chế độ "Thi thử THPT" (50 câu / 60 phút)
        // Vì chỉ có 25 câu nên sẽ hiện thông báo cảnh báo chưa đủ câu
        final modeTHPT = find.widgetWithText(InkWell, 'Thi thử THPT');
        await tester.ensureVisible(modeTHPT);
        await tester.tap(modeTHPT);
        await tester.pumpAndSettle();

        expect(find.text('50 câu'), findsOneWidget);
        expect(find.text('60 phút'), findsOneWidget);
        expect(find.textContaining('chưa đủ 50 câu'), findsOneWidget);

        // 5. Quay lại chế độ "Thi nhanh"
        final modeNhanh = find.widgetWithText(InkWell, 'Thi nhanh');
        await tester.ensureVisible(modeNhanh);
        await tester.tap(modeNhanh);
        await tester.pumpAndSettle();

        expect(find.text('10 câu'), findsOneWidget);
        expect(find.text('10 phút'), findsOneWidget);
        expect(find.text('Bắt đầu làm bài (10 câu)'), findsOneWidget);
      },
    );
  });

  group(
    'MockExamQuizScreen - Kiểm tra Responsive và không bị RenderFlex overflow',
    () {
      final screenSizes = [
        const Size(320, 600), // Màn hình nhỏ 320px
        const Size(360, 800), // Màn hình tiêu chuẩn 360px
        const Size(393, 852), // Màn hình hiện đại 393px
      ];

      final textScales = [1.0, 1.3];

      for (final size in screenSizes) {
        for (final scale in textScales) {
          testWidgets(
            'MockExamQuizScreen hiển thị trọn vẹn 3 nút không overflow trên ${size.width.toInt()}px với textScale $scale',
            (tester) async {
              tester.view.physicalSize = Size(size.width * 2, size.height * 2);
              tester.view.devicePixelRatio = 2.0;
              addTearDown(() {
                tester.view.resetPhysicalSize();
                tester.view.resetDevicePixelRatio();
              });

              await tester.pumpWidget(
                MaterialApp(
                  home: MediaQuery(
                    data: MediaQueryData(
                      size: size,
                      textScaler: TextScaler.linear(scale),
                      padding: const EdgeInsets.only(
                        bottom: 24,
                      ), // Giả lập Android 3-button / gesture bar
                    ),
                    child: const MockExamQuizScreen(
                      questions: dummyQuestions,
                      durationMinutes: 10,
                    ),
                  ),
                ),
              );

              await tester.pumpAndSettle();

              // Xác minh 3 nút điều hướng đều hiển thị đầy đủ
              expect(find.text('Câu trước'), findsOneWidget);
              expect(find.text('Câu tiếp'), findsOneWidget);
              expect(find.text('Nộp bài'), findsOneWidget);

              // Chuyển sang câu 2 và kiểm tra
              await tester.tap(find.text('Câu tiếp'));
              await tester.pumpAndSettle();

              expect(find.text('Câu trước'), findsOneWidget);
              expect(find.text('Câu tiếp'), findsOneWidget);
              expect(find.text('Nộp bài'), findsOneWidget);

              // Chuyển sang câu cuối cùng (câu 3)
              await tester.tap(find.text('Câu tiếp'));
              await tester.pumpAndSettle();

              // Ở câu cuối cùng: Chỉ còn 2 nút "Câu trước" và "Nộp bài"
              expect(find.text('Câu trước'), findsOneWidget);
              expect(find.text('Nộp bài'), findsOneWidget);
            },
          );
        }
      }
    },
  );

  group(
    'PracticeQuizScreen - Kiểm tra cuộn câu Sắp xếp dài & không bị overflow',
    () {
      final screenSizes = [
        const Size(320, 600),
        const Size(360, 800),
        const Size(393, 852),
      ];

      final textScales = [1.0, 1.3];

      for (final size in screenSizes) {
        for (final scale in textScales) {
          testWidgets(
            'PracticeQuizScreen trên ${size.width.toInt()}px, textScale $scale cuộn được đến đáp án D',
            (tester) async {
              tester.view.physicalSize = Size(size.width * 2, size.height * 2);
              tester.view.devicePixelRatio = 2.0;
              addTearDown(() {
                tester.view.resetPhysicalSize();
                tester.view.resetDevicePixelRatio();
              });

              // Sử dụng câu hỏi Sắp xếp làm câu đầu tiên để kiểm tra độ dài
              final arrangeQuestions = [
                dummyQuestions[1], // câu Arrange dài
                dummyQuestions[0],
              ];

              await tester.pumpWidget(
                MaterialApp(
                  home: MediaQuery(
                    data: MediaQueryData(
                      size: size,
                      textScaler: TextScaler.linear(scale),
                      padding: const EdgeInsets.only(bottom: 24),
                    ),
                    child: PracticeQuizScreen(
                      title: 'Luyện tập Sắp xếp câu',
                      questions: arrangeQuestions,
                    ),
                  ),
                ),
              );

              await tester.pumpAndSettle();

              // Nút điều hướng phía dưới hiển thị chuẩn
              expect(find.text('Câu trước'), findsOneWidget);
              expect(find.text('Câu tiếp'), findsOneWidget);

              // Cuộn xuống để xem đáp án D
              final optionDFinder = find.text('c - a - d - b - e');
              await tester.scrollUntilVisible(
                optionDFinder,
                150.0,
                scrollable: find.byType(Scrollable).first,
              );
              await tester.pumpAndSettle();

              // Kiểm tra đáp án D xuất hiện đầy đủ trên màn hình và có thể tap
              expect(optionDFinder, findsOneWidget);
              await tester.tap(optionDFinder);
              await tester.pumpAndSettle();

              // Sau khi chọn, chuyển câu hỏi tiếp theo
              await tester.tap(find.text('Câu tiếp'));
              await tester.pumpAndSettle();

              // Kiểm tra đã sang câu 2 và reset vị trí cuộn về đầu
              expect(
                find.textContaining('If I had studied harder'),
                findsOneWidget,
              );
            },
          );
        }
      }
    },
  );
}
