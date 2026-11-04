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
import 'models/word_progress.dart';
import 'models/wrong_book_entry.dart';
import 'models/interest_topic.dart';
import 'models/interest_word.dart';
import 'models/ipa_sound.dart';
import 'models/minimal_pair_question.dart';

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

/// Kết quả chuyển giao dữ liệu từ phiên khách sang tài khoản đã xác thực
class TransferResult {
  final int transferredAttempts;
  final int transferredWrongs;
  final int transferredWords;
  final int transferredStats;
  final bool success;
  final String? message;

  const TransferResult({
    this.transferredAttempts = 0,
    this.transferredWrongs = 0,
    this.transferredWords = 0,
    this.transferredStats = 0,
    this.success = true,
    this.message,
  });

  int get totalTransferred =>
      transferredAttempts + transferredWrongs + transferredWords + transferredStats;

  factory TransferResult.empty() => const TransferResult(
        transferredAttempts: 0,
        transferredWrongs: 0,
        transferredWords: 0,
        transferredStats: 0,
        success: true,
      );

  @override
  String toString() =>
      'TransferResult(attempts: $transferredAttempts, wrongs: $transferredWrongs, words: $transferredWords, stats: $transferredStats, success: $success)';
}

class AppDatabase {
  static const String _databaseName = 'thpt_english.db';
  static const int _databaseVersion = 5;

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
      onUpgrade: _onUpgrade,
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

