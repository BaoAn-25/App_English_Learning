import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:thpt_english/data/app_database.dart';
import 'package:thpt_english/data/models/mock_exam_draft.dart';
import 'package:thpt_english/data/models/question.dart';
import 'support/sqlite_bridge.dart';

const question = Question(
  id: 'resume-q',
  grade: 12,
  type: 'grammar',
  stem: 'Choose',
  options: ['A', 'B'],
  correctIndex: 1,
  explanation: 'B',
  difficulty: 1,
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SqliteBridge bridge;
  late Database db;
  final app = AppDatabase.instance;
  final start = DateTime(2026, 10, 29, 10);
  MockExamDraft draft() => MockExamDraft.start(
    questions: [question],
    durationMinutes: 10,
    now: start,
    optionOrder: [
      [1, 0],
    ],
  );
  setUpAll(() async {
    bridge = await SqliteBridge.start();
    db = await app.database;
  });
  tearDownAll(() async {
    await db.close();
    await bridge.close();
  });
  setUp(() async {
    for (final table in [
      'exam_drafts',
      'exam_completions',
      'attempt_answers',
      'attempts',
      'wrong_book',
      'daily_stats',
      'questions',
    ]) {
      await db.delete(table);
    }
    await app.insertQuestions([question]);
  });
  test(
    'persists question order, answers, flags and cursor with a fixed deadline',
    () async {
      final initial = draft();
      await app.createExamDraft(initial);
      final edited = initial.copyWith(answers: [1], flagged: [0]);
      final saved = await app.updateExamDraft(
        edited,
        now: start.add(const Duration(seconds: 5)),
      );
      final loaded = await app.getExamDraft();
      expect(loaded!.toJson(), saved.toJson());
      expect(loaded.optionOrder, [
        [1, 0],
      ]);
      expect(
        loaded.deadline,
        start.add(const Duration(minutes: 10)).millisecondsSinceEpoch,
      );
      expect((await app.getAllAttempts()), isEmpty);
    },
  );
  test(
    'rejects stale writes, replacing a draft, and edits after deadline',
    () async {
      final initial = draft();
      await app.createExamDraft(initial);
      await expectLater(app.createExamDraft(draft()), throwsStateError);
      await app.updateExamDraft(initial.copyWith(answers: [1]), now: start);
      await expectLater(
        app.updateExamDraft(initial, now: start),
        throwsStateError,
      );
      final current = (await app.getExamDraft())!;
      await expectLater(
        app.updateExamDraft(
          current.copyWith(answers: [0]),
          now: start.add(const Duration(minutes: 11)),
        ),
        throwsStateError,
      );
      expect((await app.getExamDraft())!.answers, [1]);
    },
  );
  test(
    'completion is atomic and repeated submissions do not duplicate XP',
    () async {
      final initial = draft();
      await app.createExamDraft(initial);
      await app.updateExamDraft(initial.copyWith(answers: [1]), now: start);
      final results = await Future.wait(
        List.generate(
          3,
          (_) => app.completeExamDraft(
            initial.id,
            now: start.add(const Duration(minutes: 12)),
          ),
        ),
      );
      expect(results.map((a) => a.id).toSet(), hasLength(1));
      expect(results.first.score, 1);
      expect(results.first.durationSec, 600);
      expect(await app.getExamDraft(), isNull);
      expect(await app.getAllAttempts(), hasLength(1));
      expect((await app.getAllDailyStats()).single.xp, 10);
      await expectLater(app.createExamDraft(initial), throwsStateError);
      await expectLater(
        app.updateExamDraft(initial, now: start),
        throwsStateError,
      );
    },
  );
  test(
    'failed result transaction preserves draft and allows a clean retry',
    () async {
      final initial = draft();
      await app.createExamDraft(initial);
      await db.execute(
        "CREATE TRIGGER fail_result BEFORE INSERT ON daily_stats BEGIN SELECT RAISE(ABORT, 'test failure'); END",
      );
      try {
        await expectLater(
          app.completeExamDraft(initial.id, now: start),
          throwsA(isA<Exception>()),
        );
        expect(await app.getExamDraft(), isNotNull);
        expect(await app.getAllAttempts(), isEmpty);
        expect(await app.getAllWrongBookEntries(), isEmpty);
        expect(await db.query('exam_completions'), isEmpty);
      } finally {
        await db.execute('DROP TRIGGER fail_result');
      }
      await app.completeExamDraft(initial.id, now: start);
      expect(await app.getAllAttempts(), hasLength(1));
    },
  );
  test(
    'changed or deleted questions block resume and completion without losing draft',
    () async {
      final initial = draft();
      await app.createExamDraft(initial);
      await db.update(
        'questions',
        {'stem': 'Changed'},
        where: 'id = ?',
        whereArgs: [question.id],
      );
      await expectLater(app.validateExamDraft(initial.id), throwsStateError);
      await expectLater(
        app.completeExamDraft(initial.id, now: start),
        throwsStateError,
      );
      expect(await app.getExamDraft(), isNotNull);
      await db.delete('questions');
      await expectLater(app.validateExamDraft(initial.id), throwsStateError);
      await app.discardExamDraft(initial.id);
      expect(await app.getExamDraft(), isNull);
    },
  );
  test('asset sync leaves active exam question content unchanged', () async {
    await app.createExamDraft(draft());
    final changed = Question.fromMap({
      ...question.toMap(),
      'stem': 'Updated',
      'explanation': 'New explanation',
      'difficulty': 3,
    });
    await app.syncQuestionsSafe([changed]);
    expect((await app.getAllQuestions()).single.toMap(), question.toMap());
    final active = (await app.getExamDraft())!;
    await app.validateExamDraft(active.id);
    await app.completeExamDraft(active.id, now: start);
  });
  test(
    'restores multiple questions and cursor without changing answer indices',
    () async {
      final second = Question.fromMap({...question.toMap(), 'id': 'second'});
      await app.insertQuestions([second]);
      final initial = MockExamDraft.start(
        questions: [second, question],
        durationMinutes: 10,
        now: start,
        optionOrder: [
          [1, 0],
          [0, 1],
        ],
      );
      await app.createExamDraft(initial);
      await app.updateExamDraft(
        initial.copyWith(answers: [1, 0], flagged: [1], currentIndex: 1),
        now: start,
      );
      final restored = (await app.getExamDraft())!;
      expect(restored.questions.map((q) => q.id), ['second', question.id]);
      expect(restored.currentIndex, 1);
      expect(restored.flagged, [1]);
      expect(restored.optionOrder, [
        [1, 0],
        [0, 1],
      ]);
      expect(restored.answers, [1, 0]);
      final result = await app.completeExamDraft(initial.id, now: start);
      expect(result.score, 1);
      expect(result.total, 2);
    },
  );

  test(
    'rejects invalid stored answers, flags, cursor and option permutation',
    () {
      final initial = draft();
      expect(() => initial.copyWith(answers: [2]), throwsFormatException);
      expect(() => initial.copyWith(flagged: [1]), throwsFormatException);
      expect(() => initial.copyWith(currentIndex: 1), throwsFormatException);
      expect(
        () => MockExamDraft.start(
          questions: [question],
          durationMinutes: 10,
          now: start,
          optionOrder: [
            [0, 0],
          ],
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'corrupt draft can be discarded explicitly without deleting a newer draft',
    () async {
      await db.insert('exam_drafts', {'slot': 1, 'payload': '{}'});
      await expectLater(
        app.getExamDraft(),
        throwsA(isA<CorruptExamDraftException>()),
      );
      final sync = await app.syncQuestionsSafe([
        question,
      ], targetVersion: 'new');
      expect(sync.skippedCount, 1);
      expect(await db.query('exam_drafts'), hasLength(1));
      await app.discardCorruptExamDraft('{}');
      expect(await app.getExamDraft(), isNull);
      final fresh = draft();
      await app.createExamDraft(fresh);
      await app.discardCorruptExamDraft('{}');
      expect((await app.getExamDraft())!.id, fresh.id);
      await expectLater(
        app.discardCorruptExamDraft(fresh.toJson()),
        throwsStateError,
      );
      expect((await app.getExamDraft())!.id, fresh.id);
    },
  );
}
