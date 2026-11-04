import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/app_repository.dart';
import '../data/asset_seeder.dart';
import '../data/question_sync_service.dart';
import '../data/remote/api_client.dart';
import '../ui/auth/auth_controller.dart';
import '../ui/auth/welcome_screen.dart';
import 'role_routing_shell.dart';

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
  String? _initErrorDetails;

  @override
  void initState() {
    super.initState();
    _initialization = _initialize();
  }

  Future<void> _initialize() async {
    _initializing = true;
    _initErrorDetails = null;
    try {
      final initialize = widget.initialize;
      if (initialize != null) {
        await initialize();
        if (widget.startWithOnboarding == null) {
          _hasCompletedOnboarding = true;
        }
      } else {
        final repository = context.read<AppRepository>();

        // 1. Chuẩn hóa địa chỉ API máy chủ Render
        try {
          await ApiClient.sanitizeOrMigrateApiUrl(repository);
        } catch (e) {
          debugPrint('ApiClient.sanitizeOrMigrateApiUrl error: $e');
        }

        // 2. Khởi tạo dữ liệu học liệu cốt lõi (Bảo vệ độc lập từng bước để không bao giờ treo app)
        try {
          await AssetSeeder.seedIfEmpty();
        } catch (e) {
          debugPrint('AssetSeeder.seedIfEmpty error: $e');
        }

        try {
          await AssetSeeder.syncVocabulary();
        } catch (e) {
          debugPrint('AssetSeeder.syncVocabulary error: $e');
        }

        try {
          await AssetSeeder.syncInterestWords();
        } catch (e) {
          debugPrint('AssetSeeder.syncInterestWords error: $e');
        }

        try {
          await QuestionSyncService.syncQuestions(repository);
        } catch (e) {
          debugPrint('QuestionSyncService.syncQuestions error: $e');
        }

        // 3. Khôi phục phiên đăng nhập
        try {
          await AuthController.instance.restoreSession();
        } catch (e) {
          debugPrint('AuthController.restoreSession error: $e');
        }

        // 4. Kiểm tra trạng thái đã hoàn thành onboarding
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
          _hasCompletedOnboarding = false;
        }
      }
    } catch (criticalErr) {
      debugPrint('Critical AppStartup error: $criticalErr');
      _initErrorDetails = criticalErr.toString();
      rethrow;
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
        // Cơ chế điều hướng:
        // 1. Nếu có chỉ định rõ ràng qua startWithOnboarding
        if (widget.startWithOnboarding == true) {
          return const WelcomeScreen();
        }
        if (widget.startWithOnboarding == false) {
          return const RoleRoutingShell();
        }

        // 2. Mặc định theo trạng thái người học thực tế đã hoàn thành Onboarding hay chưa
        if (_hasCompletedOnboarding) {
          return const RoleRoutingShell();
        }

        // Chưa hoàn thành onboarding -> vào thẳng màn hình chào mừng & học thử
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
                        child: const Text(
                          'Đang chuẩn bị dữ liệu học…',
                          style: TextStyle(fontFamily: 'BeVietnamPro', fontSize: 15),
                        ),
                      ),
                    ] else ...[
                      const Icon(
                        Icons.cloud_off_rounded,
                        size: 56,
                        color: Color(0xFFEF4444),
                      ),
                      const SizedBox(height: 16),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          'Không tải được dữ liệu.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontFamily: 'BeVietnamPro',
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Đã có trục trặc trong quá trình chuẩn bị dữ liệu ban đầu.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13.5, color: Color(0xFF64748B)),
                      ),
                      if (_initErrorDetails != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _initErrorDetails!,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.black54),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),

                      // Nút 1: Bỏ qua và vào app ngay (Ưu tiên cao nhất để không bao giờ bị kẹt)
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                            );
                          },
                          icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                          label: const Text(
                            'Tiếp tục vào học',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Nút 2: Thử lại
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _retry,
                          child: const Text('Thử tải lại'),
                        ),
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
