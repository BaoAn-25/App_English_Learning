import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/app_repository.dart';
import '../theme/components/sync_status_badge.dart';
import 'notification_service.dart';

/// ViewModel / Controller quản lý phần Cài đặt & Cá nhân.
/// Tuân thủ nguyên tắc Offline-first: ghi dữ liệu cục bộ vào SQLite trước qua AppRepository,
/// sau đó kích hoạt đồng bộ nền khi có mạng.
class SettingsController extends ChangeNotifier {
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
  String _name = 'Học sinh lớp 12';
  int _grade = 12;
  double _targetScore = 8.5;
  int _dailyGoal = 20;

  // Trạng thái thông báo
  bool _reminderEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);

  // Trạng thái đồng bộ
  SyncState _syncState = SyncState.synced;
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
    if (_lastSyncedAt == null) return 'Chưa đồng bộ';
    return DateFormat('HH:mm - dd/MM/yyyy').format(_lastSyncedAt!);
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
      notifyListeners();
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
    notifyListeners();

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
    notifyListeners();

    // Ghi cục bộ trước
    await _repository.setSetting('daily_goal', _dailyGoal.toString());
    await _repository.setSetting('has_pending_sync', 'true');

    await _syncInBackground();
  }

  /// Bật / tắt thông báo nhắc học hàng ngày
  Future<void> toggleReminder(bool enabled) async {
    _reminderEnabled = enabled;
    notifyListeners();

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
    notifyListeners();

    await _repository.setSetting('reminder_hour', time.hour.toString());
    await _repository.setSetting('reminder_minute', time.minute.toString());

    if (_reminderEnabled) {
      await _notificationService.scheduleDailyReminder(time);
    }
  }

  /// Kích hoạt đồng bộ chủ động từ nút "Đồng bộ ngay"
  Future<void> syncNow() async {
    final isOnline = await _isNetworkAvailable();
    if (!isOnline) {
      _syncState = SyncState.offline;
      notifyListeners();
      return;
    }

    _syncState = SyncState.syncing;
    notifyListeners();

    try {
      // Mô phỏng / Gọi đồng bộ API (sau này ApiClient sẽ được cắm vào đây)
      await Future.delayed(const Duration(milliseconds: 1200));

      _lastSyncedAt = DateTime.now();
      _hasPendingSync = false;
      _syncState = SyncState.synced;

      await _repository.setSetting('last_synced_at', _lastSyncedAt!.toIso8601String());
      await _repository.setSetting('has_pending_sync', 'false');
    } catch (_) {
      _syncState = SyncState.error;
    } finally {
      notifyListeners();
    }
  }

  Future<void> _syncInBackground() async {
    final isOnline = await _isNetworkAvailable();
    if (!isOnline) {
      _syncState = SyncState.offline;
      notifyListeners();
      return;
    }

    _syncState = SyncState.syncing;
    notifyListeners();

    try {
      // Đồng bộ ngầm không block UI
      await Future.delayed(const Duration(milliseconds: 800));
      _lastSyncedAt = DateTime.now();
      _hasPendingSync = false;
      _syncState = SyncState.synced;

      await _repository.setSetting('last_synced_at', _lastSyncedAt!.toIso8601String());
      await _repository.setSetting('has_pending_sync', 'false');
    } catch (_) {
      _syncState = SyncState.error;
    } finally {
      notifyListeners();
    }
  }

  Future<bool> _isNetworkAvailable() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return !connectivityResult.contains(ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  Future<void> _checkConnectivity() async {
    final online = await _isNetworkAvailable();
    if (!online) {
      _syncState = SyncState.offline;
    } else if (_hasPendingSync) {
      _syncState = SyncState.syncing;
    } else {
      _syncState = SyncState.synced;
    }
  }
}
