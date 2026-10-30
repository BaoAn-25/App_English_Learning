import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:thpt_english/data/app_repository.dart';
import 'package:thpt_english/data/models/word.dart';
import 'package:thpt_english/data/models/word_progress.dart';
import 'package:thpt_english/ui/vocab/vocab_provider.dart';
import 'package:thpt_english/ui/vocab/srs_review_screen.dart';
import 'package:thpt_english/ui/vocab/flashcard_screen.dart';

const word = Word(
  id: 'word',
  topicId: 'topic',
  grade: 12,
  english: 'hello',
  ipa: '',
  meaningVi: 'xin chào',
  example: 'Hello!',
);

class SaveRepo extends AppRepository {
  Completer<void>? pending;
  bool fail = false;
  int writes = 0;
  @override
  Future<void> upsertWordProgress(WordProgress value) async {
    writes++;
    if (fail) throw StateError('private SQL error');
    await pending?.future;
  }

  @override
  Future<List<Word>> getAllWords() async => [word];
  @override
  Future<List<WordProgress>> getDueWordProgress() async => [
    const WordProgress(
      wordId: 'word',
      reviewCount: 1,
      nextReviewAt: 0,
      lastReviewedAt: 0,
    ),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_tts'),
          (_) async => 1,
        ),
  );
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), null),
  );

  for (final action in ['correct', 'wrong', 'seen']) {
    test(
      'failed $action save leaves progress unchanged and can retry',
      () async {
        final repo = SaveRepo()..fail = true;
        final provider = VocabProvider(repo);
        Future<void> save() => switch (action) {
          'correct' => provider.markWordCorrect('word'),
          'wrong' => provider.markWordWrong('word'),
          _ => provider.markWordSeen('word'),
        };
        await expectLater(save(), throwsStateError);
        expect(provider.progressMap, isEmpty);
        repo.fail = false;
        await save();
        expect(
          provider.progressMap['word']!.reviewCount,
          action == 'seen' ? 0 : 1,
        );
        expect(repo.writes, 2);
        provider.dispose();
      },
    );
  }
  test('finishing a save after provider disposal does not notify', () async {
    final repo = SaveRepo()..pending = Completer<void>();
    final provider = VocabProvider(repo);
    final saving = provider.markWordCorrect('word');
    provider.dispose();
    repo.pending!.complete();
    await saving;
  });

  for (final flashcard in [false, true]) {
    testWidgets(
      '${flashcard ? 'flashcard' : 'SRS'} save locks buttons and retries without advancing on failure',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(430, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final repo = SaveRepo();
        final provider = VocabProvider(repo);
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: provider,
            child: MaterialApp(
              home: flashcard
                  ? const FlashcardScreen(words: [word], topicTitle: 'Topic')
                  : const SrsReviewScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (flashcard) {
          await tester.tap(find.text('hello').first);
        } else {
          await tester.tap(find.text('Xem nghĩa'));
        }
        await tester.pumpAndSettle();
        repo.pending = Completer<void>();
        final before = repo.writes;
        await tester.tap(find.text('Đã nhớ'));
        await tester.pump();
        await tester.tap(find.text('Đã nhớ'));
        await tester.pump();
        expect(repo.writes, before + 1);
        repo.pending!.completeError(StateError('private SQL error'));
        await tester.pumpAndSettle();
        expect(
          find.text('Chưa lưu được tiến độ. Vui lòng thử lại.'),
          findsOneWidget,
        );
        expect(find.textContaining('private SQL'), findsNothing);
        expect(find.text('Đã nhớ'), findsOneWidget);
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        repo.pending = null;
        await tester.tap(find.text('Đã nhớ'));
        await tester.pumpAndSettle();
        expect(provider.progressOf('word').reviewCount, 1);
        expect(
          find.text(flashcard ? 'Hoàn thành!' : 'Kết quả ôn tập'),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox());
        provider.dispose();
      },
    );
  }
  for (final flashcard in [false, true]) {
    testWidgets(
      '${flashcard ? 'flashcard' : 'SRS'} can close while a save is pending',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(430, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final repo = SaveRepo();
        final provider = VocabProvider(repo);
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: provider,
            child: MaterialApp(
              home: flashcard
                  ? const FlashcardScreen(words: [word], topicTitle: 'Topic')
                  : const SrsReviewScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(flashcard ? 'hello' : 'Xem nghĩa').first);
        await tester.pumpAndSettle();
        repo.pending = Completer<void>();
        await tester.tap(find.text('Đã nhớ'));
        await tester.pump();
        await tester.pumpWidget(const SizedBox());
        provider.dispose();
        repo.pending!.complete();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
