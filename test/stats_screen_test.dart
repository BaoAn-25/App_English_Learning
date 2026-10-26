import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:thpt_english/data/app_repository.dart';
import 'package:thpt_english/data/models/daily_stat.dart';
import 'package:thpt_english/ui/stats/stats_screen.dart';
import 'support/fake_repository.dart';

Widget statsApp(FakeRepository repository, {bool active = true}) =>
    Provider<AppRepository>.value(
      value: repository,
      child: MaterialApp(home: StatsScreen(active: active)),
    );

void main() {
  testWidgets('empty statistics show honest zero and empty guidance', (
    tester,
  ) async {
    await tester.pumpWidget(statsApp(FakeRepository()));
    await tester.pumpAndSettle();
    expect(
      find.text('Chưa có câu trả lời. Hãy bắt đầu một bài luyện tập.'),
      findsOneWidget,
    );
    expect(find.text('—'), findsOneWidget);
    expect(find.text('0 XP'), findsOneWidget);
  });
  testWidgets('shows weighted totals and refreshes when revisiting tab', (
    tester,
  ) async {
    final repository = FakeRepository()
      ..stats = [
        const DailyStat(
          date: '2026-01-01',
          xp: 120,
          questionsDone: 20,
          correct: 15,
          minutes: 10,
        ),
      ];
    await tester.pumpWidget(statsApp(repository));
    await tester.pumpAndSettle();
    expect(find.text('120 XP'), findsOneWidget);
    expect(find.text('75%'), findsOneWidget);
    await tester.pumpWidget(statsApp(repository, active: false));
    repository.stats = [];
    await tester.pumpWidget(statsApp(repository));
    await tester.pumpAndSettle();
    expect(find.text('0 XP'), findsOneWidget);
  });
  testWidgets('read failure retries without showing fake zero statistics', (
    tester,
  ) async {
    final repository = FakeRepository()..failRead = true;
    await tester.pumpWidget(statsApp(repository));
    await tester.pumpAndSettle();
    expect(find.text('Không tải được thống kê.'), findsOneWidget);
    expect(find.text('0 XP'), findsNothing);
    repository.failRead = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('0 XP'), findsOneWidget);
  });
}
