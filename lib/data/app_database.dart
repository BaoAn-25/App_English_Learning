import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models/attempt.dart';
import 'models/attempt_answer.dart';
import 'models/daily_stat.dart';
import 'models/question.dart';
import 'models/topic.dart';
import 'models/word.dart';
import 'models/wrong_book_entry.dart';

class AppDatabase {
  static const String _databaseName = 'thpt_english.db';
  static const int _databaseVersion = 1;

  AppDatabase._internal();
  static final AppDatabase instance = AppDatabase._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Topics
    await db.execute('''
      CREATE TABLE topics (
        id TEXT PRIMARY KEY,
        grade INTEGER NOT NULL,
        title TEXT NOT NULL,
        "order" INTEGER NOT NULL
      )
    ''');

    // 2. Words
    await db.execute('''
      CREATE TABLE words (
        id TEXT PRIMARY KEY,
        topicId TEXT NOT NULL,
        grade INTEGER NOT NULL,
        english TEXT NOT NULL,
        ipa TEXT NOT NULL,
        meaningVi TEXT NOT NULL,
        example TEXT NOT NULL
      )
    ''');

    // 3. Questions
    await db.execute('''
      CREATE TABLE questions (
        id TEXT PRIMARY KEY,
        grade INTEGER NOT NULL,
        type TEXT NOT NULL,
        stem TEXT NOT NULL,
        options TEXT NOT NULL,
        correctIndex INTEGER NOT NULL,
        explanation TEXT NOT NULL,
        topicId TEXT,
        passageId TEXT,
        difficulty INTEGER NOT NULL
      )
    ''');

    // 4. Attempts
    await db.execute('''
      CREATE TABLE attempts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mode TEXT NOT NULL,
        type TEXT,
        startedAt INTEGER NOT NULL,
        durationSec INTEGER NOT NULL,
        score INTEGER NOT NULL,
        total INTEGER NOT NULL
      )
    ''');

    // 5. Attempt Answers
    await db.execute('''
      CREATE TABLE attempt_answers (
        attemptId INTEGER NOT NULL,
        questionId TEXT NOT NULL,
        chosenIndex INTEGER NOT NULL,
        isCorrect INTEGER NOT NULL,
        PRIMARY KEY (attemptId, questionId)
      )
    ''');

    // 6. Wrong Book Entries
    await db.execute('''
      CREATE TABLE wrong_book (
        questionId TEXT PRIMARY KEY,
        wrongCount INTEGER NOT NULL,
        lastWrongAt INTEGER NOT NULL,
        nextReviewAt INTEGER NOT NULL
      )
    ''');

    // 7. Daily Stats
    await db.execute('''
      CREATE TABLE daily_stats (
        date TEXT PRIMARY KEY,
        xp INTEGER NOT NULL,
        questionsDone INTEGER NOT NULL,
        correct INTEGER NOT NULL,
        minutes INTEGER NOT NULL
      )
    ''');

