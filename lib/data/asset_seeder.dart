import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import 'app_database.dart';
import 'models/interest_topic.dart';
import 'models/interest_word.dart';
import 'models/ipa_sound.dart';
import 'models/minimal_pair_question.dart';
import 'models/question.dart';
import 'models/topic.dart';
import 'models/word.dart';

class AssetSeeder {
  /// Bổ sung dữ liệu mới, giữ nguyên nội dung và tiến độ của các ID đã có.
  static Future<void> syncVocabulary({
    AppDatabase? dbInstance,
    AssetBundle? bundle,
  }) async {
    final db = await (dbInstance ?? AppDatabase.instance).database;
    final assets = bundle ?? rootBundle;

    await db.transaction((txn) async {
      for (final table in ['topics', 'words']) {
        final decoded = jsonDecode(
          await assets.loadString('assets/data/$table.json'),
        );
        if (decoded is! List) {
          throw FormatException('Dữ liệu $table phải là một danh sách.');
        }
        final existingIds = (await txn.query(
          table,
          columns: ['id'],
        )).map((row) => row['id']).toSet();
        final topicIds = table == 'words'
            ? (await txn.query(
                'topics',
                columns: ['id'],
              )).map((row) => row['id']).toSet()
            : null;
        final assetIds = <String>{};
        final batch = txn.batch();
        for (final item in decoded) {
          if (item is! Map<String, dynamic>) {
            throw FormatException('Bản ghi trong $table không hợp lệ.');
          }
          final row = table == 'topics'
              ? Topic.fromMap(item).toMap()
              : Word.fromMap(item).toMap();
          final id = row['id'] as String;
          if (id.trim().isEmpty || !assetIds.add(id)) {
            throw FormatException('ID trong $table bị trống hoặc trùng.');
          }
          if (existingIds.contains(id)) continue;
          if (topicIds != null && !topicIds.contains(row['topicId'])) {
            throw const FormatException(
              'Từ vựng tham chiếu chủ đề không tồn tại.',
            );
          }
          batch.insert(table, row);
        }
        await batch.commit(noResult: true);
      }
    });
  }

  /// Đồng bộ cập nhật các từ vựng và câu đàm thoại theo sở thích mới nhất
  static Future<void> syncInterestWords({
    AppDatabase? dbInstance,
    AssetBundle? bundle,
  }) async {
    try {
      final db = await (dbInstance ?? AppDatabase.instance).database;
      final assets = bundle ?? rootBundle;
      final jsonStr = await assets.loadString('assets/data/interest_words.json');
      final decoded = jsonDecode(jsonStr);
      if (decoded is List) {
        final batch = db.batch();
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            final row = InterestWord.fromMap(item).toMap();
            batch.insert(
              'interest_words',
              row,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
        await batch.commit(noResult: true);
      }
    } catch (_) {}
  }

  static Future<void> seedIfEmpty({
    AppDatabase? dbInstance,
    AssetBundle? bundle,
  }) async {
    final db = await (dbInstance ?? AppDatabase.instance).database;
    final assets = bundle ?? rootBundle;

    final seedTables = [
      'topics',
      'words',
      'questions',
      'ipa_sounds',
      'minimal_pairs',
      'interest_topics',
      'interest_words',
    ];

    // Cùng transaction cho cả kiểm tra và ghi để không nạp trùng/dở dang.
    await db.transaction((txn) async {
      for (final table in seedTables) {
        final count = Sqflite.firstIntValue(
          await txn.rawQuery('SELECT COUNT(*) FROM $table'),
        );
        if ((count ?? 0) > 0) continue;

        final decoded = jsonDecode(
          await assets.loadString('assets/data/$table.json'),
        );
        if (decoded is! List) {
          throw FormatException('Dữ liệu $table phải là một danh sách.');
        }
        final batch = txn.batch();
        for (final item in decoded) {
          if (item is! Map<String, dynamic>) {
            throw FormatException('Bản ghi trong $table không hợp lệ.');
          }
          final row = switch (table) {
            'topics' => Topic.fromMap(item).toMap(),
            'words' => Word.fromMap(item).toMap(),
            'questions' => Question.fromMap(item).toMap(),
            'ipa_sounds' => IpaSound.fromMap(item).toMap(),
            'minimal_pairs' => MinimalPairQuestion.fromMap(item).toMap(),
            'interest_topics' => InterestTopic.fromMap(item).toMap(),
            'interest_words' => InterestWord.fromMap(item).toMap(),
            _ => throw FormatException('Bảng không xác định: $table'),
          };
          // Trùng ID là lỗi dữ liệu, không âm thầm ghi đè bản ghi khác.
          batch.insert(table, row);
        }
        await batch.commit(noResult: true);
      }
    });
  }
}
