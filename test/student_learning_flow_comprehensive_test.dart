import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:thpt_english/data/app_database.dart';
import 'package:thpt_english/data/app_repository.dart';
import 'package:thpt_english/data/models/user_profile.dart';
import 'package:thpt_english/ui/auth/auth_controller.dart';
import 'package:thpt_english/ui/home/home_screen.dart';
import 'package:thpt_english/ui/textbook/unit_detail_screen.dart';
import 'package:thpt_english/ui/textbook/unit_getting_started_screen.dart';
import 'package:thpt_english/ui/textbook/unit_language_screen.dart';
import 'package:thpt_english/ui/textbook/unit_skills_screen.dart';
import 'package:thpt_english/ui/trial/trial_lesson_screen.dart';
import 'package:thpt_english/ui/vocab/vocab_provider.dart';

import 'support/sqlite_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SqliteBridge bridge;
  late Database database;
  late AppRepository repo;

  setUpAll(() async {
    bridge = await SqliteBridge.start();
    database = await AppDatabase.instance.database;
    repo = AppRepository();
  });

  tearDownAll(() async {
    await database.close();
    await bridge.close();
  });

  setUp(() {
    // Thiết lập trạng thái học viên đã đăng nhập (anbao)
    AuthController.instance.updateProfile(
      const UserProfile(
        id: 'student_anbao_123',
        email: 'tongan542@gmail.com',
        displayName: 'anbao',
        authProvider: 'email',
        role: 'student',
        isLoggedIn: true,
        emailVerified: true,
      ),
    );
  });

  tearDown(() {
    AuthController.instance.updateProfile(
      const UserProfile(
        id: 'guest_user',
        displayName: 'Khách',
        isLoggedIn: false,
      ),
    );
  });

  Widget buildTestWidget(Widget child) {
    return MultiProvider(
      providers: [
        Provider<AppRepository>.value(value: repo),
        ChangeNotifierProvider<VocabProvider>(
          create: (_) => VocabProvider(repo),
        ),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('A. UnitDetailScreen - Luồng Học Viên Số Hóa & Không Mở Ảnh Cộc Lốc', () {
    testWidgets('1. Học viên đăng nhập: KHÔNG hiển thị nhãn "Học thử" trên bất kỳ phần nào',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget(const UnitDetailScreen(unitNumber: 1)));
      await tester.pumpAndSettle();

      // Xác minh không còn nhãn "Học thử"
      expect(find.text('Học thử'), findsNothing);

      // Xác minh nút "Xem sách gốc" có mặt ở AppBar
      expect(find.text('Xem sách gốc'), findsOneWidget);

      // Xác minh 7 phần bài học chuẩn SGK đều có mặt
      expect(find.text('Getting Started'), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('Reading'), findsOneWidget);
      expect(find.text('Pronunciation'), findsOneWidget);
      expect(find.text('Speaking'), findsOneWidget);
      expect(find.text('Listening & Writing'), findsOneWidget);
      expect(find.text('Looking Back & Project'), findsOneWidget);
    });

    testWidgets('2. Chạm vào Getting Started: Mở màn hình hội thoại tương tác (không mở ảnh)',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget(const UnitDetailScreen(unitNumber: 1)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Getting Started'));
      await tester.pumpAndSettle();

      // Xác minh đã điều hướng vào UnitGettingStartedScreen
      expect(find.byType(UnitGettingStartedScreen), findsOneWidget);
      expect(find.text('The diary of Dang Thuy Tram'), findsOneWidget);
      expect(find.text('1. Hội thoại tương tác'), findsOneWidget);
      expect(find.text('2. Bài tập SGK (4 câu)'), findsOneWidget);
    });

    testWidgets('3. Chạm vào Language: Mở màn hình Từ vựng & Ngữ pháp tương tác (không mở ảnh)',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget(const UnitDetailScreen(unitNumber: 1)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Language'));
      await tester.pumpAndSettle();

      // Xác minh đã điều hướng vào UnitLanguageScreen
      expect(find.byType(UnitLanguageScreen), findsOneWidget);
      expect(find.textContaining('1. Từ vựng SGK'), findsOneWidget);
      expect(find.text('2. Ngữ pháp trọng tâm'), findsOneWidget);
    });

    testWidgets('4. Chạm vào Reading: Mở bài đọc hiểu tương tác chuẩn SGK',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget(const UnitDetailScreen(unitNumber: 1)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reading'));
      await tester.pumpAndSettle();

      // Xác minh đã điều hướng vào TrialLessonScreen (chế độ học viên)
      expect(find.byType(TrialLessonScreen), findsOneWidget);
      expect(find.text('1. Đọc bài & Tra từ vựng'), findsOneWidget);
      expect(find.textContaining('Unit 1: Steve Jobs'), findsWidgets);
    });

    testWidgets('5. Chạm vào Speaking / Skills: Mở màn hình rèn luyện kỹ năng số hóa',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget(const UnitDetailScreen(unitNumber: 1)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Speaking'));
      await tester.pumpAndSettle();

      // Xác minh đã điều hướng vào UnitSkillsScreen
      expect(find.byType(UnitSkillsScreen), findsOneWidget);
      expect(find.text('Mẫu câu giao tiếp thông dụng (Key Useful Phrases)'), findsOneWidget);
      expect(find.textContaining('Vở bài làm số hóa'), findsOneWidget);
    });
  });

  group('B. UnitGettingStartedScreen - Tương Tác Hội Thoại & Bài Tập SGK', () {
    testWidgets('1. Hiển thị nhân vật và bong bóng đối thoại chuẩn SGK', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget(
        const UnitGettingStartedScreen(
          unitNumber: 1,
          unitTitle: 'Life Stories We Admire',
          startPage: 8,
        ),
      ));
      await tester.pumpAndSettle();

      // Kiểm tra tên nhân vật Nam và Mark
      expect(find.text('Mark').first, findsOneWidget);
      expect(find.text('Nam').first, findsOneWidget);

      // Chuyển sang Tab bài tập
      await tester.tap(find.text('2. Bài tập SGK (4 câu)'));
      await tester.pumpAndSettle();

      expect(find.text('Activity 2: Đọc hiểu hội thoại'), findsOneWidget);
      expect(find.text('1. Dang Thuy Tram was born in Ha Noi.'), findsOneWidget);
    });
  });

  group('C. UnitLanguageScreen - Flashcard & Trọng Tâm Ngữ Pháp', () {
    testWidgets('1. Tab Ngữ pháp hiển thị cấu trúc thì Quá khứ đơn vs Quá khứ tiếp diễn', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget(
        const UnitLanguageScreen(
          unitNumber: 1,
          unitTitle: 'Life Stories We Admire',
          startPage: 9,
        ),
      ));
      await tester.pumpAndSettle();

      // Chuyển sang Tab 2: Ngữ pháp trọng tâm
      await tester.tap(find.text('2. Ngữ pháp trọng tâm'));
      await tester.pumpAndSettle();

      expect(find.text('Past Simple vs. Past Continuous (Quá khứ đơn & Quá khứ tiếp diễn)'), findsOneWidget);
      expect(find.text('Luyện tập trắc nghiệm ngữ pháp SGK'), findsOneWidget);
    });
  });

  group('D. HomeScreen - Lộ Trình Học Tập Dành Cho Học Viên Đã Đăng Nhập', () {
    testWidgets('1. Học viên đăng nhập thấy Thẻ Lộ trình SGK 12 và nút học trực tiếp', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget(const HomeScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Xác minh thẻ Lộ trình học viên
      expect(find.text('LỘ TRÌNH HỌC VIÊN SGK 12'), findsOneWidget);
      expect(find.text('Học bài đọc hiểu'), findsOneWidget);
      expect(find.text('Chi tiết Unit'), findsOneWidget);
      expect(find.text('Chọn bài học từ toàn bộ 10 Unit SGK >'), findsOneWidget);
    });
  });

  group('E. TrialLessonScreen - Kết Quả Học Viên Không Đòi Đăng Ký', () {
    testWidgets('1. Học viên hoàn thành bài đọc hiển thị thẻ thành tích học viên đã lưu', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget(
        const TrialLessonScreen(
          lessonId: 'trial_unit1_reading',
          initialStep: 2,
          initialAnswers: [1, 1, 0, 1, 2],
        ),
      ));
      await tester.pumpAndSettle();

      // Xác minh thẻ thành tích học viên hiển thị
      expect(find.textContaining('Đã lưu bài học vào tài khoản: anbao'), findsOneWidget);

      // Xác minh tuyệt đối KHÔNG có nút kêu gọi tạo tài khoản
      expect(find.text('Lưu kết quả học tập vào tài khoản'), findsNothing);
      expect(find.text('Tạo tài khoản lưu kết quả'), findsNothing);
      expect(find.text('Đã có tài khoản? Đăng nhập'), findsNothing);
    });
  });
}
