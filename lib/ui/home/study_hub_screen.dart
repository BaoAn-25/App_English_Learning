import 'package:flutter/material.dart';

import '../auth/splash_screen.dart';
import '../textbook/textbook_hub_screen.dart';
import '../vocab/vocab_screen.dart';
import 'home_screen.dart';

/// Màn hình Trung tâm Học tập (Tab 0 trong MainShell)
/// Tích hợp 3 phân hệ trực quan:
/// 1. Hôm nay (Ảnh 2 wireframe: đếm ngược THPT 238 ngày, streak flame, XP, tiếp tục học Unit 3, daily tasks)
/// 2. Sách giáo khoa (Ảnh 2 wireframe: tiến độ 22%, 10 Unit Global Success, lọc Đang học / Đã tải về)
/// 3. Từ Vựng (SRS flashcard & 200 từ vựng SGK 12)
class StudyHubScreen extends StatefulWidget {
  const StudyHubScreen({super.key});

  @override
  State<StudyHubScreen> createState() => _StudyHubScreenState();
}

class _StudyHubScreenState extends State<StudyHubScreen> {
  int _selectedTab = 0; // 0: Hôm nay, 1: Sách, 2: Từ Vựng

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Icon(Icons.school_rounded, color: Colors.white, size: 18),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Prep12',
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        actions: [
          // Nút trải nghiệm Luồng Onboarding & Đăng ký (Ảnh 1)
          TextButton.icon(
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFEFF6FF),
              foregroundColor: const Color(0xFF2563EB),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            icon: const Icon(Icons.play_circle_fill_rounded, size: 18),
            label: const Text(
              'Luồng Onboarding',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SplashScreen()),
              );
            },
          ),
          const SizedBox(width: 12),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _buildSubTab(0, 'Hôm nay', Icons.today_rounded),
                  _buildSubTab(1, 'Sách', Icons.auto_stories_rounded),
                  _buildSubTab(2, 'Từ Vựng', Icons.style_rounded),
                ],
              ),
            ),
          ),
        ),
      ),
      body: IndexedStack(
        index: _selectedTab,
        children: const [
          HomeScreen(),
          TextbookHubScreen(),
          VocabScreen(),
        ],
      ),
    );
  }

  Widget _buildSubTab(int index, String label, IconData icon) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: Color(0x10000000),
                      offset: Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 13,
                  color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

