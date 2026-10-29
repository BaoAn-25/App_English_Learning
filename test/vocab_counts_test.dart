import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:thpt_english/data/app_repository.dart';
import 'package:thpt_english/data/models/topic.dart';
import 'package:thpt_english/data/models/word.dart';
import 'package:thpt_english/data/models/word_progress.dart';
import 'package:thpt_english/ui/vocab/topic_list_screen.dart';
import 'package:thpt_english/ui/vocab/vocab_provider.dart';

class CountRepo extends AppRepository {
  bool empty = false;
  @override
  Future<void> upsertWordProgress(WordProgress progress) async {}
  @override
  Future<List<Topic>> getTopicsByGrade(int grade) async => empty
      ? []
      : [
          const Topic(id: 'custom', grade: 12, title: 'Custom topic', order: 1),
          const Topic(id: 'empty', grade: 12, title: 'Empty topic', order: 2),
        ];
  @override
  Future<List<Word>> getWordsByTopicId(String id) async => id != 'custom'
      ? []
      : [
          for (final id in ['legacy-word', 'arbitrary-id'])
            Word(
              id: id,
              topicId: 'old-topic',
              grade: 12,
              english: id,
              ipa: '',
              meaningVi: id,
              example: '',
            ),
        ];
  @override
  Future<List<WordProgress>> getAllWordProgress() async => [
    for (final id in ['legacy-word', 'deleted-word'])
      WordProgress(
        wordId: id,
        reviewCount: 4,
        streak: 4,
        nextReviewAt: 0,
        lastReviewedAt: 0,
      ),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_tts'),
          (_) async => 1,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), null);
  });
  testWidgets('counts actual topic membership and excludes orphan progress', (
    tester,
  ) async {
    final repo = CountRepo();
    final provider = VocabProvider(repo);
    await provider.loadTopics();
    expect(provider.learnedCountForTopic('custom'), 1);
    expect(provider.totalLearnedCount(), 1);
    expect(provider.masteredCount(), 1);
    expect(provider.dueWordCount, 1);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: TopicListScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('2 Chủ Đề THPT Lớp 12'), findsOneWidget);
    expect(find.text('2 Từ Vựng Tiếng Anh'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('1/2 từ đã học'), findsOneWidget);
    expect(find.text('0/0 từ đã học'), findsOneWidget);
    expect(
      tester
          .widgetList<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator),
          )
          .map((w) => w.value),
      [0.5, 0.0],
    );
    await provider.markWordCorrect('arbitrary-id');
    await tester.pumpAndSettle();
    expect(find.text('2/2'), findsOneWidget);
    expect(find.text('2/2 từ đã học'), findsOneWidget);
    repo.empty = true;
    await provider.loadTopics();
    await tester.pumpAndSettle();
    expect(find.text('0/0'), findsOneWidget);
    expect(find.text('0 Chủ Đề THPT Lớp 12'), findsOneWidget);
    expect(provider.totalLearnedCount(), 0);
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  });
}
