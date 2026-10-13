import 'dart:convert';

class Question {
  final String id;
  final int grade;
  final String type; // vocab, grammar, synonym_antonym, communication, signs, arrange, cloze, reading
  final String stem;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final String? topicId;
  final String? passageId;
  final int difficulty;

  const Question({
    required this.id,
    required this.grade,
    required this.type,
    required this.stem,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    this.topicId,
    this.passageId,
    required this.difficulty,
  });

  factory Question.fromMap(Map<String, dynamic> map) {
    final rawOptions = map['options'];
    final List<String> parsedOptions;
    if (rawOptions is String) {
      final decoded = jsonDecode(rawOptions);
      if (decoded is List) {
        parsedOptions = decoded.map((e) => e.toString()).toList();
      } else {
        parsedOptions = [];
      }
    } else if (rawOptions is List) {
      parsedOptions = rawOptions.map((e) => e.toString()).toList();
    } else {
      parsedOptions = [];
    }

    return Question(
      id: map['id'] as String,
      grade: (map['grade'] as num).toInt(),
      type: map['type'] as String,
      stem: map['stem'] as String,
      options: parsedOptions,
      correctIndex: (map['correctIndex'] as num).toInt(),
      explanation: map['explanation'] as String,
      topicId: map['topicId'] as String?,
      passageId: map['passageId'] as String?,
      difficulty: (map['difficulty'] as num).toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'grade': grade,
      'type': type,
      'stem': stem,
      'options': jsonEncode(options),
      'correctIndex': correctIndex,
      'explanation': explanation,
      'topicId': topicId,
      'passageId': passageId,
      'difficulty': difficulty,
    };
  }
}
