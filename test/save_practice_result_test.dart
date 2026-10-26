import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:thpt_english/data/app_database.dart';
import 'package:thpt_english/data/app_repository.dart';
import 'package:thpt_english/data/models/attempt.dart';
import 'package:thpt_english/data/models/attempt_answer.dart';
import 'package:thpt_english/data/models/daily_stat.dart';
import 'package:thpt_english/data/models/question.dart';
import 'package:thpt_english/data/models/wrong_book_entry.dart';

import 'support/sqlite_bridge.dart';

const attempt = Attempt(
  mode: 'practice',
  type: 'grammar',
  startedAt: 1000,
  durationSec: 61,
  score: 1,
  total: 2,
);
const daily = DailyStat(
  date: '2026-10-26',
  xp: 10,
  questionsDone: 2,
  correct: 1,
  minutes: 2,
);
const wrong = WrongBookEntry(
  questionId: 'q2',
  wrongCount: 1,
  lastWrongAt: 62000,
  nextReviewAt: 86462000,
);
List<AttemptAnswer> answers(int id) => [
  AttemptAnswer(
    attemptId: id,
    questionId: 'q1',
    chosenIndex: 1,
    isCorrect: true,
  ),
  AttemptAnswer(
    attemptId: id,
    questionId: 'q2',
    chosenIndex: -1,
    isCorrect: false,
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SqliteBridge bridge;
  late Database database;
  final repository = AppRepository();

  setUpAll(() async {
    bridge = await SqliteBridge.start();
    database = await AppDatabase.instance.database;
  });
  tearDownAll(() async {
    await database.close();
    await bridge.close();
  });
  setUp(() async {
    await database.execute('DROP TRIGGER IF EXISTS fail_stats');
    await database.execute('DROP TRIGGER IF EXISTS fail_stats_update');
    for (final table in [
      'attempt_answers',
      'attempts',
      'wrong_book',
      'daily_stats',
      'questions',
    ]) {
      await database.delete(table);
    }
    await repository.insertQuestions([
      for (final id in ['q1', 'q2'])
        Question(
          id: id,
          grade: 12,
          type: 'grammar',
          stem: 'Choose',
          options: ['A', 'B'],
          correctIndex: 1,
          explanation: 'B is correct',
          difficulty: 1,
        ),
    ]);
  });

  Future<void> save({
    Attempt value = attempt,
    DailyStat stat = daily,
    List<AttemptAnswer> Function(int)? builder,
    List<WrongBookEntry> wrongs = const [wrong],
  }) => repository.savePracticeResult(
    attempt: value,
    buildAnswers: builder ?? answers,
    wrongEntries: wrongs,
    dailyStat: stat,
  );
  Future<void> expectEmpty() async {
    expect(await repository.getAllAttempts(), isEmpty);
    expect(await repository.getAllAttemptAnswers(), isEmpty);
    expect(await repository.getAllWrongBookEntries(), isEmpty);
    expect(await repository.getAllDailyStats(), isEmpty);
  }

  test(
    'saves all four records with generated attempt id and skipped answers',
    () async {
      await save();
      final saved = (await repository.getAllAttempts()).single;
      expect(saved.score, 1);
      final rows = await repository.getAttemptAnswers(saved.id!);
      expect(rows.length, 2);
      expect(rows.map((row) => row.attemptId).toSet(), {saved.id});
      expect(rows.singleWhere((row) => row.questionId == 'q2').chosenIndex, -1);
      expect((await repository.getAllWrongBookEntries()).single.wrongCount, 1);
      expect(
        (await repository.getAllDailyStats()).single.toMap(),
        daily.toMap(),
      );
    },
  );

  test('concurrent submissions accumulate without losing progress', () async {
    await Future.wait([save(), save()]);
    expect((await repository.getAllAttempts()).length, 2);
    expect((await repository.getAllAttemptAnswers()).length, 4);
    expect((await repository.getAllWrongBookEntries()).single.wrongCount, 2);
    final result = (await repository.getAllDailyStats()).single;
    expect(result.xp, 20);
    expect(result.questionsDone, 4);
    expect(result.correct, 2);
    expect(result.minutes, 4);
  });

  test(
    'late SQLite failure rolls back every table and preserves earlier progress',
    () async {
      await save();
      await database.execute(
        "CREATE TEMP TRIGGER fail_stats BEFORE INSERT ON daily_stats BEGIN SELECT RAISE(ABORT, 'forced failure'); END",
      );
      await database.execute(
        "CREATE TEMP TRIGGER fail_stats_update BEFORE UPDATE ON daily_stats BEGIN SELECT RAISE(ABORT, 'forced failure'); END",
      );
      await expectLater(save(), throwsA(isA<DatabaseException>()));
      expect((await repository.getAllAttempts()).length, 1);
      expect((await repository.getAllAttemptAnswers()).length, 2);
      expect((await repository.getAllWrongBookEntries()).single.wrongCount, 1);
      expect(
        (await repository.getAllDailyStats()).single.toMap(),
        daily.toMap(),
      );
      await database.execute('DROP TRIGGER fail_stats');
      await database.execute('DROP TRIGGER fail_stats_update');
      await save();
      expect((await repository.getAllAttempts()).length, 2);
    },
  );

  test('answer builder exception leaves no partial attempt', () async {
    await expectLater(
      save(builder: (_) => throw StateError('builder failed')),
      throwsStateError,
    );
    await expectEmpty();
  });

  test('rejects duplicate question answers and rolls back', () async {
    await expectLater(
      save(builder: (id) => [answers(id).first, answers(id).first]),
      throwsArgumentError,
    );
    await expectEmpty();
  });
  test('rejects answers belonging to another attempt', () async {
    await expectLater(
      save(builder: (_) => answers(999999)),
      throwsArgumentError,
    );
    await expectEmpty();
  });
  test('rejects missing answers', () async {
    await expectLater(
      save(builder: (id) => [answers(id).first]),
      throwsArgumentError,
    );
    await expectEmpty();
  });
  test(
    'rejects forged score, answer correctness and unknown question',
    () async {
      await expectLater(
        save(
          value: const Attempt(
            mode: 'practice',
            startedAt: 0,
            durationSec: 0,
            score: 2,
            total: 2,
          ),
        ),
        throwsArgumentError,
      );
      await expectEmpty();
      await expectLater(
        save(
          builder: (id) => [
            AttemptAnswer(
              attemptId: id,
              questionId: 'q1',
              chosenIndex: 0,
              isCorrect: true,
            ),
            answers(id).last,
          ],
        ),
        throwsArgumentError,
      );
      await expectEmpty();
      await expectLater(
        save(
          builder: (id) => [
            AttemptAnswer(
              attemptId: id,
              questionId: 'missing',
              chosenIndex: 1,
              isCorrect: true,
            ),
            answers(id).last,
          ],
        ),
        throwsArgumentError,
      );
      await expectEmpty();
    },
  );
  test('rejects out of range choice', () async {
    for (final choice in [-2, 2]) {
      await expectLater(
        save(
          builder: (id) => [
            answers(id).first,
            AttemptAnswer(
              attemptId: id,
              questionId: 'q2',
              chosenIndex: choice,
              isCorrect: false,
            ),
          ],
        ),
        throwsArgumentError,
      );
      await expectEmpty();
    }
  });
  test('rejects wrong book entries inconsistent with answers', () async {
    for (final entries in <List<WrongBookEntry>>[
      [],
      [wrong, wrong],
      [
        const WrongBookEntry(
          questionId: 'q1',
          wrongCount: 1,
          lastWrongAt: 1,
          nextReviewAt: 2,
        ),
      ],
    ]) {
      await expectLater(save(wrongs: entries), throwsArgumentError);
      await expectEmpty();
    }
  });
  test(
    'rejects invalid attempt and inconsistent daily stats before writing',
    () async {
      for (final value in [
        const Attempt(
          id: 1,
          mode: 'practice',
          startedAt: 0,
          durationSec: 0,
          score: 1,
          total: 2,
        ),
        const Attempt(
          mode: '',
          startedAt: 0,
          durationSec: 0,
          score: 1,
          total: 2,
        ),
        const Attempt(
          mode: 'practice',
          startedAt: 0,
          durationSec: -1,
          score: 1,
          total: 2,
        ),
        const Attempt(
          mode: 'practice',
          startedAt: 0,
          durationSec: 0,
          score: 0,
          total: 0,
        ),
      ]) {
        await expectLater(save(value: value), throwsArgumentError);
        await expectEmpty();
      }
      for (final stat in [
        const DailyStat(
          date: '2026-02-30',
          xp: 10,
          questionsDone: 2,
          correct: 1,
          minutes: 2,
        ),
        const DailyStat(
          date: '2026-10-26',
          xp: -1,
          questionsDone: 2,
          correct: 1,
          minutes: 2,
        ),
        const DailyStat(
          date: '2026-10-26',
          xp: 10,
          questionsDone: 3,
          correct: 1,
          minutes: 2,
        ),
        const DailyStat(
          date: '2026-10-26',
          xp: 10,
          questionsDone: 2,
          correct: 0,
          minutes: 2,
        ),
      ]) {
        await expectLater(save(stat: stat), throwsArgumentError);
        await expectEmpty();
      }
    },
  );
  test('all-correct exam saves no wrong book entries', () async {
    await save(
      value: const Attempt(
        mode: 'mock_exam',
        startedAt: 0,
        durationSec: 60,
        score: 2,
        total: 2,
      ),
      stat: const DailyStat(
        date: '2026-10-26',
        xp: 20,
        questionsDone: 2,
        correct: 2,
        minutes: 1,
      ),
      wrongs: [],
      builder: (id) => [
        for (final questionId in ['q1', 'q2'])
          AttemptAnswer(
            attemptId: id,
            questionId: questionId,
            chosenIndex: 1,
            isCorrect: true,
          ),
      ],
    );
    expect((await repository.getAllAttempts()).single.mode, 'mock_exam');
    expect(await repository.getAllWrongBookEntries(), isEmpty);
    expect((await repository.getAllDailyStats()).single.correct, 2);
  });

  test(
    'another day creates its own statistics without overwriting yesterday',
    () async {
      await save();
      await save(
        stat: const DailyStat(
          date: '2026-10-27',
          xp: 10,
          questionsDone: 2,
          correct: 1,
          minutes: 2,
        ),
      );
      final days = await repository.getAllDailyStats();
      expect(days.map((day) => day.date), ['2026-10-26', '2026-10-27']);
      expect(days.map((day) => day.xp), [10, 10]);
      expect((await repository.getAllWrongBookEntries()).single.wrongCount, 2);
    },
  );

  test('first submission SQL failure leaves all four tables empty', () async {
    await database.execute(
      "CREATE TEMP TRIGGER fail_stats BEFORE INSERT ON daily_stats BEGIN SELECT RAISE(ABORT, 'forced failure'); END",
    );
    await expectLater(save(), throwsA(isA<DatabaseException>()));
    await expectEmpty();
  });

  test('invalid wrong-book count or review date leaves no records', () async {
    for (final entry in [
      const WrongBookEntry(
        questionId: 'q2',
        wrongCount: 0,
        lastWrongAt: 0,
        nextReviewAt: 1,
      ),
      const WrongBookEntry(
        questionId: 'q2',
        wrongCount: 2,
        lastWrongAt: 0,
        nextReviewAt: 1,
      ),
      const WrongBookEntry(
        questionId: 'q2',
        wrongCount: 1,
        lastWrongAt: 5,
        nextReviewAt: 4,
      ),
    ]) {
      await expectLater(save(wrongs: [entry]), throwsArgumentError);
      await expectEmpty();
    }
  });
}
