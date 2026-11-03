import 'package:flutter/material.dart';

import '../ui/home/home_screen.dart';
import '../ui/practice/practice_screen.dart';
import '../ui/review/review_screen.dart';
import '../ui/settings/settings_screen.dart';
import '../ui/textbook/textbook_hub_screen.dart';

/// MainShell: Khung điều hướng 5 Tab chính của ứng dụng EngPass
/// Theo đúng chuẩn Wireframe: [Hôm nay] | [Sách] | [Luyện đề] | [Ôn tập] | [Tôi]
class MainShell extends StatefulWidget {
  final int initialIndex;

  const MainShell({super.key, this.initialIndex = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex;

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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: Colors.white,
        elevation: 3,
        indicatorColor: const Color(0xFFEFF6FF),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: Color(0xFF2563EB)),
            label: 'Hôm nay',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories_rounded, color: Color(0xFF2563EB)),
            label: 'Sách',
          ),
          NavigationDestination(
            icon: Icon(Icons.track_changes_rounded),
            selectedIcon: Icon(Icons.track_changes_rounded, color: Color(0xFF2563EB)),
            label: 'Luyện đề',
          ),
          NavigationDestination(
            icon: Icon(Icons.style_outlined),
            selectedIcon: Icon(Icons.style_rounded, color: Color(0xFF2563EB)),
            label: 'Ôn tập',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded, color: Color(0xFF2563EB)),
            label: 'Tôi',
          ),
        ],
      ),
    );
  }
}
