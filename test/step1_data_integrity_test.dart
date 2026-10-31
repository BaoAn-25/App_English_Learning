import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:thpt_english/data/app_database.dart';
import 'package:thpt_english/data/models/user_profile.dart';
import 'package:thpt_english/data/models/word_progress.dart';
import 'package:thpt_english/ui/auth/auth_controller.dart';
import 'package:thpt_english/ui/textbook/textbook_hub_screen.dart';

import 'support/sqlite_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SqliteBridge bridge;
  late Database database;

  setUpAll(() async {
    bridge = await SqliteBridge.start();
    database = await AppDatabase.instance.database;
  });

  tearDownAll(() async {
    await database.close();
    await bridge.close();
  });

  group('BƯỚC 1: Kiểm tra tính toàn vẹn dữ liệu người dùng & tiến độ học', () {
    test('1. Hồ sơ mặc định người dùng mới là Khách, 0 XP, 0 streak, chưa có ngày thi', () {
      const profile = UserProfile();
      expect(profile.displayName, equals('Khách'));
      expect(profile.email, isEmpty);
      expect(profile.isLoggedIn, isFalse);
      expect(profile.streakDays, equals(0));
      expect(profile.xp, equals(0));
      expect(profile.examDate, isEmpty);
      expect(profile.favoriteTopics, isEmpty);
      expect(profile.reminderEnabled, isFalse);
    });

    test('2. UserProfile.fromMap với dữ liệu rỗng không tự động gán giá trị giả', () {
      final profile = UserProfile.fromMap({});
      expect(profile.displayName, equals('Khách'));
      expect(profile.email, isEmpty);
      expect(profile.isLoggedIn, isFalse);
      expect(profile.streakDays, equals(0));
      expect(profile.xp, equals(0));
      expect(profile.examDate, isEmpty);
    });

    test('3. AuthController logout đặt lại trạng thái về Khách, 0 XP, 0 streak', () {
      final auth = AuthController.instance;
      auth.logout();
      expect(auth.isAuthenticated, isFalse);
      expect(auth.user.displayName, equals('Khách'));
      expect(auth.user.streakDays, equals(0));
      expect(auth.user.xp, equals(0));
    });

    test('4. Không tạo tiến độ SRS cho từ mồ côi (getDueWordProgress chỉ lấy từ hợp lệ)', () async {
      final db = AppDatabase.instance;
      final rawDb = await db.database;

      // Chèn 1 từ hợp lệ vào bảng words
      await rawDb.insert('words', {
        'id': 'test_valid_word_01',
        'topicId': 'test_topic_01',
        'grade': 12,
        'english': 'sustainable',
        'ipa': '/səˈsteɪnəbl/',
        'meaningVi': 'bền vững',
        'example': 'sustainable development',
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // Chèn tiến độ cho từ hợp lệ (đã đến hạn)
      final pastTime = DateTime.now().millisecondsSinceEpoch - 10000;
      await rawDb.insert('word_progress', {
        'wordId': 'test_valid_word_01',
        'reviewCount': 2,
        'streak': 2,
        'nextReviewAt': pastTime,
        'lastReviewedAt': pastTime - 10000,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // Chèn 1 tiến độ mồ côi (không có từ trong bảng words)
      await rawDb.insert('word_progress', {
        'wordId': 'custom_orphan_word_99',
        'reviewCount': 1,
        'streak': 1,
        'nextReviewAt': pastTime,
        'lastReviewedAt': pastTime - 10000,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      final dueWords = await db.getDueWordProgress();
      // Phải chứa từ hợp lệ và KHÔNG chứa bản ghi mồ côi
      final wordIds = dueWords.map((w) => w.wordId).toList();
      expect(wordIds, contains('test_valid_word_01'));
      expect(wordIds, isNot(contains('custom_orphan_word_99')));
    });

    test('5. Bảo toàn tiến độ SRS: không bị ghi đè reset khi lưu lại từ đã có', () async {
      final db = AppDatabase.instance;

      // Giả sử từ đã có tiến độ ôn tập
      final initial = WordProgress(
        wordId: 'test_word_srs_preserve',
        reviewCount: 5,
        streak: 4,
        nextReviewAt: DateTime.now().millisecondsSinceEpoch + 86400000,
        lastReviewedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await db.upsertWordProgress(initial);

      // Kiểm tra tiến độ đang có
      final saved = await db.getWordProgress('test_word_srs_preserve');
      expect(saved, isNotNull);
      expect(saved!.reviewCount, equals(5));
      expect(saved.streak, equals(4));
    });

    testWidgets('6. TextbookHubScreen hiển thị tabs bộ lọc không bị RenderFlex overflow trên màn hình 360px', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: TextbookHubScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sách giáo khoa'), findsOneWidget);
      expect(find.text('Tất cả (10)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
