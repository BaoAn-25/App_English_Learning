import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../strings.dart';

/// Kết quả chi tiết của các thao tác thiết lập nhắc nhở
enum ReminderStatus {
  success,
  permissionDenied,
  scheduleFailed,
  cancelFailed,
  busy,
}

class ReminderResult {
  final ReminderStatus status;
  final String message;
  final bool isSuccess;

  const ReminderResult({
    required this.status,
    required this.message,
    required this.isSuccess,
  });

  factory ReminderResult.success([String message = 'Đã đặt lịch nhắc học thành công.']) {
    return ReminderResult(status: ReminderStatus.success, message: message, isSuccess: true);
  }

  factory ReminderResult.permissionDenied([String message = 'Chưa được cấp quyền thông báo. Vui lòng bật quyền trong Cài đặt hệ thống.']) {
    return ReminderResult(status: ReminderStatus.permissionDenied, message: message, isSuccess: false);
  }

  factory ReminderResult.scheduleFailed([String message = 'Không thể đặt lịch thông báo trên hệ thống. Vui lòng thử lại.']) {
    return ReminderResult(status: ReminderStatus.scheduleFailed, message: message, isSuccess: false);
  }

  factory ReminderResult.cancelFailed([String message = 'Không thể hủy lịch thông báo trên hệ thống.']) {
    return ReminderResult(status: ReminderStatus.cancelFailed, message: message, isSuccess: false);
  }

  factory ReminderResult.busy([String message = 'Hệ thống đang xử lý yêu cầu trước, vui lòng thử lại sau giây lát.']) {
    return ReminderResult(status: ReminderStatus.busy, message: message, isSuccess: false);
  }
}

