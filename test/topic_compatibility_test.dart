import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:thpt_english/data/app_database.dart';
import 'package:thpt_english/data/app_repository.dart';
import 'package:thpt_english/data/asset_seeder.dart';
import 'package:thpt_english/data/models/question.dart';
import 'package:thpt_english/data/models/topic.dart';
import 'package:thpt_english/data/models/word.dart';

import 'support/sqlite_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SqliteBridge bridge;
  late Database database;
  final repository = AppRepository();
  const oldId = 'topic_12_unit1';
  const newId = 'topic_12_u1';
  const oldTopic = Topic(
    id: oldId,
    grade: 12,
    title: 'Life Stories & Success',
    order: 1,
  );
  const newTopic = Topic(
    id: newId,
    grade: 12,
    title: 'Life Stories & Success',
    order: 1,
  );

  setUpAll(() async {
    bridge = await SqliteBridge.start();
    database = await AppDatabase.instance.database;
  });
  tearDownAll(() async {
    await database.close();
    await bridge.close();
  });
  setUp(() async {
    for (final table in ['topics', 'words', 'questions', 'word_progress']) {
      await database.delete(table);
    }
    await repository.insertTopics([oldTopic, newTopic]);
    for (final id in [oldId, newId]) {
      await repository.insertWords([
        Word(
          id: 'word-$id',
          topicId: id,
          grade: 12,
          english: id,
          ipa: '',
          meaningVi: 'Meaning',
          example: 'Example',
        ),
      ]);
      await repository.insertQuestions([
        Question(
          id: 'question-$id',
          topicId: id,
          grade: 12,
          type: 'vocab',
          stem: 'Choose',
          options: ['A', 'B'],
          correctIndex: 0,
          explanation: 'A',
          difficulty: 1,
        ),
      ]);
    }
    await database.insert('word_progress', {
      'wordId': 'word-$oldId',
      'reviewCount': 2,
      'streak': 1,
      'nextReviewAt': 200,
      'lastReviewedAt': 100,
    });
  });

  test('shows one topic for a known legacy/current pair', () async {
    expect((await repository.getAllTopics()).map((t) => t.id), [newId]);
    expect((await repository.getTopicsByGrade(12)).map((t) => t.id), [newId]);
    expect(await repository.getTopicsByGrade(11), isEmpty);
  });

  test(
    'both links open old and new words and questions without rewriting data',
    () async {
      final before = {
        for (final table in ['topics', 'words', 'questions', 'word_progress'])
          table: await database.query(table),
      };
      for (final id in [oldId, newId]) {
        expect(
          (await repository.getWordsByTopicId(id)).map((w) => w.id),
          unorderedEquals(['word-$oldId', 'word-$newId']),
        );
        expect(
          (await repository.getQuestionsByTopicId(id)).map((q) => q.id),
          unorderedEquals(['question-$oldId', 'question-$newId']),
        );
      }
      for (final entry in before.entries) {
        expect(await database.query(entry.key), entry.value);
      }
    },
  );

  test(
    'keeps customized topics separate and does not mix their contents',
    () async {
      for (final edit in [
        {'title': 'My custom topic'},
        {'grade': 11},
        {'order': 5},
      ]) {
        await database.update(
          'topics',
          {...oldTopic.toMap(), ...edit},
          where: 'id = ?',
          whereArgs: [oldId],
        );
        expect(await repository.getAllTopics(), hasLength(2));
        expect(
          (await repository.getWordsByTopicId(newId)).single.id,
          'word-$newId',
        );
        expect(
          (await repository.getQuestionsByTopicId(oldId)).single.id,
          'question-$oldId',
        );
      }
    },
  );

  test('legacy-only install remains accessible', () async {
    await database.delete('topics', where: 'id = ?', whereArgs: [newId]);
    expect((await repository.getTopicsByGrade(12)).single.id, oldId);
    expect(
      (await repository.getWordsByTopicId(oldId)).single.id,
      'word-$oldId',
    );
  });

  test('unrelated topics with the same title stay separate', () async {
    await repository.insertTopics([
      Topic(id: 'custom-topic', grade: 12, title: newTopic.title, order: 1),
    ]);
    expect(
      (await repository.getAllTopics()).map((t) => t.id),
      unorderedEquals([newId, 'custom-topic']),
    );
    expect(await repository.getWordsByTopicId('custom-topic'), isEmpty);
    expect(
      await repository.getQuestionsByTopicId("unknown' OR 1=1 --"),
      isEmpty,
    );
  });
  test(
    'bundled upgrade shows ten topics while retaining all thirteen rows',
    () async {
      await repository.insertTopics(const [
        Topic(
          id: 'topic_12_unit2',
          grade: 12,
          title: 'Urbanisation & Development',
          order: 2,
        ),
        Topic(
          id: 'topic_12_unit3',
          grade: 12,
          title: 'The Green Movement',
          order: 3,
        ),
      ]);
      await AssetSeeder.syncVocabulary();
      expect(await database.query('topics'), hasLength(13));
      expect((await repository.getTopicsByGrade(12)).map((t) => t.id), [
        for (var unit = 1; unit <= 10; unit++) 'topic_12_u$unit',
      ]);
    },
  );
}
