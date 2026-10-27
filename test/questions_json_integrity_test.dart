import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('questions.json integrity tests', () {
    late List<dynamic> questions;

    setUpAll(() {
      final file = File('assets/data/questions.json');
      questions = json.decode(file.readAsStringSync()) as List<dynamic>;
    });

    test('Total count is exactly 125', () {
      expect(questions.length, 125);
    });

    test('All IDs are unique and match q_12_01 to q_12_125', () {
      final ids = questions.map((q) => q['id'] as String).toList();
      final idSet = ids.toSet();
      expect(idSet.length, 125, reason: 'Duplicate IDs found');

      final expected = List.generate(125, (i) {
        final n = i + 1;
        return 'q_12_${n.toString().padLeft(2, '0')}';
      }).toSet();
      expect(idSet, equals(expected));
    });

    test('All questions have exactly 4 options', () {
      for (final q in questions) {
        final id = q['id'] as String;
        final opts = q['options'] as List;
        expect(opts.length, 4, reason: 'ID $id: options count is ${opts.length}');
        for (final opt in opts) {
          expect((opt as String).isNotEmpty, isTrue, reason: 'ID $id: empty option');
        }
      }
    });

    test('All correctIndex are in range 0-3', () {
      for (final q in questions) {
        final id = q['id'] as String;
        final ci = q['correctIndex'] as int;
        expect(ci >= 0 && ci <= 3, isTrue, reason: 'ID $id: correctIndex=$ci out of range');
      }
    });

    test('All questions have non-empty stem, type, grade=12', () {
      for (final q in questions) {
        final id = q['id'] as String;
        expect((q['stem'] as String).isNotEmpty, isTrue, reason: 'ID $id: empty stem');
        expect((q['type'] as String).isNotEmpty, isTrue, reason: 'ID $id: empty type');
        expect(q['grade'], 12, reason: 'ID $id: grade is ${q['grade']}');
      }
    });

    test('All type values are valid enum values', () {
      const validTypes = {
        'reading', 'cloze', 'grammar', 'vocab', 'communication',
        'signs', 'synonym_antonym', 'arrange',
      };
      for (final q in questions) {
        final id = q['id'] as String;
        final type = q['type'] as String;
        expect(validTypes.contains(type), isTrue, reason: 'ID $id: invalid type "$type"');
      }
    });

    test('Reading questions (q_12_66 to q_12_85) have passageId and Question: in stem', () {
      final readingQs = questions.where((q) => q['type'] == 'reading').toList();
      expect(readingQs.length, 20);
      for (final q in readingQs) {
        final id = q['id'] as String;
        final pid = q['passageId'];
        expect(pid != null && (pid as String).isNotEmpty, isTrue,
            reason: 'Reading $id: missing passageId');
        final stem = q['stem'] as String;
        expect(stem.contains('Question:'), isTrue,
            reason: 'Reading $id: stem does not contain Question:');
      }
    });

    test('Cloze passage questions (q_12_86 to q_12_95) have passageId and Question: in stem', () {
      final clozePassageQs = questions
          .where((q) => q['type'] == 'cloze' && q['passageId'] != null)
          .toList();
      expect(clozePassageQs.length, 10);
      for (final q in clozePassageQs) {
        final id = q['id'] as String;
        final stem = q['stem'] as String;
        expect(stem.contains('Question:'), isTrue,
            reason: 'Cloze $id: stem does not contain Question:');
      }
    });

    test('Single-sentence cloze questions (q_12_56-q_12_65) have null passageId', () {
      final singleCloze = questions
          .where((q) => q['type'] == 'cloze' && q['passageId'] == null)
          .toList();
      expect(singleCloze.length, 10);
    });

    test('Signs questions (q_12_41 to q_12_102 signs) have sign text in stem', () {
      final signsQs = questions.where((q) => q['type'] == 'signs').toList();
      expect(signsQs.length, 12);
      for (final q in signsQs) {
        final id = q['id'] as String;
        final stem = (q['stem'] as String).toLowerCase();
        final hasSign = stem.contains('a sign reads:') || stem.contains('a notice reads:');
        expect(hasSign, isTrue,
            reason: 'Signs $id: missing "a sign reads:" or "a notice reads:"');
      }
    });

    test('New questions (q_12_71 to q_12_125) all have explanation', () {
      for (final q in questions) {
        final id = q['id'] as String;
        final num = int.parse(id.split('_').last);
        if (num >= 71) {
          final expl = q['explanation'] as String?;
          expect(expl != null && expl.isNotEmpty, isTrue,
              reason: 'ID $id: missing explanation');
        }
      }
    });
  });
}
