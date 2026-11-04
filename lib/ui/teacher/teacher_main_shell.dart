import 'package:flutter/material.dart';

import '../../data/app_repository.dart';
import '../../data/models/user_profile.dart';
import '../../navigation/app_startup.dart';
import '../admin/components/student_preview_mode.dart';
import '../ai/ai_tutor_sheet.dart';
import '../auth/auth_controller.dart';
import 'tabs/teacher_assignments_exam_tab.dart';
import 'tabs/teacher_classes_tab.dart';
import 'tabs/teacher_dashboard_tab.dart';
import 'tabs/teacher_reports_tab.dart';

/// Khung điều hướng chính 4 Tab dành riêng cho Vai trò Giáo viên (TeacherMainShell):
/// 1. Tổng quan (Dashboard & Việc cần làm)
/// 2. Lớp (Quản lý Lớp học, Mã lớp & Hồ sơ học sinh)
/// 3. Giao bài (Giao bài tập, Cài đặt & Giám sát thi 10s, Ngân hàng đề)
/// 4. Báo cáo (Phân bố điểm, Kỹ năng theo lớp & Báo lỗi câu hỏi)
class TeacherMainShell extends StatefulWidget {
  final AppRepository repository;

  const TeacherMainShell({super.key, required this.repository});

  @override
  State<TeacherMainShell> createState() => _TeacherMainShellState();
}

class _TeacherMainShellState extends State<TeacherMainShell> {
  int _selectedIndex = 0;
  UserProfile? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadTeacherProfile();
  }

  Future<void> _loadTeacherProfile() async {
    final user = await widget.repository.getAuthUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
      });
    }
  }

  void _navigateToTab(int index) {
    if (index >= 0 && index < 4) {
      setState(() => _selectedIndex = index);
    }
  }

  Future<void> _handleSignOut() async {
    await AuthController.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const AppStartup(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final teacherName = (_currentUser?.displayName.isNotEmpty == true)
        ? _currentUser!.displayName
        : 'Giáo viên';

    final tabs = <Widget>[
      TeacherDashboardTab(
        repository: widget.repository,
        onNavigateTab: _navigateToTab,
      ),
      TeacherClassesTab(
        repository: widget.repository,
        onNavigateTab: _navigateToTab,
      ),
      TeacherAssignmentsExamTab(
        repository: widget.repository,
      ),
      TeacherReportsTab(
        repository: widget.repository,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF283593),
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.school_rounded, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Xin chào, $teacherName',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _currentUser?.email ?? 'Cổng Giáo Viên THPT 12',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Trợ lý AI Soạn giảng',
            icon: const Icon(Icons.auto_awesome),
            onPressed: () {
              AiTutorSheet.show(context);
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.45)),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () {
                StudentPreviewMode.instance.enterPreview();
              },
              icon: const Icon(Icons.visibility_outlined, size: 16),
              label: const Text('Xem HS', style: TextStyle(fontSize: 12)),
            ),
          ),
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout_rounded, size: 20),
            onPressed: _handleSignOut,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: tabs,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _navigateToTab,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE8EAF6),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: Color(0xFF283593)),
            label: 'Tổng quan',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups, color: Color(0xFF283593)),
            label: 'Lớp',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment, color: Color(0xFF283593)),
            label: 'Giao bài',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart, color: Color(0xFF283593)),
            label: 'Báo cáo',
          ),
        ],
      ),
    );
  }
}

