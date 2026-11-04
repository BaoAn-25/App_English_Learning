import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:thpt_english/data/app_database.dart';
import 'package:thpt_english/data/rbac_proctor_ai_service.dart';
import 'package:thpt_english/ui/settings/notification_service.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import 'support/sqlite_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SqliteBridge bridge;
  late Database database;

  final List<Map<String, dynamic>> capturedScheduledNotifications = [];
  final List<Map<String, dynamic>> capturedInstantNotifications = [];

  setUpAll(() async {
    bridge = await SqliteBridge.start();
    database = await AppDatabase.instance.database;
    tz.initializeTimeZones();

    // Mock MethodChannel của flutter_local_notifications
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'initialize':
            return true;
          case 'areNotificationsEnabled':
            return true;
          case 'requestNotificationsPermission':
            return true;
          case 'show':
            capturedInstantNotifications.add({
              'id': methodCall.arguments['id'],
              'title': methodCall.arguments['title'],
              'body': methodCall.arguments['body'],
            });
            return true;
          case 'zonedSchedule':
            capturedScheduledNotifications.add({
              'id': methodCall.arguments['id'],
              'title': methodCall.arguments['title'],
              'body': methodCall.arguments['body'],
              'scheduledDate': methodCall.arguments['scheduledDateTime'],
            });
            return true;
          case 'cancel':
            return true;
          case 'pendingNotificationRequests':
            return <Map<String, dynamic>>[];
          default:
            return null;
        }
      },
    );
  });

  tearDownAll(() async {
    await database.close();
    await bridge.close();
  });

  group('Class Reminder & Push-to-Local Notification Tests', () {
    test('1. NotificationService: phát thông báo tức thì showInstantNotification thành công', () async {
      final success = await NotificationService().showInstantNotification(
        id: 7001,
        title: '🔔 Nhắc học tập từ Giáo viên',
        body: 'Thầy/Cô nhắc bạn nhớ hoàn thành bài tập hôm nay!',
      );

      expect(success, isTrue);
      expect(capturedInstantNotifications.any((n) => n['id'] == 7001), isTrue);
    });

    test('2. Giáo viên tạo Lịch nhắc hẹn lớp học: lưu CSDL và lên lịch thông báo', () async {
      final futureDate = DateTime.now().add(const Duration(hours: 3));
      final reminder = await RbacProctorAiService.instance.createClassReminder(
        classId: 'cls_12a1_test',
        className: 'Lớp 12A1',
        title: 'Nhắc ôn tập Unit 2',
        message: 'Cả lớp nhớ hoàn thành bài trắc nghiệm trước 22:00 tối nay nhé!',
        scheduledAt: futureDate,
        teacherName: 'Cô Lan',
      );

      expect(reminder.classId, 'cls_12a1_test');
      expect(reminder.className, 'Lớp 12A1');
      expect(reminder.title, 'Nhắc ôn tập Unit 2');
      expect(reminder.isActive, isTrue);

      // Đã được lưu vào danh sách
      final reminders = await RbacProctorAiService.instance.getClassReminders(classId: 'cls_12a1_test');
      expect(reminders.any((r) => r.id == reminder.id), isTrue);

      // Đã được lên lịch trong flutter_local_notifications
      expect(capturedScheduledNotifications.any((n) => n['id'] == reminder.notificationId), isTrue);
    });

    test('3. Học viên tự động đồng bộ lịch nhắc hẹn của lớp học vào điện thoại', () async {
      final scheduledCount = await RbacProctorAiService.instance.syncStudentClassReminders('student_uid_test');
      expect(scheduledCount, greaterThanOrEqualTo(1));
    });

    test('4. Hủy lịch nhắc hẹn thành công', () async {
      final reminders = await RbacProctorAiService.instance.getClassReminders(classId: 'cls_12a1_test');
      final first = reminders.first;

      await RbacProctorAiService.instance.deleteClassReminder(first.id);

      final updated = await RbacProctorAiService.instance.getClassReminders(classId: 'cls_12a1_test');
      expect(updated.any((r) => r.id == first.id), isFalse);
    });
  });
}

