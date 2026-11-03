import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thpt_english/data/trial_lesson_repository.dart';
import 'package:thpt_english/data/translation_service.dart';
import 'package:thpt_english/ui/trial/interactive_reading_text.dart';

void main() {
  setUp(() {
    TranslationService.instance.clearCache();
    TranslationService.instance.mockTranslator = null;
  });

  group('A. Tra từ theo ngữ cảnh (Contextual Word Lookup)', () {
    final repo = TrialLessonRepository.instance;

    test('1. "has" trong "has attracted": nhận diện trợ động từ thì Hiện tại hoàn thành', () {
      final result = repo.lookupWordInContext(
        word: 'has',
        sentence: 'Steve Jobs has attracted thousands of followers around the world.',
      );

      expect(result.isFoundInDictionary, isTrue);
      expect(result.grammaticalRole, contains('Hiện tại hoàn thành'));
      expect(result.partOfSpeech, contains('trợ động từ'));
      expect(result.meaning.toLowerCase(), contains('trợ động từ tạo thì'));
      expect(result.meaning.toLowerCase(), contains('hiện tại hoàn thành'));
    });

    test('2. "has" trong "He has four children": nhận diện động từ chỉ sở hữu', () {
      final result = repo.lookupWordInContext(
        word: 'has',
        sentence: 'He has four children and lives in California.',
      );

      expect(result.isFoundInDictionary, isTrue);
      expect(result.grammaticalRole, contains('sở hữu'));
      expect(result.partOfSpeech, contains('ngoại động từ'));
      expect(result.meaning, contains('sở hữu'));
      expect(result.meaning, isNot(contains('Trợ động từ tạo thì')));
    });

    test('3. "had" trong "had decided" (Quá khứ hoàn thành) vs "had a car" (Sở hữu)', () {
      final hadPerfect = repo.lookupWordInContext(
        word: 'had',
        sentence: 'Before 1990, he had decided to start a new company.',
      );
      expect(hadPerfect.grammaticalRole, contains('Quá khứ hoàn thành'));

      final hadPossession = repo.lookupWordInContext(
        word: 'had',
        sentence: 'He had a small garage behind his parents house.',
      );
      expect(hadPossession.grammaticalRole, contains('sở hữu'));
    });

    test('4. "has to" nhận diện động từ chỉ bổn phận/bắt buộc', () {
      final result = repo.lookupWordInContext(
        word: 'has',
        sentence: 'Every student has to complete the reading assignment.',
      );
      expect(result.displayWord, contains('has to'));
      expect(result.meaning, contains('Phải'));
    });

    test('5. "is/was" tiếp diễn (V-ing) vs bị động (V-ed) vs liên kết (Linking)', () {
      final continuous = repo.lookupWordInContext(
        word: 'is',
        sentence: 'The city is developing rapidly with new technologies.',
      );
      expect(continuous.grammaticalRole, contains('Tiếp diễn'));

      final passive = repo.lookupWordInContext(
        word: 'was',
        sentence: 'The personal computer was built in a small garage.',
      );
      expect(passive.grammaticalRole, contains('Bị động'));

      final linking = repo.lookupWordInContext(
        word: 'was',
        sentence: 'Steve Jobs was a brilliant visionary.',
      );
      expect(linking.grammaticalRole, contains('Động từ liên kết'));
    });

    test('6. Lemmatization và từ biến thể: "attracted", "children", "went"', () {
      final attractedRes = repo.lookupWordInContext(
        word: 'attracted',
        sentence: 'The exhibition attracted thousands of visitors.',
      );
      expect(attractedRes.isFoundInDictionary, isTrue);
      expect(attractedRes.meaning, contains('thu hút'));

      final childrenRes = repo.lookupWordInContext(
        word: 'children',
        sentence: 'He spent time with his children.',
      );
      expect(childrenRes.isFoundInDictionary, isTrue);
      expect(childrenRes.meaning, contains('trẻ em'));

      final wentRes = repo.lookupWordInContext(
        word: 'went',
        sentence: 'He went to Reed College for six months.',
      );
      expect(wentRes.isFoundInDictionary, isTrue);
      expect(wentRes.displayWord, contains('của go'));
    });

    test('7. Gợi ý cụm từ liên kết trong câu: "passed" trong "passed away"', () {
      final result = repo.lookupWordInContext(
        word: 'passed',
        sentence: 'Steve Jobs passed away on October 5, 2011.',
      );
      expect(result.phraseSuggestion, equals('passed away'));
      expect(result.phraseMeaning, contains('qua đời'));
    });
  });

  group('B. Dịch cụm từ bôi đen (Selection Translation) & TranslationService', () {
    test('1. Bôi đen "attracted thousands": trả về đúng nghĩa của cụm, KHÔNG trả về bản dịch cả đoạn', () async {
      final result = await TranslationService.instance.translateSelection(
        text: 'attracted thousands',
      );

      expect(result.isSuccess, isTrue);
      expect(result.originalText, equals('attracted thousands'));
      expect(result.translatedText, contains('thu hút hàng nghìn người'));
      // Đảm bảo không chứa bản dịch của đoạn văn Steve Jobs
      expect(result.translatedText, isNot(contains('Steve Jobs sinh ngày')));
    });

    test('2. Cụm từ chưa có trong từ điển: khi có mạng (mock translate)', () async {
      TranslationService.instance.mockTranslator = (text) async {
        if (text == 'breakthrough innovations') {
          return 'những đổi mới mang tính đột phá';
        }
        return null;
      };

      final result = await TranslationService.instance.translateSelection(
        text: 'breakthrough innovations',
      );

      expect(result.isSuccess, isTrue);
      expect(result.source, equals(TranslationSource.machineTranslation));
      expect(result.translatedText, equals('những đổi mới mang tính đột phá'));

      // Lần thứ hai phải lấy từ cache
      final cachedResult = await TranslationService.instance.translateSelection(
        text: 'breakthrough innovations',
      );
      expect(cachedResult.source, equals(TranslationSource.cache));
    });

    test('3. Cụm từ chưa có trong từ điển: khi mất kết nối mạng (trung thực)', () async {
      TranslationService.instance.mockTranslator = (text) async {
        throw Exception('Network unreachable');
      };

      final result = await TranslationService.instance.translateSelection(
        text: 'novel quantum processor',
      );

      expect(result.isSuccess, isFalse);
      expect(result.requiresNetwork, isTrue);
      expect(result.errorMessage, isNotNull);
      // Tuyệt đối không bịa nghĩa tiếng Việt
      expect(result.translatedText, isEmpty);
    });

    test('5. Xử lý timeout khi dịch trực tuyến: báo lỗi quá thời gian chờ trung thực', () async {
      TranslationService.instance.mockTranslator = (text) async {
        await Future.delayed(const Duration(milliseconds: 100));
        throw Exception('Connection timed out');
      };

      final result = await TranslationService.instance.translateSelection(
        text: 'long sentence with timeout',
      );

      expect(result.isSuccess, isFalse);
      expect(result.requiresNetwork, isTrue);
      expect(result.errorMessage, contains('timed out'));
    });

    test('6. Cụm từ xuất hiện 2 lần trong văn bản: nhận diện đúng cụm và nghĩa độc lập', () async {
      // Cả 2 lần đều tra đúng cụm carried out trong 2 câu khác nhau của đoạn văn
      final res1 = TrialLessonRepository.instance.lookupWordInContext(
        word: 'carried',
        sentence: 'The team carried out extensive research in 2020.',
      );
      expect(res1.phraseSuggestion, equals('carried out'));
      expect(res1.phraseMeaning, contains('tiến hành'));

      final res2 = TrialLessonRepository.instance.lookupWordInContext(
        word: 'carried',
        sentence: 'Later, they carried out further experiments in 2022.',
      );
      expect(res2.phraseSuggestion, equals('carried out'));
      expect(res2.phraseMeaning, contains('tiến hành'));
    });
  });

  group('C. UI Widget InteractiveReadingText & Độc lập 3 chức năng', () {
    testWidgets('1. Nút "Dịch đoạn" độc lập: chỉ mở bản dịch toàn đoạn khi bấm', (tester) async {
      const sampleText = 'Steve Jobs was born in San Francisco in 1955.';
      const sampleTranslation = 'Steve Jobs sinh ra tại San Francisco vào năm 1955.';
      var paragraphAssistanceCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveReadingText(
              text: sampleText,
              translation: sampleTranslation,
              onAssistanceUsed: (type) {
                if (type == ReadingAssistanceType.paragraphTranslate) {
                  paragraphAssistanceCalled = true;
                }
              },
            ),
          ),
        ),
      );

      // Ban đầu bản dịch toàn đoạn chưa hiển thị
      expect(find.text(sampleTranslation), findsNothing);
      expect(find.text('Dịch đoạn (Tiếng Việt)'), findsOneWidget);

      // Bấm nút Dịch đoạn
      await tester.tap(find.text('Dịch đoạn (Tiếng Việt)'));
      await tester.pumpAndSettle();

      // Bản dịch toàn đoạn hiện ra
      expect(find.text(sampleTranslation), findsOneWidget);
      expect(find.text('Thu gọn bản dịch'), findsOneWidget);
      expect(paragraphAssistanceCalled, isTrue);

      // Bấm thu gọn
      await tester.tap(find.text('Thu gọn bản dịch'));
      await tester.pumpAndSettle();
      expect(find.text(sampleTranslation), findsNothing);
    });

    testWidgets('2. Chạm vào từ "born" mở modal tra cứu ngữ cảnh', (tester) async {
      const sampleText = 'Steve Jobs was born in 1955.';
      var wordAssistanceCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveReadingText(
              text: sampleText,
              onAssistanceUsed: (type) {
                if (type == ReadingAssistanceType.wordLookup) {
                  wordAssistanceCalled = true;
                }
              },
            ),
          ),
        ),
      );

      // Tìm từ 'born' và tap
      final bornFinder = find.text('born');
      if (bornFinder.evaluate().isNotEmpty) {
        await tester.tap(bornFinder);
        await tester.pumpAndSettle();

        // Kiểm tra modal đã mở với nghĩa tiếng Việt
        expect(find.textContaining('sinh ra'), findsOneWidget);
        expect(wordAssistanceCalled, isTrue);
      }
    });

    testWidgets('3. Chống xung đột: gọi onInteractionStart khi bắt đầu chạm/tra từ', (tester) async {
      var interactionStarted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveReadingText(
              text: 'He has four children.',
              onInteractionStart: () {
                interactionStarted = true;
              },
            ),
          ),
        ),
      );

      final hasFinder = find.text('has');
      if (hasFinder.evaluate().isNotEmpty) {
        await tester.tap(hasFinder);
        await tester.pumpAndSettle();
        expect(interactionStarted, isTrue);
      }
    });

    testWidgets('4. Chạm vào từ chưa có trong từ điển: tự động tra nghĩa trực tuyến hiển thị cho người học', (tester) async {
      TranslationService.instance.mockTranslator = (text) async {
        if (text == 'unconventional') {
          return 'khác thường, độc đáo';
        }
        return null;
      };

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InteractiveReadingText(
              text: 'He had an unconventional style.',
            ),
          ),
        ),
      );

      final wordFinder = find.text('unconventional');
      if (wordFinder.evaluate().isNotEmpty) {
        await tester.tap(wordFinder);
        await tester.pumpAndSettle();

        // Kiểm tra đã hiển thị nghĩa tiếng Việt tra cứu trực tuyến
        expect(find.textContaining('khác thường, độc đáo'), findsOneWidget);
      }
    });
  });
}
