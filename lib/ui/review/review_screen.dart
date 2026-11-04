import 'package:flutter/material.dart';
import '../stats/stats_screen.dart';
import '../vocab/vocab_screen.dart';

/// Màn hình Ôn Tập (Tab 4 trong Bottom Navigation Bar)
/// Tích hợp 2 phân hệ ôn luyện:
/// 1. Từ vựng & Flashcard SRS lặp ngắt quãng
/// 2. Sổ câu sai & Thống kê điểm yếu
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121620) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E2430) : Colors.white,
        elevation: 0.5,
        title: Text(
          'Ôn tập & Tiến độ',
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2563EB),
          unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          labelStyle: const TextStyle(
            fontFamily: 'BeVietnamPro',
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: 'BeVietnamPro',
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          indicatorColor: const Color(0xFF2563EB),
          indicatorWeight: 3,
          tabs: const [
            Tab(
              icon: Icon(Icons.style_rounded, size: 20),
              text: 'Từ Vựng & SRS',
            ),
            Tab(
              icon: Icon(Icons.bar_chart_rounded, size: 20),
              text: 'Sổ Sai & Thống Kê',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          VocabScreen(),
          StatsScreen(),
        ],
      ),
    );
  }
}

