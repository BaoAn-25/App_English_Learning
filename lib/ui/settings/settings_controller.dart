import 'package:flutter/material.dart';

import '../../data/app_repository.dart';
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
  double _targetScore = 8.0;
  int _dailyGoal = 20;

  // Trạng thái thông báo
  bool _reminderEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);

  // Trạng thái đồng bộ (Offline-first: lưu trên thiết bị)
  SyncState _syncState = SyncState.offline;
  DateTime? _lastSyncedAt;
  bool _hasPendingSync = false;

  // Getters
  String get name => _name;
  int get grade => _grade;
  double get targetScore => _targetScore;
  int get dailyGoal => _dailyGoal;
  bool get reminderEnabled => _reminderEnabled;
  TimeOfDay get reminderTime => _reminderTime;
  SyncState get syncState => _syncState;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  bool get hasPendingSync => _hasPendingSync;

  String get formattedLastSynced {
    return 'Lưu trên thiết bị (Đồng bộ đám mây chưa khả dụng)';
  }

  /// Tải dữ liệu cài đặt từ SQLite (AppRepository)
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
      if (savedTarget != null) {
        _targetScore = double.tryParse(savedTarget) ?? 8.5;
      }

      final savedGoal = await _repository.getSetting('daily_goal');
      if (savedGoal != null) {
        _dailyGoal = int.tryParse(savedGoal) ?? 20;
      }

      final savedReminder = await _repository.getSetting('reminder_enabled');
      _reminderEnabled = savedReminder == 'true';

      final savedHour = await _repository.getSetting('reminder_hour');
      final savedMinute = await _repository.getSetting('reminder_minute');
      if (savedHour != null && savedMinute != null) {
        _reminderTime = TimeOfDay(
          hour: int.tryParse(savedHour) ?? 20,
          minute: int.tryParse(savedMinute) ?? 0,
        );
      }

      final savedLastSync = await _repository.getSetting('last_synced_at');
      if (savedLastSync != null) {
        _lastSyncedAt = DateTime.tryParse(savedLastSync);
      }

      final pending = await _repository.getSetting('has_pending_sync');
      _hasPendingSync = pending == 'true';

      await _checkConnectivity();
    } catch (_) {
      // Dùng giá trị mặc định nếu có lỗi đọc
    } finally {
      _notifyIfActive();
    }
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
    await _repository.setSetting('has_pending_sync', 'true');

    // 2. Kích hoạt đồng bộ nền nếu có mạng
    await _syncInBackground();
  }

  /// Cập nhật mục tiêu luyện tập mỗi ngày (10 / 20 / 30 câu)
  Future<void> setDailyGoal(int goal) async {
    if (_dailyGoal == goal) return;
    _dailyGoal = goal;
    _hasPendingSync = true;
    _notifyIfActive();

    // Ghi cục bộ trước
    await _repository.setSetting('daily_goal', _dailyGoal.toString());
    await _repository.setSetting('has_pending_sync', 'true');

    await _syncInBackground();
  }

  /// Bật / tắt thông báo nhắc học hàng ngày
  Future<void> toggleReminder(bool enabled) async {
    _reminderEnabled = enabled;
    _notifyIfActive();

    await _repository.setSetting('reminder_enabled', enabled ? 'true' : 'false');

    if (enabled) {
      final granted = await _notificationService.requestPermission();
      if (granted) {
        await _notificationService.scheduleDailyReminder(_reminderTime);
      }
    } else {
      await _notificationService.cancelReminder();
    }
  }

  /// Thay đổi giờ nhắc học
  Future<void> setReminderTime(TimeOfDay time) async {
    _reminderTime = time;
    _notifyIfActive();

    await _repository.setSetting('reminder_hour', time.hour.toString());
    await _repository.setSetting('reminder_minute', time.minute.toString());

    if (_reminderEnabled) {
      await _notificationService.scheduleDailyReminder(time);
    }
  }

  /// Kích hoạt đồng bộ chủ động từ nút "Đồng bộ ngay"
  Future<void> syncNow() async {
    // Chưa có dịch vụ backend đồng bộ thật sự cho từng tài khoản ở bước này.
    // Dữ liệu hiện được lưu toàn bộ an toàn trên thiết bị (SQLite).
    _syncState = SyncState.offline;
    _notifyIfActive();
  }

  Future<void> _syncInBackground() async {
    _syncState = SyncState.offline;
    _notifyIfActive();
  }

  Future<void> _checkConnectivity() async {
    // Vì chưa có đồng bộ backend thực tế cho user, giữ trạng thái lưu trên thiết bị
    _syncState = SyncState.offline;
  }
}
