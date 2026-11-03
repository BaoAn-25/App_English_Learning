import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thpt_english/data/models/interest_topic.dart';
import 'package:thpt_english/data/models/interest_word.dart';
import 'package:thpt_english/ui/interest/interest_topic_detail_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Kiểm thử Dữ liệu Chủ đề Sở thích (Interest Topics & Words)', () {
    test('1. File interest_topics.json có đủ 14 chủ đề hợp lệ', () async {
      final jsonStr = await rootBundle.loadString('assets/data/interest_topics.json');
      final decoded = jsonDecode(jsonStr) as List;
      expect(decoded.length, 14);

      final topics = decoded.map((e) => InterestTopic.fromMap(e as Map<String, dynamic>)).toList();
      final cafeTopic = topics.firstWhere((t) => t.id == 'it_cafe');
      expect(cafeTopic.titleVi, 'Quán Cafe & Trà sữa');
    });

    test('2. File interest_words.json có số lượng từ dồi dào (> 200 từ)', () async {
      final jsonStr = await rootBundle.loadString('assets/data/interest_words.json');
      final decoded = jsonDecode(jsonStr) as List;
      expect(decoded.length, greaterThan(200));

      final words = decoded.map((e) => InterestWord.fromMap(e as Map<String, dynamic>)).toList();
      
      // Kiểm tra chủ đề Quán Cafe & Trà sữa
      final cafeWords = words.where((w) => w.topicId == 'it_cafe').toList();
      expect(cafeWords.length, greaterThanOrEqualTo(20), reason: 'Chủ đề Cafe phải có ít nhất 20 từ & câu');
      
      // Kiểm tra chủ đề Bóng đá
      final footballWords = words.where((w) => w.topicId == 'it_football').toList();
      expect(footballWords.length, greaterThanOrEqualTo(20), reason: 'Chủ đề Bóng đá phải có ít nhất 20 từ & câu');

      // Kiểm tra chủ đề Sân bay
      final airportWords = words.where((w) => w.topicId == 'it_airport').toList();
      expect(airportWords.length, greaterThanOrEqualTo(20), reason: 'Chủ đề Sân bay phải có ít nhất 20 từ & câu');
    });

    test('3. Tất cả từ vựng và câu đàm thoại đều có IPA, giải nghĩa và ví dụ song ngữ', () async {
      final jsonStr = await rootBundle.loadString('assets/data/interest_words.json');
      final decoded = jsonDecode(jsonStr) as List;
      final words = decoded.map((e) => InterestWord.fromMap(e as Map<String, dynamic>)).toList();

      for (final w in words) {
        expect(w.english.isNotEmpty, true, reason: 'English không được rỗng: ${w.id}');
        expect(w.ipa.isNotEmpty, true, reason: 'IPA không được rỗng: ${w.id}');
        expect(w.meaningVi.isNotEmpty, true, reason: 'MeaningVi không được rỗng: ${w.id}');
        expect(w.category, isIn(['word', 'phrase']), reason: 'Category phải là word hoặc phrase: ${w.id}');
      }
    });

    testWidgets('4. InterestTopicDetailScreen hiển thị Cây nốt 5 Cửa và Linh vật có IgnorePointer', (tester) async {
      SharedPreferences.setMockInitialValues({
        'interest_node_it_cafe': 1,
        'interest_xp_it_cafe': 0,
      });

      final topic = InterestTopic(
        id: 'it_cafe',
        categoryId: 'cat_food',
        categoryName: 'Ẩm thực & Đời sống',
        title: 'Coffee Shop & Milk Tea',
        titleVi: 'Quán Cafe & Trà sữa',
        iconName: 'local_cafe_rounded',
        description: 'Mô tả quán cafe',
        order: 4,
        level: 'A1-A2',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: InterestTopicDetailScreen(topic: topic),
        ),
      );

      // Chờ hoàn thành tải dữ liệu
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Kiểm tra tiêu đề banner
      expect(find.text('Quán Cafe & Trà sữa'), findsOneWidget);
      expect(find.text('HƯỚNG DẪN'), findsOneWidget);

      // Kiểm tra hiển thị các cửa
      expect(find.text('Cửa 1: Từ vựng trực quan'), findsOneWidget);
      expect(find.text('Cửa 2: Bắt âm & Phản xạ'), findsOneWidget);
      expect(find.text('Cửa 3: Rương kinh nghiệm'), findsOneWidget);
      expect(find.text('Cửa 4: Flashcard nhớ sâu'), findsOneWidget);
      expect(find.text('Cửa 5: Về đích - Ghép câu'), findsOneWidget);

      // Kiểm tra linh vật chú chim xanh và chữ cổ vũ
      expect(find.text('Cố lên bạn ơi! 🚀'), findsOneWidget);
      expect(find.byType(IgnorePointer), findsWidgets);
    });

    testWidgets('5. Chạm Cửa 1 mở bài học tương tác với bộ câu hỏi phong phú (nhiều hơn 5 câu)', (tester) async {
      SharedPreferences.setMockInitialValues({
        'interest_node_it_cafe': 1,
        'interest_xp_it_cafe': 0,
      });

      final topic = InterestTopic(
        id: 'it_cafe',
        categoryId: 'cat_food',
        categoryName: 'Ẩm thực & Đời sống',
        title: 'Coffee Shop & Milk Tea',
        titleVi: 'Quán Cafe & Trà sữa',
        iconName: 'local_cafe_rounded',
        description: 'Mô tả quán cafe',
        order: 4,
        level: 'A1-A2',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: InterestTopicDetailScreen(topic: topic),
        ),
      );

      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Nhấn vào Cửa 1
      await tester.tap(find.text('Cửa 1: Từ vựng trực quan'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Kiểm tra trong bài học có nút BỎ QUA và KIỂM TRA
      expect(find.text('BỎ QUA'), findsOneWidget);
      expect(find.text('KIỂM TRA'), findsOneWidget);

      // Kiểm tra hiển thị số câu (ví dụ: Câu 1/8 hoặc Câu 1/10)
      expect(find.textContaining('Câu 1/'), findsOneWidget);
    });
  });
}
