import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:thpt_english/data/app_repository.dart';
import 'package:thpt_english/data/models/attempt.dart';
import 'package:thpt_english/data/models/attempt_answer.dart';
import 'package:thpt_english/data/models/daily_stat.dart';
import 'package:thpt_english/data/models/question.dart';
import 'package:thpt_english/ui/settings/settings_controller.dart';
import 'package:thpt_english/ui/stats/stats_controller.dart';

class DelayedRepository extends AppRepository {
  final ready = Completer<void>();

  @override
  Future<List<DailyStat>> getAllDailyStats() async {
    await ready.future;
    return [];
  }

  @override
  Future<String?> getSetting(String key) async {
    await ready.future;
    return null;
  }

  @override
  Future<List<Attempt>> getAllAttempts() async => [];
  @override
  Future<List<AttemptAnswer>> getAllAttemptAnswers() async => [];
  @override
  Future<List<Question>> getAllQuestions() async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final fails in [false, true]) {
    test('stats load finishes safely after disposal (error: $fails)', () async {
      final repo = DelayedRepository();
      final controller = StatsController(repo: repo);
      controller.dispose();
      if (fails) {
        repo.ready.completeError(StateError('read failed'));
      } else {
        repo.ready.complete();
      }
      await pumpEventQueue();
    });

    test(
      'settings load finishes safely after disposal (error: $fails)',
      () async {
        final repo = DelayedRepository();
        final controller = SettingsController(repo: repo);
        controller.dispose();
        if (fails) {
          repo.ready.completeError(StateError('read failed'));
        } else {
          repo.ready.complete();
        }
        await pumpEventQueue();
      },
    );
  }
}
