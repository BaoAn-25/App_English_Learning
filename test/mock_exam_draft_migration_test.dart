import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:thpt_english/data/app_database.dart';
import 'package:thpt_english/data/models/mock_exam_draft.dart';
import 'package:thpt_english/data/models/question.dart';
import 'support/sqlite_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'v2 upgrade preserves learning progress and draft survives reopening the file',
    () async {
      final dir = await Directory.systemTemp.createTemp('tai-exam-v2-');
      addTearDown(() => dir.delete(recursive: true));
      final bridge = await SqliteBridge.start(databaseDirectory: dir.path);
      addTearDown(bridge.close);
      final path = p.join(dir.path, 'thpt_english.db');
      final legacy = await openDatabase(path);
      for (final sql in (await File(
        'test/fixtures/database_v2.sql',
      ).readAsString()).split(';')) {
        if (sql.trim().isNotEmpty) await legacy.execute(sql);
      }
      const question = Question(
        id: 'q1',
        grade: 12,
        type: 'grammar',
        stem: 'Persist me',
        options: ['yes', 'no'],
        correctIndex: 0,
        explanation: '',
        difficulty: 1,
      );
      await legacy.insert('questions', question.toMap());
      await legacy.rawInsert(
        "INSERT INTO word_progress VALUES ('w1', 7, 3, 500, 300)",
      );
      await legacy.rawInsert(
        "INSERT INTO attempts VALUES (4, 'practice', 'grammar', 100, 40, 1, 1)",
      );
      await legacy.rawInsert(
        "INSERT INTO attempt_answers VALUES (4, 'q1', 0, 1)",
      );
      await legacy.rawInsert(
        "INSERT INTO daily_stats VALUES ('2026-10-28', 20, 2, 2, 1)",
      );
      await legacy.rawInsert(
        "INSERT INTO app_settings VALUES ('daily_goal', '35')",
      );
      const tables = [
        'topics',
        'words',
        'questions',
        'attempts',
        'attempt_answers',
        'wrong_book',
        'daily_stats',
        'app_settings',
        'word_progress',
      ];
      final before = <String, List<Map<String, Object?>>>{};
      for (final table in tables) {
        before[table] = await legacy.query(table);
      }
      expect(await legacy.getVersion(), 2);
      await legacy.close();
      final db = await AppDatabase.instance.database;
      expect(await db.getVersion(), 3);
      for (final table in tables) {
        expect(await db.query(table), before[table], reason: table);
      }
      expect(await db.query('exam_completions'), isEmpty);
      final draft = MockExamDraft.start(
        questions: [question],
        durationMinutes: 10,
        now: DateTime.now(),
      );
      await AppDatabase.instance.createExamDraft(draft);
      final saved = await AppDatabase.instance.updateExamDraft(
        draft.copyWith(answers: [0], flagged: [0]),
      );
      await db.close();
      final reopened = await openDatabase(path, version: 3);
      addTearDown(reopened.close);
      final newApp = AppDatabase.withDatabase(reopened);
      expect((await newApp.getExamDraft())!.toJson(), saved.toJson());
      final result = await newApp.completeExamDraft(saved.id);
      expect(result.id, greaterThan(4));
      expect(await newApp.getExamDraft(), isNull);
      expect(await reopened.query('word_progress'), before['word_progress']);
    },
  );
}
