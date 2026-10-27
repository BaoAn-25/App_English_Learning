import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/app_database.dart';
import 'data/app_repository.dart';
import 'data/asset_seeder.dart';
import 'navigation/main_shell.dart';
import 'ui/theme/app_theme.dart';
import 'ui/theme/theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Mở database cục bộ SQLite
  final appDb = AppDatabase.instance;
  await appDb.database;

  // Nạp dữ liệu mẫu từ assets nếu bảng còn rỗng
  await AssetSeeder.seedIfEmpty(dbInstance: appDb);

  runApp(
    MultiProvider(
      providers: [
        Provider<AppRepository>(
          create: (_) => AppRepository(db: appDb),
        ),
        ChangeNotifierProvider<ThemeController>(
          create: (_) => ThemeController(),
        ),
      ],
      child: const ThptEnglishApp(),
    ),
  );
}

class ThptEnglishApp extends StatelessWidget {
  const ThptEnglishApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Provider.of<ThemeController>(context);

    return MaterialApp(
      title: 'Luyện Thi THPT Tiếng Anh',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeController.themeMode,
      home: const MainShell(),
    );
  }
}
