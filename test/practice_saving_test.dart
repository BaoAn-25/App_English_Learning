import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:thpt_english/data/app_repository.dart';
import 'package:thpt_english/data/models/attempt.dart';
import 'package:thpt_english/data/models/attempt_answer.dart';
import 'package:thpt_english/data/models/daily_stat.dart';
import 'package:thpt_english/data/models/question.dart';
import 'package:thpt_english/data/models/wrong_book_entry.dart';
import 'package:thpt_english/ui/practice/practice_quiz_screen.dart';
import 'package:thpt_english/ui/practice/services/option_shuffler.dart';

import 'practice_flow_test.dart' show RecordingRepository;

class DelayedRepository extends RecordingRepository {
  DelayedRepository(super.bank);
  final ready = Completer<void>();

  @override
  Future<void> savePracticeResult({
    required Attempt attempt,
    required List<AttemptAnswer> Function(int) buildAnswers,
    required List<WrongBookEntry> wrongEntries,
    required DailyStat dailyStat,
  }) async {
    await ready.future;
    await super.savePracticeResult(
      attempt: attempt,
      buildAnswers: buildAnswers,
      wrongEntries: wrongEntries,
      dailyStat: dailyStat,
    );
  }
}

void main() {
  testWidgets('answers stay consistent with score while saving is pending', (
    tester,
  ) async {
    const question = Question(
      id: 'saving-q',
      grade: 12,
      type: 'grammar',
      stem: 'Choose an answer',
      options: ['Wrong answer', 'Correct answer'],
      correctIndex: 1,
      explanation: 'Explanation',
      difficulty: 1,
    );
    final repository = DelayedRepository([question]);
    await tester.pumpWidget(
      Provider<AppRepository>.value(
        value: repository,
        child: MaterialApp(
          home: PracticeQuizScreen(
            title: 'Practice',
            questions: const [question],
            optionMappings: [QuestionOptionMapping.identity(2)],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Correct answer'));
    await tester.pump();
    await tester.tap(find.text('Nộp bài'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Nộp bài'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Wrong answer'));
    await tester.pump();
    repository.ready.complete();
    await tester.pumpAndSettle();
    expect(repository.saveCalls, 1);
    expect(repository.savedAnswers.single.chosenIndex, 1);
    expect(repository.savedAnswers.single.isCorrect, isTrue);
    expect(repository.savedAttempt!.score, 1);
    expect(repository.savedStat!.correct, 1);
    expect(repository.savedWrong, isEmpty);
    expect(find.textContaining('Kết quả: 1/1'), findsOneWidget);
  });
}
