import 'dart:convert';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models/attempt.dart';
import 'models/attempt_answer.dart';
import 'models/daily_stat.dart';
import 'models/question.dart';
import 'models/topic.dart';
import 'models/word.dart';
import 'models/wrong_book_entry.dart';

/// Kết quả đồng bộ câu hỏi an toàn
class QuestionSyncResult {
  final int insertedCount;
  final int updatedCount;
  final int skippedCount;

  const QuestionSyncResult({
    required this.insertedCount,
    required this.updatedCount,
    required this.skippedCount,
  });

  int get totalProcessed => insertedCount + updatedCount + skippedCount;

  @override
  String toString() =>
      'QuestionSyncResult(inserted: $insertedCount, updated: $updatedCount, skipped: $skippedCount)';
}

class AppDatabase {
  static const String _databaseName = 'thpt_english.db';
  static const int _databaseVersion = 1;

  AppDatabase._internal();
  static final AppDatabase instance = AppDatabase._internal();

  @visibleForTesting
  static AppDatabase withDatabase(Database db) {
    final appDb = AppDatabase._internal();
    appDb._database = db;
    return appDb;
  }

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
    await db.insert('app_settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
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

  Future<int> insertMissingQuestions(List<Question> questions) async {
    final db = await database;

    return db.transaction((txn) async {
      int insertedCount = 0;

      for (final question in questions) {
        final result = await txn.insert(
          'questions',
          question.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );

        if (result != -1) {
          insertedCount++;
        }
      }

      return insertedCount;
    });
  }

  /// Đồng bộ câu hỏi an toàn (Safe Selective Sync)
  /// - Thêm mới hoàn toàn nếu chưa tồn tại
  /// - Nếu câu hỏi đã có trong attempt_answers hoặc wrong_book: KHÔNG đổi id, stem, options, correctIndex, type, grade, topicId, passageId
  /// - Chỉ cập nhật explanation và difficulty nếu có thay đổi
  /// - Nếu câu hỏi chưa có trong lịch sử: cho phép cập nhật đầy đủ nếu có thay đổi
  /// - Idempotent: chạy lại cùng dữ liệu không ghi đè thừa
  /// - Ghi nhận targetVersion vào app_settings chỉ khi transaction thành công
  Future<QuestionSyncResult> syncQuestionsSafe(
    List<Question> questions, {
    String? targetVersion,
  }) async {
    final db = await database;

    return db.transaction((txn) async {
      // 1. Kiểm tra phiên bản nếu có targetVersion
      if (targetVersion != null && targetVersion.isNotEmpty) {
        final versionResults = await txn.query(
          'app_settings',
          columns: ['value'],
          where: 'key = ?',
          whereArgs: ['questions_sync_version'],
          limit: 1,
        );

        if (versionResults.isNotEmpty) {
          final currentVersion = versionResults.first['value'] as String?;
          if (currentVersion == targetVersion) {
            // Xác nhận trạng thái dữ liệu phù hợp trước khi bỏ qua
            final count = Sqflite.firstIntValue(
              await txn.rawQuery('SELECT COUNT(*) FROM questions'),
            );
            if ((count ?? 0) >= questions.length) {
              return const QuestionSyncResult(
                insertedCount: 0,
                updatedCount: 0,
                skippedCount: 0,
              );
            }
          }
        }
      }

      // 2. Lấy dữ liệu câu hỏi hiện có trong DB
      final existingRows = await txn.query('questions');
      final existingMap = <String, Map<String, dynamic>>{
        for (final row in existingRows) row['id'] as String: row,
      };

      // 3. Lấy tập hợp ID câu hỏi đã có trong attempt_answers hoặc wrong_book
      final attemptRows = await txn.rawQuery(
        'SELECT DISTINCT questionId FROM attempt_answers',
      );
      final wrongRows = await txn.rawQuery(
        'SELECT DISTINCT questionId FROM wrong_book',
      );

      final lockedQuestionIds = <String>{
        for (final row in attemptRows) row['questionId'] as String,
        for (final row in wrongRows) row['questionId'] as String,
      };

      int insertedCount = 0;
      int updatedCount = 0;
      int skippedCount = 0;

      for (final q in questions) {
        final existing = existingMap[q.id];

        if (existing == null) {
          // Yêu cầu 1: Câu hỏi mới chưa có trong SQLite -> Thêm đầy đủ
          await txn.insert(
            'questions',
            q.toMap(),
            conflictAlgorithm: ConflictAlgorithm.abort,
          );
          insertedCount++;
        } else {
          final isLocked = lockedQuestionIds.contains(q.id);

          if (!isLocked) {
            // Yêu cầu 3: Chưa xuất hiện trong cả 2 bảng -> cập nhật theo JSON nếu có thay đổi
            final newMap = q.toMap();
            bool hasChanged = false;
            for (final entry in newMap.entries) {
              if (entry.key == 'options') {
                if (!_areOptionsEqual(existing['options'], q.options)) {
                  hasChanged = true;
                  break;
                }
              } else if (existing[entry.key] != entry.value) {
                hasChanged = true;
                break;
              }
            }

            if (hasChanged) {
              await txn.update(
                'questions',
                newMap,
                where: 'id = ?',
                whereArgs: [q.id],
              );
              updatedCount++;
            } else {
              skippedCount++;
            }
          } else {
            // Yêu cầu 4: Đã có trong lịch sử (attempt_answers hoặc wrong_book)
            // Không đổi: id, stem, options, correctIndex, type, grade, topicId, passageId
            // Chỉ cập nhật: explanation và difficulty khi có thay đổi
            bool hasChanged = false;
            final updates = <String, dynamic>{};

            if (existing['explanation'] != q.explanation) {
              updates['explanation'] = q.explanation;
              hasChanged = true;
            }
            if (existing['difficulty'] != q.difficulty) {
              updates['difficulty'] = q.difficulty;
              hasChanged = true;
            }

            if (hasChanged) {
              await txn.update(
                'questions',
                updates,
                where: 'id = ?',
                whereArgs: [q.id],
              );
              updatedCount++;
            } else {
              skippedCount++;
            }
          }
        }
      }

      // 4. Chỉ ghi nhận phiên bản mới khi toàn bộ transaction thành công
      if (targetVersion != null && targetVersion.isNotEmpty) {
        await txn.insert(
          'app_settings',
          {
            'key': 'questions_sync_version',
            'value': targetVersion,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      return QuestionSyncResult(
        insertedCount: insertedCount,
        updatedCount: updatedCount,
        skippedCount: skippedCount,
      );
    });
  }

  bool _areOptionsEqual(dynamic storedOptions, List<String> newOptions) {
    if (storedOptions is String) {
      try {
        final decoded = jsonDecode(storedOptions);
        if (decoded is List) {
          if (decoded.length != newOptions.length) return false;
          for (int i = 0; i < decoded.length; i++) {
            if (decoded[i].toString() != newOptions[i]) return false;
          }
          return true;
        }
      } catch (_) {
        return false;
      }
    } else if (storedOptions is List) {
      if (storedOptions.length != newOptions.length) return false;
      for (int i = 0; i < storedOptions.length; i++) {
        if (storedOptions[i].toString() != newOptions[i]) return false;
      }
      return true;
    }
    return false;
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
    final existing = await db.query(
      'wrong_book',
      where: 'questionId = ?',
      whereArgs: [entry.questionId],
      limit: 1,
    );

    if (existing.isEmpty) {
      await db.insert(
        'wrong_book',
        entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      final currentCount = (existing.first['wrongCount'] as num).toInt();
      final addedCount = entry.wrongCount > 0 ? entry.wrongCount : 1;
      await db.update(
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
  }

  Future<List<WrongBookEntry>> getDueWrongBookEntries(
    int beforeOrAtTimestamp,
  ) async {
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
    final existing = await db.query(
      'daily_stats',
      where: 'date = ?',
      whereArgs: [stat.date],
      limit: 1,
    );

    if (existing.isEmpty) {
      await db.insert(
        'daily_stats',
        stat.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      final row = existing.first;
      await db.update(
        'daily_stats',
        {
          'xp': (row['xp'] as num).toInt() + stat.xp,
          'questionsDone':
              (row['questionsDone'] as num).toInt() + stat.questionsDone,
          'correct': (row['correct'] as num).toInt() + stat.correct,
          'minutes': (row['minutes'] as num).toInt() + stat.minutes,
        },
        where: 'date = ?',
        whereArgs: [stat.date],
      );
    }
  }

  Future<List<DailyStat>> getDailyStatsInRange(
    String startDate,
    String endDate,
  ) async {
    final db = await database;
    final maps = await db.query(
      'daily_stats',
      where: 'date >= ? AND date <= ?',
      whereArgs: [startDate, endDate],
      orderBy: 'date ASC',
    );
    return maps.map(DailyStat.fromMap).toList();
  }

  Future<void> savePracticeResult({
    required Attempt attempt,
    required List<AttemptAnswer> Function(int attemptId) buildAnswers,
    required List<WrongBookEntry> wrongEntries,
    required DailyStat dailyStat,
  }) async {
    final db = await database;

    await db.transaction((txn) async {
      // 1. Lưu lượt làm bài.
      final attemptId = await txn.insert('attempts', attempt.toMap());

      // 2. Lưu từng đáp án.
      final answers = buildAnswers(attemptId);

      final batch = txn.batch();
      for (final answer in answers) {
        batch.insert('attempt_answers', answer.toMap());
      }
      await batch.commit(noResult: true);

      // 3. Cộng dồn số lần trả lời sai.
      for (final entry in wrongEntries) {
        await txn.rawInsert(
          '''
          INSERT INTO wrong_book (
            questionId, wrongCount, lastWrongAt, nextReviewAt
          )
          VALUES (?, ?, ?, ?)
          ON CONFLICT(questionId) DO UPDATE SET
            wrongCount = wrongCount + excluded.wrongCount,
            lastWrongAt = excluded.lastWrongAt,
            nextReviewAt = excluded.nextReviewAt
        ''',
          [
            entry.questionId,
            entry.wrongCount,
            entry.lastWrongAt,
            entry.nextReviewAt,
          ],
        );
      }

      // 4. Cộng dồn thống kê trong ngày.
      await txn.rawInsert(
        '''
        INSERT INTO daily_stats (
          date, xp, questionsDone, correct, minutes
        )
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(date) DO UPDATE SET
          xp = xp + excluded.xp,
          questionsDone = questionsDone + excluded.questionsDone,
          correct = correct + excluded.correct,
          minutes = minutes + excluded.minutes
      ''',
        [
          dailyStat.date,
          dailyStat.xp,
          dailyStat.questionsDone,
          dailyStat.correct,
          dailyStat.minutes,
        ],
      );
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
