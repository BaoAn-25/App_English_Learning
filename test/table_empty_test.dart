import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:thpt_english/data/app_database.dart';

import 'support/sqlite_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SqliteBridge bridge;
  late Database database;
  final appDatabase = AppDatabase.instance;

  setUpAll(() async {
    bridge = await SqliteBridge.start();
    database = await appDatabase.database;
  });
  tearDownAll(() async {
    await database.close();
    await bridge.close();
  });

  test(
    'rejects unknown names and SQL fragments without changing data',
    () async {
      final settings = await database.query('app_settings');
      for (final name in [
        '',
        'missing_table',
        'sqlite_master',
        ' topics',
        'topics WHERE 1 = 0',
        'topics; DROP TABLE app_settings; --',
      ]) {
        await expectLater(
          appDatabase.isTableEmpty(name),
          throwsArgumentError,
          reason: 'Invalid table: $name',
        );
      }
      expect(await database.query('app_settings'), settings);
    },
  );

  test(
    'accepts all application tables and distinguishes empty from populated',
    () async {
      for (final name in [
        'topics',
        'words',
        'questions',
        'attempts',
        'attempt_answers',
        'wrong_book',
        'daily_stats',
      ]) {
        expect(await appDatabase.isTableEmpty(name), isTrue, reason: name);
      }
      expect(await appDatabase.isTableEmpty('app_settings'), isFalse);
      await database.insert('topics', {
        'id': 'topic-test',
        'grade': 12,
        'title': 'Test',
        'order': 1,
      });
      expect(await appDatabase.isTableEmpty('topics'), isFalse);
      await database.delete('topics');
      expect(await appDatabase.isTableEmpty('topics'), isTrue);
    },
  );
}
