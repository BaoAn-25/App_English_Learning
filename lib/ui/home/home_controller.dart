import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/app_repository.dart';
import '../../data/models/learning_session.dart';
import '../../data/models/topic.dart';
import '../../data/trial_lesson_repository.dart';
import '../auth/auth_controller.dart';
import '../theme/components/sync_status_badge.dart';
import 'streak_calculator.dart';

/// Trạng thái tiến độ thực tế của một Unit trong SGK
class UnitProgressSummary {
  final int unitNumber;
  final int completedSections;
  final int totalSections;
  final bool hasActiveSession;
  final bool isCompleted;

  const UnitProgressSummary({
    required this.unitNumber,
    required this.completedSections,
    required this.totalSections,
    this.hasActiveSession = false,
    this.isCompleted = false,
  });

  bool get isStarted => completedSections > 0 || hasActiveSession;
}

/// Trạng thái tiến độ thực tế của một bài Review trong SGK
class ReviewProgressSummary {
  final int reviewNumber;
  final bool isCompleted;
  final bool isStarted;

  const ReviewProgressSummary({
    required this.reviewNumber,
    required this.isCompleted,
    required this.isStarted,
  });
}

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
    this.totalQuestions = 0,
  });

  double get progressRatio =>
      totalQuestions > 0 ? (completedQuestions / totalQuestions).clamp(0.0, 1.0) : 0.0;
}

/// ViewModel quản lý dữ liệu hiển thị trên Trang chủ.
/// Trả dữ liệu từ SQLite cục bộ theo đúng chủ sở hữu (ownerId), tự động cập nhật khi đổi tài khoản.
class HomeController extends ChangeNotifier {
  final AppRepository _repository;
  VoidCallback? _authListener;

  HomeController({required AppRepository repo}) : _repository = repo {
    _authListener = () {
      loadHomeData();
    };
    AuthController.instance.addListener(_authListener!);
    loadHomeData();
  }

  @override
  void dispose() {
    if (_authListener != null) {
      AuthController.instance.removeListener(_authListener!);
    }
    super.dispose();
  }

  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  int _streak = 0;
  int _totalXp = 0;
  int _level = 1;
  double _levelProgress = 0.0;
  int _todayQuestionsDone = 0;
  int _dailyGoal = 20;
  int _savedWordsCount = 0;
  int _dueWordsCount = 0;
  int _dueWrongQuestionsCount = 0;
  List<TopicProgressItem> _roadmapTopics = [];
  Map<int, UnitProgressSummary> _unitProgress = {};
  Map<int, ReviewProgressSummary> _reviewProgress = {};
  SyncState _syncState = SyncState.offline;

  String _examDate = '';
  String? _lastStudiedUnitTitle;
  LearningSession? _learningSession;

  // Getters
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  String? get errorMessage => _errorMessage;

  int get streak => _streak;
  int get totalXp => _totalXp;
  int get level => _level;
  double get levelProgress => _levelProgress;
  int get todayQuestionsDone => _todayQuestionsDone;
  int get dailyGoal => _dailyGoal;
  int get savedWordsCount => _savedWordsCount;
  int get dueWordsCount => _dueWordsCount;
  int get dueWrongQuestionsCount => _dueWrongQuestionsCount;
  List<TopicProgressItem> get roadmapTopics => _roadmapTopics;
  SyncState get syncState => _syncState;
  String get examDate => _examDate;
  String? get lastStudiedUnitTitle => _lastStudiedUnitTitle;
  LearningSession? get learningSession => _learningSession;

  UnitProgressSummary getUnitProgress(int unitNumber) =>
      _unitProgress[unitNumber] ??
      UnitProgressSummary(unitNumber: unitNumber, completedSections: 0, totalSections: 8);

  ReviewProgressSummary getReviewProgress(int reviewNumber) =>
      _reviewProgress[reviewNumber] ??
      ReviewProgressSummary(reviewNumber: reviewNumber, isCompleted: false, isStarted: false);

  double get todayProgressRatio =>
      _dailyGoal > 0 ? (_todayQuestionsDone / _dailyGoal).clamp(0.0, 1.0) : 0.0;

  bool get isDailyGoalCompleted => _todayQuestionsDone >= _dailyGoal;