    // 8. App Settings
    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Cài đặt mặc định ban đầu
    final batch = db.batch();
    batch.insert('app_settings', {'key': 'daily_goal', 'value': '20'});
    batch.insert('app_settings', {'key': 'streak_freeze_left', 'value': '2'});
    batch.insert('app_settings', {'key': 'grade', 'value': '12'});
    await batch.commit(noResult: true);
  }

  // --- App Settings ---
  Future<String?> getSetting(String key) async {
    final db = await database;
    final results = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (results.isNotEmpty) {
      return results.first['value'] as String?;
    }
    return null;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --- Topics ---
  Future<void> insertTopics(List<Topic> topics) async {
    final db = await database;
    final batch = db.batch();
    for (final topic in topics) {
      batch.insert(
        'topics',
        topic.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Topic>> getAllTopics() async {
    final db = await database;
    final maps = await db.query('topics', orderBy: '"order" ASC');
    return maps.map(Topic.fromMap).toList();
  }

  Future<List<Topic>> getTopicsByGrade(int grade) async {
    final db = await database;
    final maps = await db.query(
      'topics',
      where: 'grade = ?',
      whereArgs: [grade],
      orderBy: '"order" ASC',
    );
    return maps.map(Topic.fromMap).toList();
  }

  // --- Words ---
  Future<void> insertWords(List<Word> words) async {
    final db = await database;
    final batch = db.batch();
    for (final word in words) {
      batch.insert(
        'words',
        word.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Word>> getAllWords() async {
    final db = await database;
    final maps = await db.query('words');
    return maps.map(Word.fromMap).toList();
  }

  Future<List<Word>> getWordsByGrade(int grade) async {
    final db = await database;
    final maps = await db.query(
      'words',
      where: 'grade = ?',
      whereArgs: [grade],
    );
    return maps.map(Word.fromMap).toList();
  }

  Future<List<Word>> getWordsByTopicId(String topicId) async {
    final db = await database;
    final maps = await db.query(
      'words',
      where: 'topicId = ?',
      whereArgs: [topicId],
    );
    return maps.map(Word.fromMap).toList();
  }

  // --- Questions ---
  Future<void> insertQuestions(List<Question> questions) async {
    final db = await database;
    final batch = db.batch();
    for (final question in questions) {
      batch.insert(
        'questions',
        question.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Question>> getAllQuestions() async {
    final db = await database;
    final maps = await db.query('questions');
    return maps.map(Question.fromMap).toList();
  }

  Future<List<Question>> getQuestionsByGrade(int grade) async {
    final db = await database;
    final maps = await db.query(
      'questions',
      where: 'grade = ?',
      whereArgs: [grade],
    );
    return maps.map(Question.fromMap).toList();
  }

  Future<List<Question>> getQuestionsByType(String type) async {
    final db = await database;
    final maps = await db.query(
      'questions',
      where: 'type = ?',
      whereArgs: [type],
    );
    return maps.map(Question.fromMap).toList();
  }

  // --- Attempts ---
  Future<int> insertAttempt(Attempt attempt) async {
    final db = await database;
    return await db.insert('attempts', attempt.toMap());
  }

  Future<List<Attempt>> getAllAttempts() async {
    final db = await database;
    final maps = await db.query('attempts');
    return maps.map(Attempt.fromMap).toList();
  }

  Future<List<Attempt>> getAttempts({int? limit}) async {
    final db = await database;
    final maps = await db.query(
      'attempts',
      orderBy: 'startedAt DESC',
      limit: limit,
    );
    return maps.map(Attempt.fromMap).toList();
  }

  // --- Attempt Answers ---
  Future<void> insertAttemptAnswers(List<AttemptAnswer> answers) async {
    final db = await database;
    final batch = db.batch();
    for (final answer in answers) {
      batch.insert(
        'attempt_answers',
        answer.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<AttemptAnswer>> getAllAttemptAnswers() async {
    final db = await database;
    final maps = await db.query('attempt_answers');
    return maps.map(AttemptAnswer.fromMap).toList();
  }

  Future<List<AttemptAnswer>> getAttemptAnswers(int attemptId) async {
    final db = await database;
    final maps = await db.query(
      'attempt_answers',
      where: 'attemptId = ?',
      whereArgs: [attemptId],
    );
    return maps.map(AttemptAnswer.fromMap).toList();
  }

  // --- Wrong Book Entries ---
  Future<void> insertWrongBookEntries(List<WrongBookEntry> entries) async {
    final db = await database;
    final batch = db.batch();
    for (final entry in entries) {
      batch.insert(
        'wrong_book',
        entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<WrongBookEntry>> getAllWrongBookEntries() async {
    final db = await database;
    final maps = await db.query('wrong_book');
    return maps.map(WrongBookEntry.fromMap).toList();
  }

  Future<void> upsertWrongBookEntry(WrongBookEntry entry) async {
    final db = await database;
    await db.transaction((txn) async {
      final existing = await txn.query(
        'wrong_book',
        where: 'questionId = ?',
        whereArgs: [entry.questionId],
        limit: 1,
      );

      if (existing.isEmpty) {
        await txn.insert(
          'wrong_book',
          entry.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } else {
        final currentCount = (existing.first['wrongCount'] as num).toInt();
        final addedCount = entry.wrongCount > 0 ? entry.wrongCount : 1;
        await txn.update(
          'wrong_book',
          {
            'wrongCount': currentCount + addedCount,
            'lastWrongAt': entry.lastWrongAt,
            'nextReviewAt': entry.nextReviewAt,
          },
          where: 'questionId = ?',
          whereArgs: [entry.questionId],
        );
      }
    });
  }

  Future<List<WrongBookEntry>> getDueWrongBookEntries(int beforeOrAtTimestamp) async {
    final db = await database;
    final maps = await db.query(
      'wrong_book',
      where: 'nextReviewAt <= ?',
      whereArgs: [beforeOrAtTimestamp],
      orderBy: 'nextReviewAt ASC',
    );
    return maps.map(WrongBookEntry.fromMap).toList();
  }

  // --- Daily Stats ---
  Future<void> insertDailyStats(List<DailyStat> stats) async {
    final db = await database;
    final batch = db.batch();
    for (final stat in stats) {
      batch.insert(
        'daily_stats',
        stat.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<DailyStat>> getAllDailyStats() async {
    final db = await database;
    final maps = await db.query('daily_stats', orderBy: 'date ASC');
    return maps.map(DailyStat.fromMap).toList();
  }

  Future<void> upsertDailyStat(DailyStat stat) async {
    final db = await database;
    await db.transaction((txn) async {
      final existing = await txn.query(
        'daily_stats',
        where: 'date = ?',
        whereArgs: [stat.date],
        limit: 1,
      );

      if (existing.isEmpty) {
        await txn.insert(
          'daily_stats',
          stat.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } else {
        final row = existing.first;
        await txn.update(
          'daily_stats',
          {
            'xp': (row['xp'] as num).toInt() + stat.xp,
            'questionsDone': (row['questionsDone'] as num).toInt() + stat.questionsDone,
            'correct': (row['correct'] as num).toInt() + stat.correct,
            'minutes': (row['minutes'] as num).toInt() + stat.minutes,
          },
          where: 'date = ?',
          whereArgs: [stat.date],
        );
      }
    });
  }

  Future<List<DailyStat>> getDailyStatsInRange(String startDate, String endDate) async {
    final db = await database;
    final maps = await db.query(
      'daily_stats',
      where: 'date >= ? AND date <= ?',
      whereArgs: [startDate, endDate],
      orderBy: 'date ASC',
    );
    return maps.map(DailyStat.fromMap).toList();
  }

  /// Lưu toàn bộ kết quả hoặc không lưu gì nếu có lỗi.
  /// Giữ cùng giao diện với luồng luyện tập/thi thử của nhóm.
  Future<void> savePracticeResult({
    required Attempt attempt,
    required List<AttemptAnswer> Function(int attemptId) buildAnswers,
    required List<WrongBookEntry> wrongEntries,
    required DailyStat dailyStat,
  }) async {
    final date = DateTime.tryParse(dailyStat.date);
    if (attempt.id != null ||
        attempt.mode.trim().isEmpty ||
        attempt.startedAt < 0 ||
        attempt.durationSec < 0 ||
        attempt.total <= 0 ||
        attempt.score < 0 ||
        attempt.score > attempt.total) {
      throw ArgumentError('Lượt làm bài không hợp lệ.');
    }
    if (date == null ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dailyStat.date) ||
        date.toIso8601String().substring(0, 10) != dailyStat.date ||
        dailyStat.xp < 0 ||
        dailyStat.minutes < 0 ||
        dailyStat.questionsDone != attempt.total ||
        dailyStat.correct != attempt.score) {
      throw ArgumentError('Thống kê ngày không khớp kết quả bài làm.');
    }
    final wrongBook = List<WrongBookEntry>.of(wrongEntries);
    final db = await database;

    await db.transaction((txn) async {
      // 1. Lưu lượt làm bài.
      final attemptId = await txn.insert('attempts', attempt.toMap());

      // 2. Lưu từng đáp án.
      final answers = List<AttemptAnswer>.of(buildAnswers(attemptId));
      if (answers.length != attempt.total ||
          answers.map((answer) => answer.questionId).toSet().length !=
              answers.length ||
          answers.any((answer) => answer.attemptId != attemptId) ||
          answers.where((answer) => answer.isCorrect).length != attempt.score) {
        throw ArgumentError('Danh sách đáp án không khớp lượt làm bài.');
      }
      for (final answer in answers) {
        final rows = await txn.query(
          'questions',
          where: 'id = ?',
          whereArgs: [answer.questionId],
          limit: 1,
        );
        if (rows.isEmpty) throw ArgumentError('Câu hỏi không tồn tại.');
        final question = Question.fromMap(rows.single);
        if (question.correctIndex < 0 ||
            question.correctIndex >= question.options.length) {
          throw StateError('Đáp án của câu hỏi trong ngân hàng không hợp lệ.');
        }
        if (answer.chosenIndex < -1 ||
            answer.chosenIndex >= question.options.length ||
            answer.isCorrect != (answer.chosenIndex == question.correctIndex)) {
          throw ArgumentError(
            'Lựa chọn hoặc kết quả chấm câu hỏi không hợp lệ.',
          );
        }
      }
      final wrongIds = answers
          .where((answer) => !answer.isCorrect)
          .map((answer) => answer.questionId)
          .toSet();
      if (wrongBook.length != wrongIds.length ||
          wrongBook.map((entry) => entry.questionId).toSet().length !=
              wrongBook.length ||
          wrongBook.any(
            (entry) =>
                !wrongIds.contains(entry.questionId) ||
                entry.wrongCount != 1 ||
                entry.lastWrongAt < 0 ||
                entry.nextReviewAt < entry.lastWrongAt,
          )) {
        throw ArgumentError('Sổ câu sai không khớp các đáp án sai.');
      }

      final batch = txn.batch();
      for (final answer in answers) {
        batch.insert('attempt_answers', answer.toMap());
      }
      await batch.commit(noResult: true);

      // UPDATE rồi INSERT trong cùng transaction để hỗ trợ cả SQLite cũ.
      for (final entry in wrongBook) {
        final updated = await txn.rawUpdate(
          'UPDATE wrong_book SET wrongCount = wrongCount + ?, '
          'lastWrongAt = ?, nextReviewAt = ? WHERE questionId = ?',
          [
            entry.wrongCount,
            entry.lastWrongAt,
            entry.nextReviewAt,
            entry.questionId,
          ],
        );
        if (updated == 0) await txn.insert('wrong_book', entry.toMap());
      }
      final updated = await txn.rawUpdate(
        'UPDATE daily_stats SET xp = xp + ?, questionsDone = questionsDone + ?, '
        'correct = correct + ?, minutes = minutes + ? WHERE date = ?',
        [
          dailyStat.xp,
          dailyStat.questionsDone,
          dailyStat.correct,
          dailyStat.minutes,
          dailyStat.date,
        ],
      );
      if (updated == 0) await txn.insert('daily_stats', dailyStat.toMap());
    });
  }

  // --- Helper kiểm tra bảng rỗng để seed dữ liệu ---
  Future<bool> isTableEmpty(String tableName) async {
    final db = await database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $tableName'),
    );
    return (count ?? 0) == 0;
  }
}
