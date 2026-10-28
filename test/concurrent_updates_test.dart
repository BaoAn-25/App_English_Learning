import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:thpt_english/data/app_database.dart';
import 'package:thpt_english/data/app_repository.dart';
import 'package:thpt_english/data/models/daily_stat.dart';
import 'package:thpt_english/data/models/wrong_book_entry.dart';

import 'support/sqlite_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SqliteBridge bridge;
  late Database database;
  final repository = AppRepository();
  const daily = DailyStat(
    date: '2026-10-27',
    xp: 10,
    questionsDone: 3,
    correct: 2,
    minutes: 1,
  );
  const wrong = WrongBookEntry(
    questionId: 'q1',
    wrongCount: 2,
    lastWrongAt: 100,
    nextReviewAt: 200,
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
    await database.delete('daily_stats');
    await database.delete('wrong_book');
  });

  for (final hasExistingRow in [false, true]) {
    test(
      'daily totals survive concurrent writes, existing=$hasExistingRow',
      () async {
        if (hasExistingRow) await repository.upsertDailyStat(daily);
        await Future.wait(
          List.generate(20, (_) => repository.upsertDailyStat(daily)),
        );
        final rows = await repository.getAllDailyStats();
        final count = hasExistingRow ? 21 : 20;
        expect(rows, hasLength(1));
        expect(rows.single.toMap(), {
          'date': daily.date,
          'xp': 10 * count,
          'questionsDone': 3 * count,
          'correct': 2 * count,
          'minutes': count,
        });
      },
    );

    test(
      'wrong counts survive concurrent writes, existing=$hasExistingRow',
      () async {
        if (hasExistingRow) await repository.upsertWrongBookEntry(wrong);
        await Future.wait(
          List.generate(20, (_) => repository.upsertWrongBookEntry(wrong)),
        );
        final rows = await repository.getAllWrongBookEntries();
        expect(rows, hasLength(1));
        expect(rows.single.toMap(), {
          ...wrong.toMap(),
          'wrongCount': 2 * (hasExistingRow ? 21 : 20),
        });
      },
    );
  }

  test(
    'wrong updates preserve fallback count and latest supplied dates',
    () async {
      await repository.upsertWrongBookEntry(wrong);
      for (final count in [0, -1]) {
        await repository.upsertWrongBookEntry(
          WrongBookEntry(
            questionId: wrong.questionId,
            wrongCount: count,
            lastWrongAt: 300,
            nextReviewAt: 400,
          ),
        );
      }
      expect((await repository.getAllWrongBookEntries()).single.toMap(), {
        'questionId': wrong.questionId,
        'wrongCount': 4,
        'lastWrongAt': 300,
        'nextReviewAt': 400,
      });
    },
  );
}
