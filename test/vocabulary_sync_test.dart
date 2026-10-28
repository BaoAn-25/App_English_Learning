import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:thpt_english/data/app_database.dart';
import 'package:thpt_english/data/asset_seeder.dart';

import 'asset_seeder_test.dart' show SeedBundle;
import 'support/sqlite_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SqliteBridge bridge;
  late Database database;
  late Map<String, String> files;
  const oldTopic = {
    'id': 'topic_12_unit1',
    'grade': 12,
    'title': 'My topic',
    'order': 1,
  };
  const oldWord = {
    'id': 'word_12_01',
    'topicId': 'topic_12_unit1',
    'grade': 12,
    'english': 'old word',
    'ipa': '/old/',
    'meaningVi': 'Nghĩa đã sửa',
    'example': 'My example',
  };
  const progress = {
    'wordId': 'word_12_01',
    'reviewCount': 5,
    'streak': 3,
    'lastReviewedAt': 100,
    'nextReviewAt': 200,
  };

  setUpAll(() async {
    bridge = await SqliteBridge.start();
    database = await AppDatabase.instance.database;
    files = {
      for (final table in ['topics', 'words'])
        'assets/data/$table.json': await rootBundle.loadString(
          'assets/data/$table.json',
        ),
    };
  });
  tearDownAll(() async {
    await database.close();
    await bridge.close();
  });
  setUp(() async {
    await database.execute('DROP TRIGGER IF EXISTS fail_words');
    for (final table in ['word_progress', 'words', 'topics']) {
      await database.delete(table);
    }
    await database.insert('topics', oldTopic);
    await database.insert('words', oldWord);
    await database.insert('word_progress', progress);
  });

  Future<void> expectOriginalData() async {
    expect(await database.query('topics'), [oldTopic]);
    expect(await database.query('words'), [oldWord]);
    expect(await database.query('word_progress'), [progress]);
  }

  test(
    'adds bundled vocabulary while keeping old IDs, edits and progress',
    () async {
      await AssetSeeder.syncVocabulary();
      for (final table in ['topics', 'words']) {
        final expected = jsonDecode(files['assets/data/$table.json']!) as List;
        final rows = await database.query(table);
        expect(rows, hasLength(expected.length + 1));
        expect(
          rows.map((r) => r['id']),
          containsAll(expected.map((r) => r['id'])),
        );
      }
      expect(
        await database.query(
          'words',
          where: 'id = ?',
          whereArgs: [oldWord['id']],
        ),
        [oldWord],
      );
      expect(
        await database.query(
          'topics',
          where: 'id = ?',
          whereArgs: [oldTopic['id']],
        ),
        [oldTopic],
      );
      expect(await database.query('word_progress'), [progress]);
    },
  );

  test(
    'repeated and concurrent syncs preserve existing rows with matching IDs',
    () async {
      await AssetSeeder.syncVocabulary();
      await database.update('words', {'meaningVi': 'User edit'});
      final before = await database.query('words');
      await Future.wait([
        AssetSeeder.syncVocabulary(),
        AssetSeeder.syncVocabulary(),
      ]);
      expect(await database.query('words'), before);
      expect(
        await database.query('topics'),
        hasLength(
          (jsonDecode(files['assets/data/topics.json']!) as List).length + 1,
        ),
      );
      expect(await database.query('word_progress'), [progress]);
    },
  );

  test('bad last asset rolls back new topics and allows retry', () async {
    for (final invalid in ['{broken', '{}', '[null]']) {
      await expectLater(
        AssetSeeder.syncVocabulary(
          bundle: SeedBundle({...files, 'assets/data/words.json': invalid}),
        ),
        throwsFormatException,
      );
      await expectOriginalData();
    }
    await AssetSeeder.syncVocabulary();
    expect(
      await database.query('words'),
      hasLength(
        (jsonDecode(files['assets/data/words.json']!) as List).length + 1,
      ),
    );
  });

  test('SQL error rolls back both tables without changing progress', () async {
    await database.execute(
      "CREATE TEMP TRIGGER fail_words BEFORE INSERT ON words BEGIN SELECT RAISE(ABORT, 'forced failure'); END",
    );
    await expectLater(
      AssetSeeder.syncVocabulary(),
      throwsA(isA<DatabaseException>()),
    );
    await expectOriginalData();
  });

  test(
    'duplicate asset IDs are rejected even when row already exists',
    () async {
      await expectLater(
        AssetSeeder.syncVocabulary(
          bundle: SeedBundle({
            ...files,
            'assets/data/words.json': jsonEncode([oldWord, oldWord]),
          }),
        ),
        throwsFormatException,
      );
      await expectOriginalData();
    },
  );

  test(
    'new word with missing topic is rejected without partial data',
    () async {
      await expectLater(
        AssetSeeder.syncVocabulary(
          bundle: SeedBundle({
            ...files,
            'assets/data/words.json': jsonEncode([
              {...oldWord, 'id': 'new-word', 'topicId': 'missing'},
            ]),
          }),
        ),
        throwsFormatException,
      );
      await expectOriginalData();
    },
  );
}
