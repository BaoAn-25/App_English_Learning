import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thpt_english/navigation/app_startup.dart';

Widget startup(Future<void> Function() initialize) =>
    MaterialApp(home: AppStartup(initialize: initialize));

void main() {
  testWidgets(
    'shows loading then opens the application only after initialization',
    (tester) async {
      final completion = Completer<void>();
      await tester.pumpWidget(startup(() => completion.future));
      expect(find.text('Đang chuẩn bị dữ liệu học…'), findsOneWidget);
      expect(find.text('Học Từ Vựng & Chuyên Đề'), findsNothing);
      completion.complete();
      await tester.pumpAndSettle();
      expect(find.text('Học Từ Vựng & Chuyên Đề'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets('failure hides private error details and retry can recover', (
    tester,
  ) async {
    var calls = 0;
    final retry = Completer<void>();
    await tester.pumpWidget(
      startup(() {
        calls++;
        if (calls == 1) throw StateError('/private/data.sqlite secret');
        return retry.future;
      }),
    );
    await tester.pumpAndSettle();
    expect(find.text('Không tải được dữ liệu.'), findsOneWidget);
    expect(find.textContaining('/private'), findsNothing);
    expect(find.text('Học Từ Vựng & Chuyên Đề'), findsNothing);
    await tester.tap(find.text('Thử lại'));
    await tester.pump();
    expect(calls, 2);
    expect(find.text('Thử lại'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    retry.complete();
    await tester.pumpAndSettle();
    expect(find.text('Học Từ Vựng & Chuyên Đề'), findsOneWidget);
  });

  testWidgets(
    'async failures can be retried repeatedly without parallel calls',
    (tester) async {
      var calls = 0;
      final attempts = <Completer<void>>[];
      await tester.pumpWidget(
        startup(() {
          calls++;
          final result = Completer<void>();
          attempts.add(result);
          return result.future;
        }),
      );
      for (var index = 0; index < 2; index++) {
        attempts.last.completeError(StateError('unavailable'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Thử lại'));
        await tester.pump();
        expect(find.text('Thử lại'), findsNothing);
        expect(calls, index + 2);
      }
      attempts.last.complete();
      await tester.pumpAndSettle();
      expect(find.text('Học Từ Vựng & Chuyên Đề'), findsOneWidget);
    },
  );

  testWidgets('parent rebuild does not restart initialization', (tester) async {
    var calls = 0;
    Future<void> initialize() async {
      calls++;
    }

    await tester.pumpWidget(startup(initialize));
    await tester.pumpAndSettle();
    await tester.pumpWidget(startup(initialize));
    await tester.pumpAndSettle();
    expect(calls, 1);
  });

  testWidgets('late completion after disposal produces no exception', (
    tester,
  ) async {
    final completion = Completer<void>();
    await tester.pumpWidget(startup(() => completion.future));
    await tester.pumpWidget(const SizedBox());
    completion.completeError(StateError('closed'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('error and retry fit a small display with large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: AppStartup(initialize: () async => throw StateError('failed')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Thử lại').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'two retry callbacks in the same frame start only one operation',
    (tester) async {
      var calls = 0;
      final completion = Completer<void>();
      await tester.pumpWidget(
        startup(() {
          calls++;
          if (calls == 1) return Future.error(StateError('failed'));
          return completion.future;
        }),
      );
      await tester.pumpAndSettle();
      final retry = tester
          .widget<FilledButton>(find.byType(FilledButton))
          .onPressed!;
      retry();
      retry();
      expect(calls, 2);
      completion.complete();
      await tester.pumpAndSettle();
    },
  );
}
