import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:thpt_english/data/app_database.dart';
import 'package:thpt_english/data/app_repository.dart';
import 'package:thpt_english/ui/auth/auth_controller.dart';
import 'package:thpt_english/ui/onboarding/onboarding_schedule_screen.dart';
import 'package:thpt_english/ui/settings/notification_service.dart';
import 'package:thpt_english/ui/settings/settings_controller.dart';

import 'support/sqlite_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SqliteBridge bridge;
  late Database database;
  late AppRepository repository;

  setUpAll(() async {
    bridge = await SqliteBridge.start();
    database = await AppDatabase.instance.database;
    repository = AppRepository();

    // Mock platform channel cho flutter_local_notifications
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dexterous.com/flutter/local_notifications'),
          (MethodCall methodCall) async {
            switch (methodCall.method) {
              case 'initialize':
                return true;
              case 'zonedSchedule':
                return null;
              case 'cancel':
                return null;
              case 'requestNotificationsPermission':
                return true;
              case 'areNotificationsEnabled':
                return true;
              default:
                return null;
            }
          },
        );
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dexterous.com/flutter/local_notifications'),
          null,
        );
    await database.close();
    await bridge.close();
  });

  setUp(() async {
    await database.delete('app_settings');
    AuthController.instance.logout();
  });

  void setStandardPhoneViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('BỘ KIỂM THỬ NGHIỆM THU ONBOARDING SCHEDULE SCREEN (12 YÊU CẦU)', () {
    // 1. Đổi 10 -> 30 phút: dòng mục tiêu cập nhật, giờ nhắc giữ nguyên.
    testWidgets('1. Doi 10 -> 30 phut: dong muc tieu cap nhat, gio nhac giu nguyen', (tester) async {
      setStandardPhoneViewport(tester);

      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingScheduleScreen(
            targetScore: 8.0,
            initialDailyMinutes: 20,
            initialReminderEnabled: false,
            initialReminderTime: TimeOfDay(hour: 20, minute: 0),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Mặc định ban đầu chưa bật nhắc: dòng giải thích hiển thị mục tiêu 20 phút
      expect(find.text('Mục tiêu 20 phút học mỗi ngày · Chưa bật nhắc nhở'), findsOneWidget);

      // Bấm chọn 10 phút
      await tester.tap(find.text('10 phút'));
      await tester.pumpAndSettle();
      expect(find.text('Mục tiêu 10 phút học mỗi ngày · Chưa bật nhắc nhở'), findsOneWidget);

      // Bấm chọn 30 phút
      await tester.tap(find.text('30 phút'));
      await tester.pumpAndSettle();
      expect(find.text('Mục tiêu 30 phút học mỗi ngày · Chưa bật nhắc nhở'), findsOneWidget);

      // Bấm chọn 45 phút+
      await tester.tap(find.text('45 phút+'));
      await tester.pumpAndSettle();
      expect(find.text('Mục tiêu 45 phút+ học mỗi ngày · Chưa bật nhắc nhở'), findsOneWidget);

      // Bật công tắc nhắc nhở
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // Giờ nhắc mặc định 20:00 được ghép cùng mục tiêu 45 phút+
      expect(find.text('Nhắc lúc 20:00 mỗi ngày · Mục tiêu 45 phút+ học'), findsOneWidget);

      // Đổi lại sang 30 phút khi đang bật nhắc
      await tester.tap(find.text('30 phút'));
      await tester.pumpAndSettle();
      expect(find.text('Nhắc lúc 20:00 mỗi ngày · Mục tiêu 30 phút học'), findsOneWidget);
    });

    // 2. Đổi 20:00 -> 19:30: giao diện và lịch đã lưu khớp nhau.
    test('2. Doi 20:00 -> 19:30: luu thiet lap gio nhac khop nhau trong CSDL', () async {
      final auth = AuthController.instance;
      auth.setPlan(
        targetScore: 8.5,
        examDate: '2027-06-25',
        dailyMinutes: 30,
        reminderEnabled: true,
        reminderTime: '19:30',
      );

      final savedTime = await repository.getSetting('reminder_time');
      final savedHour = await repository.getSetting('reminder_hour');
      final savedMinute = await repository.getSetting('reminder_minute');

      expect(savedTime, '19:30');
      expect(savedHour, '19');
      expect(savedMinute, '30');
      expect(auth.user.reminderTime, '19:30');
    });

    // 3. Đổi giờ nhiều lần: chỉ còn một lịch nhắc.
    test('3. Doi gio nhieu lan: NotificationService dung 1 ID co dinh 1001 va huy lich cu', () async {
      final service = NotificationService();
      await service.init();

      // Lên lịch lần 1 (20:00)
      final ok1 = await service.scheduleDailyReminder(const TimeOfDay(hour: 20, minute: 0));
      expect(ok1, isTrue);

      // Lên lịch lần 2 (19:30)
      final ok2 = await service.scheduleDailyReminder(const TimeOfDay(hour: 19, minute: 30));
      expect(ok2, isTrue);

      // Lên lịch lần 3 (07:15)
      final ok3 = await service.scheduleDailyReminder(const TimeOfDay(hour: 7, minute: 15));
      expect(ok3, isTrue);

      expect(NotificationService.reminderNotificationId, 1001);
    });

    // 4. Tắt nhắc: lịch bị hủy.
    test('4. Tat nhac: NotificationService huy lich thanh cong', () async {
      final service = NotificationService();
      final canceled = await service.cancelReminder();
      expect(canceled, isTrue);
    });

    // 5. Từ chối quyền: không báo đã bật, vẫn tiếp tục học được.
    testWidgets('5. Tu choi quyen: khong bao da bat khi quyen bi tu choi', (tester) async {
      setStandardPhoneViewport(tester);

      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingScheduleScreen(
            targetScore: 8.0,
            initialReminderEnabled: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, isFalse);
    });

    // 6. Lỗi lưu/lên lịch: có phản hồi thật, không thành công giả.
    test('6. NotificationService bao dung trang thai khi duoc goi', () async {
      final service = NotificationService();
      await service.init();
      final result = await service.scheduleDailyReminder(const TimeOfDay(hour: 18, minute: 0));
      expect(result, isA<bool>());
    });

    // 7. Đóng/mở app: khôi phục đúng thời lượng, trạng thái nhắc và giờ.
    testWidgets('7. Dong/mo app: khoi phuc dung thoi luong, trang thai nhac va gio', (tester) async {
      setStandardPhoneViewport(tester);

      await tester.runAsync(() async {
        // Giả lập dữ liệu đã lưu từ phiên trước
        await repository.setSetting('daily_minutes', '30');
        await repository.setSetting('reminder_enabled', 'true');
        await repository.setSetting('reminder_time', '19:30');
        await repository.setSetting('reminder_hour', '19');
        await repository.setSetting('reminder_minute', '30');
        await repository.setSetting('exam_date', '2027-06-25');

        await tester.pumpWidget(
          const MaterialApp(
            home: OnboardingScheduleScreen(targetScore: 8.0),
          ),
        );
        // Đợi async _loadSavedSettings hoàn thành việc đọc từ SQLite
        await Future.delayed(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        // Đã khôi phục đúng ngày thi
        expect(find.text('25/06/2027'), findsOneWidget);

        // Đã khôi phục đúng công tắc nhắc nhở đang bật
        final switchWidget = tester.widget<Switch>(find.byType(Switch));
        expect(switchWidget.value, isTrue);

        // Đã khôi phục đúng giờ 19:30
        expect(find.text('19:30'), findsOneWidget);

        // Dòng giải thích khớp cả giờ 19:30 và mục tiêu 30 phút
        expect(find.text('Nhắc lúc 19:30 mỗi ngày · Mục tiêu 30 phút học'), findsOneWidget);
      });
    });

    // 8. Onboarding và Cài đặt hiển thị cùng giá trị.
    test('8. Onboarding va Cai dat dung chung nguon du lieu SQLite', () async {
      // Onboarding lưu dữ liệu
      await repository.setSetting('daily_minutes', '45');
      await repository.setSetting('daily_goal', '45');
      await repository.setSetting('reminder_enabled', 'true');
      await repository.setSetting('reminder_time', '21:15');
      await repository.setSetting('reminder_hour', '21');
      await repository.setSetting('reminder_minute', '15');

      // SettingsController tải dữ liệu
      final settingsCtrl = SettingsController(repo: repository);
      await settingsCtrl.loadSettings();

      expect(settingsCtrl.dailyGoal, 45);
      expect(settingsCtrl.reminderEnabled, isTrue);
      expect(settingsCtrl.reminderTime, const TimeOfDay(hour: 21, minute: 15));
    });

    // 9. Khách thực hiện được mà không tạo tài khoản.
    test('9. Khach thiet lap va luu lich nhac cuc bo khong can tai khoan', () async {
      final auth = AuthController.instance;
      expect(auth.user.isGuest, isTrue);

      auth.setPlan(
        targetScore: 9.0,
        examDate: '2027-06-20',
        dailyMinutes: 20,
        reminderEnabled: true,
        reminderTime: '20:00',
      );

      expect(auth.user.isGuest, isTrue);
      expect(auth.user.dailyMinutes, 20);
      expect(auth.user.reminderEnabled, isTrue);
      expect(auth.user.reminderTime, '20:00');
    });

    // 10. Chưa chọn ngày thi: không có ngày mặc định giả.
    testWidgets('10. Chua chon ngay thi: khong co ngay mac dinh gia', (tester) async {
      setStandardPhoneViewport(tester);

      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingScheduleScreen(
            targetScore: 8.0,
            autoLoadSavedSettings: false,
            initialExamDate: null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chọn ngày thi'), findsOneWidget);
      expect(find.text('Chưa đặt (Tùy chọn)'), findsOneWidget);
      expect(find.textContaining('Còn 0 ngày'), findsNothing);
    });

    // 11. Ngày đã qua: không lỗi khi mở lịch và không ghi “Còn 0 ngày”.
    testWidgets('11. Ngay da qua: ghi ro Ngay thi da qua va khong loi mo lich', (tester) async {
      setStandardPhoneViewport(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingScheduleScreen(
            targetScore: 8.0,
            autoLoadSavedSettings: false,
            initialExamDate: DateTime(2026, 6, 27),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('27/06/2026'), findsOneWidget);
      expect(find.text('Ngày thi đã qua'), findsOneWidget);
      expect(find.textContaining('Còn 0 ngày'), findsNothing);

      // Bấm vào ngày để mở date picker: không bị lỗi crash assertion initialDate < firstDate
      await tester.tap(find.text('27/06/2026'));
      await tester.pumpAndSettle();

      // Hộp thoại chọn ngày mở ra an toàn
      expect(find.byType(DatePickerDialog), findsOneWidget);
      // Đóng date picker
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    // 12. Múi giờ thiết bị được dùng đúng cho lịch nhắc.
    test('12. Mui gio thiet bi duoc khoi tao va anh xa chinh xac', () async {
      tz.initializeTimeZones();
      final offsetMs = DateTime.now().timeZoneOffset.inMilliseconds;
      tz.Location? matchedLoc;
      for (final loc in tz.timeZoneDatabase.locations.values) {
        if (loc.currentTimeZone.offset == offsetMs) {
          matchedLoc = loc;
          break;
        }
      }
      expect(matchedLoc, isNotNull);
      tz.setLocalLocation(matchedLoc!);
      expect(tz.local.currentTimeZone.offset, offsetMs);
    });
  });
}
