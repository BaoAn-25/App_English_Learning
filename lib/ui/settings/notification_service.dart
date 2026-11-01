import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../strings.dart';

/// Dịch vụ thông báo cục bộ (offline) nhắc học tiếng Anh hàng ngày.
/// Sử dụng chế độ inexact để hoạt động ổn định trên Android mà không cần xin quyền exact alarm đặc biệt.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  static const int reminderNotificationId = 1001;
  static const String channelId = 'daily_study_reminder';
  static const String channelName = 'Nhắc học hàng ngày';
  static const String channelDescription = 'Thông báo nhắc nhở duy trì streak và hoàn thành mục tiêu học tập';

  Future<void> init() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();
    _configureLocalTimeZone();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    try {
      await _notificationsPlugin.initialize(initSettings);
      _isInitialized = true;
    } catch (_) {
      // Bỏ qua lỗi khởi tạo trong môi trường test/desktop
    }
  }

  /// Cấu hình múi giờ thực tế của thiết bị cho thư viện timezone
  void _configureLocalTimeZone() {
    try {
      final timeZoneName = DateTime.now().timeZoneName;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      return;
    } catch (_) {}

    try {
      final offsetMs = DateTime.now().timeZoneOffset.inMilliseconds;
      for (final loc in tz.timeZoneDatabase.locations.values) {
        if (loc.currentTimeZone.offset == offsetMs) {
          tz.setLocalLocation(loc);
          return;
        }
      }
    } catch (_) {}
  }

  /// Xin quyền thông báo theo nền tảng khi người dùng chủ động bật tính năng
  Future<bool> requestPermission() async {
    await init();
    try {
      final androidImpl = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        final granted = await androidImpl.requestNotificationsPermission();
        if (granted != null) return granted;
        final areEnabled = await androidImpl.areNotificationsEnabled();
        return areEnabled ?? false;
      }

      final iosImpl = _notificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (iosImpl != null) {
        final granted = await iosImpl.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
    } catch (_) {
      return false;
    }
    return false;
  }

  /// Lên lịch thông báo lặp lại hằng ngày theo giờ đã chọn bằng zonedSchedule (chế độ inexact).
  /// Đổi giờ sẽ thay thế lịch cũ bằng một lịch duy nhất.
  Future<bool> scheduleDailyReminder(TimeOfDay time) async {
    await init();

    try {
      // Hủy lịch cũ trước để đảm bảo chỉ có 1 lịch duy nhất tồn tại
      await cancelReminder();

      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      );

      // Nếu giờ đã qua trong hôm nay thì dời sang ngày tiếp theo
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      const androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      );

      const darwinDetails = DarwinNotificationDetails();

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      await _notificationsPlugin.zonedSchedule(
        reminderNotificationId,
        AppStrings.reminderNotificationTitle,
        AppStrings.reminderNotificationBody,
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexact,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      return true;
    } catch (e) {
      debugPrint('Error scheduling reminder: $e');
      return false;
    }
  }

  /// Hủy lịch nhắc học khi người dùng tắt tính năng
  Future<bool> cancelReminder() async {
    try {
      await _notificationsPlugin.cancel(reminderNotificationId);
      return true;
    } catch (_) {
      return false;
    }
  }
}
