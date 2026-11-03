import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:thpt_english/data/app_database.dart';
import 'package:thpt_english/data/app_repository.dart';
import 'package:thpt_english/ui/settings/notification_service.dart';
import 'package:thpt_english/ui/settings/settings_controller.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import 'support/sqlite_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SqliteBridge bridge;
  late Database database;
  late AppRepository repository;

  // Trạng thái mock linh hoạt để test các tình huống lỗi và thành công
  bool mockPermissionGranted = true;
  bool mockScheduleSuccess = true;
  bool mockCancelSuccess = true;
  bool mockAreNotificationsEnabled = true;
  List<Map<String, dynamic>> mockPendingNotifications = [];

  setUpAll(() async {
    bridge = await SqliteBridge.start();
    database = await AppDatabase.instance.database;
    repository = AppRepository();
    tz.initializeTimeZones();

    // Mock MethodChannel của flutter_local_notifications
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dexterous.com/flutter/local_notifications'),
          (MethodCall methodCall) async {
            switch (methodCall.method) {
              case 'initialize':
                return true;
              case 'zonedSchedule':
                if (!mockScheduleSuccess) {
                  throw PlatformException(code: 'SCHEDULE_FAILED', message: 'Hệ thống từ chối đặt lịch');
                }
                mockPendingNotifications = [
                  {
                    'id': NotificationService.reminderNotificationId,
                    'title': 'Nhắc học',
                    'body': 'Nội dung',
                    'payload': '',
                  }
                ];
                return null;
              case 'cancel':
                if (!mockCancelSuccess) {
                  throw PlatformException(code: 'CANCEL_FAILED', message: 'Lỗi hủy lịch');
                }
                mockPendingNotifications.clear();
                return null;
              case 'requestNotificationsPermission':
                return mockPermissionGranted;
              case 'areNotificationsEnabled':
                return mockAreNotificationsEnabled;
              case 'pendingNotificationRequests':
                return mockPendingNotifications;
              default:
                return null;
            }
          },
        );

    // Mock MethodChannel của flutter_timezone
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_timezone'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'getLocalTimezone') {
              return 'Asia/Ho_Chi_Minh';
            }
            return null;
          },
        );
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dexterous.com/flutter/local_notifications'),
          null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_timezone'),
          null,
        );
    await database.close();
    await bridge.close();
  });

  setUp(() async {
    for (final table in ['app_settings']) {
      await database.delete(table);
    }
    mockPermissionGranted = true;
    mockScheduleSuccess = true;
    mockCancelSuccess = true;
    mockAreNotificationsEnabled = true;
    mockPendingNotifications.clear();
  });

  group('1. Tính toán thời điểm nhắc kế tiếp và xử lý múi giờ', () {
    test('Múi giờ thiết bị được nạp đúng Asia/Ho_Chi_Minh', () async {
      final service = NotificationService();
      await service.init();
      expect(service.currentTimeZoneName, 'Asia/Ho_Chi_Minh');
    });

    test('Thời điểm trong tương lai cùng ngày: đặt lịch đúng hôm nay', () {
      final service = NotificationService();
      final mockNow = DateTime(2026, 11, 3, 14, 0); // 14:00 hôm nay
      final target = const TimeOfDay(hour: 20, minute: 0); // 20:00

      final next = service.calculateNextReminderDateTime(target, mockNow);
      expect(next.year, 2026);
      expect(next.month, 11);
      expect(next.day, 3);
      expect(next.hour, 20);
      expect(next.minute, 0);
    });

    test('Thời điểm đã trôi qua hôm nay: tự động dời sang ngày tiếp theo', () {
      final service = NotificationService();
      final mockNow = DateTime(2026, 11, 3, 21, 30); // 21:30 hôm nay
      final target = const TimeOfDay(hour: 20, minute: 0); // 20:00 (đã qua)

      final next = service.calculateNextReminderDateTime(target, mockNow);
      expect(next.year, 2026);
      expect(next.month, 11);
      expect(next.day, 4); // Ngày hôm sau
      expect(next.hour, 20);
      expect(next.minute, 0);
    });

    test('Xử lý chính xác mốc 00:00 (Nửa đêm)', () {
      final service = NotificationService();
      final mockNow = DateTime(2026, 11, 3, 0, 5); // 00:05 sáng
      final target = const TimeOfDay(hour: 0, minute: 0); // 00:00

      final next = service.calculateNextReminderDateTime(target, mockNow);
      expect(next.day, 4); // Đã qua 00:00 hôm nay -> dời sang 00:00 ngày mai
      expect(next.hour, 0);
      expect(next.minute, 0);
    });

    test('Xử lý chính xác mốc 12:00 (Trưa) và 23:59 (Cuối ngày)', () {
      final service = NotificationService();
      final mockNowMorning = DateTime(2026, 11, 3, 8, 0);

      // 12:00 trưa
      final nextNoon = service.calculateNextReminderDateTime(const TimeOfDay(hour: 12, minute: 0), mockNowMorning);
      expect(nextNoon.day, 3);
      expect(nextNoon.hour, 12);
      expect(nextNoon.minute, 0);

      // 23:59 cuối ngày
      final nextNight = service.calculateNextReminderDateTime(const TimeOfDay(hour: 23, minute: 59), mockNowMorning);
      expect(nextNight.day, 3);
      expect(nextNight.hour, 23);
      expect(nextNight.minute, 59);
    });
  });

  group('2. Bật nhắc nhở & xử lý khi bị từ chối quyền hoặc lỗi hệ thống', () {
    test('Cấp quyền & đặt lịch thành công: lưu reminder_enabled=true', () async {
      mockPermissionGranted = true;
      mockScheduleSuccess = true;

      final controller = SettingsController(repo: repository);
      final success = await controller.toggleReminder(true);

      expect(success, isTrue);
      expect(controller.reminderEnabled, isTrue);
      expect(controller.isReminderScheduled, isTrue);
      expect(controller.reminderStatusMessage, isNull);

      final saved = await repository.getSetting('reminder_enabled');
      expect(saved, 'true');
    });

    test('Từ chối quyền: không lưu bật giả mạo, báo lỗi rõ ràng', () async {
      mockPermissionGranted = false; // Người dùng từ chối cấp quyền

      final controller = SettingsController(repo: repository);
      final success = await controller.toggleReminder(true);

      expect(success, isFalse);
      expect(controller.reminderEnabled, isFalse, reason: 'Tuyệt đối không giữ trạng thái bật khi không có quyền');
      expect(controller.hasNotificationPermission, isFalse);
      expect(controller.reminderStatusMessage, contains('Chưa được cấp quyền thông báo'));

      final saved = await repository.getSetting('reminder_enabled');
      expect(saved, 'false');
    });

    test('Lỗi đặt lịch từ hệ điều hành: không lưu bật giả mạo', () async {
      mockPermissionGranted = true;
      mockScheduleSuccess = false; // Hệ thống ném ngoại lệ khi đặt lịch

      final controller = SettingsController(repo: repository);
      final success = await controller.toggleReminder(true);

      expect(success, isFalse);
      expect(controller.reminderEnabled, isFalse);
      expect(controller.isReminderScheduled, isFalse);
      expect(controller.reminderStatusMessage, contains('Không thể đặt lịch thông báo'));

      final saved = await repository.getSetting('reminder_enabled');
      expect(saved, 'false');
    });
  });

  group('3. Đổi giờ nhắc nhở & xử lý lỗi bảo toàn giờ cũ', () {
    test('Đang bật nhắc: đổi giờ thành công cập nhật giờ mới và CSDL', () async {
      mockPermissionGranted = true;
      mockScheduleSuccess = true;

      final controller = SettingsController(repo: repository);
      await controller.toggleReminder(true);

      final success = await controller.setReminderTime(const TimeOfDay(hour: 19, minute: 30));
      expect(success, isTrue);
      expect(controller.reminderTime.hour, 19);
      expect(controller.reminderTime.minute, 30);

      final savedTime = await repository.getSetting('reminder_time');
      expect(savedTime, '19:30');
    });

    test('Đang bật nhắc: đổi giờ lỗi thì bảo toàn giờ cũ và không làm mất lịch', () async {
      mockPermissionGranted = true;
      mockScheduleSuccess = true;

      final controller = SettingsController(repo: repository);
      await controller.toggleReminder(true);
      await controller.setReminderTime(const TimeOfDay(hour: 20, minute: 0));

      // Giả lập lỗi khi đặt giờ mới
      mockScheduleSuccess = false;
      final changeResult = await controller.setReminderTime(const TimeOfDay(hour: 6, minute: 0));

      expect(changeResult, isFalse);
      // Giờ nhắc phải được bảo toàn về 20:00 cũ
      expect(controller.reminderTime.hour, 20);
      expect(controller.reminderTime.minute, 0);
      expect(controller.reminderStatusMessage, contains('Đổi giờ nhắc thất bại. Giờ nhắc cũ'));

      final savedTime = await repository.getSetting('reminder_time');
      expect(savedTime, '20:00', reason: 'Không ghi đè giờ mới khi đặt lịch thất bại');
    });

    test('Đang tắt nhắc: cho phép lưu giờ dự định mới mà không tự ý bật lịch', () async {
      mockPermissionGranted = true;
      mockScheduleSuccess = true;

      final controller = SettingsController(repo: repository);
      // Đang tắt nhắc
      expect(controller.reminderEnabled, isFalse);

      final result = await controller.setReminderTime(const TimeOfDay(hour: 7, minute: 15));
      expect(result, isTrue);
      expect(controller.reminderTime.hour, 7);
      expect(controller.reminderTime.minute, 15);
      expect(controller.reminderEnabled, isFalse, reason: 'Không được tự ý bật nhắc khi người dùng chỉ đổi giờ dự định');

      final savedTime = await repository.getSetting('reminder_time');
      expect(savedTime, '07:15');
      final savedEnabled = await repository.getSetting('reminder_enabled');
      expect(savedEnabled, isNot('true'));
    });
  });

  group('4. Tắt nhắc nhở & xử lý khi hủy thất bại', () {
    test('Tắt nhắc thành công: hủy lịch thực tế và cập nhật CSDL', () async {
      mockPermissionGranted = true;
      mockScheduleSuccess = true;
      mockCancelSuccess = true;

      final controller = SettingsController(repo: repository);
      await controller.toggleReminder(true);
      expect(controller.reminderEnabled, isTrue);

      final result = await controller.toggleReminder(false);
      expect(result, isTrue);
      expect(controller.reminderEnabled, isFalse);
      expect(controller.isReminderScheduled, isFalse);

      final saved = await repository.getSetting('reminder_enabled');
      expect(saved, 'false');
    });

    test('Hủy lịch thất bại: thông báo lỗi rõ ràng', () async {
      mockPermissionGranted = true;
      mockScheduleSuccess = true;

      final controller = SettingsController(repo: repository);
      await controller.toggleReminder(true);

      // Giả lập lỗi khi gọi hủy trên OS
      mockCancelSuccess = false;
      final result = await controller.toggleReminder(false);

      expect(result, isFalse);
      expect(controller.reminderStatusMessage, contains('Không thể hủy lịch'));
    });
  });

  group('5. Chống thao tác chồng nhau (Race condition) & đối chiếu khi mở lại app', () {
    test('Bấm bật/tắt liên tục: thao tác đang xử lý sẽ chặn lời gọi tiếp theo', () async {
      final controller = SettingsController(repo: repository);

      // Gọi đồng thời 2 lần toggleReminder
      final future1 = controller.toggleReminder(true);
      final future2 = controller.toggleReminder(false);

      final results = await Future.wait([future1, future2]);
      // Một trong hai thao tác phải thành công, thao tác chạy sau khi đang bận phải trả về false an toàn
      expect(results, contains(true));
      expect(results, contains(false));
    });

    test('Đối chiếu khi mở lại app: phát hiện quyền bị thu hồi trong cài đặt hệ thống', () async {
      // Đã bật nhắc trong app
      await repository.setSetting('reminder_enabled', 'true');
      await repository.setSetting('reminder_time', '20:00');

      // Người dùng vào Cài đặt hệ điều hành và tắt quyền thông báo
      mockAreNotificationsEnabled = false;

      final controller = SettingsController(repo: repository);
      await controller.loadSettings();

      expect(controller.reminderEnabled, isTrue); // Mong muốn của người dùng
      expect(controller.hasNotificationPermission, isFalse); // Quyền thực tế bị tắt
      expect(controller.reminderStatusMessage, contains('Quyền thông báo đang bị tắt trong Cài đặt hệ thống'));
    });

    test('Thời lượng học mỗi ngày và giờ nhắc là hai thông tin hoàn toàn độc lập', () async {
      final controller = SettingsController(repo: repository);
      await controller.setReminderTime(const TimeOfDay(hour: 20, minute: 30));

      // Đổi mục tiêu thời lượng học sang 45 phút
      await controller.setDailyGoal(45);

      expect(controller.dailyGoal, 45);
      expect(controller.reminderTime.hour, 20);
      expect(controller.reminderTime.minute, 30, reason: 'Đổi mục tiêu học không bao giờ được làm đổi giờ nhắc');
    });
  });
}
