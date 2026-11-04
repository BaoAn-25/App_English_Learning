import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:thpt_english/data/app_database.dart';
import 'package:thpt_english/data/models/user_profile.dart';
import 'package:thpt_english/data/rbac_proctor_ai_service.dart';
import 'package:thpt_english/data/translation_service.dart';
import 'package:thpt_english/ui/admin/admin_portal_screen.dart';
import 'package:thpt_english/ui/teacher/teacher_portal_screen.dart';
import 'package:thpt_english/ui/translation/translation_hub_screen.dart';

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

  group('RBAC, Proctoring 10s, Translation Hub & Multi-Role AI Copilot Tests', () {
    tearDown(() {
      ExamLockGuard.instance.exitSupervisedExam();
    });

    test('UserProfile preserves role (student/teacher/admin) and lock state in toMap/fromMap', () {
      const adminProfile = UserProfile(
        id: 'usr_admin_1',
        displayName: 'Quản trị viên',
        email: 'admin@engpass.vn',
        isLoggedIn: true,
        authProvider: 'email',
        role: 'admin',
        emailVerified: true,
        isLocked: false,
      );

      final map = adminProfile.toMap();
      final restored = UserProfile.fromMap(map);

      expect(restored.role, 'admin');
      expect(restored.isAdmin, isTrue);
      expect(restored.isTeacher, isFalse);
      expect(restored.emailVerified, isTrue);

      final lockedTeacher = adminProfile.copyWith(
        role: 'teacher',
        isLocked: true,
        lockedReason: 'Tạm khóa bảo trì',
      );
      final restoredTeacher = UserProfile.fromMap(lockedTeacher.toMap());
      expect(restoredTeacher.isTeacher, isTrue);
      expect(restoredTeacher.isLocked, isTrue);
      expect(restoredTeacher.lockedReason, 'Tạm khóa bảo trì');
    });

    test('ExamLockGuard automatically blocks TranslationService and Student AI Copilot during Supervised Exam', () async {
      ExamLockGuard.instance.exitSupervisedExam();
      expect(ExamLockGuard.instance.isLocked, isFalse);

      // Khi chưa vào phòng thi -> Dịch thuật hoạt động bình thường
      final normalTrans = await TranslationService.instance.translateBidirectional(
        text: 'adopted',
        sourceLang: 'en',
        targetLang: 'vi',
      );
      expect(normalTrans.isSuccess, isTrue);

      // Khi bước vào Phòng thi có giám sát -> Tự động khóa chống gian lận
      ExamLockGuard.instance.enterSupervisedExam(
        examId: 'sexam_test_1',
        examTitle: 'Kiểm tra 45 phút Unit 1-3',
      );
      expect(ExamLockGuard.instance.isLocked, isTrue);

      final lockedTrans = await TranslationService.instance.translateBidirectional(
        text: 'adopted',
        sourceLang: 'en',
        targetLang: 'vi',
      );
      expect(lockedTrans.isSuccess, isFalse);
      expect(lockedTrans.errorMessage, contains('khóa'));

      final lockedSelection = await TranslationService.instance.translateSelection(
        text: 'adopted',
      );
      expect(lockedSelection.isSuccess, isFalse);
      expect(lockedSelection.errorMessage, contains('khóa'));

      final lockedAi = await RbacProctorAiService.instance.askRoleCopilot(
        role: 'student',
        mode: 'general',
        message: 'Giải giúp mình câu 1',
      );
      expect(lockedAi['isLocked'], isTrue);
      expect(lockedAi['answer'].toString(), contains('khóa'));

      // Sau khi nộp bài thoát phòng thi -> Mở khóa trở lại
      ExamLockGuard.instance.exitSupervisedExam();
      expect(ExamLockGuard.instance.isLocked, isFalse);
    });

    test('AI Question Generator & Curriculum Digitizer generate structured data without manual entry', () async {
      final generatedQuestions = await RbacProctorAiService.instance.generateQuestionsWithAi(
        unitNumber: 3,
        skill: 'grammar',
        difficulty: 2,
        count: 3,
        topicPrompt: 'Green Living',
      );
      expect(generatedQuestions.length, 3);
      expect(generatedQuestions.first['options'], isA<List>());
      expect((generatedQuestions.first['options'] as List).length, 4);

      final digitized = await RbacProctorAiService.instance.digitizeCurriculumWithAi(
        unitNumber: 6,
        title: 'Artificial Intelligence in Education',
        rawText:
            'Artificial intelligence platforms help students practice pronunciation and personalize learning pathways effectively.',
      );
      expect(digitized['unitNumber'], 6);
      expect(digitized['vocabulary'], isA<List>());
      expect((digitized['vocabulary'] as List).isNotEmpty, isTrue);
      expect(digitized['questions'], isA<List>());
    });

    testWidgets('TranslationHubScreen renders 3 tabs (Realtime Text, Voice, Image OCR) and locks during exam', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TranslationHubScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dịch thuật Học thuật 3-trong-1'), findsOneWidget);
      expect(find.text('Văn bản Realtime'), findsOneWidget);
      expect(find.text('Dịch Giọng nói'), findsOneWidget);
      expect(find.text('Dịch Ảnh OCR'), findsOneWidget);

      // Khi kích hoạt khóa phòng thi -> Hiển thị màn chắn Chế độ Chống Gian Lận
      ExamLockGuard.instance.enterSupervisedExam(
        examId: 'sexam_lock_ui',
        examTitle: 'Thi học kỳ 1',
      );
      await tester.pumpAndSettle();
      expect(find.text('Chế độ Chống Gian Lận Phòng Thi'), findsOneWidget);
      ExamLockGuard.instance.exitSupervisedExam();
    });

    testWidgets('TeacherPortalScreen and AdminPortalScreen render all CRUD & AI tabs cleanly', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          const MaterialApp(
            home: TeacherPortalScreen(),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 250));
      });
      await tester.pump(const Duration(seconds: 11));
      expect(find.text('Cổng Giáo Viên & Giám Sát Thi'), findsOneWidget);
      expect(find.text('1. Đề thi & Hạn nộp'), findsOneWidget);
      expect(find.text('2. Giám sát Phòng thi (Live)'), findsOneWidget);

      await tester.runAsync(() async {
        await tester.pumpWidget(
          const MaterialApp(
            home: AdminPortalScreen(),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 250));
      });
      await tester.pump(const Duration(seconds: 11));
      expect(find.text('Trung Tâm Quản Trị Admin'), findsOneWidget);
      expect(find.text('1. Người dùng & Phân quyền'), findsOneWidget);
      expect(find.text('2. Học liệu & Thay sách mới'), findsOneWidget);
      expect(find.text('4. Cấu hình API AI'), findsOneWidget);
    });
  });
}
