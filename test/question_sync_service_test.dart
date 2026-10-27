import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:thpt_english/data/app_database.dart';
import 'package:thpt_english/data/app_repository.dart';
import 'package:thpt_english/data/models/question.dart';
import 'package:thpt_english/data/question_sync_service.dart';

/// Fake SQLite Database cho Unit Test đồng bộ câu hỏi
class InMemoryTestDatabase implements Database {
  Map<String, Map<String, dynamic>> questions = {};
  List<Map<String, dynamic>> attemptAnswers = [];
  Map<String, Map<String, dynamic>> wrongBook = {};
  Map<String, String> appSettings = {};
  List<Map<String, dynamic>> attempts = [];

  bool shouldFailTransaction = false;

  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool? exclusive,
  }) async {
    // Snapshot để rollback nếu transaction lỗi
    final questionsSnapshot = {
      for (final e in questions.entries) e.key: Map<String, dynamic>.from(e.value),
    };
    final attemptAnswersSnapshot = attemptAnswers
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final wrongBookSnapshot = {
      for (final e in wrongBook.entries) e.key: Map<String, dynamic>.from(e.value),
    };
    final appSettingsSnapshot = Map<String, String>.from(appSettings);

    final txn = _InMemoryTestTxn(this);

    try {
      if (shouldFailTransaction) {
        throw Exception('Mô phỏng lỗi giao dịch SQLite!');
      }
      final result = await action(txn);
      return result;
    } catch (e) {
      // Rollback snapshot
      questions = questionsSnapshot;
      attemptAnswers = attemptAnswersSnapshot;
      wrongBook = wrongBookSnapshot;
      appSettings = appSettingsSnapshot;
      rethrow;
    }
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    return _queryInternal(table, where: where, whereArgs: whereArgs);
  }

  List<Map<String, Object?>> _queryInternal(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) {
    if (table == 'questions') {
      return questions.values.toList();
    } else if (table == 'app_settings') {
      if (where == 'key = ?' && whereArgs != null && whereArgs.isNotEmpty) {
        final key = whereArgs.first.toString();
        if (appSettings.containsKey(key)) {
          return [
            {'key': key, 'value': appSettings[key]},
          ];
        }
        return [];
      }
      return appSettings.entries
          .map((e) => {'key': e.key, 'value': e.value})
          .toList();
    }
    return [];
  }

  Future<String?> getSetting(String key) async => appSettings[key];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _InMemoryTestTxn implements Transaction {
  final InMemoryTestDatabase db;
  _InMemoryTestTxn(this.db);

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    return db._queryInternal(table, where: where, whereArgs: whereArgs);
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    final cleanSql = sql.trim().toUpperCase();

    if (cleanSql.contains('DISTINCT QUESTIONID FROM ATTEMPT_ANSWERS')) {
      final ids = db.attemptAnswers
          .map((e) => e['questionId'] as String)
          .toSet();
      return ids.map((id) => {'questionId': id}).toList();
    } else if (cleanSql.contains('DISTINCT QUESTIONID FROM WRONG_BOOK')) {
      final ids = db.wrongBook.keys.toSet();
      return ids.map((id) => {'questionId': id}).toList();
    } else if (cleanSql.contains('COUNT(*) FROM QUESTIONS')) {
      return [
        {'COUNT(*)': db.questions.length},
      ];
    }
    return [];
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    if (table == 'questions') {
      final id = values['id'] as String;
      if (db.questions.containsKey(id) &&
          conflictAlgorithm == ConflictAlgorithm.abort) {
        throw Exception('Duplicate primary key in questions: $id');
      }
      db.questions[id] = Map<String, dynamic>.from(values);
      return 1;
    } else if (table == 'app_settings') {
      final key = values['key'] as String;
      final val = values['value'] as String;
      db.appSettings[key] = val;
      return 1;
    }
    return 1;
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    if (table == 'questions') {
      final id = whereArgs?.first as String;
      if (db.questions.containsKey(id)) {
        final existing = db.questions[id]!;
        for (final entry in values.entries) {
          existing[entry.key] = entry.value;
        }
        return 1;
      }
    }
    return 0;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late InMemoryTestDatabase fakeDb;
  late AppDatabase appDb;
  late AppRepository repository;

  setUp(() {
    fakeDb = InMemoryTestDatabase();
    appDb = AppDatabase.withDatabase(fakeDb);
    repository = AppRepository(db: appDb);
  });

  const sampleQuestion1 = Question(
    id: 'q_01',
    grade: 12,
    type: 'grammar',
    stem: 'Original stem 1',
    options: ['A', 'B', 'C', 'D'],
    correctIndex: 0,
    explanation: 'Original explanation 1',
    difficulty: 1,
  );

  const sampleQuestion2 = Question(
    id: 'q_02',
    grade: 12,
    type: 'vocab',
    stem: 'Original stem 2',
    options: ['X', 'Y', 'Z', 'W'],
    correctIndex: 1,
    explanation: 'Original explanation 2',
    difficulty: 2,
  );

  test('1. Database rỗng nạp được câu hỏi đầy đủ', () async {
    final result = await repository.syncQuestionsSafe([
      sampleQuestion1,
      sampleQuestion2,
    ]);

    expect(result.insertedCount, 2);
    expect(result.updatedCount, 0);
    expect(fakeDb.questions.length, 2);
    expect(fakeDb.questions['q_01']!['stem'], 'Original stem 1');
    expect(fakeDb.questions['q_02']!['stem'], 'Original stem 2');
  });

  test('2. Thêm câu hỏi mới không tạo bản ghi trùng', () async {
    // Nạp lần 1
    await repository.syncQuestionsSafe([sampleQuestion1]);
    expect(fakeDb.questions.length, 1);

    // Thêm câu mới q_02
    final result = await repository.syncQuestionsSafe([
      sampleQuestion1,
      sampleQuestion2,
    ]);

    expect(result.insertedCount, 1);
    expect(result.skippedCount, 1);
    expect(fakeDb.questions.length, 2);
    expect(fakeDb.questions.containsKey('q_01'), isTrue);
    expect(fakeDb.questions.containsKey('q_02'), isTrue);
  });

  test('3. Câu chưa có lịch sử được cập nhật đầy đủ khi nội dung JSON thay đổi', () async {
    await repository.syncQuestionsSafe([sampleQuestion1]);

    const updatedQuestion1 = Question(
      id: 'q_01',
      grade: 12,
      type: 'grammar',
      stem: 'Updated stem for q_01',
      options: ['A_new', 'B_new', 'C_new', 'D_new'],
      correctIndex: 2,
      explanation: 'Updated explanation 1',
      difficulty: 3,
    );

    final result = await repository.syncQuestionsSafe([updatedQuestion1]);

    expect(result.insertedCount, 0);
    expect(result.updatedCount, 1);

    final saved = fakeDb.questions['q_01']!;
    expect(saved['stem'], 'Updated stem for q_01');
    expect(saved['correctIndex'], 2);
    expect(saved['explanation'], 'Updated explanation 1');
    expect(saved['difficulty'], 3);
  });

  test('4. Câu đã có attempt_answers được bảo vệ: không đổi stem, options, correctIndex; chỉ cập nhật explanation/difficulty', () async {
    // Nạp câu hỏi ban đầu
    await repository.syncQuestionsSafe([sampleQuestion1]);

    // Giả lập học sinh đã làm câu q_01
    fakeDb.attemptAnswers.add({
      'attemptId': 100,
      'questionId': 'q_01',
      'chosenIndex': 0,
      'isCorrect': 1,
    });

    // Cố tình thay đổi stem, options, correctIndex, explanation, difficulty trong JSON
    const modifiedAttemptedQuestion = Question(
      id: 'q_01',
      grade: 12,
      type: 'grammar',
      stem: 'HACKED STEM',
      options: ['B', 'A', 'C', 'D'], // hoán đổi options
      correctIndex: 1, // đổi đáp án sang 1
      explanation: 'New refined explanation for history review',
      difficulty: 3,
    );

    final result = await repository.syncQuestionsSafe([
      modifiedAttemptedQuestion,
    ]);

    expect(result.updatedCount, 1);

    final saved = fakeDb.questions['q_01']!;
    // STEM và OPTIONS và CORRECTINDEX KHÔNG ĐƯỢC PHÉP THAY ĐỔI
    expect(saved['stem'], 'Original stem 1');
    expect(saved['options'], '["A","B","C","D"]');
    expect(saved['correctIndex'], 0);

    // CHỈ CẬP NHẬT EXPLANATION VÀ DIFFICULTY
    expect(saved['explanation'], 'New refined explanation for history review');
    expect(saved['difficulty'], 3);
  });

  test('5. Câu chỉ có trong wrong_book cũng được bảo vệ tương tự', () async {
    await repository.syncQuestionsSafe([sampleQuestion1]);

    // Giả lập câu q_01 chỉ có trong Sổ câu sai (chưa có trong attempt_answers)
    fakeDb.wrongBook['q_01'] = {
      'questionId': 'q_01',
      'wrongCount': 2,
      'lastWrongAt': 1234567,
      'nextReviewAt': 2345678,
    };

    const modifiedWrongQuestion = Question(
      id: 'q_01',
      grade: 12,
      type: 'grammar',
      stem: 'CHANGED WRONG STEM',
      options: ['Z1', 'Z2', 'Z3', 'Z4'],
      correctIndex: 3,
      explanation: 'Explanation updated for wrong book review',
      difficulty: 2,
    );

    final result = await repository.syncQuestionsSafe([modifiedWrongQuestion]);

    expect(result.updatedCount, 1);

    final saved = fakeDb.questions['q_01']!;
    expect(saved['stem'], 'Original stem 1');
    expect(saved['options'], '["A","B","C","D"]');
    expect(saved['correctIndex'], 0);
    expect(saved['explanation'], 'Explanation updated for wrong book review');
  });

  test('6. Lịch sử và sổ câu sai vẫn giữ nguyên sau đồng bộ', () async {
    await repository.syncQuestionsSafe([sampleQuestion1, sampleQuestion2]);

    fakeDb.attemptAnswers.add({
      'attemptId': 1,
      'questionId': 'q_01',
      'chosenIndex': 0,
      'isCorrect': 1,
    });
    fakeDb.wrongBook['q_02'] = {
      'questionId': 'q_02',
      'wrongCount': 1,
      'lastWrongAt': 9999,
      'nextReviewAt': 8888,
    };

    // Chạy đồng bộ
    await repository.syncQuestionsSafe([sampleQuestion1, sampleQuestion2]);

    // Kiểm tra tính toàn vẹn
    expect(fakeDb.attemptAnswers.length, 1);
    expect(fakeDb.attemptAnswers.first['chosenIndex'], 0);
    expect(fakeDb.wrongBook.length, 1);
    expect(fakeDb.wrongBook['q_02']!['wrongCount'], 1);
  });

  test('7. Chạy đồng bộ nhiều lần với cùng dữ liệu có tính idempotent (không ghi dữ liệu thừa)', () async {
    // Lần 1: nạp 2 câu
    final res1 = await repository.syncQuestionsSafe([
      sampleQuestion1,
      sampleQuestion2,
    ]);
    expect(res1.insertedCount, 2);
    expect(res1.updatedCount, 0);

    // Lần 2: chạy lại với đúng dữ liệu đó
    final res2 = await repository.syncQuestionsSafe([
      sampleQuestion1,
      sampleQuestion2,
    ]);
    expect(res2.insertedCount, 0);
    expect(res2.updatedCount, 0);
    expect(res2.skippedCount, 2);

    // Lần 3: chạy lại với targetVersion
    final res3 = await repository.syncQuestionsSafe(
      [sampleQuestion1, sampleQuestion2],
      targetVersion: '1.0.0',
    );
    expect(res3.insertedCount, 0);
    expect(res3.updatedCount, 0);

    // Lần 4: cùng targetVersion sẽ bỏ qua tức thì
    final res4 = await repository.syncQuestionsSafe(
      [sampleQuestion1, sampleQuestion2],
      targetVersion: '1.0.0',
    );
    expect(res4.insertedCount, 0);
    expect(res4.updatedCount, 0);
    expect(res4.skippedCount, 0);
  });

  test('8. Khi transaction thất bại, không ghi nhận phiên bản đồng bộ thành công', () async {
    // Database rỗng, cố tình kích hoạt lỗi transaction
    fakeDb.shouldFailTransaction = true;

    expect(
      () => repository.syncQuestionsSafe(
        [sampleQuestion1],
        targetVersion: 'fail_version_999',
      ),
      throwsException,
    );

    // Phiên bản KHÔNG được ghi vào app_settings
    expect(fakeDb.appSettings['questions_sync_version'], isNull);
    // Bảng questions không bị lưu bừa
    expect(fakeDb.questions.isEmpty, isTrue);
  });

  test('9. QuestionSyncService hỗ trợ đồng bộ từ chuỗi JSON an toàn', () async {
    const jsonStr = '''
    [
      {
        "id": "q_json_1",
        "grade": 12,
        "type": "grammar",
        "stem": "JSON stem test",
        "options": ["One", "Two", "Three", "Four"],
        "correctIndex": 0,
        "explanation": "JSON expl",
        "difficulty": 1
      }
    ]
    ''';

    final result = await QuestionSyncService.syncQuestionsFromJson(
      repository,
      jsonStr,
      targetVersion: 'v_json_1',
    );

    expect(result.insertedCount, 1);
    expect(fakeDb.questions.containsKey('q_json_1'), isTrue);
    expect(fakeDb.appSettings['questions_sync_version'], 'v_json_1');
  });
}
