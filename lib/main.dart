import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/app_repository.dart';
import 'navigation/app_startup.dart';
import 'ui/theme/app_theme.dart';
import 'ui/theme/theme_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        Provider<AppRepository>(create: (_) => AppRepository()),
        ChangeNotifierProvider<ThemeController>(create: (_) => ThemeController()),
      ],
      child: const ThptEnglishApp(),
    ),
  );
}

class ThptEnglishApp extends StatelessWidget {
  const ThptEnglishApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'English 12',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.lightTheme,
      themeMode: context.watch<ThemeController>().themeMode,
      home: const AppStartup(),
    );
  }
}
