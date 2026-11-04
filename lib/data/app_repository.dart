import 'dart:async';
import 'dart:math';

import 'app_database.dart';
import 'remote/api_client.dart';
import 'models/attempt.dart';
import 'models/attempt_answer.dart';
import 'models/daily_stat.dart';
import 'models/learning_session.dart';
import 'models/question.dart';
import 'models/topic.dart';
import 'models/user_profile.dart';
import 'models/word.dart';
import 'models/word_progress.dart';
import 'models/wrong_book_entry.dart';
import 'trial_policy.dart';

/// Lớp mỏng bọc AppDatabase, là nơi duy nhất các màn hình gọi để truy xuất dữ liệu.
class AppRepository {
  final AppDatabase _db;

  AppRepository({AppDatabase? db}) : _db = db ?? AppDatabase.instance;

  // --- Quản lý phiên khách (Guest Session) & Quyền sở hữu (Ownership) ---
  Future<String> getCurrentOwnerId() async {
    final user = await getAuthUser();
    if (user != null && user.id.isNotEmpty && !user.isGuest) {
      return user.id;
    }
    return getOrCreateGuestSessionId();
  }

  Future<String> getOrCreateGuestSessionId() async {
    final existing = await getSetting('current_guest_session_id');
    if (existing != null && existing.trim().isNotEmpty) {
      return existing;
    }
    final newId = 'guest_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999).toString().padLeft(5, '0')}';
    await setSetting('current_guest_session_id', newId);
    return newId;
  }

  Future<String> resetGuestSessionId() async {
    final newId = 'guest_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999).toString().padLeft(5, '0')}';
    await setSetting('current_guest_session_id', newId);
    return newId;
  }

  Future<String?> getCompletedTrialLessonId(String ownerId) async {
    return getSetting('completed_trial_lesson_$ownerId');
  }

  Future<void> setCompletedTrialLessonId(String ownerId, String lessonId) async {
    await setSetting('completed_trial_lesson_$ownerId', lessonId);
  }

  Future<TransferResult> transferGuestData({
    required String fromGuestId,
    required String toUserId,
  }) {
    return _db.transferGuestData(fromGuestId: fromGuestId, toUserId: toUserId);
  }

  Future<List<String>> getEntityKeysByOwner(String ownerId, String entityType) =>
      _db.getEntityKeysByOwner(ownerId: ownerId, entityType: entityType);

  // --- Quản lý bài đang học dở & trạng thái tiếp tục học (Learning Session) ---
  Future<void> saveLearningSession(LearningSession session) async {
    // 1. Lưu theo chủ sở hữu và lessonId cụ thể (để không bị ghi đè khi người học đổi Unit)
    await setSetting(
      'learning_session_${session.ownerId}_${session.lessonId}',
      session.toJson(),
    );
    // 2. Lưu phiên gần nhất cho ownerId (để HomeScreen hiển thị thẻ Tiếp tục học bài gần nhất)
    await setSetting('learning_session_${session.ownerId}', session.toJson());
    // Lưu title bài học gần nhất để đồng bộ hiển thị tương thích
    await setSetting('last_studied_unit', session.lessonTitle);
  }

