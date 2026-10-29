import 'dart:convert';
import 'dart:math';

import 'question.dart';

/// Carries the exact unreadable payload for explicit, race-safe removal.
class CorruptExamDraftException implements Exception {
  final String payload;
  const CorruptExamDraftException(this.payload);
  @override
  String toString() => 'Bản nháp bài thi không đọc được.';
}

/// A locally saved exam. Answer indices always refer to the original options.
class MockExamDraft {
  final String id;
  final List<Question> questions;
  final List<List<int>> optionOrder;
  final List<int?> answers;
  final List<int> flagged;
  final int currentIndex;
  final int startedAt;
  final int deadline;
  final int revision;

  MockExamDraft({
    required this.id,
    required List<Question> questions,
    required List<List<int>> optionOrder,
    required List<int?> answers,
    required List<int> flagged,
    required this.currentIndex,
    required this.startedAt,
    required this.deadline,
    this.revision = 0,
  }) : questions = List.unmodifiable(
         questions.map(
           (q) => Question.fromMap({
             ...q.toMap(),
             'options': List<String>.unmodifiable(q.options),
           }),
         ),
       ),
       optionOrder = List.unmodifiable(
         optionOrder.map((order) => List<int>.unmodifiable(order)),
       ),
       answers = List.unmodifiable(answers),
       flagged = List.unmodifiable(flagged) {
    if (id.isEmpty ||
        questions.isEmpty ||
        questions.length > 100 ||
        questions.map((q) => q.id).toSet().length != questions.length ||
        answers.length != questions.length ||
        optionOrder.length != questions.length ||
        currentIndex < 0 ||
        currentIndex >= questions.length ||
        startedAt < 0 ||
        deadline <= startedAt ||
        (deadline - startedAt) % 60000 != 0 ||
        deadline - startedAt > 24 * 60 * 60000 ||
        revision < 0 ||
        flagged.toSet().length != flagged.length ||
        flagged.any((i) => i < 0 || i >= questions.length)) {
      throw const FormatException('Bài thi đã lưu không hợp lệ.');
    }
    for (var i = 0; i < questions.length; i++) {
      final count = questions[i].options.length;
      final order = optionOrder[i];
      final answer = answers[i];
      if (count < 2 ||
          questions[i].correctIndex < 0 ||
          questions[i].correctIndex >= count ||
          order.length != count ||
          order.toSet().length != count ||
          order.any((n) => n < 0 || n >= count) ||
          (answer != null && (answer < 0 || answer >= count))) {
        throw const FormatException('Đáp án đã lưu không hợp lệ.');
      }
    }
  }

  factory MockExamDraft.start({
    required List<Question> questions,
    required int durationMinutes,
    required DateTime now,
    List<List<int>>? optionOrder,
  }) {
    final random = Random.secure();
    return MockExamDraft(
      id: List.generate(
        16,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join(),
      questions: questions,
      optionOrder:
          optionOrder ??
          questions
              .map(
                (q) =>
                    List.generate(q.options.length, (i) => i)..shuffle(random),
              )
              .toList(),
      answers: List.filled(questions.length, null),
      flagged: [],
      currentIndex: 0,
      startedAt: now.millisecondsSinceEpoch,
      deadline: now
          .add(Duration(minutes: durationMinutes))
          .millisecondsSinceEpoch,
    );
  }

  int get durationMinutes => (deadline - startedAt) ~/ 60000;
  bool expired(DateTime now) => now.millisecondsSinceEpoch >= deadline;

  MockExamDraft copyWith({
    List<int?>? answers,
    List<int>? flagged,
    int? currentIndex,
    int? revision,
  }) => MockExamDraft(
    id: id,
    questions: questions,
    optionOrder: optionOrder,
    answers: answers ?? this.answers,
    flagged: flagged ?? this.flagged,
    currentIndex: currentIndex ?? this.currentIndex,
    revision: revision ?? this.revision,
    startedAt: startedAt,
    deadline: deadline,
  );

  String toJson() => jsonEncode({
    'id': id,
    'questions': questions.map((q) => q.toMap()).toList(),
    'optionOrder': optionOrder,
    'answers': answers,
    'flagged': flagged,
    'currentIndex': currentIndex,
    'startedAt': startedAt,
    'deadline': deadline,
    'revision': revision,
  });

  factory MockExamDraft.fromJson(String source) {
    final m = jsonDecode(source) as Map<String, dynamic>;
    return MockExamDraft(
      id: m['id'] as String,
      questions: (m['questions'] as List)
          .map((q) => Question.fromMap(Map<String, dynamic>.from(q as Map)))
          .toList(),
      optionOrder: (m['optionOrder'] as List)
          .map((v) => List<int>.from(v as List))
          .toList(),
      answers: List<int?>.from(m['answers'] as List),
      flagged: List<int>.from(m['flagged'] as List),
      currentIndex: m['currentIndex'] as int,
      startedAt: m['startedAt'] as int,
      deadline: m['deadline'] as int,
      revision: m['revision'] as int,
    );
  }
}
