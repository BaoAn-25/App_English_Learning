import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:thpt_english/data/app_repository.dart';
import 'package:thpt_english/ui/settings/settings_screen.dart';

import 'support/fake_repository.dart';

Widget settingsApp(FakeRepository repository) => Provider<AppRepository>.value(
  value: repository,
  child: const MaterialApp(home: SettingsScreen()),
);

void main() {
  testWidgets('loads saved goal and persists a new goal across remounts', (
    tester,
  ) async {
    final repository = FakeRepository()..settings['daily_goal'] = '30';
    await tester.pumpWidget(settingsApp(repository));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, '30'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '45');
    await tester.tap(find.text('Lưu mục tiêu'));
    await tester.pumpAndSettle();
    expect(repository.settings['daily_goal'], '45');
    expect(find.text('Đã lưu mục tiêu.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(settingsApp(repository));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, '45'), findsOneWidget);
  });

  testWidgets('rejects empty, non integer and out of range goals', (
    tester,
  ) async {
    final repository = FakeRepository();
    await tester.pumpWidget(settingsApp(repository));
    await tester.pumpAndSettle();
    for (final value in ['', 'abc', '1.5', '0', '-1', '201']) {
      await tester.enterText(find.byType(TextFormField), value);
      await tester.tap(find.text('Lưu mục tiêu'));
      await tester.pumpAndSettle();
      expect(find.text('Nhập số nguyên từ 1 đến 200.'), findsOneWidget);
      expect(repository.settings, isEmpty);
    }
    for (final value in ['1', '200']) {
      await tester.enterText(find.byType(TextFormField), value);
      await tester.tap(find.text('Lưu mục tiêu'));
      await tester.pumpAndSettle();
      expect(repository.settings['daily_goal'], value);
    }
  });

  testWidgets('failed save retains input and supports retry', (tester) async {
    final repository = FakeRepository()..failWrite = true;
    await tester.pumpWidget(settingsApp(repository));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '50');
    await tester.tap(find.text('Lưu mục tiêu'));
    await tester.pumpAndSettle();
    expect(
      find.text('Chưa lưu được mục tiêu. Vui lòng thử lại.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextFormField, '50'), findsOneWidget);
    expect(find.text('Đã lưu mục tiêu.'), findsNothing);
    repository.failWrite = false;
    await tester.tap(find.text('Lưu mục tiêu'));
    await tester.pumpAndSettle();
    expect(repository.settings['daily_goal'], '50');
  });

  testWidgets('load errors can retry and invalid saved goal uses default', (
    tester,
  ) async {
    final repository = FakeRepository()
      ..failRead = true
      ..settings['daily_goal'] = 'broken';
    await tester.pumpWidget(settingsApp(repository));
    await tester.pumpAndSettle();
    expect(find.text('Không tải được cài đặt.'), findsOneWidget);
    repository.failRead = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, '20'), findsOneWidget);
  });
}
