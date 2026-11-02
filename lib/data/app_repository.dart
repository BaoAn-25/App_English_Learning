import 'dart:math';

import 'app_database.dart';
import 'models/attempt.dart';
import 'models/attempt_answer.dart';
import 'models/daily_stat.dart';
import 'models/learning_session.dart';
import 'models/question.dart';
import 'models/topic.dart';
import 'models/word.dart';
import 'models/word_progress.dart';
import 'models/wrong_book_entry.dart';
import 'trial_policy.dart';

/// Lớp mỏng bọc AppDatabase, là nơi duy nhất các màn hình gọi để truy xuất dữ liệu.
class AppRepository {
  final AppDatabase _db;

  AppRepository({AppDatabase? db}) : _db = db ?? AppDatabase.instance;

  // --- Quản lý phiên khách (Guest Session) & Quyền sở hữu (Ownership) ---
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
    await setSetting('learning_session_${session.ownerId}', session.toJson());
    // Lưu title bài học gần nhất để đồng bộ hiển thị tương thích
    await setSetting('last_studied_unit', session.lessonTitle);
  }

  Future<LearningSession?> getLearningSession(String ownerId) async {
    final raw = await getSetting('learning_session_$ownerId');
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return LearningSession.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearLearningSession(String ownerId) async {
    final db = await _db.database;
    await db.delete(
      'app_settings',
      where: 'key = ?',
      whereArgs: ['learning_session_$ownerId'],
    );
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

  Future<List<Question>> getAllQuestions() async {
    final questions = await _db.getAllQuestions();
    final trialQuestions = TrialPolicy.questionsAsStandardQuestions;
    final existingIds = {for (final q in questions) q.id};
    final missing = trialQuestions.where((q) => !existingIds.contains(q.id)).toList();
    if (missing.isNotEmpty) {
      await _db.insertQuestions(missing);
      return [...questions, ...missing];
    }
    return questions;
  }

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
  Future<int> insertAttempt(Attempt attempt, {String? ownerId}) =>
      _db.insertAttempt(attempt, ownerId: ownerId);
  Future<List<Attempt>> getAllAttempts({String? ownerId}) =>
      _db.getAllAttempts(ownerId: ownerId);
  Future<List<Attempt>> getAttempts({String? ownerId, int? limit}) =>
      _db.getAttempts(ownerId: ownerId, limit: limit);

  // --- Chi tiết câu trả lời (Attempt Answers) ---
  Future<void> insertAttemptAnswers(List<AttemptAnswer> answers) =>
      _db.insertAttemptAnswers(answers);
  Future<List<AttemptAnswer>> getAllAttemptAnswers() =>
      _db.getAllAttemptAnswers();
  Future<List<AttemptAnswer>> getAttemptAnswers(int attemptId) =>
      _db.getAttemptAnswers(attemptId);

  // --- Sổ câu sai (Wrong Book) ---
  Future<void> insertWrongBookEntries(List<WrongBookEntry> entries) =>
      _db.insertWrongBookEntries(entries);
  Future<List<WrongBookEntry>> getAllWrongBookEntries({String? ownerId}) =>
      _db.getAllWrongBookEntries(ownerId: ownerId);
  Future<void> upsertWrongBookEntry(WrongBookEntry entry) =>
      _db.upsertWrongBookEntry(entry);
  Future<List<WrongBookEntry>> getDueWrongBookEntries(
    int beforeOrAtTimestamp,
  ) => _db.getDueWrongBookEntries(beforeOrAtTimestamp);

  // --- Thống kê hàng ngày (Daily Stats) ---
  Future<void> insertDailyStats(List<DailyStat> stats) =>
      _db.insertDailyStats(stats);
  Future<List<DailyStat>> getAllDailyStats() => _db.getAllDailyStats();
  Future<void> upsertDailyStat(DailyStat stat) => _db.upsertDailyStat(stat);
  Future<List<DailyStat>> getDailyStatsInRange(
    String startDate,
    String endDate,
  ) => _db.getDailyStatsInRange(startDate, endDate);

  // --- Tiến độ từ vựng (Word Progress / SRS) ---
  Future<WordProgress?> getWordProgress(String wordId) =>
      _db.getWordProgress(wordId);
  Future<List<WordProgress>> getAllWordProgress({String? ownerId}) =>
      _db.getAllWordProgress(ownerId: ownerId);
  Future<void> upsertWordProgress(WordProgress progress, {String? ownerId}) =>
      _db.upsertWordProgress(progress, ownerId: ownerId);
  Future<List<WordProgress>> getDueWordProgress() => _db.getDueWordProgress();

  Future<void> savePracticeResult({
    required Attempt attempt,
    required List<AttemptAnswer> Function(int attemptId) buildAnswers,
    required List<WrongBookEntry> wrongEntries,
    required DailyStat dailyStat,
    String? ownerId,
  }) {
    return _db.savePracticeResult(
      attempt: attempt,
      buildAnswers: buildAnswers,
      wrongEntries: wrongEntries,
      dailyStat: dailyStat,
      ownerId: ownerId,
    );
  }
}
