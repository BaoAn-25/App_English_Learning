import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'package:thpt_english/data/app_database.dart';
import 'package:thpt_english/data/app_repository.dart';
import 'package:thpt_english/data/models/user_profile.dart';
import 'package:thpt_english/data/rbac_proctor_ai_service.dart';
import 'package:thpt_english/navigation/role_routing_shell.dart';
import 'package:thpt_english/ui/admin/admin_main_shell.dart';
import 'package:thpt_english/ui/admin/components/student_preview_mode.dart';
import 'package:thpt_english/ui/auth/auth_controller.dart';
import 'package:thpt_english/ui/teacher/teacher_main_shell.dart';
import 'support/sqlite_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SqliteBridge bridge;
  late Database database;
  late AppRepository repository;
  final service = RbacProctorAiService.instance;

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
    SharedPreferences.setMockInitialValues({
      'has_completed_first_lesson': true,
    });
    // Xóa sạch các setting test
    await database.delete('app_settings');
    StudentPreviewMode.instance.exitPreview();
  });

  test('1. Real Data Verification: No mock data is auto-seeded when database is empty', () async {
    final materials = await service.getStudyMaterials();
    final exams = await service.getSupervisedExams();
    final classes = await service.getClasses();
    final bugReports = await service.getBugReports();
    final teacherReqs = await service.getTeacherRequests();

    expect(materials, isEmpty);
    expect(exams, isEmpty);
    expect(classes, isEmpty);
    expect(bugReports, isEmpty);
    expect(teacherReqs, isEmpty);
  });

  test('2. Full Teacher - Student Real Data Flow: Class Join Code, Assignment, 10s Exam Explanation & Bug Report', () async {
    // 1. Giáo viên tạo lớp 12A1 có bật duyệt học sinh
    final createdClass = await service.createClass(
      name: '12A1',
      schoolName: 'THPT Nguyễn Trãi',
      schoolYear: '2026-2027',
      joinCode: '12A1-8899',
      requireApproval: true,
      teacherName: 'Cô Thu Hà',
      teacherEmail: 'thuha@school.edu.vn',
    );
    expect(createdClass['code'], '12A1-8899');

    // 2. Học sinh nhập mã lớp 12A1-8899 để xin vào lớp
    await repository.saveAuthUser(
      const UserProfile(
        id: 'stu_01',
        email: 'minhan@student.edu.vn',
        displayName: 'Nguyễn Minh An',
        role: 'student',
      ),
    );
    final joinRes = await service.joinClassByCode('12A1-8899');
    expect(joinRes['ok'], isTrue);
    expect(joinRes['status'], 'pending');

    // 3. Giáo viên kiểm tra danh sách chờ duyệt và bấm Duyệt
    final classId = createdClass['id'].toString();
    var members = await service.getClassMembers(classId, syncRemote: false);
    expect(members.length, 1);
    expect(members.first['status'], 'pending');

    await service.decideClassMember(
      classId: classId,
      memberId: members.first['id'].toString(),
      status: 'approved',
    );
    members = await service.getClassMembers(classId, syncRemote: false);
    expect(members.first['status'], 'approved');

    // 4. Giáo viên đổi mã lớp mới lưu thật vào DB
    final newCode = await service.regenerateClassCode(classId);
    expect(newCode, isNot('12A1-8899'));
    final updatedClasses = await service.getClasses();
    expect(updatedClasses.first['code'], newCode);

    // 5. Giáo viên giao bài tập Unit 5 cho lớp 12A1 và học sinh nộp bài
    final assign = await service.createAssignment(
      title: 'Unit 5 - Reading & Vocabulary',
      classId: classId,
      className: '12A1',
      unitNumber: 5,
      dueAt: DateTime.now().add(const Duration(days: 3)),
    );
    await service.submitAssignment(
      assignmentId: assign['id'].toString(),
      classId: classId,
      score: 8.5,
    );
    final subs = await service.getSubmissionsForClass(classId: classId);
    expect(subs.length, 1);
    expect(subs.first['score'], 8.5);

    // 6. Giáo viên tạo đề thi giám sát 10s, học sinh rời app quá 10s bị tự nộp, gửi giải trình và giáo viên bấm Cho làm lại
    final exam = await service.saveSupervisedExam(
      title: 'Thi giữa kỳ - Unit 1–3',
      description: 'Giám sát 10s',
      classId: classId,
      className: '12A1',
      durationMinutes: 45,
      deadlineAt: DateTime.now().add(const Duration(days: 2)),
      graceSeconds: 10,
      maxViolations: 2,
      violationAction: 'force_submit',
    );
    final session = await service.startSupervisedExamSession(
      exam: exam,
      userId: 'stu_01',
      studentName: 'Nguyễn Minh An',
      studentEmail: 'minhan@student.edu.vn',
    );
    final autoSubmitted = await service.recordProctorHeartbeat(
      exam: exam,
      currentSession: session,
      currentAnswers: {'0': 0},
      eventType: 'timeout_10s_exceeded',
      outOfAppSeconds: 14,
    );
    expect(autoSubmitted.status, 'force_submitted_auto');

    // Học sinh gửi giải trình
    final explained = await service.submitExamExplanation(
      examId: exam.id,
      sessionId: session.id,
      explanation: 'Điện thoại em bị mất kết nối Wi-Fi đột ngột 15 giây.',
    );
    expect(explained?.studentExplanation, contains('mất kết nối Wi-Fi'));

    // Giáo viên bấm Cho làm lại (reset_violation)
    final reopened = await service.performTeacherProctorAction(
      exam: exam,
      session: explained!,
      action: 'reset_violation',
    );
    expect(reopened.status, 'in_progress');
    expect(reopened.violationCount, 0);

    // 7. Học sinh gửi báo lỗi câu hỏi -> Hiển thị trong danh sách Báo lỗi của Giáo viên/Admin
    await service.submitBugReport(
      targetCode: 'Unit 3 • Câu 4',
      unitNumber: 3,
      skill: 'grammar',
      issueType: 'Sai đáp án',
      reason: 'Đáp án A và B đều hợp ngữ pháp.',
    );
    final reports = await service.getBugReports();
    expect(reports.length, 1);
    expect(reports.first['targetCode'], 'Unit 3 • Câu 4');
    await service.updateBugReportStatus(
      reportId: reports.first['id'].toString(),
      status: 'fixed',
    );
    final updatedReports = await service.getBugReports();
    expect(updatedReports.first['status'], 'fixed');
  });

  testWidgets('3. TeacherMainShell renders 4 dedicated tabs and RoleRoutingShell isolates Teacher vs Admin vs Student', (tester) async {
    // Đăng nhập tài khoản Giáo viên -> Vào thẳng TeacherMainShell (4 Tab: Tổng quan, Lớp, Giao bài, Báo cáo)
    const teacherUser = UserProfile(
      id: 'usr_teacher_01',
      email: 'thuha@nguyentrai.edu.vn',
      displayName: 'Cô Thu Hà',
      role: 'teacher',
      isLoggedIn: true,
    );
    AuthController.instance.setUserForTesting(teacherUser);
    await repository.saveAuthUser(teacherUser);

    await tester.runAsync(() async {
      await tester.pumpWidget(
        Provider<AppRepository>.value(
          value: repository,
          child: const MaterialApp(
            home: RoleRoutingShell(),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump(const Duration(seconds: 11));

    expect(find.byType(RoleRoutingShell), findsOneWidget);
    expect(find.byType(TeacherMainShell), findsOneWidget);
    expect(find.byType(AdminMainShell), findsNothing);
    expect(find.widgetWithText(NavigationDestination, 'Tổng quan'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Lớp'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Giao bài'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Báo cáo'), findsOneWidget);
    expect(find.text('Xem HS'), findsOneWidget);

    // Kiểm tra bấm nút Xem HS kích hoạt StudentPreviewMode
    await tester.tap(find.text('Xem HS'));
    await tester.pump();
    expect(StudentPreviewMode.instance.isPreviewActive, isTrue);

    // Dọn dẹp widget và thoát preview
    StudentPreviewMode.instance.exitPreview();
    await tester.runAsync(() async {
      await tester.pumpWidget(const SizedBox());
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
  });
}
