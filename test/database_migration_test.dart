import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:thpt_english/data/app_database.dart';

import 'support/sqlite_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'opening persisted v1 preserves every legacy table and adds usable SRS',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'tai-db-migration-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final bridge = await SqliteBridge.start(
        databaseDirectory: directory.path,
      );
      addTearDown(bridge.close);
      final path = p.join(directory.path, 'thpt_english.db');
      final legacy = await openDatabase(path);
      final schema = await File('test/fixtures/database_v1.sql').readAsString();
      for (final statement in schema.split(';')) {
        if (statement.trim().isNotEmpty) await legacy.execute(statement);
      }
      // Hand-authored v1 data includes customized settings and existing progress.
      await legacy.rawInsert(
        "INSERT INTO topics VALUES ('t1', 12, 'Chủ đề cũ', 1)",
      );
      await legacy.rawInsert(
        "INSERT INTO words VALUES ('w1', 't1', 12, 'learn', '/lɜːn/', 'học', 'Learn daily.')",
      );
      await legacy.rawInsert(
        '''INSERT INTO questions VALUES ('q1', 12, 'grammar', 'Old question', '["A","B"]', 1, 'Old explanation', 't1', NULL, 2)''',
      );
      await legacy.rawInsert(
        "INSERT INTO attempts VALUES (7, 'practice', 'grammar', 100, 60, 0, 1)",
      );
      await legacy.rawInsert(
        "INSERT INTO attempt_answers VALUES (7, 'q1', 0, 0)",
      );
      await legacy.rawInsert(
        "INSERT INTO wrong_book VALUES ('q1', 3, 100, 200)",
      );
      await legacy.rawInsert(
        "INSERT INTO daily_stats VALUES ('2026-10-28', 30, 5, 3, 12)",
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
      ];
      final before = <String, List<Map<String, Object?>>>{};
      for (final table in tables) {
        before[table] = await legacy.query(table);
        expect(before[table], isNotEmpty);
      }
      expect(await legacy.getVersion(), 1);
      expect(
        await legacy.rawQuery(
          "SELECT name FROM sqlite_master WHERE name = 'word_progress'",
        ),
        isEmpty,
      );
      await legacy.close();
      expect(await File(path).exists(), isTrue);

      // This invokes production _onUpgrade, not a copied migration callback.
      final upgraded = await AppDatabase.instance.database;
      expect(await upgraded.getVersion(), 3);
      for (final table in tables) {
        expect(
          await upgraded.query(table),
          before[table],
          reason: '$table must survive upgrade',
        );
      }
      expect(await upgraded.query('word_progress'), isEmpty);
      await upgraded.insert('word_progress', {
        'wordId': 'w1',
        'nextReviewAt': 500,
        'lastReviewedAt': 300,
      });
      expect(await upgraded.query('word_progress'), [
        {
          'wordId': 'w1',
          'reviewCount': 0,
          'streak': 0,
          'nextReviewAt': 500,
          'lastReviewedAt': 300,
        },
      ]);
      final nextAttempt = await upgraded.rawInsert(
        "INSERT INTO attempts (mode, startedAt, durationSec, score, total) VALUES ('practice', 300, 30, 1, 1)",
      );
      expect(nextAttempt, greaterThan(7));
      await upgraded.close();

      final reopened = await openDatabase(path, version: 3);
      addTearDown(reopened.close);
      expect(await reopened.getVersion(), 3);
      expect(
        (await reopened.query('word_progress')).single['nextReviewAt'],
        500,
      );
      expect(await reopened.query('app_settings'), before['app_settings']);
      expect(await reopened.query('attempts'), hasLength(2));
    },
  );
}
