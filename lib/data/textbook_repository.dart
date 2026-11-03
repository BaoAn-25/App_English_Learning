import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import 'app_database.dart';
import 'models/question.dart';
import 'models/topic.dart';
import 'models/word.dart';

class BookCollection {
  final String id, title, kind;
  final int start, end;
  final List<Map<String, dynamic>> sections;
  BookCollection(Map<String, dynamic> m)
    : id = m['id'],
      title = m['title'],
      kind = m['kind'],
      start = m['start'],
      end = m['end'],
      sections = (m['sections'] as List).cast<Map<String, dynamic>>();
}

class Textbook {
  final String version;
  final List<BookCollection> collections;
  final Map<int, Map<String, dynamic>> pages;
  Textbook(Map<String, dynamic> m)
    : version = m['version'],
      collections = (m['units'] as List).map((u) => BookCollection(u)).toList(),
      pages = {for (final p in m['pages']) p['number'] as int: p};

  String asset(int page) => pages[page]!['asset'] as String;
  List<int> search(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return [];
    return pages.entries
        .where(
          (p) =>
              (p.value['searchText'] as String).toLowerCase().contains(needle),
        )
        .map((p) => p.key)
        .toList();
  }

  static String pageLabel(int page) => switch (page) {
    -1 => 'Bìa trước',
    0 => 'Hội đồng thẩm định',
    157 => 'Bìa sau',
    _ => 'Trang $page',
  };
}

class TextbookRepository {
  static const version = 'global-success-12-2026-v1';
  static const archiveKey = 'textbook_legacy_archive_v1';
  final AppDatabase database;
  final AssetBundle assets;
  TextbookRepository({AppDatabase? database, AssetBundle? assets})
    : database = database ?? AppDatabase.instance,
      assets = assets ?? rootBundle;

  Future<Textbook> load() async => Textbook(
    jsonDecode(await assets.loadString('assets/data/textbook.json')),
  );

  /// Archive and switch all related tables atomically. Never reuse legacy IDs.
  Future<void> install() async {
    final db = await database.database;
    final release = await load();
    if (release.version != version || release.pages.length != 159) {
      throw const FormatException('Bộ sách không đầy đủ.');
    }
    final payload = <String, List<Map<String, Object?>>>{};
    for (final table in ['topics', 'words', 'questions']) {
      final data =
          jsonDecode(await assets.loadString('assets/data/$table.json'))
              as List;
      payload[table] = data
          .map<Map<String, Object?>>(
            (m) => switch (table) {
              'topics' => Topic.fromMap(m).toMap(),
              'words' => Word.fromMap(m).toMap(),
              _ => Question.fromMap(m).toMap(),
            },
          )
          .toList();
      final ids = payload[table]!.map((m) => m['id']).toSet();
      if (ids.length != data.length ||
          ids.any((id) => !(id as String).startsWith('gs12_'))) {
        throw FormatException('ID không hợp lệ: $table');
      }
    }
    final topicIds = payload['topics']!.map((m) => m['id']).toSet();
    if (topicIds.length != 10 ||
        payload['words']!.isEmpty ||
        payload['questions']!.isEmpty) {
      throw const FormatException('Thiếu dữ liệu học.');
    }
    for (final row in [...payload['words']!, ...payload['questions']!]) {
      if (!topicIds.contains(row['topicId'])) {
        throw const FormatException('Không tìm thấy Unit của nội dung.');
      }
    }
    for (final row in payload['questions']!) {
      final q = Question.fromMap(row);
      if (q.options.length < 2 ||
          q.correctIndex < 0 ||
          q.correctIndex >= q.options.length) {
        throw const FormatException('Đáp án không hợp lệ.');
      }
    }
    await db.transaction((txn) async {
      final current = await txn.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: ['content_version'],
      );
      if (current.isNotEmpty && current.first['value'] == version) return;
      const tables = [
        'attempt_answers',
        'wrong_book',
        'word_progress',
        'attempts',
        'daily_stats',
        'questions',
        'words',
        'topics',
      ];
      final snapshot = <String, Object?>{};
      for (final table in tables) {
        snapshot[table] = await txn.query(table);
      }
      final hasData = snapshot.values.any((v) => (v as List).isNotEmpty);
      if (hasData) {
        final oldArchive = await txn.query(
          'app_settings',
          where: 'key = ?',
          whereArgs: [archiveKey],
        );
        if (oldArchive.isNotEmpty) {
          throw StateError('Đã có bản lưu trữ; không ghi đè lịch sử cũ.');
        }
        await txn.insert('app_settings', {
          'key': archiveKey,
          'value': jsonEncode({
            'createdAt': DateTime.now().toIso8601String(),
            'tables': snapshot,
          }),
        });
      }
      for (final table in tables) {
        await txn.delete(table);
      }
      for (final table in ['topics', 'words', 'questions']) {
        for (final row in payload[table]!) {
          await txn.insert(table, row);
        }
      }
      await txn.insert('app_settings', {
        'key': 'content_version',
        'value': version,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  String _studyKey(int page, String? ownerId) {
    if (ownerId != null && ownerId.trim().isNotEmpty) {
      return 'book_${version}_owner_${ownerId}_page_$page';
    }
    return 'book_${version}_page_$page';
  }

  Future<Map<String, dynamic>> study(int page, {String? ownerId}) async {
    final key = _studyKey(page, ownerId);
    var value = await database.getSetting(key);
    // Nếu chưa có theo owner và ownerId được truyền vào, thử đọc bản ghi cũ chưa gắn owner (nếu có)
    if (value == null && ownerId != null && ownerId.trim().isNotEmpty) {
      value = await database.getSetting('book_${version}_page_$page');
    }
    return value == null
        ? {'completed': false, 'answers': <dynamic>[]}
        : jsonDecode(value);
  }

  Future<void> saveStudy(
    int page,
    List<Map<String, dynamic>> answers,
    bool completed, {
    String? ownerId,
  }) async {
    if (page < -1 || page > 157) throw ArgumentError.value(page);
    final key = _studyKey(page, ownerId);
    await database.setSetting(
      key,
      jsonEncode({
        'completed': completed,
        'answers': answers,
        'ownerId': ownerId,
        'updatedAt': DateTime.now().toIso8601String(),
      }),
    );
  }

  Future<Set<int>> completedPages({String? ownerId}) async {
    final db = await database.database;
    final prefix = (ownerId != null && ownerId.trim().isNotEmpty)
        ? 'book_${version}_owner_${ownerId}_page_%'
        : 'book_${version}_page_%';
    final rows = await db.query(
      'app_settings',
      where: 'key LIKE ?',
      whereArgs: [prefix],
    );
    return {
      for (final r in rows)
        if (jsonDecode(r['value'] as String)['completed'] == true)
          int.parse((r['key'] as String).split('_').last),
    };
  }
}
