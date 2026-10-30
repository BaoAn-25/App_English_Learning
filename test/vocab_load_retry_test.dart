import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:thpt_english/data/app_repository.dart';
import 'package:thpt_english/data/models/topic.dart';
import 'package:thpt_english/data/models/word.dart';
import 'package:thpt_english/data/models/word_progress.dart';
import 'package:thpt_english/ui/vocab/vocab_provider.dart';
import 'package:thpt_english/ui/vocab/topic_list_screen.dart';
import 'package:thpt_english/ui/vocab/word_list_screen.dart';
import 'package:thpt_english/ui/vocab/srs_review_screen.dart';

const topic = Topic(id: 'topic', grade: 12, title: 'Test topic', order: 1);
Word word(String id) => Word(
  id: id,
  topicId: 'topic',
  grade: 12,
  english: id,
  ipa: '',
  meaningVi: 'Nghĩa',
  example: 'Example',
);

class LoadRepo extends AppRepository {
  bool fail = true;
  Completer<List<WordProgress>>? pendingDue;
  final pending = <String, Completer<List<Word>>>{};
  @override
  Future<List<Topic>> getTopicsByGrade(int grade) async {
    if (fail) throw StateError('private database error');
    return [topic];
  }

  @override
  Future<List<Word>> getWordsByTopicId(String id) async {
    if (pending.containsKey(id)) return pending[id]!.future;
    if (fail) throw StateError('private database error');
    return [word('hello')];
  }

  @override
  Future<List<WordProgress>> getAllWordProgress() async => [];
  @override
  Future<List<WordProgress>> getDueWordProgress() async {
    if (pendingDue != null) return pendingDue!.future;
    if (fail) throw StateError('private database error');
    return [
      const WordProgress(
        wordId: 'hello',
        reviewCount: 1,
        nextReviewAt: 0,
        lastReviewedAt: 0,
      ),
    ];
  }

  @override
  Future<List<Word>> getAllWords() async => [word('hello')];
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
  for (final mode in ['topics', 'words', 'due']) {
    testWidgets('$mode shows load failure and retries successfully', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(430, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = LoadRepo();
      final provider = VocabProvider(repo);
      if (mode == 'topics') await provider.loadTopics();
      if (mode == 'words') await provider.loadWordsByTopic(topic.id);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            home: switch (mode) {
              'topics' => const TopicListScreen(),
              'words' => const WordListScreen(topic: topic),
              _ => const SrsReviewScreen(),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Thử lại'), findsOneWidget);
      expect(find.textContaining('private database'), findsNothing);
      expect(find.text('Không có chủ đề nào.'), findsNothing);
      expect(find.byTooltip('Flashcard'), findsNothing);
      repo.fail = false;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('Thử lại'), findsNothing);
      expect(
        find.text(mode == 'topics' ? 'Test topic' : 'hello'),
        findsWidgets,
      );
      await tester.pumpWidget(const SizedBox());
      provider.dispose();
    });
  }
  test(
    'latest topic wins and failed topic cannot expose previous words',
    () async {
      final repo = LoadRepo()..fail = false;
      final provider = VocabProvider(repo);
      await provider.loadWordsByTopic('first');
      repo.fail = true;
      await provider.loadWordsByTopic('failed');
      expect(provider.words, isEmpty);
      repo.pending['slow'] = Completer<List<Word>>();
      repo.pending['fast'] = Completer<List<Word>>();
      final slow = provider.loadWordsByTopic('slow');
      final fast = provider.loadWordsByTopic('fast');
      repo.pending['fast']!.complete([word('fast')]);
      await fast;
      repo.pending['slow']!.complete([word('slow')]);
      await slow;
      expect(provider.words.map((w) => w.id), ['fast']);
      expect(provider.selectedTopicId, 'fast');
      provider.dispose();
    },
  );
  test('simultaneous due loaders wait for the same result', () async {
    final repo = LoadRepo()..fail = false;
    repo.pendingDue = Completer<List<WordProgress>>();
    final provider = VocabProvider(repo);
    final first = provider.loadDueWords();
    var secondFinished = false;
    final second = provider.loadDueWords().then((_) => secondFinished = true);
    await Future<void>.delayed(Duration.zero);
    expect(secondFinished, isFalse);
    repo.pendingDue!.complete([]);
    await Future.wait([first, second]);
    expect(provider.dueLoadFailed, isFalse);
    provider.dispose();
  });
}
