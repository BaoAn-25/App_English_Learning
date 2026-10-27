import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:thpt_english/data/models/question.dart';
import 'package:thpt_english/ui/practice/services/exam_builder_service.dart';

Question _q(String id, String type, {String? passageId, int correct = 0}) {
  return Question(
    id: id,
    grade: 12,
    type: type,
    stem: 'stem $id',
    options: const ['A', 'B', 'C', 'D'],
    correctIndex: correct,
    explanation: 'exp',
    passageId: passageId,
    difficulty: 1,
  );
}

void _expectPassageClusters(List<Question> list) {
  final seen = <String>{};
  String? current;
  for (final q in list) {
    final pid = q.passageId;
    if (pid != current) {
      if (current != null) seen.add(current);
      if (pid != null) {
        expect(seen.contains(pid), isFalse,
            reason: 'Passage $pid bị tách thành nhiều cụm');
      }
      current = pid;
    }
  }
  // Thứ tự trong cụm tăng dần theo id.
  final byPassage = <String, List<int>>{};
  for (final q in list) {
    if (q.passageId == null) continue;
    byPassage
        .putIfAbsent(q.passageId!, () => [])
        .add(int.parse(q.id.split('_').last));
  }
  for (final e in byPassage.entries) {
    final sorted = [...e.value]..sort();
    expect(e.value, sorted, reason: 'Passage ${e.key} sai thứ tự câu');
  }
}

