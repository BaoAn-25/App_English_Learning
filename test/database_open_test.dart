import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:thpt_english/data/app_database.dart';

import 'support/sqlite_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // One lifecycle per file: the production singleton deliberately has no reset API.
  test(
    'failed database open can retry with concurrent and subsequent readers',
    () async {
      var opens = 0;
      final opening = Completer<void>();
      final release = Completer<void>();
      final bridge = await SqliteBridge.start(
        beforeCall: (call) async {
          if (call.method != 'openDatabase') return;
          opens++;
          if (opens == 1) {
            throw PlatformException(
              code: 'sqlite_error',
              message: 'Cannot open database',
            );
          }
          if (opens == 2) {
            opening.complete();
            await release.future;
          }
        },
      );
      addTearDown(bridge.close);
      final app = AppDatabase.instance;
      await expectLater(app.database, throwsA(isA<Exception>()));

      // Hold the real platform boundary open so these calls necessarily overlap.
      final readers = List.generate(20, (_) => app.database);
      final results = Future.wait(readers);
      await opening.future;
      release.complete();
      final databases = await results;
      final db = databases.first;
      addTearDown(db.close);
      expect(databases.every((value) => identical(value, db)), isTrue);
      expect(opens, 2); // One failed open and one shared successful open.
      expect(await db.getVersion(), 3);
      expect(await app.getSetting('daily_goal'), '20');
      await app.setSetting('daily_goal', '35');
      expect(await app.database, same(db));
      expect(await app.getSetting('daily_goal'), '35');
      expect(opens, 2);
    },
  );
}
