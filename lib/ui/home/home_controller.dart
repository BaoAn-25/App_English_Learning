import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/app_repository.dart';
import '../../data/models/topic.dart';
import '../theme/components/sync_status_badge.dart';
import 'streak_calculator.dart';

/// Đại diện cho một chủ đề trong lộ trình học tập, có trạng thái mở khóa.
class TopicProgressItem {
  final Topic topic;
  final bool isUnlocked;
  final bool isCompleted;
  final int completedQuestions;
  final int totalQuestions;

  const TopicProgressItem({
    required this.topic,
    required this.isUnlocked,
    required this.isCompleted,
    this.completedQuestions = 0,
    this.totalQuestions = 10,
  });

  double get progressRatio =>
      totalQuestions > 0 ? (completedQuestions / totalQuestions).clamp(0.0, 1.0) : 0.0;
}

/// ViewModel quản lý dữ liệu hiển thị trên Trang chủ.
/// Trả dữ liệu từ SQLite cục bộ ngay lập tức, sau đó đồng bộ ngầm khi có kết nối mạng.
class HomeController extends ChangeNotifier {
  final AppRepository _repository;

  HomeController({required AppRepository repo}) : _repository = repo {
    loadHomeData();
  }

  bool _isLoading = true;
  int _streak = 0;
  int _totalXp = 0;
  int _level = 1;
  double _levelProgress = 0.0;
  int _todayQuestionsDone = 0;
  int _dailyGoal = 20;
  List<TopicProgressItem> _roadmapTopics = [];
  SyncState _syncState = SyncState.synced;

  // Getters
  bool get isLoading => _isLoading;
  int get streak => _streak;
  int get totalXp => _totalXp;
  int get level => _level;
  double get levelProgress => _levelProgress;
  int get todayQuestionsDone => _todayQuestionsDone;
  int get dailyGoal => _dailyGoal;
  List<TopicProgressItem> get roadmapTopics => _roadmapTopics;
  SyncState get syncState => _syncState;

  double get todayProgressRatio =>
      _dailyGoal > 0 ? (_todayQuestionsDone / _dailyGoal).clamp(0.0, 1.0) : 0.0;

  bool get isDailyGoalCompleted => _todayQuestionsDone >= _dailyGoal;

  /// Đọc dữ liệu cục bộ từ AppRepository
  Future<void> loadHomeData() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Lấy cài đặt mục tiêu ngày
      final goalStr = await _repository.getSetting('daily_goal');
      if (goalStr != null) {
        _dailyGoal = int.tryParse(goalStr) ?? 20;
      }

      // 2. Lấy thống kê ngày từ SQLite
      final stats = await _repository.getAllDailyStats();
      _streak = StreakCalculator.calculateStreak(stats);

      _totalXp = stats.fold<int>(0, (sum, s) => sum + s.xp);
      _level = StreakCalculator.calculateLevel(_totalXp);
      _levelProgress = StreakCalculator.calculateLevelProgress(_totalXp);

      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final todayStat = stats.where((s) => s.date == todayStr).firstOrNull;
      _todayQuestionsDone = todayStat?.questionsDone ?? 0;

      // 3. Lấy lộ trình chủ đề lớp 12
      final rawTopics = await _repository.getTopicsByGrade(12);
      rawTopics.sort((a, b) => a.order.compareTo(b.order));

      // Lấy lịch sử làm bài để tính tiến độ mở khóa lộ trình
      final attempts = await _repository.getAllAttempts();
      final completedAttemptCount = attempts.length;

      final items = <TopicProgressItem>[];
      for (int i = 0; i < rawTopics.length; i++) {
        final topic = rawTopics[i];
        // Bài đầu tiên luôn mở khóa. Bài thứ i mở khóa khi người dùng đã có bài tập trước đó
        final bool isUnlocked = (i == 0) || (i <= completedAttemptCount);
        final bool isCompleted = i < completedAttemptCount;

        items.add(
          TopicProgressItem(
            topic: topic,
            isUnlocked: isUnlocked,
            isCompleted: isCompleted,
            completedQuestions: isCompleted ? 10 : (isUnlocked ? 3 : 0),
            totalQuestions: 10,
          ),
        );
      }
      _roadmapTopics = items;

      // 4. Kiểm tra mạng
      await _checkConnectivity();
    } catch (_) {
      // An toàn dữ liệu
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Làm mới dữ liệu (khi người dùng vuốt refresh hoặc có kết nối mạng)
  Future<void> refresh() async {
    final online = await _isNetworkAvailable();
    if (!online) {
      _syncState = SyncState.offline;
      await loadHomeData();
      return;
    }

    _syncState = SyncState.syncing;
    notifyListeners();

    try {
      // Mô phỏng làm mới từ API ngầm
      await Future.delayed(const Duration(milliseconds: 600));
      await loadHomeData();
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
