import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ui/auth/auth_controller.dart';
import '../ui/home/home_screen.dart';
import '../ui/practice/practice_screen.dart';
import '../ui/review/review_screen.dart';
import '../ui/settings/settings_screen.dart';
import '../ui/textbook/textbook_hub_screen.dart';

/// MainShell: Khung điều hướng 5 Tab chính của ứng dụng EngPass
/// Áp dụng mô hình Progressive Disclosure: Khách mới vào app bị khóa tab Luyện đề & Ôn tập
/// cho tới khi hoàn thành bài học đầu tiên (luyện âm, sở thích hoặc bài đọc SGK).
class MainShell extends StatefulWidget {
  final int initialIndex;

  const MainShell({super.key, this.initialIndex = 0});

  /// Đánh dấu đã hoàn thành bài học đầu tiên và mở khóa toàn bộ tính năng
  static Future<void> markFirstLessonCompleted(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alreadyCompleted = prefs.getBool('has_completed_first_lesson') ?? false;
      if (!alreadyCompleted) {
        await prefs.setBool('has_completed_first_lesson', true);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Text('🎉', style: TextStyle(fontSize: 20)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tuyệt vời! Bạn đã mở khóa toàn bộ tab Luyện đề & Ôn tập!',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              backgroundColor: Color(0xFF16A34A),
              duration: Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (_) {}
  }

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex;
  bool _hasCompletedFirstLesson = false;

  final List<Widget> _screens = const [
    HomeScreen(),
    TextbookHubScreen(),
    PracticeScreen(),
    ReviewScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _checkFirstLessonStatus();
  }

  Future<void> _checkFirstLessonStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isCompleted = prefs.getBool('has_completed_first_lesson') ?? false;
      if (mounted) {
        setState(() {
          _hasCompletedFirstLesson = isCompleted;
        });
      }
    } catch (_) {}
  }

  void _showUnlockFeatureDialog(String featureName) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.lock_rounded, color: Color(0xFFD97706), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Nhiệm vụ mở khóa',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tính năng $featureName đang tạm khóa để bạn làm quen với phương pháp học.',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF3B82F6) : const Color(0xFFBFDBFE),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.stars_rounded, color: Color(0xFF2563EB), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Hoàn thành 1 bài học bất kỳ (Phát âm IPA, Sở thích hoặc Học thử SGK) để tự động mở khóa vĩnh viễn!',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(
                'Để sau',
                style: TextStyle(
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(dialogCtx);
                setState(() => _currentIndex = 0); // Về tab Hôm nay để học
              },
              child: const Text('Học ngay để mở khóa', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isGuest = !AuthController.instance.isAuthenticated || AuthController.instance.user.isGuest;
    final isLockedForGuest = isGuest && !_hasCompletedFirstLesson;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          if (isLockedForGuest && (index == 2 || index == 3)) {
            final name = index == 2 ? 'Luyện đề thi THPT' : 'Ôn tập Flashcard SRS';
            _showUnlockFeatureDialog(name);
            return;
          }
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 3,
        indicatorColor: isDark ? const Color(0xFF2563EB).withAlpha(60) : const Color(0xFFEFF6FF),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: Color(0xFF2563EB)),
            label: 'Hôm nay',
          ),
          const NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories_rounded, color: Color(0xFF2563EB)),
            label: 'Sách',
          ),
          NavigationDestination(
            icon: isLockedForGuest
                ? const Badge(
                    label: Text('🔒', style: TextStyle(fontSize: 10)),
                    backgroundColor: Colors.transparent,
                    child: Icon(Icons.track_changes_rounded, color: Color(0xFF94A3B8)),
                  )
                : const Icon(Icons.track_changes_rounded),
            selectedIcon: const Icon(Icons.track_changes_rounded, color: Color(0xFF2563EB)),
            label: isLockedForGuest ? 'Luyện đề 🔒' : 'Luyện đề',
          ),
          NavigationDestination(
            icon: isLockedForGuest
                ? const Badge(
                    label: Text('🔒', style: TextStyle(fontSize: 10)),
                    backgroundColor: Colors.transparent,
                    child: Icon(Icons.style_outlined, color: Color(0xFF94A3B8)),
                  )
                : const Icon(Icons.style_outlined),
            selectedIcon: const Icon(Icons.style_rounded, color: Color(0xFF2563EB)),
            label: isLockedForGuest ? 'Ôn tập 🔒' : 'Ôn tập',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded, color: Color(0xFF2563EB)),
            label: 'Tôi',
          ),
        ],
      ),
    );
  }
}
