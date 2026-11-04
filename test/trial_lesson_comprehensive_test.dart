import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:thpt_english/data/app_database.dart';
import 'package:thpt_english/data/app_repository.dart';
import 'package:thpt_english/data/models/learning_session.dart';
import 'package:thpt_english/data/trial_lesson_repository.dart';
import 'package:thpt_english/data/trial_policy.dart';
import 'package:thpt_english/ui/auth/auth_controller.dart';
import 'package:thpt_english/ui/trial/interactive_reading_text.dart';
import 'package:thpt_english/ui/trial/trial_lesson_screen.dart';

import 'support/sqlite_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SqliteBridge bridge;
  late Database database;
  late AppRepository repository;

  setUpAll(() async {
    bridge = await SqliteBridge.start();
    database = await AppDatabase.instance.database;
    repository = AppRepository();
  });

  tearDownAll(() async {
    await database.close();
    await bridge.close();
  });

  setUp(() async {
    for (final table in [
      'data_ownership',
      'attempt_answers',
      'attempts',
      'wrong_book',
      'word_progress',
      'daily_stats',
      'questions',
      'app_settings',
    ]) {
      await database.delete(table);
    }
    AuthController.instance.logout();
  });

  group('1. Cấu trúc học liệu và tính sẵn sàng của 10 Unit', () {
    test('TrialLessonRepository có đủ 10 Unit với định danh lessonId ổn định', () {
      final lessons = TrialLessonRepository.allLessons;
      expect(lessons.length, 10);

      final lessonIds = lessons.map((l) => l.lessonId).toSet();
      expect(lessonIds.length, 10, reason: 'Mỗi bài học thử phải có lessonId duy nhất');

      for (int i = 1; i <= 10; i++) {
        expect(lessonIds.contains('trial_unit${i}_reading'), isTrue);
      }
    });

    test('Toàn bộ 10 Unit đều có isReady=true với đầy đủ bài đọc, câu hỏi và đối chiếu SGK', () {
      final readyLessons = TrialLessonRepository.instance.getReadyLessons();
      expect(readyLessons.length, 10, reason: 'Tất cả 10 Unit đều đã sẵn sàng học thử');

      final readyUnitNumbers = readyLessons.map((l) => l.unitNumber).toList();
      expect(readyUnitNumbers, containsAll([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]));

      for (final lesson in readyLessons) {
        expect(lesson.isReady, isTrue);
        expect(lesson.paragraphs.length, greaterThanOrEqualTo(2));
        expect(lesson.questions.length, greaterThanOrEqualTo(4));
        expect(lesson.vocabulary.isNotEmpty, isTrue);
        expect(lesson.textbookSource, contains('Global Success'));
        expect(lesson.textbookSource, contains('Trang in'));
      }
    });

    test('Các Unit 2, 3, 7, 8 có nội dung bài đọc và câu hỏi đối chiếu SGK chuẩn xác', () {
      final u2 = TrialLessonRepository.instance.getLessonByUnit(2)!;
      final u3 = TrialLessonRepository.instance.getLessonByUnit(3)!;
      final u7 = TrialLessonRepository.instance.getLessonByUnit(7)!;
      final u8 = TrialLessonRepository.instance.getLessonByUnit(8)!;

      // Unit 2
      expect(u2.isReady, isTrue);
      expect(u2.lessonTitle, contains('Globalisation'));
      expect(u2.paragraphs.any((p) => p.text.contains('K-pop')), isTrue);
      expect(u2.questions.any((q) => q.word.contains('Variety of cuisines') || q.options.contains('D. Variety of cuisines')), isTrue);

      // Unit 3
      expect(u3.isReady, isTrue);
      expect(u3.lessonTitle, contains('Plastics'));
      expect(u3.paragraphs.any((p) => p.text.contains('cardboard boxes')), isTrue);
      expect(u3.questions.any((q) => q.targetWord == 'cardboard boxes'), isTrue);
      expect(u3.questions.any((q) => q.targetWord == 'contaminated'), isTrue);

      // Unit 7
      expect(u7.isReady, isTrue);
      expect(u7.lessonTitle, contains('Digital Media'));
      expect(u7.paragraphs.any((p) => p.text.contains('Minh Quang')), isTrue);
      expect(u7.questions.any((q) => q.targetWord == 'credible'), isTrue);
      expect(u7.questions.any((q) => q.targetWord == 'here to stay'), isTrue);

      // Unit 8
      expect(u8.isReady, isTrue);
      expect(u8.lessonTitle, contains('Wildlife Conservation'));
      expect(u8.paragraphs.any((p) => p.text.contains('Con Dao Island')), isTrue);
      expect(u8.questions.any((q) => q.targetWord == 'spawning ground'), isTrue);
      expect(u8.questions.any((q) => q.options.any((o) => o.contains('coral reefs'))), isTrue);
    });

    test('Mỗi bài sẵn sàng có câu hỏi riêng biệt, không dùng chung câu hỏi Unit 1', () {
      final unit1 = TrialLessonRepository.instance.getLessonById('trial_unit1_reading')!;
      final unit4 = TrialLessonRepository.instance.getLessonById('trial_unit4_reading')!;
      final unit9 = TrialLessonRepository.instance.getLessonById('trial_unit9_reading')!;

      expect(unit1.questions.first.word, isNot(equals(unit4.questions.first.word)));
      expect(unit4.questions.first.word, isNot(equals(unit9.questions.first.word)));
      expect(unit1.lessonTitle, contains('Life and Achievements'));
      expect(unit4.unitTitle, contains('Urbanisation'));
      expect(unit9.unitTitle, contains('Career'));
    });
  });

  group('2. Từ điển ngoại tuyến và nhận diện cụm từ', () {
    test('Tra từ đơn có trong từ điển ngoại tuyến', () {
      final res = TrialLessonRepository.instance.lookupWordOrPhrase(query: 'achievements');
      expect(res.isFoundInDictionary, isTrue);
      expect(res.displayWord, contains('achievements'));
      expect(res.meaning, anyOf([contains('thành tích'), contains('thành tựu')]));
    });

    test('Nhận diện cụm từ nhiều từ (phrasal verbs, idioms)', () {
      final phrases = [
        'dropped out',
        'passed away',
        'take into account',
        'hands-on',
        'on-the-job training',
        'high-rise',
      ];

      for (final phrase in phrases) {
        final res = TrialLessonRepository.instance.lookupWordOrPhrase(query: phrase);
        expect(res.isFoundInDictionary, isTrue, reason: 'Cần nhận diện cụm từ: $phrase');
        expect(res.isPhrase, isTrue);
        expect(res.displayWord.toLowerCase(), phrase.toLowerCase());
      }
    });

    test('Chuẩn hóa từ có dấu câu, ký tự đặc biệt và chữ hoa/thường', () {
      final resUpper = TrialLessonRepository.instance.lookupWordOrPhrase(query: 'ACHIEVEMENTS');
      expect(resUpper.isFoundInDictionary, isTrue);

      final resPunct = TrialLessonRepository.instance.lookupWordOrPhrase(query: 'dropped out,');
      expect(resPunct.isFoundInDictionary, isTrue);
      expect(resPunct.displayWord, 'dropped out');
    });

    test('Từ không có trong từ điển trả về isFoundInDictionary=false trung thực, không trả nghĩa giả', () {
      final res = TrialLessonRepository.instance.lookupWordOrPhrase(query: 'supercalifragilistic');
      expect(res.isFoundInDictionary, isFalse);
      expect(res.source, contains('Học liệu'));
    });
  });

  group('3. Chính sách quyền học thử (Không tự áp đặt giới hạn khi chưa xác nhận)', () {
    test('Khách có quyền truy cập tất cả 10 bài học thử đã sẵn sàng', () {
      for (int i = 1; i <= 10; i++) {
        expect(
          TrialPolicy.canAccessTrialLesson(lessonId: 'trial_unit${i}_reading'),
          isTrue,
          reason: 'Unit $i phải cho phép truy cập học thử',
        );
      }
    });

    test('Bài học không tồn tại trả về canAccessTrialLesson=false an toàn', () {
      expect(
        TrialPolicy.canAccessTrialLesson(lessonId: 'trial_unit99_reading'),
        isFalse,
      );
    });

    test('canGuestAccessLesson tương thích ngược và cho phép truy cập bài sẵn sàng', () {
      final canAccess = TrialPolicy.canGuestAccessLesson(
        isGuest: true,
        targetLessonId: 'trial_unit4_reading',
        completedLessonId: 'trial_unit1_reading',
      );
      expect(canAccess, isTrue, reason: 'Khách không bị khóa sau khi đã hoàn thành 1 bài');
    });
  });

  group('4. Lưu trữ tiến độ bài dở tách biệt theo lessonId và chuyển giao dữ liệu', () {
    test('Tiến độ bài dở của Unit 1 và Unit 2 được lưu độc lập, không ghi đè lẫn nhau', () async {
      final guestId = await repository.getOrCreateGuestSessionId();

      // Lưu tiến độ dở Unit 1 qua LearningSession
      final s1 = LearningSession(
        ownerId: guestId,
        lessonId: 'trial_unit1_reading',
        lessonTitle: 'Unit 1: Steve Jobs',
        currentQuestionIndex: 2,
        totalQuestions: 5,
        questionIds: ['u1_rd_q1', 'u1_rd_q2', 'u1_rd_q3', 'u1_rd_q4', 'u1_rd_q5'],
        selectedAnswers: [1, 0, null, null, null],
      );
      await repository.saveLearningSession(s1);

      // Lưu tiến độ dở Unit 2 qua LearningSession
      final s2 = LearningSession(
        ownerId: guestId,
        lessonId: 'trial_unit2_reading',
        lessonTitle: 'Unit 2: Globalisation',
        currentQuestionIndex: 1,
        totalQuestions: 6,
        questionIds: ['u2_rd_q1', 'u2_rd_q2', 'u2_rd_q3', 'u2_rd_q4', 'u2_rd_q5', 'u2_rd_q6'],
        selectedAnswers: [3, null, null, null, null, null],
      );
      await repository.saveLearningSession(s2);

      // Đọc lại riêng từng bài theo lessonId
      final readS1 = await repository.getLearningSession(guestId, lessonId: 'trial_unit1_reading');
      final readS2 = await repository.getLearningSession(guestId, lessonId: 'trial_unit2_reading');

      expect(readS1, isNotNull);
      expect(readS1!.lessonId, 'trial_unit1_reading');
      expect(readS1.currentQuestionIndex, 2);
      expect(readS1.selectedAnswers[0], 1);

      expect(readS2, isNotNull);
      expect(readS2!.lessonId, 'trial_unit2_reading');
      expect(readS2.currentQuestionIndex, 1);
      expect(readS2.selectedAnswers[0], 3);

      // Đổi qua lại không làm mất bài dở
      expect(readS1.lessonId, isNot(equals(readS2.lessonId)));
    });

    test('Lưu bài học thử đã hoàn thành và chuyển giao sang tài khoản mới an toàn', () async {
      final guestId = await repository.getOrCreateGuestSessionId();

      // Lưu bài đã hoàn thành
      await repository.setCompletedTrialLessonId(guestId, 'trial_unit5_reading');
      final guestCompleted = await repository.getCompletedTrialLessonId(guestId);
      expect(guestCompleted, 'trial_unit5_reading');

      // Chuyển sang tài khoản mới
      const newUserId = 'student_account_999';
      await repository.transferGuestData(fromGuestId: guestId, toUserId: newUserId);

      final userCompleted = await repository.getCompletedTrialLessonId(newUserId);
      expect(userCompleted, 'trial_unit5_reading', reason: 'Tài khoản mới phải nhận được bài đã hoàn thành từ khách');
    });
  });

  group('5. Giao diện đọc theo lessonId, không phụ thuộc cố định Unit 1 và không dùng mock fallback', () {
    testWidgets('TrialLessonScreen không tự ý fallback về Unit 1 khi truyền lessonId không tồn tại', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TrialLessonScreen(lessonId: 'trial_unknown_nonexistent_lesson'),
        ),
      );
      await tester.pumpAndSettle();

      // Phải hiển thị thông báo lỗi rõ ràng, không được tự động mở bài Steve Jobs
      expect(find.textContaining('Không tìm thấy dữ liệu cho bài học'), findsOneWidget);
      expect(find.textContaining('Steve Jobs'), findsNothing);
      expect(find.text('Chọn bài học khác'), findsOneWidget);
    });

    testWidgets('InteractiveReadingText hiển thị văn bản và nút Dịch đoạn bật/tắt bản dịch', (WidgetTester tester) async {
      final unit1 = TrialLessonRepository.instance.getLessonById('trial_unit1_reading')!;
      final p1 = unit1.paragraphs.first;
      final assistanceLogs = <ReadingAssistanceType>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: InteractiveReadingText(
                text: p1.text,
                translation: p1.translation,
                keyVocabulary: unit1.vocabulary,
                translateButtonLabel: 'Dịch đoạn (Tiếng Việt)',
                onAssistanceUsed: (type) {
                  assistanceLogs.add(type);
                },
              ),
            ),
          ),
        ),
      );

      // Verify widget SelectableText hiển thị đầy đủ văn bản tiếng Anh
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is SelectableText &&
              (widget.textSpan?.toPlainText().contains('Steven Paul Jobs') ?? false),
        ),
        findsOneWidget,
      );

      // Ban đầu chưa hiển thị bản dịch tiếng Việt
      expect(find.textContaining('Steven Paul Jobs sinh ngày 24'), findsNothing);

      // Tìm nút "Dịch đoạn" và bấm
      final translateButton = find.text('Dịch đoạn (Tiếng Việt)');
      expect(translateButton, findsOneWidget);

      await tester.tap(translateButton);
      await tester.pumpAndSettle();

      // Sau khi bấm, bản dịch tiếng Việt phải xuất hiện
      expect(find.textContaining('Steven Paul Jobs sinh ngày 24'), findsOneWidget);
      expect(assistanceLogs, contains(ReadingAssistanceType.paragraphTranslate));

      // Bấm nút "Thu gọn" để ẩn bản dịch
      final collapseButton = find.text('Thu gọn bản dịch');
      expect(collapseButton, findsOneWidget);

      await tester.tap(collapseButton);
      await tester.pumpAndSettle();

      // Bản dịch đã ẩn đi
      expect(find.textContaining('Steven Paul Jobs sinh ngày 24'), findsNothing);
    });
  });
}
