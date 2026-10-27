import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thpt_english/main.dart' as app;
import 'package:thpt_english/ui/theme/theme_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'root provides saved theme and keeps startup retry on theme change',
    (tester) async {
      SharedPreferences.setMockInitialValues({'app_theme_mode': 'dark'});
      const databaseChannel = MethodChannel('com.tekartik.sqflite');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var databaseCalls = 0;
      messenger.setMockMethodCallHandler(databaseChannel, (_) async {
        databaseCalls++;
        throw PlatformException(code: 'database_unavailable');
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(databaseChannel, null),
      );

      app.main();
      await tester.pumpAndSettle();
      expect(find.text('Thử lại'), findsOneWidget);
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
      );
      final startupCalls = databaseCalls;
      final context = tester.element(find.byType(MaterialApp));
      await context.read<ThemeController>().setThemeMode(ThemeMode.light);
      await tester.pumpAndSettle();
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.light,
      );
      expect(find.text('Thử lại'), findsOneWidget);
      expect(databaseCalls, startupCalls);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_theme_mode'), 'light');
    },
  );
}
