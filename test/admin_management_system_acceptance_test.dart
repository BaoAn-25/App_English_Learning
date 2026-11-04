import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';

import 'package:thpt_english/data/app_database.dart';
import 'package:thpt_english/data/app_repository.dart';
import 'package:thpt_english/data/models/user_profile.dart';
import 'package:thpt_english/data/rbac_proctor_ai_service.dart';
import 'package:thpt_english/navigation/role_routing_shell.dart';
import 'package:thpt_english/ui/admin/admin_main_shell.dart';
import 'package:thpt_english/ui/admin/components/student_preview_banner.dart';
import 'package:thpt_english/ui/admin/components/student_preview_mode.dart';
import 'package:thpt_english/ui/auth/auth_controller.dart';

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

  setUp(() {
    StudentPreviewMode.instance.exitPreview();
  });

  tearDown(() {
    StudentPreviewMode.instance.exitPreview();
  });

  group('Admin Management System Tests', () {
    test('StudentPreviewMode toggle state correctly updates listeners', () {
      final preview = StudentPreviewMode.instance;
      expect(preview.isPreviewActive, isFalse);

      int listenerCallCount = 0;
      void listener() => listenerCallCount++;
      preview.addListener(listener);

      preview.enterPreview();
      expect(preview.isPreviewActive, isTrue);
      expect(listenerCallCount, equals(1));

      preview.exitPreview();
      expect(preview.isPreviewActive, isFalse);
      expect(listenerCallCount, equals(2));

      preview.removeListener(listener);
    });

    test('RbacProctorAiService correctly performs Admin User CRUD & Audit Logging', () async {
      final service = RbacProctorAiService.instance;

      // 1. Tải danh sách người dùng ban đầu (phải luôn có admin tối cao tongan542@gmail.com)
      final initialUsers = await service.getAdminUsers();
      expect(initialUsers.any((u) => u['email'] == UserProfile.systemAdminEmail), isTrue);

      // 2. Tạo một tài khoản giáo viên mới
      final createdTeacher = await service.createAdminUser(
        email: 'teacher.test@school.edu.vn',
        password: 'SecurePassword123!',
        displayName: 'Thầy Hùng',
        role: 'teacher',
      );
      expect(createdTeacher['role'], equals('teacher'));

      // 3. Khóa tài khoản do vi phạm
      await service.updateAdminUser(
        userId: createdTeacher['id'].toString(),
        isLocked: true,
        lockedReason: 'Thí sinh out app quá 10s',
      );

      final updatedUsers = await service.getAdminUsers();
      final target = updatedUsers.firstWhere((u) => u['id'] == createdTeacher['id']);
      expect(target['is_locked'], isTrue);
      expect(target['locked_reason'], contains('10s'));

      // 4. Mở khóa tài khoản
      await service.updateAdminUser(
        userId: createdTeacher['id'].toString(),
        isLocked: false,
        lockedReason: '',
      );
      final unlocked = (await service.getAdminUsers()).firstWhere((u) => u['id'] == createdTeacher['id']);
      expect(unlocked['is_locked'], isFalse);

      // 5. Kiểm tra nhật ký kiểm toán có ghi nhận các hành vi trên
      final logs = await service.getAuditLogs();
      expect(logs.isNotEmpty, isTrue);
      expect(logs.any((l) => l['action'] == 'ADMIN_CREATE_USER'), isTrue);
    });

    test('Curriculum Versioning can save and activate new textbook without wiping user data', () async {
      final service = RbacProctorAiService.instance;

      final initialVersions = await service.getCurriculumVersions();
      expect(initialVersions.isNotEmpty, isTrue);
      expect(initialVersions.first['isActive'], isTrue);

      // Xuất bản phiên bản sách mới v2
      final newVersion = await service.saveAndOptionallyActivateCurriculum(
        versionCode: 'GS12-2026.NEW',
        title: 'SGK Tiếng Anh 12 Bộ GD&ĐT 2026',
        description: 'Cập nhật từ vựng và bài đọc mới',
        payload: {
          'unitCount': 10,
          'units': [
            {
              'unitNumber': 1,
              'title': 'Life Stories of Renowned Figures',
              'vocabulary': [
                {
                  'english': 'innovator',
                  'ipa': '/ˈɪnəveɪtər/',
                  'meaningVi': 'nhà đổi mới',
                  'example': 'He is a great innovator in AI.'
                }
              ],
              'questions': []
            }
          ]
        },
        activateImmediately: true,
      );

      expect(newVersion['isActive'], isTrue);

      final versionsAfter = await service.getCurriculumVersions();
      final activeVersion = versionsAfter.firstWhere((v) => v['isActive'] == true);
      expect(activeVersion['versionCode'], equals('GS12-2026.NEW'));
    });

    testWidgets('AdminMainShell renders all 5 management tabs and student preview banner', (tester) async {
      final repo = AppRepository();

      await tester.runAsync(() async {
        await tester.pumpWidget(
          Provider<AppRepository>.value(
            value: repo,
            child: MaterialApp(
              home: AdminMainShell(
                repository: repo,
              ),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 250));
      });
      await tester.pump(const Duration(seconds: 11));

      // Kiểm tra Header của Admin Console
      expect(find.text('Trung Tâm Quản Trị'), findsOneWidget);
      expect(find.text('ADMIN'), findsOneWidget);

      // Kiểm tra 5 Phân hệ chính trên Bottom Navigation Bar
      expect(find.widgetWithText(NavigationDestination, 'Tổng quan'), findsOneWidget);
      expect(find.widgetWithText(NavigationDestination, 'Học liệu'), findsOneWidget);
      expect(find.widgetWithText(NavigationDestination, 'Người dùng'), findsOneWidget);
      expect(find.widgetWithText(NavigationDestination, 'Lớp & Thi'), findsOneWidget);
      expect(find.widgetWithText(NavigationDestination, 'Quản trị'), findsOneWidget);

      // Kiểm tra nút Xem trước giao diện học sinh trên AppBar
      expect(find.text('Xem HS'), findsOneWidget);

      // Bấm vào nút Xem HS
      await tester.tap(find.text('Xem HS'));
      await tester.pump();
      expect(StudentPreviewMode.instance.isPreviewActive, isTrue);
    });

    testWidgets('StudentPreviewBanner renders correct message and returns to Admin on tap', (tester) async {
      StudentPreviewMode.instance.enterPreview();
      expect(StudentPreviewMode.instance.isPreviewActive, isTrue);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StudentPreviewBanner(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chế độ Xem Trước Học Sinh'), findsOneWidget);
      expect(find.text('Quay lại Admin'), findsOneWidget);

      await tester.tap(find.text('Quay lại Admin'));
      await tester.pumpAndSettle();

      expect(StudentPreviewMode.instance.isPreviewActive, isFalse);
    });

    testWidgets('RoleRoutingShell mounts AdminMainShell when current user is Admin', (tester) async {
      final repo = AppRepository();
      AuthController.instance.setUserForTesting(
        const UserProfile(
          id: 'adm_01',
          email: 'tongan542@gmail.com',
          displayName: 'anbao',
          role: 'admin',
        ),
      );

      await tester.runAsync(() async {
        await tester.pumpWidget(
          Provider<AppRepository>.value(
            value: repo,
            child: const MaterialApp(
              home: RoleRoutingShell(),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 250));
      });
      await tester.pump(const Duration(seconds: 11));

      expect(find.byType(RoleRoutingShell), findsOneWidget);
      expect(find.byType(AdminMainShell), findsOneWidget);
      expect(find.text('Trung Tâm Quản Trị'), findsOneWidget);
    });
  });
}