    // 4. Attempts (có ownerId phân lập dữ liệu người dùng)
    await db.execute('''
      CREATE TABLE attempts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ownerId TEXT NOT NULL DEFAULT '',
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

    // 6. Wrong Book Entries (khóa kép: questionId + ownerId)
    await db.execute('''
      CREATE TABLE wrong_book (
        questionId TEXT NOT NULL,
        ownerId TEXT NOT NULL DEFAULT '',
        wrongCount INTEGER NOT NULL,
        lastWrongAt INTEGER NOT NULL,
        nextReviewAt INTEGER NOT NULL,
        PRIMARY KEY (questionId, ownerId)
      )
    ''');

    // 7. Daily Stats (khóa kép: date + ownerId)
    await db.execute('''
      CREATE TABLE daily_stats (
        date TEXT NOT NULL,
        ownerId TEXT NOT NULL DEFAULT '',
        xp INTEGER NOT NULL,
        questionsDone INTEGER NOT NULL,
        correct INTEGER NOT NULL,
        minutes INTEGER NOT NULL,
        PRIMARY KEY (date, ownerId)
      )
    ''');

    // 8. App Settings
    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // 9. Word Progress (SRS) (khóa kép: wordId + ownerId)
    await _createWordProgressTable(db);

    // 10. Data Ownership (tách biệt dữ liệu khách & tài khoản)
    await _createDataOwnershipTable(db);

    // Cài đặt mặc định ban đầu
    final batch = db.batch();
    batch.insert('app_settings', {'key': 'daily_goal', 'value': '20'});
    batch.insert('app_settings', {'key': 'streak_freeze_left', 'value': '2'});
    batch.insert('app_settings', {'key': 'grade', 'value': '12'});
    await batch.commit(noResult: true);
  }

  Future<void> _createWordProgressTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS word_progress (
        wordId TEXT NOT NULL,
        ownerId TEXT NOT NULL DEFAULT '',
        reviewCount INTEGER NOT NULL DEFAULT 0,
        streak INTEGER NOT NULL DEFAULT 0,
        nextReviewAt INTEGER NOT NULL,
        lastReviewedAt INTEGER NOT NULL,
        PRIMARY KEY (wordId, ownerId)
      )
    ''');
  }

  Future<void> _createDataOwnershipTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS data_ownership (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entityType TEXT NOT NULL,
        entityKey TEXT NOT NULL,
        ownerId TEXT NOT NULL,
        createdAt INTEGER NOT NULL,
        UNIQUE(entityType, entityKey, ownerId)
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createWordProgressTable(db);
    }
    if (oldVersion < 3) {
      await _createDataOwnershipTable(db);
    }
    if (oldVersion < 4) {
      await _migrateToV4(db);
    }
    if (oldVersion < 5) {
      await _createExploreAndPronunciationTables(db);
    }
  }

  /// Nâng cấp sang Version 4: chuyển daily_stats, wrong_book, word_progress
  /// sang khóa chính kép kết hợp ownerId và thêm ownerId vào attempts để chống ghi đè chéo.
  Future<void> _migrateToV4(Database db) async {
    // 1. Thêm cột ownerId vào attempts nếu chưa có
    final attemptCols = await db.rawQuery('PRAGMA table_info(attempts)');
    final hasAttemptOwner = attemptCols.any((c) => c['name'] == 'ownerId');
    if (!hasAttemptOwner) {
      await db.execute("ALTER TABLE attempts ADD COLUMN ownerId TEXT NOT NULL DEFAULT ''");
      await db.execute('''
        UPDATE attempts
        SET ownerId = (
          SELECT ownerId FROM data_ownership
          WHERE data_ownership.entityType = 'attempt'
            AND data_ownership.entityKey = CAST(attempts.id AS TEXT)
          LIMIT 1
        )
        WHERE EXISTS (
          SELECT 1 FROM data_ownership
          WHERE data_ownership.entityType = 'attempt'
            AND data_ownership.entityKey = CAST(attempts.id AS TEXT)
        )
      ''');
    }

    // 2. Chuyển daily_stats sang khóa kép (date, ownerId)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS daily_stats_v4 (
        date TEXT NOT NULL,
        ownerId TEXT NOT NULL DEFAULT '',
        xp INTEGER NOT NULL,
        questionsDone INTEGER NOT NULL,
        correct INTEGER NOT NULL,
        minutes INTEGER NOT NULL,
        PRIMARY KEY (date, ownerId)
      )
    ''');
    await db.execute('''
      INSERT OR REPLACE INTO daily_stats_v4 (date, ownerId, xp, questionsDone, correct, minutes)
      SELECT
        d.date,
        COALESCE((
          SELECT o.ownerId FROM data_ownership o
          WHERE o.entityType = 'daily_stat' AND o.entityKey = d.date
          LIMIT 1
        ), ''),
        d.xp,
        d.questionsDone,
        d.correct,
        d.minutes
      FROM daily_stats d
    ''');
    await db.execute('DROP TABLE daily_stats');
    await db.execute('ALTER TABLE daily_stats_v4 RENAME TO daily_stats');

    // 3. Chuyển wrong_book sang khóa kép (questionId, ownerId)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS wrong_book_v4 (
        questionId TEXT NOT NULL,
        ownerId TEXT NOT NULL DEFAULT '',
        wrongCount INTEGER NOT NULL,
        lastWrongAt INTEGER NOT NULL,
        nextReviewAt INTEGER NOT NULL,
        PRIMARY KEY (questionId, ownerId)
      )
    ''');
    await db.execute('''
      INSERT OR REPLACE INTO wrong_book_v4 (questionId, ownerId, wrongCount, lastWrongAt, nextReviewAt)
      SELECT
        w.questionId,
        COALESCE((
          SELECT o.ownerId FROM data_ownership o
          WHERE o.entityType = 'wrong_book' AND o.entityKey = w.questionId
          LIMIT 1
        ), ''),
        w.wrongCount,
        w.lastWrongAt,
        w.nextReviewAt
      FROM wrong_book w
    ''');
    await db.execute('DROP TABLE wrong_book');
    await db.execute('ALTER TABLE wrong_book_v4 RENAME TO wrong_book');

    // 4. Chuyển word_progress sang khóa kép (wordId, ownerId)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS word_progress_v4 (
        wordId TEXT NOT NULL,
        ownerId TEXT NOT NULL DEFAULT '',
        reviewCount INTEGER NOT NULL DEFAULT 0,
        streak INTEGER NOT NULL DEFAULT 0,
        nextReviewAt INTEGER NOT NULL,
        lastReviewedAt INTEGER NOT NULL,
        PRIMARY KEY (wordId, ownerId)
      )
    ''');
    await db.execute('''
      INSERT OR REPLACE INTO word_progress_v4 (wordId, ownerId, reviewCount, streak, nextReviewAt, lastReviewedAt)
      SELECT
        wp.wordId,
        COALESCE((
          SELECT o.ownerId FROM data_ownership o
          WHERE o.entityType = 'word_progress' AND o.entityKey = wp.wordId
          LIMIT 1
        ), ''),
        wp.reviewCount,
        wp.streak,
        wp.nextReviewAt,
        wp.lastReviewedAt
      FROM word_progress wp
    ''');
    await db.execute('DROP TABLE word_progress');
    await db.execute('ALTER TABLE word_progress_v4 RENAME TO word_progress');
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
  static const _legacyTopicIds = {
    'topic_12_unit1': 'topic_12_u1',
    'topic_12_unit2': 'topic_12_u2',
    'topic_12_unit3': 'topic_12_u3',
  };

  // Chỉ gộp khi đọc các cặp ID mẫu đã biết có cùng thông tin chủ đề.
  Map<String, String> _topicAliases(List<Topic> topics) {
    final byId = {for (final topic in topics) topic.id: topic};
    final aliases = <String, String>{};
    for (final pair in _legacyTopicIds.entries) {
      final old = byId[pair.key];
      final current = byId[pair.value];
      if (old != null &&
          current != null &&
          old.grade == current.grade &&
          old.title == current.title &&
          old.order == current.order) {
        aliases[pair.key] = pair.value;
      }
    }
    return aliases;
  }

  List<Topic> _visibleTopics(List<Map<String, Object?>> maps) {
    final topics = maps.map(Topic.fromMap).toList();
    final aliases = _topicAliases(topics);
    return topics.where((topic) => !aliases.containsKey(topic.id)).toList();
  }

  Future<List<String>> _topicIdsForRead(Database db, String topicId) async {
    for (final pair in _legacyTopicIds.entries) {
      if (topicId != pair.key && topicId != pair.value) continue;
      final rows = await db.query(
        'topics',
        where: 'id IN (?, ?)',
        whereArgs: [pair.key, pair.value],
      );
      if (_topicAliases(rows.map(Topic.fromMap).toList()).containsKey(pair.key)) {
        return [pair.key, pair.value];
      }
      break;
    }
    return [topicId];
  }

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
    return _visibleTopics(maps);
  }

  Future<List<Topic>> getTopicsByGrade(int grade) async {
    final db = await database;
    final maps = await db.query(
      'topics',
      where: 'grade = ?',
      whereArgs: [grade],
      orderBy: '"order" ASC',
    );
    return _visibleTopics(maps);
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
    final ids = await _topicIdsForRead(db, topicId);
    final maps = await db.query(
      'words',
      where: 'topicId IN (${List.filled(ids.length, '?').join(', ')})',
      whereArgs: ids,
    );
    return maps.map(Word.fromMap).toList();
  }

  Future<void> insertWord(Word word) async {
    final db = await database;
    await db.insert(
      'words',
      word.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateWord(Word word) async {
    final db = await database;
    await db.update(
      'words',
      word.toMap(),
      where: 'id = ?',
      whereArgs: [word.id],
    );
  }

  Future<void> deleteWord(String wordId) async {
    final db = await database;
    await db.delete(
      'words',
      where: 'id = ?',
      whereArgs: [wordId],
    );
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

  Future<List<Question>> getQuestionsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    final maps = await db.query(
      'questions',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
    final questionMap = {for (final m in maps) m['id'] as String: Question.fromMap(m)};
    return ids.map((id) => questionMap[id]).whereType<Question>().toList();
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

  Future<List<Question>> getQuestionsByTopicId(String topicId) async {
    final db = await database;
    final ids = await _topicIdsForRead(db, topicId);
    final maps = await db.query(
      'questions',
      where: 'topicId IN (${List.filled(ids.length, '?').join(', ')})',
      whereArgs: ids,
    );
    return maps.map(Question.fromMap).toList();
  }

  // --- Attempts ---
  Future<int> insertAttempt(Attempt attempt, {String? ownerId}) async {
    final db = await database;
    final attemptId = await db.insert('attempts', attempt.toMap());
    if (ownerId != null && ownerId.trim().isNotEmpty) {
      await recordOwnership(
        entityType: 'attempt',
        entityKey: attemptId.toString(),
        ownerId: ownerId,
      );
    }
    return attemptId;
  }

  Future<List<Attempt>> getAllAttempts({String? ownerId}) async {
    final db = await database;
    if (ownerId == null || ownerId.trim().isEmpty) {
      final maps = await db.query('attempts');
      return maps.map(Attempt.fromMap).toList();
    }
    final maps = await db.query(
      'attempts',
      where: 'ownerId = ?',
      whereArgs: [ownerId],
    );
    return maps.map(Attempt.fromMap).toList();
  }

  Future<List<Attempt>> getAttempts({String? ownerId, int? limit}) async {
    final db = await database;
    if (ownerId == null || ownerId.trim().isEmpty) {
      final maps = await db.query(
        'attempts',
        orderBy: 'startedAt DESC',
        limit: limit,
      );
      return maps.map(Attempt.fromMap).toList();
    }
    final maps = await db.query(
      'attempts',
      where: 'ownerId = ?',
      whereArgs: [ownerId],
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

  Future<List<AttemptAnswer>> getAllAttemptAnswers({String? ownerId}) async {
    final db = await database;
    if (ownerId == null || ownerId.trim().isEmpty) {
      final maps = await db.query('attempt_answers');
      return maps.map(AttemptAnswer.fromMap).toList();
    }
    final attempts = await getAllAttempts(ownerId: ownerId);
    if (attempts.isEmpty) return [];
    final attemptIds = attempts.map((a) => a.id).toList();
    final maps = await db.query(
      'attempt_answers',
      where: 'attemptId IN (${List.filled(attemptIds.length, '?').join(', ')})',
      whereArgs: attemptIds,
    );
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
  Future<void> insertWrongBookEntries(List<WrongBookEntry> entries, {String? ownerId}) async {
    final db = await database;
    final batch = db.batch();
    for (final entry in entries) {
      final entryMap = Map<String, dynamic>.from(entry.toMap());
      if (ownerId != null && ownerId.isNotEmpty) {
        entryMap['ownerId'] = ownerId;
      } else if (!entryMap.containsKey('ownerId')) {
        entryMap['ownerId'] = '';
      }
      batch.insert(
        'wrong_book',
        entryMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<WrongBookEntry>> getAllWrongBookEntries({String? ownerId}) async {
    final db = await database;
    if (ownerId == null || ownerId.trim().isEmpty) {
      final maps = await db.query('wrong_book');
      return maps.map(WrongBookEntry.fromMap).toList();
    }
    final maps = await db.query(
      'wrong_book',
      where: 'ownerId = ?',
      whereArgs: [ownerId],
    );
    return maps.map(WrongBookEntry.fromMap).toList();
  }

  Future<void> upsertWrongBookEntry(WrongBookEntry entry, {String? ownerId}) async {
    final db = await database;
    final effectiveOwner = ownerId ?? entry.ownerId ?? '';
    await db.transaction((txn) async {
      final existing = await txn.query(
        'wrong_book',
        where: 'questionId = ? AND ownerId = ?',
        whereArgs: [entry.questionId, effectiveOwner],
        limit: 1,
      );

      if (existing.isEmpty) {
        final entryMap = Map<String, dynamic>.from(entry.toMap());
        entryMap['ownerId'] = effectiveOwner;
        await txn.insert(
          'wrong_book',
          entryMap,
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
          where: 'questionId = ? AND ownerId = ?',
          whereArgs: [entry.questionId, effectiveOwner],
        );
      }
    });
  }

  Future<List<WrongBookEntry>> getDueWrongBookEntries(
    int beforeOrAtTimestamp, {
    String? ownerId,
  }) async {
    final db = await database;
    if (ownerId == null || ownerId.trim().isEmpty) {
      final maps = await db.query(
        'wrong_book',
        where: 'nextReviewAt <= ?',
        whereArgs: [beforeOrAtTimestamp],
        orderBy: 'nextReviewAt ASC',
      );
      return maps.map(WrongBookEntry.fromMap).toList();
    }
    final maps = await db.query(
      'wrong_book',
      where: 'nextReviewAt <= ? AND ownerId = ?',
      whereArgs: [beforeOrAtTimestamp, ownerId],
      orderBy: 'nextReviewAt ASC',
    );
    return maps.map(WrongBookEntry.fromMap).toList();
  }

  // --- Daily Stats ---
  Future<void> insertDailyStats(List<DailyStat> stats, {String? ownerId}) async {
    final db = await database;
    final batch = db.batch();
    for (final stat in stats) {
      final statMap = Map<String, dynamic>.from(stat.toMap());
      if (ownerId != null && ownerId.isNotEmpty) {
        statMap['ownerId'] = ownerId;
      } else if (!statMap.containsKey('ownerId')) {
        statMap['ownerId'] = '';
      }
      batch.insert(
        'daily_stats',
        statMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<DailyStat>> getAllDailyStats({String? ownerId}) async {
    final db = await database;
    if (ownerId == null || ownerId.trim().isEmpty) {
      final maps = await db.query('daily_stats', orderBy: 'date ASC');
      return maps.map(DailyStat.fromMap).toList();
    }
    final maps = await db.query(
      'daily_stats',
      where: 'ownerId = ?',
      whereArgs: [ownerId],
      orderBy: 'date ASC',
    );
    return maps.map(DailyStat.fromMap).toList();
  }

  Future<void> upsertDailyStat(DailyStat stat, {String? ownerId}) async {
    final db = await database;
    final effectiveOwner = ownerId ?? stat.ownerId ?? '';
    await db.transaction((txn) async {
      final existing = await txn.query(
        'daily_stats',
        where: 'date = ? AND ownerId = ?',
        whereArgs: [stat.date, effectiveOwner],
        limit: 1,
      );

      if (existing.isEmpty) {
        final statMap = Map<String, dynamic>.from(stat.toMap());
        statMap['ownerId'] = effectiveOwner;
        await txn.insert(
          'daily_stats',
          statMap,
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
          where: 'date = ? AND ownerId = ?',
          whereArgs: [stat.date, effectiveOwner],
        );
      }
    });
  }

  Future<List<DailyStat>> getDailyStatsInRange(
    String startDate,
    String endDate, {
    String? ownerId,
  }) async {
    final db = await database;
    if (ownerId == null || ownerId.trim().isEmpty) {
      final maps = await db.query(
        'daily_stats',
        where: 'date >= ? AND date <= ?',
        whereArgs: [startDate, endDate],
        orderBy: 'date ASC',
      );
      return maps.map(DailyStat.fromMap).toList();
    }
    final maps = await db.query(
      'daily_stats',
      where: 'date >= ? AND date <= ? AND ownerId = ?',
      whereArgs: [startDate, endDate, ownerId],
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
    String? ownerId,
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
    final effectiveOwner = ownerId ?? attempt.ownerId ?? '';

    await db.transaction((txn) async {
      // 1. Lưu lượt làm bài kèm ownerId.
      final attemptMap = Map<String, dynamic>.from(attempt.toMap());
      attemptMap['ownerId'] = effectiveOwner;
      final attemptId = await txn.insert('attempts', attemptMap);

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

      // UPDATE rồi INSERT trong cùng transaction phân lập theo (questionId, ownerId)
      for (final entry in wrongBook) {
        final updated = await txn.rawUpdate(
          'UPDATE wrong_book SET wrongCount = wrongCount + ?, '
          'lastWrongAt = ?, nextReviewAt = ? WHERE questionId = ? AND ownerId = ?',
          [
            entry.wrongCount,
            entry.lastWrongAt,
            entry.nextReviewAt,
            entry.questionId,
            effectiveOwner,
          ],
        );
        if (updated == 0) {
          final entryMap = Map<String, dynamic>.from(entry.toMap());
          entryMap['ownerId'] = effectiveOwner;
          await txn.insert('wrong_book', entryMap);
        }
      }

      // UPDATE rồi INSERT trong cùng transaction phân lập theo (date, ownerId)
      final updated = await txn.rawUpdate(
        'UPDATE daily_stats SET xp = xp + ?, questionsDone = questionsDone + ?, '
        'correct = correct + ?, minutes = minutes + ? WHERE date = ? AND ownerId = ?',
        [
          dailyStat.xp,
          dailyStat.questionsDone,
          dailyStat.correct,
          dailyStat.minutes,
          dailyStat.date,
          effectiveOwner,
        ],
      );
      if (updated == 0) {
        final statMap = Map<String, dynamic>.from(dailyStat.toMap());
        statMap['ownerId'] = effectiveOwner;
        await txn.insert('daily_stats', statMap);
      }

      // Ghi nhận quyền sở hữu dữ liệu nếu có ownerId
      if (effectiveOwner.isNotEmpty) {
        final now = DateTime.now().millisecondsSinceEpoch;
        await txn.insert(
          'data_ownership',
          {
            'entityType': 'attempt',
            'entityKey': attemptId.toString(),
            'ownerId': effectiveOwner,
            'createdAt': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        for (final entry in wrongBook) {
          await txn.insert(
            'data_ownership',
            {
              'entityType': 'wrong_book',
              'entityKey': entry.questionId,
              'ownerId': effectiveOwner,
              'createdAt': now,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await txn.insert(
          'data_ownership',
          {
            'entityType': 'daily_stat',
            'entityKey': dailyStat.date,
            'ownerId': effectiveOwner,
            'createdAt': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  // --- Helper kiểm tra bảng rỗng để seed dữ liệu ---
  Future<bool> isTableEmpty(String tableName) async {
    const tables = {
      'topics',
      'words',
      'questions',
      'attempts',
      'attempt_answers',
      'wrong_book',
      'daily_stats',
      'app_settings',
      'word_progress',
      'data_ownership',
    };
    if (!tables.contains(tableName)) {
      throw ArgumentError.value(tableName, 'tableName', 'Unknown application table');
    }
    final db = await database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $tableName'),
    );
    return (count ?? 0) == 0;
  }

  // --- Word Progress (SRS) ---
  Future<WordProgress?> getWordProgress(String wordId, {String? ownerId}) async {
    final db = await database;
    if (ownerId == null || ownerId.trim().isEmpty) {
      final maps = await db.query(
        'word_progress',
        where: 'wordId = ?',
        whereArgs: [wordId],
        limit: 1,
      );
      if (maps.isEmpty) return null;
      return WordProgress.fromMap(maps.first);
    }
    final maps = await db.query(
      'word_progress',
      where: 'wordId = ? AND ownerId = ?',
      whereArgs: [wordId, ownerId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return WordProgress.fromMap(maps.first);
  }

  Future<List<WordProgress>> getAllWordProgress({String? ownerId}) async {
    final db = await database;
    if (ownerId == null || ownerId.trim().isEmpty) {
      final maps = await db.query('word_progress');
      return maps.map(WordProgress.fromMap).toList();
    }
    final maps = await db.query(
      'word_progress',
      where: 'ownerId = ?',
      whereArgs: [ownerId],
    );
    return maps.map(WordProgress.fromMap).toList();
  }

  Future<void> upsertWordProgress(WordProgress progress, {String? ownerId}) async {
    final db = await database;
    final effectiveOwner = ownerId ?? progress.ownerId ?? '';
    await db.transaction((txn) async {
      final progressMap = Map<String, dynamic>.from(progress.toMap());
      progressMap['ownerId'] = effectiveOwner;
      await txn.insert(
        'word_progress',
        progressMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      if (effectiveOwner.isNotEmpty) {
        await txn.insert(
          'data_ownership',
          {
            'entityType': 'word_progress',
            'entityKey': progress.wordId,
            'ownerId': effectiveOwner,
            'createdAt': DateTime.now().millisecondsSinceEpoch,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  // --- Data Ownership & Guest Data Transfer ---
  Future<void> recordOwnership({
    required String entityType,
    required String entityKey,
    required String ownerId,
    int? createdAt,
    DatabaseExecutor? txn,
  }) async {
    final executor = txn ?? await database;
    await executor.insert(
      'data_ownership',
      {
        'entityType': entityType,
        'entityKey': entityKey,
        'ownerId': ownerId,
        'createdAt': createdAt ?? DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<String>> getEntityKeysByOwner({
    required String entityType,
    required String ownerId,
    DatabaseExecutor? txn,
  }) async {
    final executor = txn ?? await database;
    final rows = await executor.query(
      'data_ownership',
      columns: ['entityKey'],
      where: 'entityType = ? AND ownerId = ?',
      whereArgs: [entityType, ownerId],
    );
    return rows.map((r) => r['entityKey'] as String).toList();
  }

  Future<bool> hasOwnership({
    required String entityType,
    required String entityKey,
    required String ownerId,
    DatabaseExecutor? txn,
  }) async {
    final executor = txn ?? await database;
    final rows = await executor.query(
      'data_ownership',
      columns: ['id'],
      where: 'entityType = ? AND entityKey = ? AND ownerId = ?',
      whereArgs: [entityType, entityKey, ownerId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Chuyển toàn bộ dữ liệu thuộc phiên khách [fromGuestId] sang tài khoản mới [toUserId].
  /// Hoàn toàn atomic qua Transaction. Nếu có lỗi, rollback 100% không mất dữ liệu khách.
  /// Idempotent: chạy nhiều lần không nhân đôi điểm hoặc bản ghi.
  /// Tuyệt đối KHÔNG gán các bản ghi unowned (không có trong data_ownership).
  Future<TransferResult> transferGuestData({
    required String fromGuestId,
    required String toUserId,
  }) async {
    if (fromGuestId == toUserId || fromGuestId.isEmpty || toUserId.isEmpty) {
      return TransferResult.empty();
    }
    final db = await database;
    return await db.transaction((txn) async {
      // 1. Chuyển attempts trực tiếp
      await txn.update(
        'attempts',
        {'ownerId': toUserId},
        where: 'ownerId = ?',
        whereArgs: [fromGuestId],
      );

      // 2. Chuyển daily_stats có merge dữ liệu
      final guestStats = await txn.query(
        'daily_stats',
        where: 'ownerId = ?',
        whereArgs: [fromGuestId],
      );
      for (final gs in guestStats) {
        final date = gs['date'] as String;
        final userStat = await txn.query(
          'daily_stats',
          where: 'date = ? AND ownerId = ?',
          whereArgs: [date, toUserId],
          limit: 1,
        );
        if (userStat.isNotEmpty) {
          final u = userStat.first;
          await txn.update(
            'daily_stats',
            {
              'xp': (u['xp'] as num).toInt() + (gs['xp'] as num).toInt(),
              'questionsDone': (u['questionsDone'] as num).toInt() + (gs['questionsDone'] as num).toInt(),
              'correct': (u['correct'] as num).toInt() + (gs['correct'] as num).toInt(),
              'minutes': (u['minutes'] as num).toInt() + (gs['minutes'] as num).toInt(),
            },
            where: 'date = ? AND ownerId = ?',
            whereArgs: [date, toUserId],
          );
          await txn.delete(
            'daily_stats',
            where: 'date = ? AND ownerId = ?',
            whereArgs: [date, fromGuestId],
          );
        } else {
          await txn.update(
            'daily_stats',
            {'ownerId': toUserId},
            where: 'date = ? AND ownerId = ?',
            whereArgs: [date, fromGuestId],
          );
        }
      }

      // 3. Chuyển wrong_book có merge dữ liệu
      final guestWrongs = await txn.query(
        'wrong_book',
        where: 'ownerId = ?',
        whereArgs: [fromGuestId],
      );
      for (final gw in guestWrongs) {
        final qId = gw['questionId'] as String;
        final userWrong = await txn.query(
          'wrong_book',
          where: 'questionId = ? AND ownerId = ?',
          whereArgs: [qId, toUserId],
          limit: 1,
        );
        if (userWrong.isNotEmpty) {
          final uw = userWrong.first;
          final lastWrongAt = ((uw['lastWrongAt'] as num).toInt() > (gw['lastWrongAt'] as num).toInt())
              ? (uw['lastWrongAt'] as num).toInt()
              : (gw['lastWrongAt'] as num).toInt();
          final nextReviewAt = ((uw['nextReviewAt'] as num).toInt() < (gw['nextReviewAt'] as num).toInt())
              ? (uw['nextReviewAt'] as num).toInt()
              : (gw['nextReviewAt'] as num).toInt();
          await txn.update(
            'wrong_book',
            {
              'wrongCount': (uw['wrongCount'] as num).toInt() + (gw['wrongCount'] as num).toInt(),
              'lastWrongAt': lastWrongAt,
              'nextReviewAt': nextReviewAt,
            },
            where: 'questionId = ? AND ownerId = ?',
            whereArgs: [qId, toUserId],
          );
          await txn.delete(
            'wrong_book',
            where: 'questionId = ? AND ownerId = ?',
            whereArgs: [qId, fromGuestId],
          );
        } else {
          await txn.update(
            'wrong_book',
            {'ownerId': toUserId},
            where: 'questionId = ? AND ownerId = ?',
            whereArgs: [qId, fromGuestId],
          );
        }
      }

      // 4. Chuyển word_progress
      final guestWords = await txn.query(
        'word_progress',
        where: 'ownerId = ?',
        whereArgs: [fromGuestId],
      );
      for (final gword in guestWords) {
        final wId = gword['wordId'] as String;
        final userWord = await txn.query(
          'word_progress',
          where: 'wordId = ? AND ownerId = ?',
          whereArgs: [wId, toUserId],
          limit: 1,
        );
        if (userWord.isNotEmpty) {
          await txn.delete(
            'word_progress',
            where: 'wordId = ? AND ownerId = ?',
            whereArgs: [wId, fromGuestId],
          );
        } else {
          await txn.update(
            'word_progress',
            {'ownerId': toUserId},
            where: 'wordId = ? AND ownerId = ?',
            whereArgs: [wId, fromGuestId],
          );
        }
      }

      final rows = await txn.query(
        'data_ownership',
        where: 'ownerId = ?',
        whereArgs: [fromGuestId],
      );

      int transferredAttempts = 0;
      int transferredWrongs = 0;
      int transferredWords = 0;
      int transferredStats = 0;

      for (final row in rows) {
        final id = row['id'] as int;
        final entityType = row['entityType'] as String;
        final entityKey = row['entityKey'] as String;

        // Kiểm tra xem tài khoản đích đã có ánh xạ cho thực thể này chưa
        final existing = await txn.query(
          'data_ownership',
          where: 'entityType = ? AND entityKey = ? AND ownerId = ?',
          whereArgs: [entityType, entityKey, toUserId],
          limit: 1,
        );

        if (existing.isNotEmpty) {
          // Tránh nhân đôi: xoá ánh xạ khách cũ nếu tài khoản đích đã có
          await txn.delete(
            'data_ownership',
            where: 'id = ?',
            whereArgs: [id],
          );
        } else {
          // Gắn chủ sở hữu mới sang tài khoản thật
          await txn.update(
            'data_ownership',
            {'ownerId': toUserId},
            where: 'id = ?',
            whereArgs: [id],
          );

          switch (entityType) {
            case 'attempt':
              transferredAttempts++;
              break;
            case 'wrong_book':
              transferredWrongs++;
              break;
            case 'word_progress':
              transferredWords++;
              break;
            case 'daily_stat':
              transferredStats++;
              break;
          }
        }
      }

      // Chuyển giao các phiên học dở nếu có (bao gồm cả phiên chung và phiên theo từng lessonId)
      final sessionRows = await txn.query(
        'app_settings',
        where: 'key LIKE ?',
        whereArgs: ['learning_session_$fromGuestId%'],
      );
      for (final sRow in sessionRows) {
        final oldKey = sRow['key'] as String;
        final newKey = oldKey.replaceFirst(
          'learning_session_$fromGuestId',
          'learning_session_$toUserId',
        );
        final sessionVal = sRow['value'] as String;
        await txn.insert(
          'app_settings',
          {'key': newKey, 'value': sessionVal},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await txn.delete(
          'app_settings',
          where: 'key = ?',
          whereArgs: [oldKey],
        );
      }

      // Chuyển giao bài học thử đã hoàn thành (nếu có)
      final completedTrialRow = await txn.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: ['completed_trial_lesson_$fromGuestId'],
        limit: 1,
      );
      if (completedTrialRow.isNotEmpty) {
        final lessonIdVal = completedTrialRow.first['value'] as String;
        await txn.insert(
          'app_settings',
          {'key': 'completed_trial_lesson_$toUserId', 'value': lessonIdVal},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await txn.delete(
          'app_settings',
          where: 'key = ?',
          whereArgs: ['completed_trial_lesson_$fromGuestId'],
        );
      }

      // Chuyển giao bài làm theo trang sách & vở bài làm kỹ năng
      final bookPageRows = await txn.query(
        'app_settings',
        where: 'key LIKE ? OR key LIKE ?',
        whereArgs: ['book_%_owner_${fromGuestId}_page_%', 'unit_skill_note_${fromGuestId}_%'],
      );
      for (final bpRow in bookPageRows) {
        final oldKey = bpRow['key'] as String;
        final newKey = oldKey.replaceFirst(fromGuestId, toUserId);
        final val = bpRow['value'] as String;
        await txn.insert(
          'app_settings',
          {'key': newKey, 'value': val},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await txn.delete(
          'app_settings',
          where: 'key = ?',
          whereArgs: [oldKey],
        );
      }

      return TransferResult(
        transferredAttempts: transferredAttempts,
        transferredWrongs: transferredWrongs,
        transferredWords: transferredWords,
        transferredStats: transferredStats,
        success: true,
      );
    });
  }

  Future<List<WordProgress>> getDueWordProgress({String? ownerId}) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (ownerId == null || ownerId.trim().isEmpty) {
      final maps = await db.rawQuery(
        '''
        SELECT wp.* FROM word_progress wp
        INNER JOIN words w ON wp.wordId = w.id
        WHERE wp.nextReviewAt <= ?
        ORDER BY wp.nextReviewAt ASC
        ''',
        [now],
      );
      return maps.map(WordProgress.fromMap).toList();
    }
    final keys = await getEntityKeysByOwner(entityType: 'word_progress', ownerId: ownerId);
    if (keys.isEmpty) return [];
    final inPlaceholders = List.filled(keys.length, '?').join(', ');
    final maps = await db.rawQuery(
      '''
      SELECT wp.* FROM word_progress wp
      INNER JOIN words w ON wp.wordId = w.id
      WHERE wp.nextReviewAt <= ? AND wp.wordId IN ($inPlaceholders)
      ORDER BY wp.nextReviewAt ASC
      ''',
      [now, ...keys],
    );
    return maps.map(WordProgress.fromMap).toList();
  }

// Dữ liệu code phương thức mới
  Future<void> _createExploreAndPronunciationTables(Database db) async {
    // 11. Bảng 44 âm IPA
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ipa_sounds (
        id TEXT PRIMARY KEY,
        symbol TEXT NOT NULL,
        type TEXT NOT NULL,
        name TEXT NOT NULL,
        exampleWord TEXT NOT NULL,
        exampleIpa TEXT NOT NULL,
        exampleMeaning TEXT NOT NULL,
        audioFile TEXT,
        "order" INTEGER NOT NULL
      )
    ''');

    // 12. Tiến độ luyện phát âm IPA theo người dùng (ownerId)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ipa_progress (
        soundId TEXT NOT NULL,
        ownerId TEXT NOT NULL DEFAULT '',
        masteryLevel INTEGER NOT NULL DEFAULT 0,
        practiceCount INTEGER NOT NULL DEFAULT 0,
        lastPracticedAt INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (soundId, ownerId)
      )
    ''');

    // 13. Câu hỏi cặp âm tối thiểu (Minimal Pairs: dock vs deck)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS minimal_pairs (
        id TEXT PRIMARY KEY,
        soundAId TEXT NOT NULL,
        soundBId TEXT NOT NULL,
        wordA TEXT NOT NULL,
        ipaA TEXT NOT NULL,
        meaningA TEXT NOT NULL,
        wordB TEXT NOT NULL,
        ipaB TEXT NOT NULL,
        meaningB TEXT NOT NULL,
        difficulty INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // 14. Chủ đề sở thích (Interest Topics)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS interest_topics (
        id TEXT PRIMARY KEY,
        categoryId TEXT NOT NULL,
        categoryName TEXT NOT NULL,
        title TEXT NOT NULL,
        titleVi TEXT NOT NULL,
        iconName TEXT NOT NULL,
        description TEXT NOT NULL,
        "order" INTEGER NOT NULL,
        level TEXT NOT NULL DEFAULT 'A1-B1'
      )
    ''');

    // 15. Từ vựng & câu đàm thoại theo sở thích (Interest Words & Phrases)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS interest_words (
        id TEXT PRIMARY KEY,
        topicId TEXT NOT NULL,
        english TEXT NOT NULL,
        ipa TEXT NOT NULL,
        meaningVi TEXT NOT NULL,
        exampleEn TEXT NOT NULL,
        exampleVi TEXT NOT NULL,
        category TEXT NOT NULL DEFAULT 'word',
        "order" INTEGER NOT NULL
      )
    ''');
  }

  // --- CRUD: Bảng ngữ âm IPA & Luyện phát âm ---
  Future<void> insertIpaSounds(List<IpaSound> sounds) async {
    final db = await database;
    final batch = db.batch();
    for (final s in sounds) {
      batch.insert('ipa_sounds', s.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<IpaSound>> getAllIpaSounds({String? ownerId}) async {
    final db = await database;
    final safeOwnerId = ownerId ?? '';
    final results = await db.rawQuery('''
      SELECT s.*, COALESCE(p.masteryLevel, 0) as masteryLevel
      FROM ipa_sounds s
      LEFT JOIN ipa_progress p ON s.id = p.soundId AND p.ownerId = ?
      ORDER BY s."order" ASC
    ''', [safeOwnerId]);

    return results.map((row) {
      final mastery = (row['masteryLevel'] as num?)?.toInt() ?? 0;
      return IpaSound.fromMap(row, mastery: mastery);
    }).toList();
  }

  Future<void> updateIpaMastery(String soundId, String ownerId, int masteryDelta) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.rawInsert('''
      INSERT INTO ipa_progress (soundId, ownerId, masteryLevel, practiceCount, lastPracticedAt)
      VALUES (?, ?, ?, 1, ?)
      ON CONFLICT(soundId, ownerId) DO UPDATE SET
        masteryLevel = MIN(100, MAX(0, masteryLevel + ?)),
        practiceCount = practiceCount + 1,
        lastPracticedAt = ?
    ''', [soundId, ownerId, masteryDelta.clamp(0, 100), now, masteryDelta, now]);
  }

  Future<void> insertMinimalPairs(List<MinimalPairQuestion> pairs) async {
    final db = await database;
    final batch = db.batch();
    for (final p in pairs) {
      batch.insert('minimal_pairs', p.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<MinimalPairQuestion>> getAllMinimalPairs() async {
    final db = await database;
    final results = await db.query('minimal_pairs');
    return results.map(MinimalPairQuestion.fromMap).toList();
  }

  // --- CRUD: Chủ đề sở thích & Từ vựng đàm thoại ---
  Future<void> insertInterestTopics(List<InterestTopic> topics) async {
    final db = await database;
    final batch = db.batch();
    for (final t in topics) {
      batch.insert('interest_topics', t.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<InterestTopic>> getAllInterestTopics() async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT t.*, COUNT(w.id) as wordCount
      FROM interest_topics t
      LEFT JOIN interest_words w ON t.id = w.topicId
      GROUP BY t.id
      ORDER BY t."order" ASC
    ''');
    return results.map((row) {
      final count = (row['wordCount'] as num?)?.toInt() ?? 0;
      return InterestTopic.fromMap(row, wordCount: count);
    }).toList();
  }

  Future<void> insertInterestWords(List<InterestWord> words) async {
    final db = await database;
    final batch = db.batch();
    for (final w in words) {
      batch.insert('interest_words', w.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<InterestWord>> getWordsByInterestTopicId(String topicId) async {
    final db = await database;
    final results = await db.query(
      'interest_words',
      where: 'topicId = ?',
      whereArgs: [topicId],
      orderBy: '"order" ASC',
    );
    return results.map(InterestWord.fromMap).toList();
  }

  Future<List<InterestWord>> getAllInterestWords() async {
    final db = await database;
    final results = await db.query('interest_words', orderBy: '"order" ASC');
    return results.map(InterestWord.fromMap).toList();
  }

}