  /// Đọc dữ liệu cục bộ từ AppRepository theo đúng người sở hữu
  Future<void> loadHomeData([String? ownerId]) async {
    _isLoading = true;
    _hasError = false;
    _errorMessage = null;
    notifyListeners();

    try {
      final auth = AuthController.instance;
      final effectiveOwnerId = ownerId ??
          (auth.isAuthenticated && !auth.user.isGuest
              ? auth.user.id
              : await _repository.getOrCreateGuestSessionId());

      // 1. Cài đặt mục tiêu ngày và ngày thi
      final goalStr = await _repository.getSetting('daily_goal');
      if (goalStr != null) {
        _dailyGoal = int.tryParse(goalStr) ?? 20;
      }
      _examDate = await _repository.getSetting('exam_date') ?? '';

      // 2. Từ vựng và câu sai đến hạn ôn tập thực tế theo đúng ownerId
      final dueWords = await _repository.getDueWordProgress(ownerId: effectiveOwnerId);
      _dueWordsCount = dueWords.length;
      final allWords = await _repository.getAllWordProgress(ownerId: effectiveOwnerId);
      _savedWordsCount = allWords.length;

      final dueWrong = await _repository.getDueWrongBookEntries(
        DateTime.now().millisecondsSinceEpoch,
        ownerId: effectiveOwnerId,
      );
      _dueWrongQuestionsCount = dueWrong.length;

      // 3. Phiên học dở / hoàn thành của chủ sở hữu hiện tại
      _learningSession = await _repository.getLearningSession(effectiveOwnerId);
      if (_learningSession != null) {
        _lastStudiedUnitTitle = _learningSession!.lessonTitle;
      } else {
        _lastStudiedUnitTitle = await _repository.getSetting('last_studied_unit');
      }

      // 4. Thống kê theo ngày thực tế của chủ sở hữu
      final stats = await _repository.getAllDailyStats(ownerId: effectiveOwnerId);
      _streak = StreakCalculator.calculateStreak(stats);
      _totalXp = stats.fold<int>(0, (sum, s) => sum + s.xp);
      _level = StreakCalculator.calculateLevel(_totalXp);
      _levelProgress = StreakCalculator.calculateLevelProgress(_totalXp);

      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final todayStat = stats.where((s) => s.date == todayStr).firstOrNull;
      _todayQuestionsDone = todayStat?.questionsDone ?? 0;

      // 5. Tính tiến độ thực tế của từng Unit trong SGK (1..10)
      final unitProg = <int, UnitProgressSummary>{};
      for (int u = 1; u <= 10; u++) {
        int doneCount = 0;
        final lesson = TrialLessonRepository.instance.getLessonByUnit(u);
        final session = lesson != null
            ? await _repository.getLearningSession(effectiveOwnerId, lessonId: lesson.lessonId)
            : null;
        final bool hasActive = session != null && session.isInProgress;
        if (session != null && session.isCompleted) {
          doneCount++;
        }
        for (final secKey in [
          'getting_started',
          'language',
          'speaking',
          'listening',
          'writing',
          'communication_culture_clil',
          'looking_back_project'
        ]) {
          final p = await _repository.getSetting('unit_section_progress_${effectiveOwnerId}_u${u}_$secKey');
          if (p == 'completed') {
            doneCount++;
          }
        }
        unitProg[u] = UnitProgressSummary(
          unitNumber: u,
          completedSections: doneCount,
          totalSections: 8,
          hasActiveSession: hasActive,
          isCompleted: doneCount >= 8,
        );
      }
      _unitProgress = unitProg;

      // 6. Tính tiến độ thực tế của 4 mốc Review SGK
      final revProg = <int, ReviewProgressSummary>{};
      for (int r = 1; r <= 4; r++) {
        final isComp = (await _repository.getSetting('review_${r}_completed_$effectiveOwnerId')) == 'true';
        final hasWriting = (await _repository.getSetting('review_${r}_writing_$effectiveOwnerId')) != null;
        revProg[r] = ReviewProgressSummary(
          reviewNumber: r,
          isCompleted: isComp,
          isStarted: hasWriting,
        );
      }
      _reviewProgress = revProg;

      // 7. Lộ trình chủ đề lớp 12
      final rawTopics = await _repository.getTopicsByGrade(12);
      rawTopics.sort((a, b) => a.order.compareTo(b.order));

      final allAnswers = await _repository.getAllAttemptAnswers(ownerId: effectiveOwnerId);
      final answeredQuestionIds = allAnswers.map((a) => a.questionId).toSet();

      final items = <TopicProgressItem>[];
      for (int i = 0; i < rawTopics.length; i++) {
        final topic = rawTopics[i];
        final topicQuestions = await _repository.getQuestionsByTopicId(topic.id);
        final totalQuestions = topicQuestions.length; // Phản ánh số câu thực tế, không giả định 10 câu
        final completedQuestions = topicQuestions
            .where((q) => answeredQuestionIds.contains(q.id))
            .length;

        final bool isCompleted = totalQuestions > 0 && completedQuestions >= totalQuestions;
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

      // 8. Trạng thái đồng bộ
      final lastSyncOwner = await _repository.getSetting('last_synced_owner_id');
      final lastSyncAt = await _repository.getSetting('last_synced_at');
      if (auth.isAuthenticated &&
          !auth.user.isGuest &&
          lastSyncOwner == auth.user.id &&
          lastSyncAt != null) {
        _syncState = SyncState.synced;
      } else {
        _syncState = SyncState.offline;
      }
    } catch (e) {
      _hasError = true;
      _errorMessage = 'Không thể tải dữ liệu trang chủ: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Làm mới dữ liệu (khi người dùng vuốt refresh)
  Future<void> refresh() async {
    await loadHomeData();
  }
}