/// Dịch vụ thông báo cục bộ (offline) nhắc học tiếng Anh hàng ngày.
///
/// Sử dụng chế độ inexact (`AndroidScheduleMode.inexact`) để hoạt động ổn định
/// trên mọi phiên bản Android (từ Android 8 đến Android 14+) mà không cần xin
/// quyền đặc biệt nguy hiểm (`USE_EXACT_ALARM` hay `SCHEDULE_EXACT_ALARM`).
/// Thông báo có thể xê dịch vài phút do cơ chế tối ưu hóa pin (Doze Mode) của hệ điều hành.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  String _currentTimeZoneName = 'UTC';

  // Khóa chống thao tác chồng nhau (Race conditions)
  bool _isOperating = false;

  static const int reminderNotificationId = 1001;
  static const String channelId = 'daily_study_reminder';
  static const String channelName = 'Nhắc học hàng ngày';
  static const String channelDescription =
      'Thông báo nhắc nhở duy trì streak và hoàn thành mục tiêu học tập tiếng Anh 12';

  String get currentTimeZoneName => _currentTimeZoneName;
  bool get isInitialized => _isInitialized;

  /// Khởi tạo dịch vụ thông báo và cấu hình múi giờ IANA chuẩn
  Future<void> init() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();
    await _configureLocalTimeZone();

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
    } catch (e) {
      debugPrint('NotificationService init warning: $e');
    }
  }

  /// Cấu hình múi giờ thực tế của thiết bị bằng định danh IANA (flutter_timezone)
  Future<void> _configureLocalTimeZone() async {
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      final String timeZoneName = timezoneInfo.identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      _currentTimeZoneName = timeZoneName;
      return;
    } catch (_) {}

    // Fallback 1: Dùng tên múi giờ của DateTime nếu có trong cơ sở dữ liệu
    try {
      final timeZoneName = DateTime.now().timeZoneName;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      _currentTimeZoneName = timeZoneName;
      return;
    } catch (_) {}

    // Fallback 2: Đối chiếu múi giờ theo offset UTC
    try {
      final offsetMs = DateTime.now().timeZoneOffset.inMilliseconds;
      // Ưu tiên Asia/Ho_Chi_Minh cho người dùng Việt Nam (UTC+7)
      if (offsetMs == 7 * 3600 * 1000) {
        try {
          tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
          _currentTimeZoneName = 'Asia/Ho_Chi_Minh';
          return;
        } catch (_) {}
      }
      for (final loc in tz.timeZoneDatabase.locations.values) {
        if (loc.currentTimeZone.offset == offsetMs) {
          tz.setLocalLocation(loc);
          _currentTimeZoneName = loc.name;
          return;
        }
      }
    } catch (_) {}

    // Fallback 3: Dùng UTC an toàn nếu hoàn toàn không xác định được
    tz.setLocalLocation(tz.UTC);
    _currentTimeZoneName = 'UTC';
  }

  /// Kiểm tra xem quyền thông báo hiện tại có đang được cấp hay không
  Future<bool> areNotificationsEnabled() async {
    await init();
    try {
      final androidImpl = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        final enabled = await androidImpl.areNotificationsEnabled();
        return enabled ?? false;
      }

      // iOS / macOS
      final iosImpl = _notificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (iosImpl != null) {
        final permissions = await iosImpl.checkPermissions();
        return permissions?.isEnabled ?? false;
      }
      return true;
    } catch (_) {
      return false;
    }
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

  /// Tính toán thời điểm nhắc nhở kế tiếp theo giờ địa phương của người dùng.
  /// Xử lý chính xác các trường hợp:
  /// - 00:00 (Nửa đêm), 12:00 (Trưa), 23:59 (Cuối ngày).
  /// - Nếu giờ hôm nay đã qua -> Dời sang ngày tiếp theo (bảo toàn đúng giờ địa phương kể cả khi chuyển giờ mùa hè DST).
  tz.TZDateTime calculateNextReminderDateTime(TimeOfDay time, [DateTime? mockNow]) {
    final now = mockNow != null ? tz.TZDateTime.from(mockNow, tz.local) : tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    // Nếu thời điểm đã qua trong ngày hôm nay, lên lịch cho ngày mai
    if (scheduledDate.isBefore(now)) {
      scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day + 1,
        time.hour,
        time.minute,
      );
    }
    return scheduledDate;
  }

  /// Lên lịch thông báo lặp lại hằng ngày theo giờ đã chọn bằng `zonedSchedule`.
  /// Sử dụng một ID duy nhất (`reminderNotificationId = 1001`), hệ điều hành sẽ
  /// tự động thay thế lịch cũ bằng lịch mới mà không gây mất lịch nếu có lỗi mạng/hệ thống.
  Future<bool> scheduleDailyReminder(TimeOfDay time) async {
    await init();

    if (_isOperating) return false;
    _isOperating = true;

    try {
      final scheduledDate = calculateNextReminderDateTime(time);

      const androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: '@mipmap/ic_launcher',
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
    } finally {
      _isOperating = false;
    }
  }

  /// Hủy lịch nhắc học khi người dùng tắt tính năng
  Future<bool> cancelReminder() async {
    await init();

    if (_isOperating) return false;
    _isOperating = true;

    try {
      await _notificationsPlugin.cancel(reminderNotificationId);
      return true;
    } catch (e) {
      debugPrint('Error canceling reminder: $e');
      return false;
    } finally {
      _isOperating = false;
    }
  }

  /// Lấy danh sách các thông báo đang chờ xử lý thực tế từ hệ điều hành
  Future<List<PendingNotificationRequest>> getPendingNotificationRequests() async {
    await init();
    try {
      return await _notificationsPlugin.pendingNotificationRequests();
    } catch (_) {
      return const [];
    }
  }

  /// Kiểm tra xem thông báo nhắc học ID 1001 có đang tồn tại trong danh sách pending không
  Future<bool> hasPendingReminder() async {
    final pending = await getPendingNotificationRequests();
    return pending.any((req) => req.id == reminderNotificationId);
  }
}
