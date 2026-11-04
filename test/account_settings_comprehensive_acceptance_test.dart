import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:thpt_english/data/app_database.dart';
import 'package:thpt_english/data/app_repository.dart';
import 'package:thpt_english/data/models/user_profile.dart';
import 'package:thpt_english/ui/auth/auth_controller.dart';
import 'package:thpt_english/ui/common/dialogs/avatar_picker_dialog.dart';
import 'package:thpt_english/ui/settings/settings_screen.dart';
import 'package:thpt_english/ui/theme/theme_controller.dart';

import 'support/sqlite_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SqliteBridge bridge;
  late Database database;

  setUpAll(() async {
    HttpOverrides.global = _TestHttpOverrides();
    bridge = await SqliteBridge.start();
    database = await AppDatabase.instance.database;
  });

  tearDownAll(() async {
    await database.close();
    await bridge.close();
  });

  group('Account & Settings Comprehensive Redesign Tests', () {
    late AppRepository repo;
    late ThemeController themeController;

    setUp(() {
      repo = AppRepository();
      themeController = ThemeController();
    });

    void setDesktopViewport(WidgetTester tester) {
      tester.view.physicalSize = const Size(1920, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    testWidgets('1. Guest Role: renders Offline Badge, Register button, Reset Guest Data action',
        (WidgetTester tester) async {
      await tester.runAsync(() async {
        setDesktopViewport(tester);
        AuthController.instance.setUserForTesting(const UserProfile());

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              Provider<AppRepository>.value(value: repo),
              ChangeNotifierProvider<ThemeController>.value(value: themeController),
            ],
            child: MaterialApp(
              home: SettingsScreen(repository: repo),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify guest elements
        expect(find.text('Khách trải nghiệm'), findsOneWidget);
        expect(find.text('OFFLINE'), findsOneWidget);
        expect(find.text('Đăng ký tài khoản (Mở khóa toàn bộ)'), findsOneWidget);
        expect(find.text('Đã có tài khoản? Đăng nhập để đồng bộ'), findsOneWidget);
        expect(find.text('Xóa dữ liệu học thử trên thiết bị'), findsOneWidget);

        // Verify notification center & theme mode exist
        expect(find.text('Trung tâm thông báo & Nhắc học'), findsOneWidget);
        expect(find.text('Giao diện ứng dụng'), findsOneWidget);
      });
    });

    testWidgets('2. Student Role: renders Student Badge, Avatar picker trigger, Notification channels',
        (WidgetTester tester) async {
      await tester.runAsync(() async {
        setDesktopViewport(tester);
        AuthController.instance.setUserForTesting(const UserProfile(
          id: 'student_123',
          email: 'student@example.com',
          displayName: 'Nguyễn Văn Học Sinh',
          role: 'student',
          authProvider: 'email',
          emailVerified: true,
          isLoggedIn: true,
        ));

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              Provider<AppRepository>.value(value: repo),
              ChangeNotifierProvider<ThemeController>.value(value: themeController),
            ],
            child: MaterialApp(
              home: SettingsScreen(repository: repo),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify Student Badge
        expect(find.text('Nguyễn Văn Học Sinh'), findsOneWidget);
        expect(find.text('HỌC VIÊN'), findsOneWidget);
        expect(find.text('student@example.com'), findsOneWidget);
        expect(find.text('Đã xác minh'), findsOneWidget);

        // Verify notification channel switches
        expect(find.text('Thông báo chung & Bảo trì'), findsOneWidget);
        expect(find.text('Bài tập & Hạn thi mới'), findsOneWidget);
        expect(find.text('Cảnh báo nguy cơ mất chuỗi Streak'), findsOneWidget);
        expect(find.text('Bảng xếp hạng & Vinh danh'), findsOneWidget);
        expect(find.text('Hiệu ứng âm thanh'), findsOneWidget);

        // Verify Theme options
        expect(find.text('Tự động'), findsOneWidget);
        expect(find.text('Sáng'), findsOneWidget);
        expect(find.text('Tối'), findsOneWidget);
      });
    });

    testWidgets('3. Teacher Role: renders Teacher Badge & Teacher Portal shortcut card',
        (WidgetTester tester) async {
      await tester.runAsync(() async {
        setDesktopViewport(tester);
        AuthController.instance.setUserForTesting(const UserProfile(
          id: 'teacher_123',
          email: 'teacher@school.edu.vn',
          displayName: 'Thầy Hoàng Giáo Viên',
          role: 'teacher',
          authProvider: 'google',
          emailVerified: true,
          isLoggedIn: true,
        ));

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              Provider<AppRepository>.value(value: repo),
              ChangeNotifierProvider<ThemeController>.value(value: themeController),
            ],
            child: MaterialApp(
              home: SettingsScreen(repository: repo),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify Teacher badge & Teacher portal card
        expect(find.text('Thầy Hoàng Giáo Viên'), findsOneWidget);
        expect(find.text('GIÁO VIÊN BỘ MÔN'), findsOneWidget);
        expect(find.text('Cổng Giáo Viên & Giám Sát Thi'), findsOneWidget);
        expect(find.text('Vào Cổng Giáo Viên & Giám Sát'), findsOneWidget);
      });
    });

    testWidgets('4. Admin Role: renders Super Admin Badge & Admin Management shortcut card',
        (WidgetTester tester) async {
      await tester.runAsync(() async {
        setDesktopViewport(tester);
        AuthController.instance.setUserForTesting(const UserProfile(
          id: 'admin_123',
          email: 'admin@engpass.edu.vn',
          displayName: 'An Quản Trị Viên',
          role: 'admin',
          authProvider: 'email',
          emailVerified: true,
          isLoggedIn: true,
        ));

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              Provider<AppRepository>.value(value: repo),
              ChangeNotifierProvider<ThemeController>.value(value: themeController),
            ],
            child: MaterialApp(
              home: SettingsScreen(repository: repo),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify Admin badge & Portal card
        expect(find.text('An Quản Trị Viên'), findsOneWidget);
        expect(find.text('QUẢN TRỊ VIÊN HỆ THỐNG'), findsOneWidget);
        expect(find.text('Trung Tâm Quản Trị Hệ Thống'), findsOneWidget);
        expect(find.text('Trung Tâm Quản Trị Admin'), findsOneWidget);
        expect(find.text('Cổng Giáo Viên'), findsOneWidget);
      });
    });

    testWidgets('5. Avatar Picker Dialog: displays presets tab and custom URL tab',
        (WidgetTester tester) async {
      setDesktopViewport(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  AvatarPickerDialog.show(
                    ctx,
                    currentAvatarUrl: '',
                    onSelected: (_) {},
                  );
                },
                child: const Text('Open Picker'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      expect(find.text('Đổi ảnh đại diện (Avatar)'), findsOneWidget);
      expect(find.text('Bộ sưu tập EngPass'), findsOneWidget);
      expect(find.text('Link ảnh từ web'), findsOneWidget);
      expect(find.text('Học bá THPT'), findsOneWidget);

      // Switch to Link tab
      await tester.tap(find.text('Link ảnh từ web'));
      await tester.pumpAndSettle();

      expect(find.text('Dán đường dẫn ảnh (URL)'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });
  });
}

class _TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _MockHttpClient();
  }
}

class _MockHttpClient extends Fake implements HttpClient {
  @override
  bool autoUncompress = true;
  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = const Duration(seconds: 15);
  @override
  int? maxConnectionsPerHost;
  @override
  String? userAgent;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _MockHttpClientRequest();
}

class _MockHttpClientRequest extends Fake implements HttpClientRequest {
  @override
  final HttpHeaders headers = _MockHttpHeaders();

  @override
  Future<HttpClientResponse> close() async => _MockHttpClientResponse();
}

class _MockHttpHeaders extends Fake implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class _MockHttpClientResponse extends Fake implements HttpClientResponse {
  @override
  int get statusCode => 200;
  @override
  int get contentLength => _transparentPng.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(void Function(List<int>)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return Stream<List<int>>.value(_transparentPng).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

final Uint8List _transparentPng = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);
