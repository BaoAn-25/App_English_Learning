import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thpt_english/ui/practice/widgets/question_stem_view.dart';

void main() {
  Widget buildTestWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: child,
        ),
      ),
    );
  }

  group('QuestionStemView - Dạng Sắp xếp (Arrange)', () {
    testWidgets(
      'q_12_46: Không nhận nhầm "abroad." thành nhãn d., có đúng 4 ý a, b, c, d',
      (WidgetTester tester) async {
        const stem =
            'Arrange the sentences into a logical paragraph. '
            'a. Finally, she received a scholarship to study abroad. '
            'b. Lan had always dreamed of becoming a scientist. '
            'c. To achieve her goal, she studied hard and joined science competitions. '
            'd. Her determination inspired many classmates.';

        await tester.pumpWidget(
          buildTestWidget(
            const QuestionStemView(stem: stem, type: 'arrange'),
          ),
        );

        // Header huy hiệu "Sắp xếp"
        expect(find.text('Sắp xếp'), findsOneWidget);

        // Có đúng 4 huy hiệu nhãn a, b, c, d
        expect(find.text('a'), findsOneWidget);
        expect(find.text('b'), findsOneWidget);
        expect(find.text('c'), findsOneWidget);
        expect(find.text('d'), findsOneWidget);
        expect(find.text('e'), findsNothing);

        // Nội dung nguyên vẹn, không bị cắt cụt từ "abroad."
        expect(
          find.text('Finally, she received a scholarship to study abroad.'),
          findsOneWidget,
        );
        expect(
          find.text('Lan had always dreamed of becoming a scientist.'),
          findsOneWidget,
        );
        expect(
          find.text(
            'To achieve her goal, she studied hard and joined science competitions.',
          ),
          findsOneWidget,
        );
        expect(
          find.text('Her determination inspired many classmates.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'q_12_50: Không nhận nhầm "home." thành nhãn e., có đúng 4 ý a, b, c, d',
      (WidgetTester tester) async {
        const stem =
            'Arrange the sentences into a logical paragraph. '
            'a. First, residents separate paper, plastic and glass at home. '
            'b. Recycling can significantly reduce household waste. '
            'c. These materials are then collected and sent to recycling centres. '
            'd. Finally, they are processed into useful new products.';

        await tester.pumpWidget(
          buildTestWidget(
            const QuestionStemView(stem: stem, type: 'arrange'),
          ),
        );

        expect(find.text('a'), findsOneWidget);
        expect(find.text('b'), findsOneWidget);
        expect(find.text('c'), findsOneWidget);
        expect(find.text('d'), findsOneWidget);
        expect(find.text('e'), findsNothing);

        expect(
          find.text(
            'First, residents separate paper, plastic and glass at home.',
          ),
          findsOneWidget,
        );
        expect(
          find.text('Finally, they are processed into useful new products.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'q_12_51: Không nhận nhầm "programme." thành nhãn e., có đúng 4 ý a, b, c, d',
      (WidgetTester tester) async {
        const stem =
            'Arrange the email sentences. '
            'a. I would be grateful if you could provide more information. '
            'b. Dear Sir or Madam, '
            'c. I am writing to enquire about your summer internship programme. '
            'd. Yours faithfully, Minh Nguyen.';

        await tester.pumpWidget(
          buildTestWidget(
            const QuestionStemView(stem: stem, type: 'arrange'),
          ),
        );

        expect(find.text('a'), findsOneWidget);
        expect(find.text('b'), findsOneWidget);
        expect(find.text('c'), findsOneWidget);
        expect(find.text('d'), findsOneWidget);
        expect(find.text('e'), findsNothing);

        expect(
          find.text(
            'I am writing to enquire about your summer internship programme.',
          ),
          findsOneWidget,
        );
        expect(
          find.text('Yours faithfully, Minh Nguyen.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'q_12_55: Hỗ trợ 5 ý a, b, c, d, e và không nhận nhầm "website." thành nhãn e.',
      (WidgetTester tester) async {
        const stem =
            'Arrange the email sentences. '
            'a. Thank you for considering my application. '
            'b. Dear Recruitment Team, '
            'c. I am particularly interested in your environmental research projects. '
            'd. I would like to apply for the volunteer position advertised on your website. '
            'e. Yours sincerely, Hoa Tran.';

        await tester.pumpWidget(
          buildTestWidget(
            const QuestionStemView(stem: stem, type: 'arrange'),
          ),
        );

        expect(find.text('a'), findsOneWidget);
        expect(find.text('b'), findsOneWidget);
        expect(find.text('c'), findsOneWidget);
        expect(find.text('d'), findsOneWidget);
        expect(find.text('e'), findsOneWidget);

        expect(
          find.text(
            'I would like to apply for the volunteer position advertised on your website.',
          ),
          findsOneWidget,
        );
        expect(
          find.text('Yours sincerely, Hoa Tran.'),
          findsOneWidget,
        );
      },
    );
  });

  group('QuestionStemView - Dạng Biển báo (Signs)', () {
    testWidgets(
      'q_12_41: Hiển thị card biển báo với tiền tố "A sign reads:"',
      (WidgetTester tester) async {
        const stem =
            "A sign reads: 'NO LITTERING – KEEP THIS AREA CLEAN'. What does it mean?";

        await tester.pumpWidget(
          buildTestWidget(
            const QuestionStemView(stem: stem, type: 'signs'),
          ),
        );

        expect(find.text('NOTICE / BIỂN BÁO'), findsOneWidget);
        expect(
          find.text('NO LITTERING – KEEP THIS AREA CLEAN'),
          findsOneWidget,
        );
        expect(find.text('What does it mean?'), findsOneWidget);
      },
    );

    testWidgets(
      'q_12_43: Hiển thị card biển báo với tiền tố "A notice reads:"',
      (WidgetTester tester) async {
        const stem =
            "A notice reads: 'PLEASE SWITCH OFF THE LIGHTS WHEN LEAVING'. What should people do?";

        await tester.pumpWidget(
          buildTestWidget(
            const QuestionStemView(stem: stem, type: 'signs'),
          ),
        );

        expect(find.text('NOTICE / BIỂN BÁO'), findsOneWidget);
        expect(
          find.text('PLEASE SWITCH OFF THE LIGHTS WHEN LEAVING'),
          findsOneWidget,
        );
        expect(find.text('What should people do?'), findsOneWidget);
      },
    );

    testWidgets(
      'q_12_45: Hiển thị card biển báo với tiền tố "A notice reads:" và dấu hai chấm / chấm bên trong',
      (WidgetTester tester) async {
        const stem =
            "A notice reads: 'APPLICATION DEADLINE: 30 JUNE. LATE SUBMISSIONS WILL NOT BE ACCEPTED.' What does it mean?";

        await tester.pumpWidget(
          buildTestWidget(
            const QuestionStemView(stem: stem, type: 'signs'),
          ),
        );

        expect(find.text('NOTICE / BIỂN BÁO'), findsOneWidget);
        expect(
          find.text(
            'APPLICATION DEADLINE: 30 JUNE. LATE SUBMISSIONS WILL NOT BE ACCEPTED.',
          ),
          findsOneWidget,
        );
        expect(find.text('What does it mean?'), findsOneWidget);
      },
    );

    testWidgets(
      'Tự động nhận diện dạng Biển báo khi type null nhưng có "A notice reads:"',
      (WidgetTester tester) async {
        const stem =
            "A notice reads: 'LIBRARY CLOSES AT 5 PM'. What does it mean?";

        await tester.pumpWidget(
          buildTestWidget(
            const QuestionStemView(stem: stem),
          ),
        );

        expect(find.text('NOTICE / BIỂN BÁO'), findsOneWidget);
        expect(find.text('LIBRARY CLOSES AT 5 PM'), findsOneWidget);
      },
    );
  });

  group('QuestionStemView - Đảm bảo không ảnh hưởng dạng khác', () {
    testWidgets('Dạng Grammar tiêu chuẩn hiển thị văn bản thường', (
      WidgetTester tester,
    ) async {
      const stem =
          'If people use less plastic, the environment _______ cleaner.';

      await tester.pumpWidget(
        buildTestWidget(
          const QuestionStemView(stem: stem, type: 'grammar'),
        ),
      );

      expect(find.text(stem), findsOneWidget);
      expect(find.text('Sắp xếp'), findsNothing);
      expect(find.text('NOTICE / BIỂN BÁO'), findsNothing);
      expect(find.text('Bài đọc điền từ'), findsNothing);
    });

    testWidgets('Dạng Reading hiển thị khung đọc hiểu và câu hỏi', (
      WidgetTester tester,
    ) async {
      const stem =
          "Read the passage: 'Marie Curie was a pioneering scientist who conducted important research on radioactivity.' Question: What is the main idea of the passage?";

      await tester.pumpWidget(
        buildTestWidget(
          const QuestionStemView(stem: stem, type: 'reading'),
        ),
      );

      expect(find.text('Đoạn văn đọc hiểu'), findsOneWidget);
      expect(
        find.text(
          'Marie Curie was a pioneering scientist who conducted important research on radioactivity.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Question: What is the main idea of the passage?'),
        findsOneWidget,
      );
    });

    testWidgets('Dạng Reading với tiền tố "Read the following passage:" cũng hiển thị chuẩn', (
      WidgetTester tester,
    ) async {
      const stem =
          "Read the following passage: 'Artificial intelligence is transforming modern industries.' Question: What is the topic of the text?";

      await tester.pumpWidget(
        buildTestWidget(
          const QuestionStemView(stem: stem, type: 'reading'),
        ),
      );

      expect(find.text('Đoạn văn đọc hiểu'), findsOneWidget);
      expect(
        find.text('Artificial intelligence is transforming modern industries.'),
        findsOneWidget,
      );
      expect(
        find.text('Question: What is the topic of the text?'),
        findsOneWidget,
      );
    });

    testWidgets('Dạng Cloze câu đơn (q_12_56) vẫn hiển thị văn bản thường, không vỡ layout', (
      WidgetTester tester,
    ) async {
      const stem =
          'Complete the sentence: Many cities are developing public transport systems to _______ traffic congestion.';

      await tester.pumpWidget(
        buildTestWidget(
          const QuestionStemView(stem: stem, type: 'cloze'),
        ),
      );

      expect(find.text(stem), findsOneWidget);
      expect(find.text('Bài đọc điền từ'), findsNothing);
      expect(find.text('Đoạn văn đọc hiểu'), findsNothing);
    });

    testWidgets('Dạng Cloze bài đọc (passage) hiển thị khung "Bài đọc điền từ" và câu hỏi riêng', (
      WidgetTester tester,
    ) async {
      const stem =
          "Read the passage: 'Lifelong learning helps workers maintain mental sharpness and (1) _______ to new technologies.' Question: Which word best fits the blank (1)?";

      await tester.pumpWidget(
        buildTestWidget(
          const QuestionStemView(stem: stem, type: 'cloze'),
        ),
      );

      expect(find.text('Bài đọc điền từ'), findsOneWidget);
      expect(
        find.text(
          'Lifelong learning helps workers maintain mental sharpness and (1) _______ to new technologies.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Question: Which word best fits the blank (1)?'),
        findsOneWidget,
      );
      expect(find.text('Đoạn văn đọc hiểu'), findsNothing);
    });
  });
}