void main() {
  late List<Question> bank;

  setUpAll(() {
    final raw = json.decode(File('assets/data/questions.json').readAsStringSync())
        as List<dynamic>;
    bank = raw
        .map((e) => Question.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  });

  group('Ma trận đề thi', () {
    test('3 chế độ có tổng ma trận đúng bằng số câu', () {
      for (final n in [10, 20, 50]) {
        final m = ExamBuilderService.matrixFor(n);
        expect(m.values.fold<int>(0, (a, b) => a + b), n);
        expect(m.keys.toSet(), ExamBuilderService.typeOrder.toSet());
      }
    });

    test('Số câu tùy ý được phân bổ đúng tổng', () {
      for (final n in [1, 7, 13, 33, 64]) {
        final m = ExamBuilderService.matrixFor(n);
        expect(m.values.fold<int>(0, (a, b) => a + b), n);
      }
    });
  });

  group('buildMockExam với ngân hàng 125 câu thật', () {
    for (final n in [10, 20, 50]) {
      test('Chế độ $n câu: đủ số câu, không trùng ID, đúng ma trận, cụm liền nhau',
          () {
        for (var seed = 0; seed < 200; seed++) {
          final result = ExamBuilderService(random: Random(seed))
              .buildMockExam(bank, count: n);

          expect(result.questions.length, n, reason: 'seed $seed');
          expect(result.isComplete, isTrue);
          expect(result.shortage, 0);
          expect(result.questions.map((q) => q.id).toSet().length, n,
              reason: 'Trùng ID, seed $seed');

          final matrix = ExamBuilderService.matrixFor(n);
          for (final type in ExamBuilderService.typeOrder) {
            final got = result.questions.where((q) => q.type == type).length;
            expect(got, matrix[type], reason: '$type seed $seed');
          }
          _expectPassageClusters(result.questions);
        }
      });
    }

    test('Không cắt bài đọc ở chế độ 10/20/50 (nếu có thể chọn nguyên cụm)', () {
      for (final n in [10, 20, 50]) {
        for (var seed = 0; seed < 100; seed++) {
          final result = ExamBuilderService(random: Random(seed))
              .buildMockExam(bank, count: n);
          expect(result.splitPassageCount, 0, reason: 'n=$n seed=$seed');
          final sizes = <String, int>{};
          for (final q in bank) {
            if (q.passageId != null) {
              sizes[q.passageId!] = (sizes[q.passageId!] ?? 0) + 1;
            }
          }
          final inExam = <String, int>{};
          for (final q in result.questions) {
            if (q.passageId != null) {
              inExam[q.passageId!] = (inExam[q.passageId!] ?? 0) + 1;
            }
          }
          for (final e in inExam.entries) {
            expect(e.value, sizes[e.key], reason: '${e.key} bị cắt');
          }
        }
      }
    });

    test('Không thay đổi options và correctIndex của dữ liệu gốc', () {
      final originals = {
        for (final q in bank) q.id: (List<String>.of(q.options), q.correctIndex),
      };
      final result =
          ExamBuilderService(random: Random(1)).buildMockExam(bank, count: 50);
      for (final q in result.questions) {
        expect(q.options, originals[q.id]!.$1);
        expect(q.correctIndex, originals[q.id]!.$2);
      }
      // Danh sách đầu vào không bị thay đổi thứ tự/độ dài.
      expect(bank.length, originals.length);
    });

    test('Đề thi là các câu thuộc ngân hàng (cùng instance)', () {
      final ids = bank.map((q) => q.id).toSet();
      final result =
          ExamBuilderService(random: Random(3)).buildMockExam(bank, count: 20);
      expect(result.questions.every((q) => ids.contains(q.id)), isTrue);
    });
  });

  group('Trường hợp thiếu câu hỏi', () {
    test('Ngân hàng ít hơn yêu cầu: trả về toàn bộ, báo thiếu', () {
      final small = [
        _q('q_1', 'grammar'),
        _q('q_2', 'vocab'),
        _q('q_3', 'grammar'),
      ];
      final r = ExamBuilderService(random: Random(0))
          .buildMockExam(small, count: 10);
      expect(r.questions.length, 3);
      expect(r.isComplete, isFalse);
      expect(r.shortage, 7);
    });

    test('Thiếu một dạng bài: bù từ dạng còn dư, vẫn đủ số câu', () {
      final onlyGrammar = List.generate(30, (i) => _q('q_$i', 'grammar'));
      final r = ExamBuilderService(random: Random(0))
          .buildMockExam(onlyGrammar, count: 20);
      expect(r.questions.length, 20);
      expect(r.questions.map((q) => q.id).toSet().length, 20);
      expect(r.isComplete, isTrue);
    });

    test('Ngân hàng rỗng', () {
      final r = ExamBuilderService().buildMockExam([], count: 10);
      expect(r.questions, isEmpty);
      expect(r.isComplete, isFalse);
    });

    test('ID trùng trong đầu vào bị loại', () {
      final dup = [_q('q_1', 'grammar'), _q('q_1', 'grammar'), _q('q_2', 'vocab')];
      final r =
          ExamBuilderService(random: Random(0)).buildMockExam(dup, count: 3);
      expect(r.questions.length, 2);
    });

    test('Chỉ cắt bài đọc khi bắt buộc và vẫn giữ thứ tự liên tiếp', () {
      final reading = List.generate(
        5,
        (i) => _q('q_${i + 1}', 'reading', passageId: 'p1'),
      );
      final r = ExamBuilderService(random: Random(0))
          .buildMockExam(reading, count: 3);
      expect(r.questions.length, 3);
      expect(r.splitPassageCount, 1);
      expect(r.questions.map((q) => q.id).toList(), ['q_1', 'q_2', 'q_3']);
    });
  });

  group('buildPracticeSet (luyện tập)', () {
    test('Reading: nhóm nguyên cụm, 10 câu, không trùng, đúng thứ tự', () {
      final reading = bank.where((q) => q.type == 'reading').toList();
      for (var seed = 0; seed < 100; seed++) {
        final set = ExamBuilderService(random: Random(seed))
            .buildPracticeSet(reading, count: 10);
        expect(set.length, 10);
        expect(set.map((q) => q.id).toSet().length, 10);
        _expectPassageClusters(set);
      }
    });

    test('Cloze: gồm cả cụm passage và câu lẻ, vẫn liền nhau', () {
      final cloze = bank.where((q) => q.type == 'cloze').toList();
      for (var seed = 0; seed < 100; seed++) {
        final set = ExamBuilderService(random: Random(seed))
            .buildPracticeSet(cloze, count: 10);
        expect(set.length, 10);
        expect(set.map((q) => q.id).toSet().length, 10);
        _expectPassageClusters(set);
      }
    });

    test('Dạng ít hơn 10 câu: trả về tất cả', () {
      final few = bank.where((q) => q.type == 'arrange').take(4).toList();
      final set = ExamBuilderService().buildPracticeSet(few, count: 10);
      expect(set.length, 4);
    });
  });
}
