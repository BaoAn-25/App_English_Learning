import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

import 'app_database.dart';
import 'models/question.dart';
import 'models/topic.dart';
import 'models/word.dart';

class AssetSeeder {
  static Future<void> seedIfEmpty({AppDatabase? dbInstance}) async {
    final db = dbInstance ?? AppDatabase.instance;

    // Nạp topics mẫu nếu bảng rỗng
    if (await db.isTableEmpty('topics')) {
      final jsonStr = await rootBundle.loadString('assets/data/topics.json');
      final dynamic decoded = jsonDecode(jsonStr);
      if (decoded is List) {
        final topics = decoded
            .map((e) => Topic.fromMap(e as Map<String, dynamic>))
            .toList();
        await db.insertTopics(topics);
      }
    }

    // Nạp words mẫu nếu bảng rỗng
    if (await db.isTableEmpty('words')) {
      final jsonStr = await rootBundle.loadString('assets/data/words.json');
      final dynamic decoded = jsonDecode(jsonStr);
      if (decoded is List) {
        final words = decoded
            .map((e) => Word.fromMap(e as Map<String, dynamic>))
            .toList();
        await db.insertWords(words);
      }
    }

    // Nạp questions mẫu nếu bảng rỗng
    if (await db.isTableEmpty('questions')) {
      final jsonStr = await rootBundle.loadString('assets/data/questions.json');
      final dynamic decoded = jsonDecode(jsonStr);
      if (decoded is List) {
        final questions = decoded
            .map((e) => Question.fromMap(e as Map<String, dynamic>))
            .toList();
        await db.insertQuestions(questions);
      }
    }
  }
}
