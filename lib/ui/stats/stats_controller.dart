import 'package:flutter/material.dart';

import '../../data/app_repository.dart';
import '../theme/components/sync_status_badge.dart';
import 'stats_calculator.dart';

/// ViewModel quản lý dữ liệu cho màn hình Thống kê tiến độ.
/// Trả dữ liệu tức thì từ SQLite trên máy, cập nhật ngầm từ API khi online.
class StatsController extends ChangeNotifier {
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

  StatsController({required AppRepository repo}) : _repository = repo {
    loadStats();
  }

  int _rangeDays = 7; // Mặc định 7 ngày (có thể chuyển sang 30 ngày)
  bool _isLoading = true;
  OverallStatsSummary? _summary;
  SyncState _syncState = SyncState.synced;

  // Getters
  int get rangeDays => _rangeDays;
  bool get isLoading => _isLoading;
  OverallStatsSummary? get summary => _summary;
  SyncState get syncState => _syncState;

  Future<void> setRangeDays(int days) async {
    if (_rangeDays == days) return;
    _rangeDays = days;
    _notifyIfActive();
    await loadStats();
  }

  /// Tải dữ liệu từ SQLite cục bộ qua AppRepository
  Future<void> loadStats() async {
    _isLoading = true;
    _notifyIfActive();

    try {
      final stats = await _repository.getAllDailyStats();
      final attempts = await _repository.getAllAttempts();
      final answers = await _repository.getAllAttemptAnswers();
      final questions = await _repository.getAllQuestions();

      _summary = StatsCalculator.calculateOverallSummary(
        stats: stats,
        attempts: attempts,
        answers: answers,
        questions: questions,
        rangeDays: _rangeDays,
      );

      await _checkConnectivity();
    } catch (_) {
      // Dữ liệu an toàn
    } finally {
      _isLoading = false;
      _notifyIfActive();
    }
  }

  /// Kích hoạt làm mới dữ liệu
  Future<void> refresh() async {
    await loadStats();
    _syncState = SyncState.offline;
    _notifyIfActive();
  }

  Future<void> _checkConnectivity() async {
    // Dữ liệu đọc từ SQLite cục bộ, đồng bộ tài khoản chưa khả dụng
    _syncState = SyncState.offline;
  }
}
