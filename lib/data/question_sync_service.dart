import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'app_database.dart';
import 'app_repository.dart';
import 'models/question.dart';

class QuestionSyncService {
  /// Phương thức đồng bộ mặc định (tương thích ngược hoàn toàn với main.dart)
  /// Trả về số câu hỏi mới được chèn vào SQLite
  static Future<int> syncQuestions(
    AppRepository repository, {
    String? targetVersion,
  }) async {
    final result = await syncQuestionsDetailed(
      repository,
      targetVersion: targetVersion,
    );
    return result.insertedCount;
  }

  /// Đồng bộ chi tiết từ file assets, trả về QuestionSyncResult
  static Future<QuestionSyncResult> syncQuestionsDetailed(
    AppRepository repository, {
    String? targetVersion,
    String assetPath = 'assets/data/questions.json',
  }) async {
    final jsonString = await rootBundle.loadString(assetPath);
    return syncQuestionsFromJson(
      repository,
      jsonString,
      targetVersion: targetVersion,
    );
  }

  /// Đồng bộ an toàn từ chuỗi JSON
  static Future<QuestionSyncResult> syncQuestionsFromJson(
    AppRepository repository,
    String jsonString, {
    String? targetVersion,
  }) async {
    final decoded = jsonDecode(jsonString);

    if (decoded is! List) {
      throw const FormatException(
        'questions.json phải chứa một danh sách câu hỏi.',
      );
    }

    final questions = decoded.map((item) {
      return Question.fromMap(Map<String, dynamic>.from(item as Map));
    }).toList();

    return syncQuestionsList(
      repository,
      questions,
      targetVersion: targetVersion,
    );
  }

  /// Đồng bộ an toàn từ danh sách Question
  static Future<QuestionSyncResult> syncQuestionsList(
    AppRepository repository,
    List<Question> questions, {
    String? targetVersion,
  }) async {
    return repository.syncQuestionsSafe(
      questions,
      targetVersion: targetVersion,
    );
  }
}
