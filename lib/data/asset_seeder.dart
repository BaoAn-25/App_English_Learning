import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import 'app_database.dart';
import 'models/question.dart';
import 'models/topic.dart';
import 'models/word.dart';

class AssetSeeder {
  static Future<void> seedIfEmpty({
    AppDatabase? dbInstance,
    AssetBundle? bundle,
  }) async {
    final db = await (dbInstance ?? AppDatabase.instance).database;
    final assets = bundle ?? rootBundle;

    // Cùng transaction cho cả kiểm tra và ghi để không nạp trùng/dở dang.
    await db.transaction((txn) async {
      for (final table in ['topics', 'words', 'questions']) {
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
            _ => Question.fromMap(item).toMap(),
          };
          // Trùng ID là lỗi dữ liệu, không âm thầm ghi đè bản ghi khác.
          batch.insert(table, row);
        }
        await batch.commit(noResult: true);
      }
    });
  }
}
