import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:thpt_english/data/app_database.dart';
import 'package:thpt_english/data/asset_seeder.dart';

import 'support/sqlite_bridge.dart';

class SeedBundle extends CachingAssetBundle {
  final Map<String, String> files;
  final requested = <String>[];
  SeedBundle(this.files);

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    requested.add(key);
    final text = files[key];
    if (text == null) throw StateError('Missing asset');
    return text;
  }

  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(
    Uint8List.fromList(utf8.encode(await loadString(key))),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SqliteBridge bridge;
  late Database database;
  late Map<String, String> files;
  const tables = ['topics', 'words', 'questions'];

  setUpAll(() async {
    bridge = await SqliteBridge.start();
    database = await AppDatabase.instance.database;
    files = {
      for (final table in tables)
        'assets/data/$table.json': await rootBundle.loadString(
          'assets/data/$table.json',
        ),
    };
  });
  tearDownAll(() async {
    await database.close();
    await bridge.close();
  });
  setUp(() async {
    await database.execute('DROP TRIGGER IF EXISTS fail_seed');
    for (final table in tables) {
      await database.delete(table);
    }
  });

  Future<void> expectEmpty() async {
    for (final table in tables) {
      expect(await database.query(table), isEmpty, reason: table);
    }
  }

  test(
    'seeds real bundled assets and repeated calls preserve changes',
    () async {
      await AssetSeeder.seedIfEmpty(bundle: SeedBundle(files));
      for (final table in tables) {
        expect(
          (await database.query(table)).length,
          (jsonDecode(files['assets/data/$table.json']!) as List).length,
        );
      }
      await database.update('topics', {'title': 'Tên đã sửa'});
      final emptyBundle = SeedBundle({});
      await AssetSeeder.seedIfEmpty(bundle: emptyBundle);
      expect(emptyBundle.requested, isEmpty);
      expect((await database.query('topics')).first['title'], 'Tên đã sửa');
    },
  );
  test(
    'malformed last asset rolls back earlier tables and can retry',
    () async {
      final broken = SeedBundle({
        ...files,
        'assets/data/questions.json': '{broken',
      });
      await expectLater(
        AssetSeeder.seedIfEmpty(bundle: broken),
        throwsFormatException,
      );
      await expectEmpty();
      await AssetSeeder.seedIfEmpty(bundle: SeedBundle(files));
      expect(await database.query('questions'), isNotEmpty);
    },
  );
  test('missing asset and non-list root fail without partial data', () async {
    for (final bundle in [
      SeedBundle({...files}..remove('assets/data/questions.json')),
      SeedBundle({...files, 'assets/data/questions.json': '{}'}),
    ]) {
      await expectLater(
        AssetSeeder.seedIfEmpty(bundle: bundle),
        throwsA(anything),
      );
      await expectEmpty();
    }
  });
  test('SQLite error in last table rolls back all seeded tables', () async {
    await database.execute(
      "CREATE TEMP TRIGGER fail_seed BEFORE INSERT ON questions BEGIN SELECT RAISE(ABORT, 'forced failure'); END",
    );
    await expectLater(
      AssetSeeder.seedIfEmpty(bundle: SeedBundle(files)),
      throwsA(isA<DatabaseException>()),
    );
    await expectEmpty();
  });
  test(
    'existing table remains intact when seeding another table fails',
    () async {
      await database.insert('topics', {
        'id': 'existing',
        'grade': 12,
        'title': 'Giữ nguyên',
        'order': 1,
      });
      await expectLater(
        AssetSeeder.seedIfEmpty(
          bundle: SeedBundle({...files, 'assets/data/questions.json': 'null'}),
        ),
        throwsFormatException,
      );
      expect((await database.query('topics')).single['title'], 'Giữ nguyên');
      expect(await database.query('words'), isEmpty);
    },
  );
  test(
    'duplicate identifiers are rejected instead of silently replacing data',
    () async {
      final topics = jsonDecode(files['assets/data/topics.json']!) as List;
      await expectLater(
        AssetSeeder.seedIfEmpty(
          bundle: SeedBundle({
            ...files,
            'assets/data/topics.json': jsonEncode([topics.first, topics.first]),
          }),
        ),
        throwsA(isA<DatabaseException>()),
      );
      await expectEmpty();
    },
  );
  test('concurrent seed calls do not duplicate data', () async {
    await Future.wait([
      AssetSeeder.seedIfEmpty(bundle: SeedBundle(files)),
      AssetSeeder.seedIfEmpty(bundle: SeedBundle(files)),
    ]);
    expect((await database.query('topics')).length, 3);
    expect((await database.query('questions')).length, 3);
  });
}
