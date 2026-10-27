import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:thpt_english/data/app_database.dart';
import 'package:thpt_english/data/app_repository.dart';
import 'package:thpt_english/data/asset_seeder.dart';
import 'package:thpt_english/navigation/app_startup.dart';
import 'package:thpt_english/navigation/main_shell.dart';

import 'support/sqlite_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SqliteBridge bridge;
  late Database database;
  late int questionCount;

  setUpAll(() async {
    bridge = await SqliteBridge.start();
    database = await AppDatabase.instance.database;
    questionCount =
        (jsonDecode(await rootBundle.loadString('assets/data/questions.json'))
                as List)
            .length;
    await AssetSeeder.seedIfEmpty();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_tts'),
          (_) async => 1,
        );
  });
  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), null);
    await database.close();
    await bridge.close();
  });
  setUp(() async {
    await database.execute('DROP TRIGGER IF EXISTS fail_sync');
    // Existing installs already contain some questions, so seeding skips them.
    await database.execute(
      'DELETE FROM questions WHERE rowid NOT IN (SELECT MIN(rowid) FROM questions)',
    );
  });

  Future<void> settleStartup(WidgetTester tester) async {
    for (var i = 0; i < 200; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await tester.pump();
      if ((find.byType(MainShell).evaluate().isNotEmpty &&
              find.byType(CircularProgressIndicator).evaluate().isEmpty) ||
          find.text('Thử lại').evaluate().isNotEmpty) {
        return;
      }
    }
    fail('Startup did not finish');
  }

  Widget app() => Provider<AppRepository>(
    create: (_) => AppRepository(),
    child: const MaterialApp(home: AppStartup()),
  );

  testWidgets('startup synchronizes missing questions on an existing install', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(app());
      await settleStartup(tester);
      expect(find.byType(MainShell), findsOneWidget);
      final rows = await database.query('questions');
      expect(rows, hasLength(questionCount));
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('sync failure stays on startup and retry restores complete data', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await database.execute(
        "CREATE TEMP TRIGGER fail_sync BEFORE INSERT ON questions BEGIN SELECT RAISE(ABORT, 'sync failed'); END",
      );
      await tester.pumpWidget(app());
      await settleStartup(tester);
      expect(find.byType(MainShell), findsNothing);
      expect(find.text('Thử lại'), findsOneWidget);
      final before = await database.query('questions');
      expect(before, hasLength(1));
      await database.execute('DROP TRIGGER fail_sync');
      await tester.tap(find.text('Thử lại'));
      await settleStartup(tester);
      expect(find.byType(MainShell), findsOneWidget);
      final after = await database.query('questions');
      expect(after, hasLength(questionCount));
      await tester.pumpWidget(const SizedBox());
    });
  });
}
