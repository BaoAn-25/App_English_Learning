import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:thpt_english/data/models/question.dart';
import 'package:thpt_english/data/models/word.dart';
import 'package:thpt_english/data/models/word_progress.dart';

void main() {
  group('Vocab & Topics JSON Data Tests', () {
    test('topics.json contains all 10 topics (grade 12)', () {
      final file = File('assets/data/topics.json');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      final List<dynamic> jsonList = jsonDecode(content);

      // Hoàn thành đủ 10 chủ đề
      expect(jsonList.length, equals(10));

      for (var i = 0; i < 10; i++) {
        final item = jsonList[i];
        expect(item['id'], equals('topic_12_u${i + 1}'));
        expect(item['grade'], equals(12));
        expect(item['title'], isNotEmpty);
        expect(item['order'], equals(i + 1));
      }
    });

    test('words.json contains exactly 200 words across all 10 topics (20 words/topic)', () {
      final file = File('assets/data/words.json');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      final List<dynamic> jsonList = jsonDecode(content);

      // Đủ 200 từ
      expect(jsonList.length, equals(200));

      // 20 từ mỗi chủ đề cho cả 10 chủ đề
      for (var u = 1; u <= 10; u++) {
        final topicId = 'topic_12_u$u';
        final words = jsonList.where((w) => w['topicId'] == topicId).toList();
        expect(words.length, equals(20), reason: 'Topic $topicId must have 20 words');
      }

      // Kiểm tra schema và tính hợp lệ từng từ
      for (final item in jsonList) {
        final word = Word.fromMap(item as Map<String, dynamic>);
        expect(word.id, isNotEmpty);
        expect(word.topicId, isNotEmpty);
        expect(word.grade, equals(12));
        expect(word.english, isNotEmpty);
        expect(word.ipa, startsWith('/'));
        expect(word.meaningVi, isNotEmpty);
        expect(word.example, isNotEmpty);
      }
    });

    test('questions.json contains exactly 280 questions across all 8 standard exam types', () {
      final file = File('assets/data/questions.json');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      final List<dynamic> jsonList = jsonDecode(content);

      // Đúng chuẩn 280 câu hỏi theo tiêu chí nghiệm thu tuần 3
      expect(jsonList.length, equals(280));

      final typeCounts = <String, int>{};
      for (final item in jsonList) {
        final type = item['type'] as String;
        typeCounts[type] = (typeCounts[type] ?? 0) + 1;

        final q = Question.fromMap(item as Map<String, dynamic>);
        expect(q.id, isNotEmpty);
        expect(q.grade, equals(12));
        expect(q.stem, isNotEmpty);
        expect(q.options.length, equals(4));
        expect(q.correctIndex, inInclusiveRange(0, 3));
        expect(q.explanation, isNotEmpty);
        expect(q.topicId, isNotNull);
      }

      // Kiểm tra đầy đủ 8 dạng bài thi tốt nghiệp THPT
      expect(typeCounts['vocab'], equals(50));
      expect(typeCounts['synonym_antonym'], equals(30));
      expect(typeCounts['grammar'], equals(50));
      expect(typeCounts['communication'], equals(30));
      expect(typeCounts['signs'], equals(30));
      expect(typeCounts['arrange'], equals(30));
      expect(typeCounts['cloze'], equals(30));
      expect(typeCounts['reading'], equals(30));
    });
  });

  group('Simple Review Box (Hộp ôn từ đơn giản) Tests', () {
    test('Initial word progress is unlearned and due immediately', () {
      final p = WordProgress.newWord('w_u1_01');
      expect(p.reviewCount, equals(0));
      expect(p.streak, equals(0));
      expect(p.isLearned, isFalse);
      expect(p.isMastered, isFalse);
      expect(p.isDue, isTrue);
    });

    test('afterCorrect (nhớ): ôn lại sau 3 ngày (nextReviewAt = now + 3 days)', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final p = WordProgress.newWord('w_u1_01').afterCorrect();

      expect(p.reviewCount, equals(1));
      expect(p.streak, equals(1));
      expect(p.isLearned, isTrue);

      // Thời gian ôn lại là xấp xỉ 3 ngày (dung sai 2 giây)
      final diffDays = (p.nextReviewAt - now) / const Duration(days: 1).inMilliseconds;
      expect(diffDays, closeTo(3.0, 0.01));

      // Ngay sau khi ôn đúng thì từ không còn due
      expect(p.isDue, isFalse);
    });

    test('afterWrong (chưa nhớ): ôn lại ngày mai (nextReviewAt = now + 1 day)', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final p = WordProgress.newWord('w_u1_01')
          .afterCorrect()
          .afterCorrect()
          .afterWrong();

      expect(p.reviewCount, equals(3));
      expect(p.streak, equals(0)); // Reset streak
      expect(p.isLearned, isTrue);

      // Thời gian ôn lại là xấp xỉ 1 ngày (dung sai 2 giây)
      final diffDays = (p.nextReviewAt - now) / const Duration(days: 1).inMilliseconds;
      expect(diffDays, closeTo(1.0, 0.01));

      // Ngay sau khi ôn sai thì từ không còn due cho đến ngày mai
      expect(p.isDue, isFalse);
    });
  });
}
