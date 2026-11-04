import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/app_repository.dart';
import '../data/asset_seeder.dart';
import '../data/question_sync_service.dart';
import '../data/remote/api_client.dart';
import '../ui/auth/auth_controller.dart';
import '../ui/auth/welcome_screen.dart';
import 'main_shell.dart';

class AppStartup extends StatefulWidget {
  final Future<void> Function()? initialize;
  final bool? startWithOnboarding;

  const AppStartup({
    super.key,
    this.initialize,
    this.startWithOnboarding,
  });

  @override
  State<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<AppStartup> {
  late Future<void> _initialization;
  bool _initializing = false;
  bool _hasCompletedOnboarding = false;

  @override
  void initState() {
    super.initState();
    _initialization = _initialize();
  }

  Future<void> _initialize() async {
    _initializing = true;
    try {
      final initialize = widget.initialize;
      if (initialize != null) {
        await initialize();
        if (widget.startWithOnboarding == null) {
          _hasCompletedOnboarding = true;
        }
      } else {
        final repository = context.read<AppRepository>();
        await ApiClient.sanitizeOrMigrateApiUrl(repository);
        await AssetSeeder.seedIfEmpty();
        await AssetSeeder.syncVocabulary();
        await AssetSeeder.syncInterestWords();
        await QuestionSyncService.syncQuestions(repository);
        await AuthController.instance.restoreSession();

        try {
          final prefs = await SharedPreferences.getInstance();
          final savedOnboarding = prefs.getBool('has_completed_onboarding') ?? false;
          final isLoggedInStudent = AuthController.instance.isAuthenticated &&
              !AuthController.instance.user.isGuest;
          _hasCompletedOnboarding = savedOnboarding || isLoggedInStudent;
          if (isLoggedInStudent && !savedOnboarding) {
            await prefs.setBool('has_completed_onboarding', true);
          }
        } catch (_) {
          _hasCompletedOnboarding = true;
        }
      }
    } finally {
      _initializing = false;
    }
  }

  void _retry() {
    if (_initializing) return;
    setState(() {
      _initialization = _initialize();
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _initialization,
    builder: (context, snapshot) {
      final loading = snapshot.connectionState != ConnectionState.done;
      if (!loading && !snapshot.hasError) {
        // Cơ chế điều hướng minh bạch:
        // 1. Nếu có chỉ định rõ ràng qua startWithOnboarding
        if (widget.startWithOnboarding == true) {
          return const WelcomeScreen();
        }
        if (widget.startWithOnboarding == false) {
          return const MainShell();
        }

        // 2. Mặc định theo trạng thái người học thực tế đã hoàn thành Onboarding hay chưa
        if (_hasCompletedOnboarding) {
          return const MainShell();
        }

        // Chưa hoàn thành onboarding -> vào thẳng màn hình chào mừng & học thử (Ảnh 1)
        return const WelcomeScreen();
      }
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (loading) ...[
                      const CircularProgressIndicator(),
                      const SizedBox(height: 24),
                      Semantics(
                        liveRegion: true,
                        child: const Text('Đang chuẩn bị dữ liệu học…'),
                      ),
                    ] else ...[
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          'Không tải được dữ liệu.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Vui lòng thử lại.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _retry,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
