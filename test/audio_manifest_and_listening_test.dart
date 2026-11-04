import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:thpt_english/data/listening_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Audio Manifest & Integration Verification', () {
    late Map<String, dynamic> manifestData;
    late List<dynamic> tracksRaw;

    setUpAll(() {
      final file = File('assets/data/audio_manifest.json');
      expect(file.existsSync(), isTrue, reason: 'audio_manifest.json phải tồn tại');
      final content = file.readAsStringSync();
      manifestData = jsonDecode(content) as Map<String, dynamic>;
      tracksRaw = manifestData['tracks'] as List<dynamic>;
    });

    test('1. Đúng 51 track MP3 trong manifest và không có ID trùng lặp', () {
      expect(tracksRaw.length, equals(51), reason: 'Phải có đúng 51 audio tracks');

      final ids = <String>{};
      for (final t in tracksRaw) {
        final id = t['id'] as String;
        expect(ids.contains(id), isFalse, reason: 'ID không được trùng lặp: $id');
        ids.add(id);
      }
    });

    test('2. Tất cả 51 file MP3 được khai báo đều tồn tại thực tế trên ổ đĩa', () {
      for (final t in tracksRaw) {
        final assetPath = t['assetPath'] as String;
        final file = File(assetPath);
        expect(file.existsSync(), isTrue, reason: 'File MP3 phải tồn tại: $assetPath');
        expect(file.lengthSync(), equals(t['bytes']), reason: 'Kích thước bytes phải khớp manifest');
      }
    });

    test('3. Unit 7 Listening dùng chung một track cho Activity 2 và 3', () {
      final u7Tracks = tracksRaw.where((t) => t['lessonKey'] == 'unit-07' && t['section'] == 'listening').toList();
      expect(u7Tracks.length, equals(1), reason: 'Unit 7 Listening chỉ có 1 track chung');

      final track = u7Tracks.first;
      final acts = (track['activityNumbers'] as List<dynamic>).map((e) => e.toString()).toList();
      expect(acts, containsAll(['2', '3']), reason: 'Unit 7 track phải phục vụ cả activity 2 và 3');
      expect(track['durationSeconds'], greaterThan(200.0), reason: 'Thời lượng track 7 dài khoảng 202s');
    });

    test('4. Unit 6 Listening có hai phần hội thoại riêng biệt theo hoạt động', () {
      final u6Tracks = tracksRaw.where((t) => t['lessonKey'] == 'unit-06' && t['section'] == 'listening').toList();
      expect(u6Tracks.length, equals(2), reason: 'Unit 6 có 2 track cho 2 hoạt động');

      final a2 = u6Tracks.firstWhere((t) => (t['activityNumbers'] as List<dynamic>).contains('2'));
      final a3 = u6Tracks.firstWhere((t) => (t['activityNumbers'] as List<dynamic>).contains('3'));

      expect(a2['id'], equals('gs12_unit_06_listening_a2'));
      expect(a3['id'], equals('gs12_unit_06_listening_a3'));
      expect(a2['durationSeconds'], closeTo(77.09, 0.5));
      expect(a3['durationSeconds'], closeTo(105.81, 0.5));
    });

    test('5. Reading Review 1..4 liên kết đúng và không bị nhầm thành Unit', () {
      final reviews = ['review-01', 'review-02', 'review-03', 'review-04'];
      for (final rev in reviews) {
        final revReading = tracksRaw.where((t) => t['lessonKey'] == rev && t['section'] == 'reading').toList();
        expect(revReading.length, equals(1), reason: '$rev phải có đúng 1 reading track');
        final r = revReading.first;
        expect((r['activityNumbers'] as List<dynamic>).contains('1'), isTrue, reason: 'Reading review là activity 1');
      }
    });

    test('6. Đủ 10 track Vocabulary Activity 1 cho cả 10 Unit', () {
      for (int i = 1; i <= 10; i++) {
        final key = 'unit-${i.toString().padLeft(2, '0')}';
        final vocabTracks = tracksRaw.where((t) => t['lessonKey'] == key && t['section'] == 'language' && t['subskill'] == 'vocabulary').toList();
        expect(vocabTracks.length, equals(1), reason: '$key phải có 1 vocabulary audio track');
      }
    });
  });

  group('Listening Repository & Normalization Tests', () {
    final repo = ListeningRepository.instance;

    test('7. Đủ 10 Unit và 4 Review trong ListeningRepository', () {
      final all = repo.getAllLessons();
      expect(all.length, equals(14));

      for (int i = 1; i <= 10; i++) {
        final lesson = repo.getLesson('unit-${i.toString().padLeft(2, '0')}');
        expect(lesson, isNotNull);
        expect(lesson!.unitNumber, equals(i));
        expect(lesson.activities.isNotEmpty, isTrue);
      }

      for (int i = 1; i <= 4; i++) {
        final rev = repo.getLesson('review-${i.toString().padLeft(2, '0')}');
        expect(rev, isNotNull);
        expect(rev!.isReview, isTrue);
      }
    });

    test('8. So khớp đáp án mềm mại (hoa/thường, khoảng trắng, dấu câu, từ tương đương)', () {
      const item = ListeningItem(
        id: 'test_1',
        prompt: 'Fill in',
        answer: 'Halloween party',
        acceptableAnswers: ['party', 'halloween'],
      );

      // Đúng chuẩn
      expect(ListeningRepository.checkAnswer(item, 'Halloween party'), isTrue);
      // Viết thường
      expect(ListeningRepository.checkAnswer(item, 'halloween party'), isTrue);
      // Thừa khoảng trắng
      expect(ListeningRepository.checkAnswer(item, '  halloween   party  '), isTrue);
      // Thừa dấu chấm
      expect(ListeningRepository.checkAnswer(item, 'Halloween party.'), isTrue);
      // Đáp án chấp nhận thay thế
      expect(ListeningRepository.checkAnswer(item, 'party'), isTrue);
      expect(ListeningRepository.checkAnswer(item, 'halloween'), isTrue);
      // Sai nội dung
      expect(ListeningRepository.checkAnswer(item, 'Christmas party'), isFalse);
      expect(ListeningRepository.checkAnswer(item, ''), isFalse);
    });
  });
}

