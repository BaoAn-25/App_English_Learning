import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/app_database.dart';
import 'data/app_repository.dart';
import 'data/asset_seeder.dart';
import 'data/question_sync_service.dart';
import 'navigation/main_shell.dart';
import 'ui/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Mở database cục bộ SQLite
  final appDb = AppDatabase.instance;
  await appDb.database;

  // Nạp dữ liệu mẫu từ assets nếu bảng còn rỗng
  await AssetSeeder.seedIfEmpty(dbInstance: appDb);

  final appRepository = AppRepository(db: appDb);

  final insertedCount = await QuestionSyncService.syncQuestions(appRepository);

  debugPrint('Đồng bộ câu hỏi: thêm $insertedCount câu mới');

  runApp(
    Provider<AppRepository>(
      create: (_) => appRepository,
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
      home: const MainShell(),
    );
  }
}
