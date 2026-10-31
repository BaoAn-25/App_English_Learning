import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/app_repository.dart';
import '../../data/models/learning_session.dart';
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

  String _examDate = '';
  int _dueWordsCount = 0;
  int _dueWrongQuestionsCount = 0;
  String? _lastStudiedUnitTitle;
  LearningSession? _learningSession;

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
  String get examDate => _examDate;
  int get dueWordsCount => _dueWordsCount;
  int get dueWrongQuestionsCount => _dueWrongQuestionsCount;
  String? get lastStudiedUnitTitle => _lastStudiedUnitTitle;
  LearningSession? get learningSession => _learningSession;

  double get todayProgressRatio =>
      _dailyGoal > 0 ? (_todayQuestionsDone / _dailyGoal).clamp(0.0, 1.0) : 0.0;

  bool get isDailyGoalCompleted => _todayQuestionsDone >= _dailyGoal;

  /// Đọc dữ liệu cục bộ từ AppRepository
  Future<void> loadHomeData([String? ownerId]) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Lấy cài đặt mục tiêu ngày và ngày thi
      final goalStr = await _repository.getSetting('daily_goal');
      if (goalStr != null) {
        _dailyGoal = int.tryParse(goalStr) ?? 20;
      }
      _examDate = await _repository.getSetting('exam_date') ?? '';

      // Đếm từ vựng và câu sai đến hạn ôn tập thực tế
      final dueWords = await _repository.getDueWordProgress();
      _dueWordsCount = dueWords.length;
      final dueWrong = await _repository.getDueWrongBookEntries(DateTime.now().millisecondsSinceEpoch);
      _dueWrongQuestionsCount = dueWrong.length;

      // Lấy phiên học dở / hoàn thành của chủ sở hữu hiện tại
      final effectiveOwnerId = ownerId ?? await _repository.getOrCreateGuestSessionId();
      _learningSession = await _repository.getLearningSession(effectiveOwnerId);
      if (_learningSession != null) {
        _lastStudiedUnitTitle = _learningSession!.lessonTitle;
      } else {
        _lastStudiedUnitTitle = await _repository.getSetting('last_studied_unit');
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

      // Lấy câu trả lời thực tế để tính số câu đã làm theo từng topicId
      final allAnswers = await _repository.getAllAttemptAnswers();
      final answeredQuestionIds = allAnswers.map((a) => a.questionId).toSet();

      final items = <TopicProgressItem>[];
      for (int i = 0; i < rawTopics.length; i++) {
        final topic = rawTopics[i];
        final topicQuestions = await _repository.getQuestionsByTopicId(topic.id);
        final totalQuestions = topicQuestions.isEmpty ? 10 : topicQuestions.length;
        final completedQuestions = topicQuestions
            .where((q) => answeredQuestionIds.contains(q.id))
            .length;

        final bool isCompleted = completedQuestions > 0 && completedQuestions >= totalQuestions;
        // Chủ đề đầu tiên luôn mở khóa. Chủ đề tiếp theo mở khi chủ đề trước có học hoặc có tiến độ thực tế
        final bool isUnlocked = (i == 0) || (items.isNotEmpty && (items[i - 1].completedQuestions > 0));

        items.add(
          TopicProgressItem(
            topic: topic,
            isUnlocked: isUnlocked,
            isCompleted: isCompleted,
            completedQuestions: completedQuestions,
            totalQuestions: totalQuestions,
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
    await loadHomeData();
    _syncState = SyncState.offline;
    notifyListeners();
  }

  Future<void> _checkConnectivity() async {
    // Dữ liệu đọc từ SQLite cục bộ, đồng bộ tài khoản chưa triển khai
    _syncState = SyncState.offline;
  }
}
