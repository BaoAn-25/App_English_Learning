import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:thpt_english/data/app_repository.dart';
import 'package:thpt_english/data/models/attempt.dart';
import 'package:thpt_english/data/models/mock_exam_draft.dart';
import 'package:thpt_english/data/models/question.dart';
import 'package:thpt_english/ui/practice/mock_exam_quiz_screen.dart';
import 'package:thpt_english/ui/practice/mock_exam_screen.dart';

const q = Question(
  id: 'q',
  grade: 12,
  type: 'grammar',
  stem: 'Resume question',
  options: ['First', 'Second'],
  correctIndex: 1,
  explanation: 'Second',
  difficulty: 1,
);

class DraftRepo extends AppRepository {
  MockExamDraft draft;
  bool failWrite = false;
  int completions = 0;
  bool active = true;
  bool corrupt = false;
  @override
  Future<MockExamDraft?> getExamDraft() async {
    if (corrupt) throw const CorruptExamDraftException('{}');
    return active ? draft : null;
  }

  @override
  Future<void> discardCorruptExamDraft(String payload) async {
    corrupt = false;
    active = false;
  }

  @override
  Future<List<Question>> getQuestionsByGrade(int grade) async => [q];
  @override
  Future<void> discardExamDraft(String id) async {
    active = false;
  }

  DraftRepo(this.draft);
  @override
  Future<MockExamDraft> updateExamDraft(
    MockExamDraft value, {
    DateTime? now,
  }) async {
    if (failWrite) throw StateError('private database error');
    return draft = value.copyWith(revision: value.revision + 1);
  }

  @override
  Future<Attempt> completeExamDraft(String id, {DateTime? now}) async {
    completions++;
    return Attempt(
      id: 1,
      mode: 'mock_exam',
      startedAt: draft.startedAt,
      durationSec: 60,
      score: 0,
      total: 1,
    );
  }
}

void main() {
  final start = DateTime(2026, 10, 29, 10);
  MockExamDraft makeDraft() => MockExamDraft.start(
    questions: [q],
    durationMinutes: 1,
    now: start,
    optionOrder: [
      [1, 0],
    ],
  );
  Widget app(DraftRepo repo, DateTime Function() clock) =>
      Provider<AppRepository>.value(
        value: repo,
        child: MaterialApp(
          home: MockExamQuizScreen(
            questions: repo.draft.questions,
            durationMinutes: 1,
            draft: repo.draft,
            clock: clock,
          ),
        ),
      );
  testWidgets(
    'resume restores flags, selected answers, option order and original deadline',
    (tester) async {
      final repo = DraftRepo(makeDraft().copyWith(answers: [1], flagged: [0]));
      await tester.pumpWidget(
        app(repo, () => start.add(const Duration(seconds: 30))),
      );
      await tester.pumpAndSettle();
      expect(find.text('Đã cắm cờ'), findsOneWidget);
      expect(find.text('00:30'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Second')).dy,
        lessThan(tester.getTopLeft(find.text('First')).dy),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'failed save keeps last saved answer and offers retry without exposing internal errors',
    (tester) async {
      final repo = DraftRepo(makeDraft())..failWrite = true;
      await tester.pumpWidget(app(repo, () => start));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Second'));
      await tester.pumpAndSettle();
      expect(repo.draft.answers, [null]);
      expect(find.byKey(const ValueKey('draft-save-error')), findsOneWidget);
      expect(find.textContaining('private database'), findsNothing);
      repo.failWrite = false;
      await tester.tap(find.text('Thử lưu lại'));
      await tester.pumpAndSettle();
      expect(repo.draft.answers, [1]);
      expect(find.byKey(const ValueKey('draft-save-error')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'expired draft completes once on reopening and cannot accept answers',
    (tester) async {
      final repo = DraftRepo(makeDraft());
      await tester.pumpWidget(
        app(repo, () => start.add(const Duration(minutes: 2))),
      );
      await tester.pumpAndSettle();
      expect(repo.completions, 1);
      expect(repo.draft.answers, [null]);
      await tester.pump(const Duration(seconds: 5));
      expect(repo.completions, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('entry preserves saved exam until discard is confirmed', (
    tester,
  ) async {
    final repo = DraftRepo(makeDraft());
    await tester.pumpWidget(
      Provider<AppRepository>.value(
        value: repo,
        child: const MaterialApp(home: MockExamScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tiếp tục bài thi'), findsOneWidget);
    await tester.tap(find.text('Bỏ bài để thi mới'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Giữ bài'));
    await tester.pumpAndSettle();
    expect(find.text('Tiếp tục bài thi'), findsOneWidget);
    await tester.tap(find.text('Bỏ bài để thi mới'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bỏ bài'));
    await tester.pumpAndSettle();
    expect(find.text('Tiếp tục bài thi'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'corrupt draft recovery requires confirmation and reloads exam entry',
    (tester) async {
      final repo = DraftRepo(makeDraft())..corrupt = true;
      await tester.pumpWidget(
        Provider<AppRepository>.value(
          value: repo,
          child: const MaterialApp(home: MockExamScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bỏ bản nháp lỗi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Giữ bài'));
      await tester.pumpAndSettle();
      expect(find.text('Bỏ bản nháp lỗi'), findsOneWidget);
      await tester.tap(find.text('Bỏ bản nháp lỗi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bỏ bài'));
      await tester.pumpAndSettle();
      expect(find.text('Bỏ bản nháp lỗi'), findsNothing);
      expect(find.text('Chọn chế độ thi'), findsOneWidget);
    },
  );
}
