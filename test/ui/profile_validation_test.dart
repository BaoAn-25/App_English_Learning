import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thpt_english/data/app_repository.dart';
import 'package:thpt_english/ui/settings/settings_controller.dart';
import 'package:thpt_english/ui/settings/edit_profile_dialog.dart';

class ProfileRepo extends AppRepository {
  final values = <String, String>{};
  int writes = 0;
  bool fail = false;
  @override
  Future<String?> getSetting(String key) async => values[key];
  @override
  Future<void> setSetting(String key, String value) async {
    if (fail) throw StateError('private SQL error');
    writes++;
    values[key] = value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/connectivity'),
          (_) async => ['none'],
        ),
  );
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/connectivity'),
          null,
        ),
  );
  test('invalid profile values never mutate state or storage', () async {
    final repo = ProfileRepo();
    final controller = SettingsController(repo: repo);
    await pumpEventQueue();
    for (final score in [-1.0, 10.1, double.nan, double.infinity]) {
      await expectLater(
        controller.updateProfile(name: 'Tài', grade: 12, targetScore: score),
        throwsArgumentError,
      );
    }
    for (final name in ['   ', 'a' * 101]) {
      await expectLater(
        controller.updateProfile(name: name, grade: 12, targetScore: 8),
        throwsArgumentError,
      );
    }
    await expectLater(
      controller.updateProfile(name: 'Tài', grade: 0, targetScore: 8),
      throwsArgumentError,
    );
    expect(repo.writes, 0);
    expect(controller.targetScore, 8.5);
    expect(controller.name, 'Học sinh lớp 12');
    controller.dispose();
  });
  test('valid boundaries persist trimmed name', () async {
    final repo = ProfileRepo();
    final controller = SettingsController(repo: repo);
    await pumpEventQueue();
    for (final score in [0.0, 10.0]) {
      await controller.updateProfile(
        name: '  Tài  ',
        grade: 12,
        targetScore: score,
      );
      expect(repo.values['user_name'], 'Tài');
      expect(controller.targetScore, score);
    }
    controller.dispose();
  });
  test('invalid stored profile values use safe defaults', () async {
    final repo = ProfileRepo();
    repo.values.addAll({
      'user_name': 'a' * 101,
      'target_score': 'NaN',
      'grade': '-1',
    });
    final controller = SettingsController(repo: repo);
    await pumpEventQueue();
    expect(controller.name, 'Học sinh lớp 12');
    expect(controller.targetScore, 8.5);
    expect(controller.grade, 12);
    controller.dispose();
  });
  test('failed profile write preserves visible profile', () async {
    final repo = ProfileRepo()..fail = true;
    final controller = SettingsController(repo: repo);
    await pumpEventQueue();
    await expectLater(
      controller.updateProfile(name: 'Changed', grade: 11, targetScore: 9),
      throwsStateError,
    );
    expect(controller.name, 'Học sinh lớp 12');
    expect(controller.grade, 12);
    expect(controller.targetScore, 8.5);
    controller.dispose();
  });

  testWidgets(
    'profile form shows validation and keeps failed saves open for retry',
    (tester) async {
      final repo = ProfileRepo();
      final controller = SettingsController(repo: repo);
      await tester.runAsync(() => pumpEventQueue());
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => EditProfileDialog(controller: controller),
                ),
                child: const Text('Edit'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).last, 'NaN');
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();
      expect(find.text('Điểm mục tiêu phải từ 0 đến 10.'), findsOneWidget);
      expect(repo.writes, 0);
      await tester.enterText(find.byType(TextFormField).last, '9');
      repo.fail = true;
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();
      expect(
        find.text('Chưa lưu được hồ sơ. Vui lòng thử lại.'),
        findsOneWidget,
      );
      expect(find.textContaining('private SQL'), findsNothing);
      repo.fail = false;
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();
      expect(find.byType(EditProfileDialog), findsNothing);
      expect(repo.values['target_score'], '9.0');
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
}
