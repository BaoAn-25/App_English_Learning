import 'package:flutter/material.dart';

import '../../data/app_repository.dart';
import '../../data/remote/api_client.dart';
import '../auth/auth_controller.dart';
import '../theme/components/sync_status_badge.dart';
import 'notification_service.dart';

/// ViewModel / Controller quản lý phần Cài đặt & Cá nhân.
/// Tuân thủ nguyên tắc Offline-first: ghi dữ liệu cục bộ vào SQLite trước qua AppRepository,
/// sau đó kích hoạt đồng bộ nền khi có mạng.
class SettingsController extends ChangeNotifier {
  bool _disposed = false;

  // Các thao tác dữ liệu có thể hoàn tất sau khi màn hình đã đóng.
  void _notifyIfActive() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  final AppRepository _repository;
  final NotificationService _notificationService;

  SettingsController({
    required AppRepository repo,
    NotificationService? notificationService,
  })  : _repository = repo,
        _notificationService = notificationService ?? NotificationService() {
    loadSettings();
  }

  // Trạng thái hồ sơ & cài đặt
  String _name = 'Khách';
  int _grade = 12;
  double? _targetScore;
  int _dailyGoal = 20;

  // Trạng thái thông báo nhắc nhở
  bool _reminderEnabled = false; // Mong muốn của người dùng
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);
  bool _hasNotificationPermission = true; // Trạng thái quyền thực tế của hệ điều hành
  bool _isReminderScheduled = false; // Lịch có đang chờ trên hệ thống hay không
  bool _isProcessingReminder = false; // Khóa chống thao tác chồng nhau (race condition)
  String? _reminderStatusMessage; // Thông báo trạng thái/lỗi phản ánh trung thực

  // Trạng thái đồng bộ (Offline-first: lưu trên thiết bị)
  SyncState _syncState = SyncState.offline;
  DateTime? _lastSyncedAt;
  String? _lastSyncedOwnerId;
  bool _hasPendingSync = false;

  // Getters
  String get name => _name;
  int get grade => _grade;
  double? get targetScore => _targetScore;
  bool get hasTargetScore => _targetScore != null && _targetScore! > 0;
  int get dailyGoal => _dailyGoal;
  bool get reminderEnabled => _reminderEnabled;
  TimeOfDay get reminderTime => _reminderTime;
  bool get hasNotificationPermission => _hasNotificationPermission;
  bool get isReminderScheduled => _isReminderScheduled;
  bool get isProcessingReminder => _isProcessingReminder;
  String? get reminderStatusMessage => _reminderStatusMessage;
  SyncState get syncState => _syncState;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  bool get hasPendingSync => _hasPendingSync;

  String get formattedLastSynced {
    final auth = AuthController.instance;
    if (!auth.isAuthenticated || auth.user.isGuest) {
      return 'Dữ liệu học tập đang được lưu an toàn trên thiết bị';
    }
    if (_lastSyncedAt != null && _lastSyncedOwnerId == auth.user.id) {
      final hour = _lastSyncedAt!.hour.toString().padLeft(2, '0');
      final min = _lastSyncedAt!.minute.toString().padLeft(2, '0');
      final day = _lastSyncedAt!.day.toString().padLeft(2, '0');
      final month = _lastSyncedAt!.month.toString().padLeft(2, '0');
      return 'Đã đồng bộ thành công lúc $hour:$min ngày $day/$month/${_lastSyncedAt!.year}';
    }
    return 'Tài khoản chưa có dữ liệu đồng bộ đám mây trên thiết bị này.';
  }

  /// Tải dữ liệu cài đặt từ SQLite (AppRepository) và đối chiếu với hệ thống
  Future<void> loadSettings() async {
    try {
      final savedName = await _repository.getSetting('user_name');
      if (savedName != null && savedName.isNotEmpty) {
        _name = savedName;
      }

      final savedGrade = await _repository.getSetting('grade');
      if (savedGrade != null) {
        _grade = int.tryParse(savedGrade) ?? 12;
      }

      final savedTarget = await _repository.getSetting('target_score');
      final isTargetConfirmed = await _repository.getSetting('target_score_confirmed');
      if (savedTarget != null && isTargetConfirmed == 'true') {
        _targetScore = double.tryParse(savedTarget);
      } else {
        _targetScore = null;
      }

      final savedMinutes = await _repository.getSetting('daily_minutes');
      final savedGoal = await _repository.getSetting('daily_goal');
      if (savedMinutes != null) {
        _dailyGoal = int.tryParse(savedMinutes) ?? 20;
      } else if (savedGoal != null) {
        _dailyGoal = int.tryParse(savedGoal) ?? 20;
      }

      final savedReminder = await _repository.getSetting('reminder_enabled');
      _reminderEnabled = savedReminder == 'true';

      final savedHour = await _repository.getSetting('reminder_hour');
      final savedMinute = await _repository.getSetting('reminder_minute');
      final savedTime = await _repository.getSetting('reminder_time');
      if (savedHour != null && savedMinute != null) {
        _reminderTime = TimeOfDay(
          hour: int.tryParse(savedHour) ?? 20,
          minute: int.tryParse(savedMinute) ?? 0,
        );
      } else if (savedTime != null && savedTime.contains(':')) {
        final parts = savedTime.split(':');
        _reminderTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 20,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }

      final savedLastSync = await _repository.getSetting('last_synced_at');
      if (savedLastSync != null) {
        _lastSyncedAt = DateTime.tryParse(savedLastSync);
      }
      _lastSyncedOwnerId = await _repository.getSetting('last_synced_owner_id');

      // Tự động nhận diện và chuyển đổi cấu hình máy chủ cũ sang Render HTTPS chính thức
      await ApiClient.sanitizeOrMigrateApiUrl(_repository);

      final pending = await _repository.getSetting('has_pending_sync');
      _hasPendingSync = pending == 'true';

      await _checkConnectivity();

      // Đối chiếu trạng thái quyền và lịch thực tế với hệ thống
      await checkAndReconcileReminder();
    } catch (_) {
      // Dùng giá trị mặc định nếu có lỗi đọc
    } finally {
      _notifyIfActive();
    }
  }

  /// Đối chiếu quyền thông báo và lịch thực tế với hệ điều hành
  /// Gọi khi mở màn hình Cài đặt hoặc khi ứng dụng được kích hoạt lại (resume)
  Future<void> checkAndReconcileReminder() async {
    try {
      final hasPerm = await _notificationService.areNotificationsEnabled();
      _hasNotificationPermission = hasPerm;

      final isPending = await _notificationService.hasPendingReminder();
      _isReminderScheduled = isPending;

      if (_reminderEnabled) {
        if (!hasPerm) {
          _reminderStatusMessage =
              'Quyền thông báo đang bị tắt trong Cài đặt hệ thống. Vui lòng bật lại để nhận nhắc nhở.';
        } else if (!isPending) {
          // Người dùng muốn bật, có quyền, nhưng chưa có lịch -> Tự động khôi phục lịch an toàn
          final scheduled = await _notificationService.scheduleDailyReminder(_reminderTime);
          _isReminderScheduled = scheduled;
          if (scheduled) {
            _reminderStatusMessage = null;
          }
        } else {
          _reminderStatusMessage = null;
        }
      } else {
        _reminderStatusMessage = null;
      }
    } catch (_) {}
    _notifyIfActive();
  }

  /// Cập nhật thông tin hồ sơ: Ghi SQLite trước, sau đó đồng bộ
  Future<void> updateProfile({
    required String name,
    required int grade,
    required double targetScore,
  }) async {
    _name = name;
    _grade = grade;
    _targetScore = targetScore;
    _hasPendingSync = true;
    _notifyIfActive();

    // 1. Lưu cục bộ an toàn
    await _repository.setSetting('user_name', _name);
    await _repository.setSetting('grade', _grade.toString());
    await _repository.setSetting('target_score', _targetScore.toString());
    await _repository.setSetting('target_score_confirmed', 'true');
    await _repository.setSetting('has_pending_sync', 'true');

    // Đồng bộ vào AuthController
    final auth = AuthController.instance;
    auth.updateProfile(auth.user.copyWith(
      targetScore: targetScore,
      isTargetScoreConfirmed: true,
    ));

    // 2. Kích hoạt đồng bộ nền nếu có mạng
    await _syncInBackground();
  }

  /// Cập nhật mục tiêu luyện tập mỗi ngày (10 / 20 / 30 / 45 phút)
  /// Hoàn toàn độc lập với giờ nhắc học
  Future<void> setDailyGoal(int goal) async {
    if (_dailyGoal == goal) return;
    _dailyGoal = goal;
    _hasPendingSync = true;
    _notifyIfActive();

    // Ghi cục bộ trước cho cả hai key để Onboarding và Settings đồng bộ
    await _repository.setSetting('daily_goal', _dailyGoal.toString());
    await _repository.setSetting('daily_minutes', _dailyGoal.toString());
    await _repository.setSetting('has_pending_sync', 'true');

    await _syncInBackground();
  }

  /// Bật / tắt thông báo nhắc học hàng ngày.
  /// Thao tác an toàn, tuần tự, chỉ xác nhận trạng thái bật khi đã đặt lịch thành công.
  Future<bool> toggleReminder(bool enabled) async {
    if (_isProcessingReminder) return false;
    _isProcessingReminder = true;
    _notifyIfActive();

    try {
      if (enabled) {
        // 1. Xin quyền thông báo
        final granted = await _notificationService.requestPermission();
        if (!granted) {
          _hasNotificationPermission = false;
          _reminderEnabled = false;
          _isReminderScheduled = false;
          _reminderStatusMessage =
              'Chưa được cấp quyền thông báo. Vui lòng cấp quyền trong Cài đặt hệ thống để nhận nhắc học.';
          await _repository.setSetting('reminder_enabled', 'false');
          return false;
        }

        _hasNotificationPermission = true;

        // 2. Lên lịch thông báo với giờ hiện tại
        final scheduled = await _notificationService.scheduleDailyReminder(_reminderTime);
        if (scheduled) {
          _reminderEnabled = true;
          _isReminderScheduled = true;
          _reminderStatusMessage = null;
          await _repository.setSetting('reminder_enabled', 'true');
          return true;
        } else {
          // Lên lịch thất bại: không giữ trạng thái bật giả mạo
          _reminderEnabled = false;
          _isReminderScheduled = false;
          _reminderStatusMessage =
              'Không thể đặt lịch thông báo trên hệ thống. Vui lòng thử lại sau.';
          await _repository.setSetting('reminder_enabled', 'false');
          return false;
        }
      } else {
        // Tắt nhắc học: Hủy lịch thực tế và kiểm tra kết quả
        final canceled = await _notificationService.cancelReminder();
        if (canceled) {
          _reminderEnabled = false;
          _isReminderScheduled = false;
          _reminderStatusMessage = null;
          await _repository.setSetting('reminder_enabled', 'false');
          return true;
        } else {
          _reminderStatusMessage =
              'Không thể hủy lịch nhắc học trên hệ thống. Vui lòng thử lại.';
          return false;
        }
      }
    } finally {
      _isProcessingReminder = false;
      _notifyIfActive();
    }
  }

  /// Thay đổi giờ nhắc học.
  /// Nếu đang bật: Đặt lịch giờ mới; nếu lỗi thì bảo toàn giờ cũ, không làm mất lịch.
  /// Nếu đang tắt: Chỉ lưu giờ dự định mới mà không tự ý bật lịch.
  Future<bool> setReminderTime(TimeOfDay time) async {
    if (_isProcessingReminder) return false;
    _isProcessingReminder = true;
    _notifyIfActive();

    try {
      final timeStr =
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

      if (!_reminderEnabled) {
        // Nhắc học đang tắt: Chỉ cập nhật giờ dự định
        _reminderTime = time;
        await _repository.setSetting('reminder_time', timeStr);
        await _repository.setSetting('reminder_hour', time.hour.toString());
        await _repository.setSetting('reminder_minute', time.minute.toString());
        _reminderStatusMessage = null;
        return true;
      }

      // Nhắc học đang bật: Bảo toàn giờ cũ đề phòng đặt lịch mới thất bại
      final oldTime = _reminderTime;
      final scheduled = await _notificationService.scheduleDailyReminder(time);

      if (scheduled) {
        _reminderTime = time;
        _isReminderScheduled = true;
        _reminderStatusMessage = null;
        await _repository.setSetting('reminder_time', timeStr);
        await _repository.setSetting('reminder_hour', time.hour.toString());
        await _repository.setSetting('reminder_minute', time.minute.toString());
        return true;
      } else {
        // Lỗi: Khôi phục giờ cũ, không thay đổi trong CSDL
        _reminderTime = oldTime;
        final oldTimeStr =
            '${oldTime.hour.toString().padLeft(2, '0')}:${oldTime.minute.toString().padLeft(2, '0')}';
        _reminderStatusMessage =
            'Đổi giờ nhắc thất bại. Giờ nhắc cũ ($oldTimeStr) vẫn được duy trì.';
        return false;
      }
    } finally {
      _isProcessingReminder = false;
      _notifyIfActive();
    }
  }

  String? _syncMessage;
  String? get syncMessage => _syncMessage;

  /// Kích hoạt đồng bộ chủ động từ nút "Đồng bộ ngay"
  Future<void> syncNow() async {
    final auth = AuthController.instance;
    if (!auth.isAuthenticated || auth.user.isGuest) {
      _syncState = SyncState.offline;
      _syncMessage = 'Tài khoản khách: Dữ liệu được lưu an toàn trên máy. Hãy đăng nhập để đồng bộ đám mây.';
      _notifyIfActive();
      return;
    }

    _syncState = SyncState.syncing;
    _syncMessage = 'Đang kết nối máy chủ đám mây để đồng bộ...';
    _notifyIfActive();

    try {
      final token = await _repository.getAuthToken();
      final client = ApiClient(tokenProvider: () => token);
      final isHealthy = await client.checkHealth();
      if (!isHealthy) {
        _syncState = SyncState.error;
        _syncMessage = 'Không thể kết nối máy chủ đám mây (${client.baseUrl}). Vui lòng kiểm tra kết nối mạng Internet hoặc thử lại sau ít phút.';
        _notifyIfActive();
        return;
      }

      // Gửi thống kê các ngày học của tài khoản này lên máy chủ
      final stats = await _repository.getAllDailyStats(ownerId: auth.user.id);
      for (final stat in stats) {
        final res = await client.syncDailyStat(
          statDate: stat.date,
          questionsDone: stat.questionsDone,
          correctCount: stat.correct,
          xpEarned: stat.xp,
        );
        if (!res.isSuccess) {
          _syncState = SyncState.error;
          _syncMessage = 'Đồng bộ thất bại ngày ${stat.date}: ${res.errorMessage}. Dữ liệu cục bộ vẫn được bảo toàn an toàn.';
          _notifyIfActive();
          return;
        }
      }

      // Cập nhật hồ sơ học tập lên máy chủ (có kiểm tra phản hồi xác nhận)
      final profileOk = await client.updateProfile({
        'targetScore': _targetScore,
        'dailyMinutes': _dailyGoal,
      });
      if (!profileOk) {
        _syncState = SyncState.error;
        _syncMessage = 'Cập nhật hồ sơ lên máy chủ thất bại. Dữ liệu cục bộ vẫn được bảo toàn an toàn.';
        _notifyIfActive();
        return;
      }

      _lastSyncedAt = DateTime.now();
      _lastSyncedOwnerId = auth.user.id;
      await _repository.setSetting('last_synced_at', _lastSyncedAt!.toIso8601String());
      await _repository.setSetting('last_synced_owner_id', _lastSyncedOwnerId!);
      _syncState = SyncState.synced;
      _syncMessage = 'Đã đồng bộ thành công lúc ${_lastSyncedAt!.hour.toString().padLeft(2, '0')}:${_lastSyncedAt!.minute.toString().padLeft(2, '0')}.';
    } catch (e) {
      _syncState = SyncState.error;
      _syncMessage = 'Lỗi đồng bộ: $e. Dữ liệu cục bộ vẫn được bảo toàn an toàn.';
    } finally {
      _notifyIfActive();
    }
  }

  Future<void> _syncInBackground() async {
    final auth = AuthController.instance;
    if (auth.isAuthenticated && !auth.user.isGuest) {
      await syncNow();
    } else {
      _syncState = SyncState.offline;
      _notifyIfActive();
    }
  }

  Future<void> _checkConnectivity() async {
    final auth = AuthController.instance;
    if (!auth.isAuthenticated || auth.user.isGuest) {
      _syncState = SyncState.offline;
      return;
    }
    final token = await _repository.getAuthToken();
    final client = ApiClient(tokenProvider: () => token);
    final ok = await client.checkHealth();
    // Chỉ hiển thị synced khi kiểm tra mạng thành công và có bản ghi đồng bộ thực tế của tài khoản này
    if (ok && _lastSyncedAt != null && _lastSyncedOwnerId == auth.user.id) {
      _syncState = SyncState.synced;
    } else {
      _syncState = SyncState.offline;
    }
    _notifyIfActive();
  }
}
