import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../../data/app_repository.dart';
import '../theme/components/sync_status_badge.dart';
import 'stats_calculator.dart';

/// ViewModel quản lý dữ liệu cho màn hình Thống kê tiến độ.
/// Trả dữ liệu tức thì từ SQLite trên máy, cập nhật ngầm từ API khi online.
class StatsController extends ChangeNotifier {
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
    notifyListeners();
    await loadStats();
  }

  /// Tải dữ liệu từ SQLite cục bộ qua AppRepository
  Future<void> loadStats() async {
    _isLoading = true;
    notifyListeners();

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
      notifyListeners();
    }
  }

  /// Kích hoạt làm mới dữ liệu từ API nền
  Future<void> refresh() async {
    final online = await _isNetworkAvailable();
    if (!online) {
      _syncState = SyncState.offline;
      await loadStats();
      return;
    }

    _syncState = SyncState.syncing;
    notifyListeners();

    try {
      // Mô phỏng / Gọi API sync ngầm
      await Future.delayed(const Duration(milliseconds: 600));
      await loadStats();
      _syncState = SyncState.synced;
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
    _syncState = online ? SyncState.synced : SyncState.offline;
  }
}
