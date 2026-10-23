import 'app_database.dart';
import 'models/attempt.dart';
import 'models/attempt_answer.dart';
import 'models/daily_stat.dart';
import 'models/question.dart';
import 'models/topic.dart';
import 'models/word.dart';
import 'models/word_progress.dart';
import 'models/wrong_book_entry.dart';

/// Lớp mỏng bọc AppDatabase, là nơi duy nhất các màn hình gọi để truy xuất dữ liệu.
class AppRepository {
  final AppDatabase _db;

  AppRepository({AppDatabase? db}) : _db = db ?? AppDatabase.instance;

  // --- Cài đặt (App Settings) ---
  Future<String?> getSetting(String key) => _db.getSetting(key);
  Future<void> setSetting(String key, String value) => _db.setSetting(key, value);

  // --- Chủ đề (Topics) ---
  Future<void> insertTopics(List<Topic> topics) => _db.insertTopics(topics);
  Future<List<Topic>> getAllTopics() => _db.getAllTopics();
  Future<List<Topic>> getTopicsByGrade(int grade) => _db.getTopicsByGrade(grade);

  // --- Từ vựng (Words) ---
  Future<void> insertWords(List<Word> words) => _db.insertWords(words);
  Future<List<Word>> getAllWords() => _db.getAllWords();
  Future<List<Word>> getWordsByGrade(int grade) => _db.getWordsByGrade(grade);
  Future<List<Word>> getWordsByTopicId(String topicId) => _db.getWordsByTopicId(topicId);

  // --- Câu hỏi (Questions) ---
  Future<void> insertQuestions(List<Question> questions) => _db.insertQuestions(questions);
  Future<List<Question>> getAllQuestions() => _db.getAllQuestions();
  Future<List<Question>> getQuestionsByGrade(int grade) => _db.getQuestionsByGrade(grade);
  Future<List<Question>> getQuestionsByType(String type) => _db.getQuestionsByType(type);
  Future<List<Question>> getQuestionsByTopicId(String topicId) => _db.getQuestionsByTopicId(topicId);

  // --- Lượt làm bài (Attempts) ---
  Future<int> insertAttempt(Attempt attempt) => _db.insertAttempt(attempt);
  Future<List<Attempt>> getAllAttempts() => _db.getAllAttempts();
  Future<List<Attempt>> getAttempts({int? limit}) => _db.getAttempts(limit: limit);

  // --- Chi tiết câu trả lời (Attempt Answers) ---
  Future<void> insertAttemptAnswers(List<AttemptAnswer> answers) => _db.insertAttemptAnswers(answers);
  Future<List<AttemptAnswer>> getAllAttemptAnswers() => _db.getAllAttemptAnswers();
  Future<List<AttemptAnswer>> getAttemptAnswers(int attemptId) => _db.getAttemptAnswers(attemptId);

  // --- Sổ câu sai (Wrong Book) ---
  Future<void> insertWrongBookEntries(List<WrongBookEntry> entries) => _db.insertWrongBookEntries(entries);
  Future<List<WrongBookEntry>> getAllWrongBookEntries() => _db.getAllWrongBookEntries();
  Future<void> upsertWrongBookEntry(WrongBookEntry entry) => _db.upsertWrongBookEntry(entry);
  Future<List<WrongBookEntry>> getDueWrongBookEntries(int beforeOrAtTimestamp) =>
      _db.getDueWrongBookEntries(beforeOrAtTimestamp);

  // --- Thống kê hàng ngày (Daily Stats) ---
  Future<void> insertDailyStats(List<DailyStat> stats) => _db.insertDailyStats(stats);
  Future<List<DailyStat>> getAllDailyStats() => _db.getAllDailyStats();
  Future<void> upsertDailyStat(DailyStat stat) => _db.upsertDailyStat(stat);
  Future<List<DailyStat>> getDailyStatsInRange(String startDate, String endDate) =>
      _db.getDailyStatsInRange(startDate, endDate);

  // --- Tiến độ từ vựng (Word Progress / SRS) ---
  Future<WordProgress?> getWordProgress(String wordId) => _db.getWordProgress(wordId);
  Future<List<WordProgress>> getAllWordProgress() => _db.getAllWordProgress();
  Future<void> upsertWordProgress(WordProgress progress) => _db.upsertWordProgress(progress);
  Future<List<WordProgress>> getDueWordProgress() => _db.getDueWordProgress();
}

