import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/app_repository.dart';
import 'navigation/app_startup.dart';
import 'ui/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    Provider<AppRepository>(
      create: (_) => AppRepository(),
      child: const ThptEnglishApp(),
    ),
  );
}

class ThptEnglishApp extends StatelessWidget {
  const ThptEnglishApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Luyện Thi THPT Tiếng Anh',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const AppStartup(),
    );
  }
}
