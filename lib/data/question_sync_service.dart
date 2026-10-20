import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'app_repository.dart';
import 'models/question.dart';

class QuestionSyncService {
  static Future<int> syncQuestions(AppRepository repository) async {
    final jsonString = await rootBundle.loadString(
      'assets/data/questions.json',
    );

    final decoded = jsonDecode(jsonString);

    if (decoded is! List) {
      throw const FormatException(
        'questions.json phải chứa một danh sách câu hỏi.',
      );
    }

    final questions = decoded.map((item) {
      return Question.fromMap(Map<String, dynamic>.from(item as Map));
    }).toList();

    return repository.insertMissingQuestions(questions);
  }
}