  Future<LearningSession?> getLearningSession(
    String ownerId, {
    String? lessonId,
  }) async {
    if (lessonId != null && lessonId.isNotEmpty) {
      final rawSpecific = await getSetting(
        'learning_session_${ownerId}_$lessonId',
      );
      if (rawSpecific != null && rawSpecific.trim().isNotEmpty) {
        try {
          return LearningSession.fromJson(rawSpecific);
        } catch (_) {}
      }
    }
    final raw = await getSetting('learning_session_$ownerId');
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final session = LearningSession.fromJson(raw);
      if (lessonId == null || session.lessonId == lessonId) {
        return session;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearLearningSession(String ownerId, {String? lessonId}) async {
    final db = await _db.database;
    if (lessonId != null && lessonId.isNotEmpty) {
      await db.delete(
        'app_settings',
        where: 'key = ?',
        whereArgs: ['learning_session_${ownerId}_$lessonId'],
      );
      // Nếu session gần nhất trùng lessonId này thì xóa luôn
      final current = await getLearningSession(ownerId);
      if (current?.lessonId == lessonId) {
        await db.delete(
          'app_settings',
          where: 'key = ?',
          whereArgs: ['learning_session_$ownerId'],
        );
      }
    } else {
      await db.delete(
        'app_settings',
        where: 'key LIKE ?',
        whereArgs: ['learning_session_$ownerId%'],
      );
    }
  }

  // --- Cài đặt (App Settings) ---
  Future<String?> getSetting(String key) => _db.getSetting(key);
  Future<void> setSetting(String key, String value) =>
      _db.setSetting(key, value);

  // --- Chủ đề (Topics) ---
  Future<void> insertTopics(List<Topic> topics) => _db.insertTopics(topics);
  Future<List<Topic>> getAllTopics() => _db.getAllTopics();
  Future<List<Topic>> getTopicsByGrade(int grade) =>
      _db.getTopicsByGrade(grade);

  // --- Từ vựng (Words) ---
  Future<void> insertWords(List<Word> words) => _db.insertWords(words);
  Future<void> insertWord(Word word) => _db.insertWord(word);
  Future<void> updateWord(Word word) => _db.updateWord(word);
  Future<void> deleteWord(String wordId) => _db.deleteWord(wordId);
  Future<List<Word>> getAllWords() => _db.getAllWords();
  Future<List<Word>> getWordsByGrade(int grade) => _db.getWordsByGrade(grade);
  Future<List<Word>> getWordsByTopicId(String topicId) =>
      _db.getWordsByTopicId(topicId);

  // --- Câu hỏi (Questions) ---
  Future<void> insertQuestions(List<Question> questions) =>
      _db.insertQuestions(questions);
  Future<int> insertMissingQuestions(List<Question> questions) {
    return _db.insertMissingQuestions(questions);
  }
  Future<QuestionSyncResult> syncQuestionsSafe(
    List<Question> questions, {
    String? targetVersion,
  }) {
    return _db.syncQuestionsSafe(questions, targetVersion: targetVersion);
  }

  Future<List<Question>> getAllQuestions() => _db.getAllQuestions();

  Future<List<Question>> getQuestionsByIds(List<String> ids) async {
    final questions = await _db.getQuestionsByIds(ids);
    final foundIds = {for (final q in questions) q.id};
    final missingIds = ids.where((id) => !foundIds.contains(id)).toList();
    if (missingIds.isNotEmpty) {
      final trialQuestions = TrialPolicy.questionsAsStandardQuestions;
      final trialMap = {for (final q in trialQuestions) q.id: q};
      final newlyAdded = <Question>[];
      for (final id in missingIds) {
        final q = trialMap[id];
        if (q != null) newlyAdded.add(q);
      }
      if (newlyAdded.isNotEmpty) {
        await _db.insertQuestions(newlyAdded);
        questions.addAll(newlyAdded);
      }
    }
    return questions;
  }
  Future<List<Question>> getQuestionsByGrade(int grade) =>
      _db.getQuestionsByGrade(grade);
  Future<List<Question>> getQuestionsByType(String type) =>
      _db.getQuestionsByType(type);
  Future<List<Question>> getQuestionsByTopicId(String topicId) =>
      _db.getQuestionsByTopicId(topicId);

  // --- Lượt làm bài (Attempts) ---
  Future<int> insertAttempt(Attempt attempt, {String? ownerId}) async {
    final effectiveOwner = (ownerId != null && ownerId.trim().isNotEmpty)
        ? ownerId
        : await getCurrentOwnerId();
    return _db.insertAttempt(attempt, ownerId: effectiveOwner);
  }

  Future<List<Attempt>> getAllAttempts({String? ownerId}) async {
    final effectiveOwner = (ownerId != null && ownerId.trim().isNotEmpty)
        ? ownerId
        : await getCurrentOwnerId();
    return _db.getAllAttempts(ownerId: effectiveOwner);
  }

  Future<List<Attempt>> getAttempts({String? ownerId, int? limit}) async {
    final effectiveOwner = (ownerId != null && ownerId.trim().isNotEmpty)
        ? ownerId
        : await getCurrentOwnerId();
    return _db.getAttempts(ownerId: effectiveOwner, limit: limit);
  }

  // --- Chi tiết câu trả lời (Attempt Answers) ---
  Future<void> insertAttemptAnswers(List<AttemptAnswer> answers) =>
      _db.insertAttemptAnswers(answers);
  Future<List<AttemptAnswer>> getAllAttemptAnswers({String? ownerId}) async {
    final effectiveOwner = (ownerId != null && ownerId.trim().isNotEmpty)
        ? ownerId
        : await getCurrentOwnerId();
    return _db.getAllAttemptAnswers(ownerId: effectiveOwner);
  }
  Future<List<AttemptAnswer>> getAttemptAnswers(int attemptId) =>
      _db.getAttemptAnswers(attemptId);

  // --- Sổ câu sai (Wrong Book) ---
  Future<void> insertWrongBookEntries(List<WrongBookEntry> entries, {String? ownerId}) async {
    final effectiveOwner = (ownerId != null && ownerId.trim().isNotEmpty)
        ? ownerId
        : await getCurrentOwnerId();
    return _db.insertWrongBookEntries(entries, ownerId: effectiveOwner);
  }

  Future<List<WrongBookEntry>> getAllWrongBookEntries({String? ownerId}) async {
    final effectiveOwner = (ownerId != null && ownerId.trim().isNotEmpty)
        ? ownerId
        : await getCurrentOwnerId();
    return _db.getAllWrongBookEntries(ownerId: effectiveOwner);
  }

  Future<void> upsertWrongBookEntry(WrongBookEntry entry, {String? ownerId}) async {
    final effectiveOwner = (ownerId != null && ownerId.trim().isNotEmpty)
        ? ownerId
        : await getCurrentOwnerId();
    return _db.upsertWrongBookEntry(entry, ownerId: effectiveOwner);
  }

  Future<List<WrongBookEntry>> getDueWrongBookEntries(
    int beforeOrAtTimestamp, {
    String? ownerId,
  }) async {
    final effectiveOwner = (ownerId != null && ownerId.trim().isNotEmpty)
        ? ownerId
        : await getCurrentOwnerId();
    return _db.getDueWrongBookEntries(beforeOrAtTimestamp, ownerId: effectiveOwner);
  }

  // --- Thống kê hàng ngày (Daily Stats) ---
  Future<void> insertDailyStats(List<DailyStat> stats, {String? ownerId}) async {
    final effectiveOwner = (ownerId != null && ownerId.trim().isNotEmpty)
        ? ownerId
        : await getCurrentOwnerId();
    return _db.insertDailyStats(stats, ownerId: effectiveOwner);
  }

  Future<List<DailyStat>> getAllDailyStats({String? ownerId}) async {
    final effectiveOwner = (ownerId != null && ownerId.trim().isNotEmpty)
        ? ownerId
        : await getCurrentOwnerId();
    return _db.getAllDailyStats(ownerId: effectiveOwner);
  }

  Future<void> upsertDailyStat(DailyStat stat, {String? ownerId}) async {
    final effectiveOwner = (ownerId != null && ownerId.trim().isNotEmpty)
        ? ownerId
        : await getCurrentOwnerId();
    await _db.upsertDailyStat(stat, ownerId: effectiveOwner);

    // Tự động đồng bộ điểm XP và số câu đã làm lên máy chủ Render để ghi nhận vào Bảng xếp hạng chung
    try {
      final token = await getAuthToken();
      if (token != null && token.isNotEmpty) {
        final client = ApiClient(tokenProvider: () => token);
        final todayStat = await _db.getDailyStat(stat.date, ownerId: effectiveOwner);
        if (todayStat != null) {
          unawaited(client.syncDailyStat(
            statDate: todayStat.date,
            questionsDone: todayStat.questionsDone,
            correctCount: todayStat.correct,
            xpEarned: todayStat.xp,
          ));
        }
      }
    } catch (_) {}
  }

  /// Ghi nhận điểm thưởng XP và thời gian học thực tế vào thống kê hằng ngày (Daily Stats)
  /// để cập nhật ngay lập tức XP, Chuỗi ngày học (Streak) và Bảng xếp hạng trên Trang chủ.
  Future<void> recordStudyReward({
    required int xp,
    int minutes = 3,
    int questionsDone = 0,
    int correct = 0,
    String? ownerId,
  }) async {
    try {
      final now = DateTime.now();
      final dateStr =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final stat = DailyStat(
        date: dateStr,
        xp: xp > 0 ? xp : 0,
        questionsDone: questionsDone > 0 ? questionsDone : 0,
        correct: correct > 0 ? correct : 0,
        minutes: minutes > 0 ? minutes : 1,
      );
      await upsertDailyStat(stat, ownerId: ownerId);
    } catch (_) {}
  }

  Future<List<DailyStat>> getDailyStatsInRange(
    String startDate,
    String endDate, {
    String? ownerId,
  }) async {
    final effectiveOwner = (ownerId != null && ownerId.trim().isNotEmpty)
        ? ownerId
        : await getCurrentOwnerId();
    return _db.getDailyStatsInRange(startDate, endDate, ownerId: effectiveOwner);
  }

  Future<bool> hasGuestData(String guestId) async {
    final session = await getLearningSession(guestId);
    if (session != null) return true;
    final trialLesson = await getCompletedTrialLessonId(guestId);
    if (trialLesson != null && trialLesson.isNotEmpty) return true;
    final attempts = await getEntityKeysByOwner(guestId, 'attempts');
    if (attempts.isNotEmpty) return true;
    final words = await getAllWordProgress(ownerId: guestId);
    if (words.isNotEmpty) return true;
    final wrongEntries = await getAllWrongBookEntries(ownerId: guestId);
    if (wrongEntries.isNotEmpty) return true;
    final dailyStats = await getAllDailyStats(ownerId: guestId);
    if (dailyStats.isNotEmpty) return true;
    return false;
  }

  // --- Quản lý phiên đăng nhập an toàn của học viên ---
  Future<void> saveAuthToken(String token) async {
    await setSetting('auth_token', token);
  }

  Future<String?> getAuthToken() async {
    return getSetting('auth_token');
  }

  Future<void> clearAuthToken() async {
    final db = await _db.database;
    await db.delete('app_settings', where: 'key = ?', whereArgs: ['auth_token']);
  }

  Future<void> saveAuthUser(UserProfile user) async {
    await setSetting('auth_user_id', user.id);
    await setSetting('auth_email', user.email);
    await setSetting('auth_display_name', user.displayName);
    await setSetting('auth_avatar_url', user.avatarUrl);
    await setSetting('auth_provider', user.authProvider);
    await setSetting('auth_role', user.role);
    await setSetting('auth_email_verified', user.emailVerified ? 'true' : 'false');
    await setSetting('is_logged_in', 'true');
  }

  Future<UserProfile?> getAuthUser() async {
    final isLoggedIn = await getSetting('is_logged_in');
    if (isLoggedIn != 'true') return null;
    final id = await getSetting('auth_user_id');
    if (id == null || id.isEmpty) return null;
    final email = await getSetting('auth_email') ?? '';
    final name = await getSetting('auth_display_name') ?? 'Học viên';
    final avatar = await getSetting('auth_avatar_url') ?? '';
    final provider = await getSetting('auth_provider') ?? 'email';
    final role = await getSetting('auth_role') ?? 'student';
    final verified = await getSetting('auth_email_verified') == 'true';

    return UserProfile(
      id: id,
      email: email,
      displayName: name,
      avatarUrl: avatar,
      authProvider: provider,
      role: role,
      emailVerified: verified,
      isLoggedIn: true,
    );
  }

  Future<void> clearAuthUser() async {
    final db = await _db.database;
    await db.delete('app_settings', where: "key LIKE 'auth_%' OR key = 'is_logged_in'");
  }

  Future<void> signOut() async {
    await clearAuthToken();
    await clearAuthUser();
  }

  Future<Map<String, dynamic>> getOverallStats({String? ownerId}) async {
    final attempts = await getAllAttempts(ownerId: ownerId);
    int totalDone = 0;
    int totalScore = 0;
    for (final a in attempts) {
      totalDone += a.total;
      totalScore += a.score;
    }
    final streakRaw = await getSetting('learning_streak') ?? '0';
    final streak = int.tryParse(streakRaw) ?? 0;
    return {
      'totalDone': totalDone,
      'totalCorrect': totalScore,
      'streak': streak,
      'attemptsCount': attempts.length,
    };
  }

  // --- Tiến độ từ vựng (Word Progress / SRS) ---
  Future<WordProgress?> getWordProgress(String wordId, {String? ownerId}) async {
    final effectiveOwner = (ownerId != null && ownerId.trim().isNotEmpty)
        ? ownerId
        : await getCurrentOwnerId();
    return _db.getWordProgress(wordId, ownerId: effectiveOwner);
  }

  Future<List<WordProgress>> getAllWordProgress({String? ownerId}) async {
    final effectiveOwner = (ownerId != null && ownerId.trim().isNotEmpty)
        ? ownerId
        : await getCurrentOwnerId();
    return _db.getAllWordProgress(ownerId: effectiveOwner);
  }

  Future<void> upsertWordProgress(WordProgress progress, {String? ownerId}) async {
    final effectiveOwner = (ownerId != null && ownerId.trim().isNotEmpty)
        ? ownerId
        : await getCurrentOwnerId();
    return _db.upsertWordProgress(progress, ownerId: effectiveOwner);
  }

  Future<List<WordProgress>> getDueWordProgress({String? ownerId}) async {
    final effectiveOwner = (ownerId != null && ownerId.trim().isNotEmpty)
        ? ownerId
        : await getCurrentOwnerId();
    return _db.getDueWordProgress(ownerId: effectiveOwner);
  }

  Future<void> savePracticeResult({
    required Attempt attempt,
    required List<AttemptAnswer> Function(int attemptId) buildAnswers,
    required List<WrongBookEntry> wrongEntries,
    required DailyStat dailyStat,
    String? ownerId,
  }) async {
    final effectiveOwner = (ownerId != null && ownerId.trim().isNotEmpty)
        ? ownerId
        : await getCurrentOwnerId();
    return _db.savePracticeResult(
      attempt: attempt,
      buildAnswers: buildAnswers,
      wrongEntries: wrongEntries,
      dailyStat: dailyStat,
      ownerId: effectiveOwner,
    );
  }
}
