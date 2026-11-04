import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:thpt_english/data/app_database.dart';
import 'package:thpt_english/data/app_repository.dart';
import 'package:thpt_english/data/models/attempt.dart';
import 'package:thpt_english/data/models/attempt_answer.dart';
import 'package:thpt_english/data/models/daily_stat.dart';
import 'package:thpt_english/data/models/learning_session.dart';
import 'package:thpt_english/data/models/wrong_book_entry.dart';
import 'package:thpt_english/data/trial_lesson_repository.dart';
import 'package:thpt_english/data/trial_policy.dart';

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
      'daily_stats',
      'questions',
      'app_settings',
    ]) {
      await database.delete(table);
    }
  });

  group('Kiểm thử Toàn Diện 10 Bài Học Thử SGK Global Success 12', () {
    test('1. Kiểm tra tính toàn vẹn và độc nhất của toàn bộ 10 Unit', () {
      final lessons = TrialLessonRepository.allLessons;
      expect(lessons.length, 10);

      final lessonIds = <String>{};
      final questionIds = <String>{};

      for (int u = 1; u <= 10; u++) {
        final lesson = TrialLessonRepository.instance.getLessonByUnit(u);
        expect(lesson, isNotNull, reason: 'Unit $u phải tồn tại trong Repository');
        expect(lesson!.unitNumber, u);
        expect(lesson.isReady, isTrue, reason: 'Unit $u phải ở trạng thái sẵn sàng');
        expect(lesson.lessonId, 'trial_unit${u}_reading');
        expect(lessonIds.add(lesson.lessonId), isTrue, reason: 'lessonId ${lesson.lessonId} bị trùng');

        // Kiểm tra bài đọc
        expect(lesson.paragraphs.isNotEmpty, isTrue, reason: 'Unit $u phải có đoạn văn bài đọc');
        for (final p in lesson.paragraphs) {
          expect(p.id.isNotEmpty, isTrue);
          expect(p.label.isNotEmpty, isTrue);
          expect(p.text.trim().isNotEmpty, isTrue);
          expect(p.translation.trim().isNotEmpty, isTrue);
        }

        // Kiểm tra câu hỏi
        expect(lesson.questions.length, greaterThanOrEqualTo(4), reason: 'Unit $u phải có từ 4 câu hỏi trở lên');
        for (final q in lesson.questions) {
          expect(q.id.isNotEmpty, isTrue);
          expect(questionIds.add(q.id), isTrue, reason: 'ID câu hỏi ${q.id} bị trùng lặp');
          expect(q.word.isNotEmpty, isTrue);
          expect(q.contextSentence.isNotEmpty, isTrue);
          expect(q.contextTranslation.isNotEmpty, isTrue);
          expect(q.textbookQuote.isNotEmpty, isTrue);
          expect(q.options.length, greaterThanOrEqualTo(2));
          expect(q.correctIndex, greaterThanOrEqualTo(0));
          expect(q.correctIndex, lessThan(q.options.length));
          expect(q.explanation.isNotEmpty, isTrue);

          // Chuyển sang Question model chuẩn
          final stdQ = q.toQuestion(lessonId: lesson.lessonId, topicId: 'unit$u');
          expect(stdQ.id, q.id);
          expect(stdQ.type, 'reading');
          expect(stdQ.correctIndex, q.correctIndex);
          expect(stdQ.options, q.options);
        }

        // Kiểm tra từ điển
        expect(lesson.vocabulary.isNotEmpty, isTrue, reason: 'Unit $u phải có từ điển từ vựng');
      }
    });

    test('2. Đối chiếu số trang và metadata sách gốc của 10 Unit từ textbook.json', () async {
      final jsonStr = await rootBundle.loadString('assets/data/textbook.json');
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final units = (data['units'] as List).cast<Map<String, dynamic>>();

      // Bảng đối chiếu số trang in SGK thực tế
      final expectedPages = {
        1: {'start': 8, 'end': 19, 'reading': 11},
        2: {'start': 20, 'end': 31, 'reading': 23},
        3: {'start': 32, 'end': 43, 'reading': 35},
        4: {'start': 48, 'end': 59, 'reading': 52},
        5: {'start': 60, 'end': 71, 'reading': 64},
        6: {'start': 76, 'end': 87, 'reading': 80},
        7: {'start': 88, 'end': 99, 'reading': 92},
        8: {'start': 100, 'end': 111, 'reading': 104},
        9: {'start': 116, 'end': 127, 'reading': 120},
        10: {'start': 128, 'end': 139, 'reading': 132},
      };

      for (int u = 1; u <= 10; u++) {
        final unitMeta = units.firstWhere((m) => m['id'] == 'gs12_u0$u' || m['id'] == 'gs12_u$u');
        final exp = expectedPages[u]!;

        expect(unitMeta['start'], exp['start'], reason: 'Unit $u start page không khớp');
        expect(unitMeta['end'], exp['end'], reason: 'Unit $u end page không khớp');

        final sections = (unitMeta['sections'] as List).cast<Map<String, dynamic>>();
        final readingSec = sections.firstWhere((s) => (s['title'] as String).contains('Reading'));
        expect(readingSec['page'], exp['reading'], reason: 'Unit $u Reading page không khớp');

        // Đảm bảo không dùng công thức sai unitNumber * 12 (chỉ Unit 4 và 5 vô tình trùng số do số trang các bài trước)
        if (u != 4 && u != 5) {
          expect(exp['start'], isNot(equals(u * 12)), reason: 'Công thức u * 12 sai lệch với số trang thật của Unit $u');
        }

        // Kiểm tra nguồn SGK ghi trong TrialLessonData
        final lesson = TrialLessonRepository.instance.getLessonByUnit(u)!;
        expect(lesson.textbookSource, contains('Trang in ${exp['reading']}'));
      }
    });

    test('3. Đổi nhiều Unit và lưu tiến độ dở không ghi đè bài của nhau', () async {
      const ownerId = 'test_multi_unit_student';

      // Học dở Unit 2
      final sessionU2 = LearningSession(
        ownerId: ownerId,
        lessonId: 'trial_unit2_reading',
        lessonTitle: 'Unit 2: A Multicultural World',
        currentQuestionIndex: 2,
        totalQuestions: 6,
        questionIds: ['u2_rd_q1', 'u2_rd_q2', 'u2_rd_q3', 'u2_rd_q4', 'u2_rd_q5', 'u2_rd_q6'],
        selectedAnswers: [3, 0, null, null, null, null],
      );
      await repository.saveLearningSession(sessionU2);

      // Chuyển sang học dở Unit 3
      final sessionU3 = LearningSession(
        ownerId: ownerId,
        lessonId: 'trial_unit3_reading',
        lessonTitle: 'Unit 3: Green Living',
        currentQuestionIndex: 3,
        totalQuestions: 6,
        questionIds: ['u3_rd_q1', 'u3_rd_q2', 'u3_rd_q3', 'u3_rd_q4', 'u3_rd_q5', 'u3_rd_q6'],
        selectedAnswers: [0, 1, 1, null, null, null],
      );
      await repository.saveLearningSession(sessionU3);

      // Chuyển sang học dở Unit 8
      final sessionU8 = LearningSession(
        ownerId: ownerId,
        lessonId: 'trial_unit8_reading',
        lessonTitle: 'Unit 8: Wildlife Conservation',
        currentQuestionIndex: 1,
        totalQuestions: 6,
        questionIds: ['u8_rd_q1', 'u8_rd_q2', 'u8_rd_q3', 'u8_rd_q4', 'u8_rd_q5', 'u8_rd_q6'],
        selectedAnswers: [1, null, null, null, null, null],
      );
      await repository.saveLearningSession(sessionU8);

      // Khôi phục lại từng bài học theo lessonId
      final restoredU2 = await repository.getLearningSession(ownerId, lessonId: 'trial_unit2_reading');
      final restoredU3 = await repository.getLearningSession(ownerId, lessonId: 'trial_unit3_reading');
      final restoredU8 = await repository.getLearningSession(ownerId, lessonId: 'trial_unit8_reading');

      expect(restoredU2, isNotNull);
      expect(restoredU2!.lessonId, 'trial_unit2_reading');
      expect(restoredU2.currentQuestionIndex, 2);
      expect(restoredU2.selectedAnswers[0], 3);

      expect(restoredU3, isNotNull);
      expect(restoredU3!.lessonId, 'trial_unit3_reading');
      expect(restoredU3.currentQuestionIndex, 3);
      expect(restoredU3.selectedAnswers[1], 1);

      expect(restoredU8, isNotNull);
      expect(restoredU8!.lessonId, 'trial_unit8_reading');
      expect(restoredU8.currentQuestionIndex, 1);
      expect(restoredU8.selectedAnswers[0], 1);

      // Phiên gần nhất trên trang chủ là Unit 8
      final latestSession = await repository.getLearningSession(ownerId);
      expect(latestSession, isNotNull);
      expect(latestSession!.lessonId, 'trial_unit8_reading');
    });

    test('4. Lưu kết quả học và nạp câu sai vào Sổ câu sai hoạt động bình thường', () async {
      const ownerId = 'test_wrong_book_student';
      final u7 = TrialLessonRepository.instance.getLessonByUnit(7)!;

      // Chèn questions vào SQLite
      await repository.insertQuestions(u7.questionsAsStandardQuestions);

      final attempt = Attempt(
        mode: 'trial',
        type: u7.lessonId,
        startedAt: DateTime.now().millisecondsSinceEpoch - 120000,
        durationSec: 120,
        score: 4,
        total: 6,
      );

      final wrongEntries = [
        WrongBookEntry(
          questionId: 'u7_rd_q1',
          wrongCount: 1,
          lastWrongAt: DateTime.now().millisecondsSinceEpoch,
          nextReviewAt: DateTime.now().millisecondsSinceEpoch + 86400000,
        ),
        WrongBookEntry(
          questionId: 'u7_rd_q5',
          wrongCount: 1,
          lastWrongAt: DateTime.now().millisecondsSinceEpoch,
          nextReviewAt: DateTime.now().millisecondsSinceEpoch + 86400000,
        ),
      ];

      await repository.savePracticeResult(
        attempt: attempt,
        buildAnswers: (attemptId) => List.generate(
          6,
          (i) => AttemptAnswer(
            attemptId: attemptId,
            questionId: u7.questions[i].id,
            chosenIndex: i == 0 || i == 4 ? 2 : u7.questions[i].correctIndex,
            isCorrect: i != 0 && i != 4,
          ),
        ),
        wrongEntries: wrongEntries,
        dailyStat: const DailyStat(date: '2026-11-03', xp: 40, questionsDone: 6, correct: 4, minutes: 2),
        ownerId: ownerId,
      );

      // Kiểm tra câu sai đã được lưu vào database và truy vấn được
      final wrongList = await AppDatabase.instance.getAllWrongBookEntries(ownerId: ownerId);
      expect(wrongList.any((w) => w.questionId == 'u7_rd_q1'), isTrue);
      expect(wrongList.any((w) => w.questionId == 'u7_rd_q5'), isTrue);

      final qList = await AppDatabase.instance.getQuestionsByIds(['u7_rd_q1']);
      expect(qList.isNotEmpty, isTrue);
      final q1 = qList.first;
      expect(q1.passageId, u7.lessonId);
      expect(q1.explanation, contains('credible'));
    });

    test('5. Số lượng bài học sẵn sàng là 10, chính sách mở cho khách', () {
      final readyCount = TrialLessonRepository.instance.getReadyLessons().length;
      expect(readyCount, 10);

      for (int i = 1; i <= 10; i++) {
        expect(TrialPolicy.isTrialContent(unitNumber: i, sectionTitle: 'Reading'), isTrue);
        expect(TrialPolicy.canAccessTrialLesson(lessonId: 'trial_unit${i}_reading'), isTrue);
      }

      expect(TrialPolicy.isTrialContent(unitNumber: 1, sectionTitle: 'Speaking'), isFalse);
    });
  });
}
