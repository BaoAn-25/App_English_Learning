import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:thpt_english/data/app_database.dart';
import 'package:thpt_english/data/rbac_proctor_ai_service.dart';

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

  group('Supervised Exam Anti-Cheat, Retry Prevention & Guest Access Tests', () {
    tearDown(() {
      ExamLockGuard.instance.exitSupervisedExam();
    });

    final testExam = SupervisedExamModel(
      id: 'exam_test_unit_12',
      title: 'Kỳ thi Giám sát Unit 1 Khối 12',
      description: 'Đề thi kiểm thử',
      classId: 'cls_12a1',
      className: '12A1',
      durationMinutes: 45,
      graceSeconds: 10,
      maxViolations: 2,
      maxAttempts: 1,
      violationAction: 'force_submit',
      questions: [
        {
          'id': 'q1',
          'stem': 'What is the synonym of "preserve"?',
          'options': ['conserve', 'destroy', 'ignore', 'waste'],
          'correctIndex': 0,
        },
        {
          'id': 'q2',
          'stem': 'Grammar question',
          'options': ['A', 'B', 'C', 'D'],
          'correctIndex': 1,
        },
      ],
      deadlineAt: DateTime.now().add(const Duration(days: 1)),
      createdBy: 'teacher',
      createdAt: DateTime.now(),
    );

    test('1. Bắt đầu bài thi và tạo session ban đầu', () async {
      final session = await RbacProctorAiService.instance.startSupervisedExamSession(
        exam: testExam,
        userId: 'student_anti_cheat_01',
        studentName: 'Học Sinh A',
        studentEmail: 'studentA@test.com',
      );

      expect(session.userId, 'student_anti_cheat_01');
      expect(session.examId, 'exam_test_unit_12');
      expect(session.isActive, isTrue);
      expect(session.violationCount, 0);
    });

    test('2. Rời ứng dụng và quay lại kịp thời (< graceSeconds): chỉ tính 1 vi phạm, không bị nộp bài', () async {
      final initialSession = await RbacProctorAiService.instance.startSupervisedExamSession(
        exam: testExam,
        userId: 'student_anti_cheat_02',
        studentName: 'Học Sinh B',
        studentEmail: 'studentB@test.com',
      );

      // Quay lại sau 3 giây (< 10s)
      final updated = await RbacProctorAiService.instance.recordProctorHeartbeat(
        exam: testExam,
        currentSession: initialSession,
        currentAnswers: {'q1': 0},
        eventType: 'app_backgrounded',
        outOfAppSeconds: 3,
        detail: 'Rời ứng dụng 3 giây rồi quay lại làm bài.',
      );

      expect(updated.isActive, isTrue);
      expect(updated.violationCount, 1);
      expect(updated.status, 'warning_out_of_app');
    });

    test('3. Rời ứng dụng quá graceSeconds (>= 10s): Tự động thu bài và khóa phiên thi', () async {
      final initialSession = await RbacProctorAiService.instance.startSupervisedExamSession(
        exam: testExam,
        userId: 'student_anti_cheat_03',
        studentName: 'Học Sinh C',
        studentEmail: 'studentC@test.com',
      );

      // Quá 10 giây không quay lại
      final terminated = await RbacProctorAiService.instance.recordProctorHeartbeat(
        exam: testExam,
        currentSession: initialSession,
        currentAnswers: {'q1': 0},
        eventType: 'timeout_10s_exceeded',
        outOfAppSeconds: 15,
        detail: 'Quá 10 giây không quay lại phòng thi.',
      );

      expect(terminated.isActive, isFalse);
      expect(terminated.status, 'force_submitted_auto');
      expect(terminated.violationLogs.any((log) => log['type'] == 'EXCEEDED_GRACE_TIME'), isTrue);
    });

    test('4. Chặn làm lại bài: User đã hoàn tất/bị thu bài thì startSupervisedExamSession không tạo bài mới', () async {
      // User 03 đã bị thu bài ở test trên
      final retriedSession = await RbacProctorAiService.instance.startSupervisedExamSession(
        exam: testExam,
        userId: 'student_anti_cheat_03',
        studentName: 'Học Sinh C',
        studentEmail: 'studentC@test.com',
      );

      // Phải trả về đúng session cũ đã kết thúc, không được active
      expect(retriedSession.isActive, isFalse);
      expect(retriedSession.status, 'force_submitted_auto');
    });
  });
}
