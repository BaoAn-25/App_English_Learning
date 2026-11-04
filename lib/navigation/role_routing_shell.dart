import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_repository.dart';
import '../ui/admin/admin_main_shell.dart';
import '../ui/admin/components/student_preview_banner.dart';
import '../ui/admin/components/student_preview_mode.dart';
import '../ui/auth/auth_controller.dart';
import '../ui/teacher/teacher_main_shell.dart';
import 'main_shell.dart';

/// Bộ phân luồng giao diện thông minh dựa trên Vai trò (Role Routing Shell)
/// - Nếu tài khoản là Admin: Tự động khởi động [AdminMainShell] (Trung tâm Quản trị toàn hệ thống).
/// - Nếu Admin chọn "Xem trước Giao diện Học sinh": Hiển thị [MainShell] nhưng gắn [StudentPreviewBanner] trên đầu.
/// - Nếu tài khoản là Học viên (Student) hoặc Khách: Luôn khởi động [MainShell] học tập thông thường, tuyệt đối không thấy UI Admin.
class RoleRoutingShell extends StatefulWidget {
  final int initialIndex;

  const RoleRoutingShell({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<RoleRoutingShell> createState() => _RoleRoutingShellState();
}

class _RoleRoutingShellState extends State<RoleRoutingShell> {
  final AuthController _auth = AuthController.instance;
  final StudentPreviewMode _previewMode = StudentPreviewMode.instance;

  @override
  void initState() {
    super.initState();
    _auth.addListener(_onStateChanged);
    _previewMode.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _auth.removeListener(_onStateChanged);
    _previewMode.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.read<AppRepository>();
    final user = _auth.user;
    final isAdmin = user.isAdmin;
    final isTeacher = user.isTeacher;
    final isPreviewActive = _previewMode.isPreviewActive;

    // 1. Trường hợp Admin hoặc Giáo viên đang bật chế độ xem trước Học sinh
    if ((isAdmin || isTeacher) && isPreviewActive) {
      return Scaffold(
        body: Column(
          children: [
            const StudentPreviewBanner(),
            Expanded(
              child: MainShell(
                initialIndex: widget.initialIndex,
              ),
            ),
          ],
        ),
      );
    }

    // 2. Trường hợp Admin đang đăng nhập -> Vào thẳng AdminMainShell (5 Tab)
    if (isAdmin) {
      return AdminMainShell(
        repository: repository,
      );
    }

    // 3. Trường hợp Giáo viên đang đăng nhập -> Vào thẳng TeacherMainShell (4 Tab)
    if (isTeacher) {
      return TeacherMainShell(
        repository: repository,
      );
    }

    // 4. Trường hợp là Học viên (Student) hoặc Khách chưa đăng nhập
    return MainShell(
      initialIndex: widget.initialIndex,
    );
  }
}
