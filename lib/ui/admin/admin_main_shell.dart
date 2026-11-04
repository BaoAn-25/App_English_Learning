import 'package:flutter/material.dart';

import '../../data/app_repository.dart';
import '../auth/auth_controller.dart';
import 'components/student_preview_mode.dart';
import 'tabs/admin_content_tab.dart';
import 'tabs/admin_dashboard_tab.dart';
import 'tabs/admin_management_tab.dart';
import 'tabs/admin_proctor_tab.dart';
import 'tabs/admin_users_tab.dart';

/// Khung điều hướng chính của Quản Trị Viên (Admin Main Shell)
/// Gồm 5 phân hệ theo thiết kế chuẩn Claude:
/// 1. Tổng quan
/// 2. Học liệu (10 Unit, Soạn câu hỏi, Nhập sách AI)
/// 3. Người dùng (Học sinh, Duyệt giáo viên, Khóa TK)
/// 4. Lớp & Thi (Lớp học, Giám sát 10s Live, Thông báo)
/// 5. Quản trị (Báo lỗi, Xuất bản SGK mới, Audit Logs, Settings)
class AdminMainShell extends StatefulWidget {
  final AppRepository repository;
  final int initialTabIndex;

  const AdminMainShell({
    super.key,
    required this.repository,
    this.initialTabIndex = 0,
  });

  @override
  State<AdminMainShell> createState() => _AdminMainShellState();
}

class _AdminMainShellState extends State<AdminMainShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
  }

  void _onTabSelected(int index) {
    if (_currentIndex != index) {
      setState(() => _currentIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthController.instance.user;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        titleSpacing: 8,
        leadingWidth: 46,
        leading: Padding(
          padding: const EdgeInsets.only(left: 10),
          child: CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFF1E3A8A).withValues(alpha: 0.12),
            child: const Icon(Icons.admin_panel_settings, color: Color(0xFF1E3A8A), size: 19),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Flexible(
                  child: Text(
                    'Trung Tâm Quản Trị',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Colors.black87),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A8A),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'ADMIN',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
            Text(
              user.displayName.isNotEmpty ? user.displayName : user.email,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          Tooltip(
            message: 'Xem trước Giao diện Học sinh',
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF15803D),
                backgroundColor: const Color(0xFFDCFCE7),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () {
                StudentPreviewMode.instance.enterPreview();
              },
              icon: const Icon(Icons.remove_red_eye, size: 15),
              label: const Text('Xem HS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
            ),
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black87),
            onSelected: (val) {
              if (val == 'preview') {
                StudentPreviewMode.instance.enterPreview();
              } else if (val == 'logout') {
                AuthController.instance.logout();
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'preview',
                child: Row(
                  children: [
                    Icon(Icons.school_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Xem trước giao diện Học sinh'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Đăng xuất', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          AdminDashboardTab(
            onNavigateTab: _onTabSelected,
          ),
          AdminContentTab(
            repository: widget.repository,
          ),
          AdminUsersTab(
            repository: widget.repository,
          ),
          AdminProctorTab(
            repository: widget.repository,
          ),
          AdminManagementTab(
            repository: widget.repository,
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _onTabSelected,
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFF1E3A8A).withValues(alpha: 0.12),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard, color: Color(0xFF1E3A8A)),
              label: 'Tổng quan',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book, color: Color(0xFF1E3A8A)),
              label: 'Học liệu',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people, color: Color(0xFF1E3A8A)),
              label: 'Người dùng',
            ),
            NavigationDestination(
              icon: Icon(Icons.security_outlined),
              selectedIcon: Icon(Icons.security, color: Color(0xFF1E3A8A)),
              label: 'Lớp & Thi',
            ),
            NavigationDestination(
              icon: Icon(Icons.tune_outlined),
              selectedIcon: Icon(Icons.tune, color: Color(0xFF1E3A8A)),
              label: 'Quản trị',
            ),
          ],
        ),
      ),
    );
  }
}
