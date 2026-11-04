import '../classes/student_classes_screen.dart';
import '../auth/welcome_screen.dart';
import '../auth/auth_controller.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';
import '../theme/theme_controller.dart';
import '../onboarding/onboarding_target_screen.dart';
import '../common/dialogs/avatar_picker_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_repository.dart';
import '../strings.dart';
import '../theme/app_tokens.dart';
import '../theme/components/app_button.dart';
import '../theme/components/app_card.dart';
import '../theme/components/section_header.dart';
import '../theme/components/sync_status_badge.dart';
import 'settings_controller.dart';
import '../teacher/teacher_main_shell.dart';
import '../admin/admin_main_shell.dart';
import '../admin/components/student_preview_mode.dart';

/// Màn hình Cá nhân & Cài đặt.
/// Xuất widget công khai để MainShell gắn vào NavigationBar.
/// Không tự điều hướng đăng xuất, gọi qua [onLogout] truyền vào.
class SettingsScreen extends StatefulWidget {
  final AppRepository? repository;
  final VoidCallback? onLogout;

  const SettingsScreen({
    super.key,
    this.repository,
    this.onLogout,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
  late final AppRepository _repo;
  late final SettingsController _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    try {
      _repo = widget.repository ?? Provider.of<AppRepository>(context, listen: false);
    } catch (_) {
      _repo = AppRepository();
    }
    _controller = SettingsController(repo: _repo);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller.checkAndReconcileReminder();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SettingsController>.value(
      value: _controller,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(AppStrings.settingsTitle),
        ),
        body: Consumer<SettingsController>(
          builder: (context, controller, child) {
            final auth = AuthController.instance;

            return ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.space16,
                vertical: AppTokens.space8,
              ),
              children: [
                // 1. Hồ sơ cá nhân (Khách hoặc Đã đăng nhập)
                if (!auth.isAuthenticated)
                  _buildGuestProfileCard(context)
                else
                  _buildProfileCard(context, controller),
                const SizedBox(height: AppTokens.space16),

                // 1.5. Cổng Chức Năng Dành Riêng Cho Giáo Viên / Admin (Học viên không hiển thị)
                if (auth.user.isTeacher || auth.user.isAdmin) ...[
                  _buildRoleAndPortalsCard(context),
                  const SizedBox(height: AppTokens.space16),
                ],

                // 1.6. Lớp học của tôi (Dành cho Học sinh tham gia theo mã)
                _buildStudentClassesCard(context),
                const SizedBox(height: AppTokens.space16),

                // 2. Mục tiêu luyện tập hàng ngày
                _buildDailyGoalCard(context, controller),
                const SizedBox(height: AppTokens.space16),

                // 3. Trung tâm thông báo & Nhắc nhở dự án
                _buildNotificationCenterCard(context, controller),
                const SizedBox(height: AppTokens.space16),

                // 4. Giao diện Sáng / Tối
                _buildThemeModeCard(context),
                const SizedBox(height: AppTokens.space16),

                // 5. Trạng thái đồng bộ / Lưu trữ
                _buildSyncCard(context, controller),
                const SizedBox(height: AppTokens.space16),

                // 6. Thông tin ứng dụng & Đăng xuất (chỉ hiện đăng xuất khi đã đăng nhập)
                _buildAppInfoAndLogout(context, isAuthenticated: auth.isAuthenticated),
                const SizedBox(height: AppTokens.space32),
              ],
            );
          },
        ),
      ),
    );
  }

  // --- Khối Lớp học của tôi (Học sinh tham gia lớp theo mã) ---
  Widget _buildStudentClassesCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StudentClassesScreen()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.school_rounded, color: Color(0xFF2563EB), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lớp học của tôi',
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppTokens.textMain,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tham gia lớp bằng mã, nhận bài tập & đề thi từ giáo viên',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  // --- Khối Cổng Quản Trị / Giáo Viên (Chỉ dành riêng cho Teacher hoặc Admin) ---
  Widget _buildRoleAndPortalsCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: AuthController.instance,
      builder: (context, _) {
        final user = AuthController.instance.user;

        // Nếu là học sinh hoặc khách: Tuyệt đối không hiển thị
        if (user.isStudent || (!user.isTeacher && !user.isAdmin)) {
          return const SizedBox.shrink();
        }

        // Cổng Quản trị viên Tối cao (Admin)
        if (user.isAdmin) {
          return AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTokens.primary.withAlpha(25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.admin_panel_settings_rounded, color: AppTokens.primary, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Trung Tâm Quản Trị Hệ Thống',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppTokens.textMain,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTokens.primary.withAlpha(30),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'QUẢN TRỊ VIÊN (ADMIN)',
                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: AppTokens.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Toàn quyền quản trị hệ thống: Quản lý người dùng, phân quyền vai trò, thay sách mới và xem nhật ký kiểm toán.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? AppTokens.darkTextSub : AppTokens.textSub,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTokens.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        if (StudentPreviewMode.instance.isPreviewActive) {
                          StudentPreviewMode.instance.exitPreview();
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => AdminMainShell(repository: _repo)),
                        );
                      },
                      icon: const Icon(Icons.admin_panel_settings_rounded, size: 18),
                      label: const Text('Trung Tâm Quản Trị Admin', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => TeacherMainShell(repository: _repo)),
                        );
                      },
                      icon: const Icon(Icons.school_rounded, size: 18),
                      label: const Text('Cổng Giáo Viên'),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        // Cổng Giáo viên (Teacher)
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTokens.primaryLight.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.school_rounded, color: AppTokens.primaryLight, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cổng Giáo Viên & Giám Sát Thi',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : AppTokens.textMain,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTokens.primaryLight.withAlpha(30),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'GIÁO VIÊN (TEACHER)',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: AppTokens.primaryLight),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Quản lý đề thi & hạn nộp, Giám sát trực tiếp phòng thi học sinh chống gian lận 10 giây, Ngân hàng câu hỏi và Tài liệu bổ trợ.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? AppTokens.darkTextSub : AppTokens.textSub,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTokens.primaryLight,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => TeacherMainShell(repository: _repo)),
                  );
                },
                icon: const Icon(Icons.school_rounded, size: 18),
                label: const Text('Vào Cổng Giáo Viên & Giám Sát', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Khối 1A: Hồ sơ dành riêng cho Khách học thử ---
  Widget _buildGuestProfileCard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppTokens.primary.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  size: 30,
                  color: AppTokens.primary,
                ),
              ),
              const SizedBox(width: AppTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Khách trải nghiệm',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            color: isDark ? Colors.white : AppTokens.textMain,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withAlpha(25),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFCD34D)),
                          ),
                          child: const Text(
                            'OFFLINE',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFB45309)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Dữ liệu làm bài & từ vựng đang lưu tạm trên máy.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : theme.colorScheme.outline,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space16),
          AppButton(
            label: 'Đăng ký tài khoản (Mở khóa toàn bộ)',
            variant: AppButtonVariant.primary,
            isFullWidth: true,
            icon: Icons.person_add_rounded,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RegisterScreen()),
              );
            },
          ),
          const SizedBox(height: AppTokens.space8),
          Center(
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              child: const Text(
                'Đã có tài khoản? Đăng nhập để đồng bộ',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTokens.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(42),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              side: BorderSide(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
            ),
            icon: Icon(Icons.tune_rounded, size: 18, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
            label: Text(
              'Thiết lập lại mục tiêu & sở thích',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF334155)),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OnboardingTargetScreen()),
              );
            },
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              side: BorderSide(color: isDark ? const Color(0xFFEF4444).withAlpha(100) : const Color(0xFFFCA5A5)),
              foregroundColor: const Color(0xFFEF4444),
            ),
            icon: const Icon(Icons.delete_sweep_rounded, size: 18),
            label: const Text(
              'Xóa dữ liệu học thử trên thiết bị',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            onPressed: () => _confirmResetGuestData(context),
          ),
        ],
      ),
    );
  }

  // --- Khối 1B: Hồ sơ người dùng đã đăng nhập (Học sinh / Giáo viên / Admin) ---
  Widget _buildProfileCard(BuildContext context, SettingsController controller) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final auth = AuthController.instance;
    final user = auth.user;
    final initialLetter = user.displayName.isNotEmpty
        ? user.displayName.trim()[0].toUpperCase()
        : (user.email.isNotEmpty ? user.email.trim()[0].toUpperCase() : 'H');

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar người dùng thật + nút đổi ảnh (Presets hoặc Link bên ngoài)
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppTokens.primary.withAlpha(25),
                    backgroundImage: user.avatarUrl.isNotEmpty ? NetworkImage(user.avatarUrl) : null,
                    child: user.avatarUrl.isEmpty
                        ? Text(
                            initialLetter,
                            style: const TextStyle(
                              fontFamily: 'BeVietnamPro',
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppTokens.primary,
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: InkWell(
                      onTap: () {
                        AvatarPickerDialog.show(
                          context,
                          currentAvatarUrl: user.avatarUrl,
                          onSelected: (newUrl) async {
                            final ok = await controller.updateAvatar(newUrl);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(ok ? 'Cập nhật ảnh đại diện thành công!' : 'Đã cập nhật ảnh đại diện'),
                                  backgroundColor: AppTokens.successGreen,
                                ),
                              );
                            }
                          },
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: AppTokens.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(40),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.camera_alt_rounded, size: 12, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: AppTokens.space16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName.isNotEmpty ? user.displayName : controller.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 3),
                    // Huy hiệu phân quyền vai trò người dùng
                    if (user.isAdmin)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED).withAlpha(25),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFC4B5FD)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shield_rounded, size: 12, color: Color(0xFF7C3AED)),
                            SizedBox(width: 4),
                            Text(
                              'QUẢN TRỊ VIÊN HỆ THỐNG',
                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF7C3AED)),
                            ),
                          ],
                        ),
                      )
                    else if (user.isTeacher)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D9488).withAlpha(25),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF5EEAD4)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.school_rounded, size: 12, color: Color(0xFF0D9488)),
                            SizedBox(width: 4),
                            Text(
                              'GIÁO VIÊN BỘ MÔN',
                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF0D9488)),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withAlpha(25),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF93C5FD)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.menu_book_rounded, size: 12, color: Color(0xFF2563EB)),
                            SizedBox(width: 4),
                            Text(
                              'HỌC VIÊN',
                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
                            ),
                          ],
                        ),
                      ),
                    if (user.email.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        user.email,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppTokens.space4),
                    Text(
                      controller.hasTargetScore
                          ? 'Mục tiêu: ${controller.targetScore!.toStringAsFixed(1)} đ • Kế hoạch: ${controller.dailyGoal} câu/ngày'
                          : 'Kế hoạch học: ${controller.dailyGoal} câu/ngày',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.outline,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                tooltip: 'Chỉnh sửa tên & mục tiêu',
                onPressed: () => _showEditProfileDialog(context, controller),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Phương thức đăng nhập & Trạng thái xác minh email thật
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      user.authProvider == 'google' ? Icons.g_mobiledata_rounded : Icons.email_outlined,
                      size: 18,
                      color: const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        user.authProvider == 'google' ? 'Đăng nhập Google' : 'Đăng nhập Email',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Badge trạng thái xác minh email
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: user.emailVerified ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: user.emailVerified ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      user.emailVerified ? Icons.verified_rounded : Icons.info_outline_rounded,
                      size: 14,
                      color: user.emailVerified ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      user.emailVerified ? 'Đã xác minh' : 'Chưa xác minh',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: user.emailVerified ? const Color(0xFF15803D) : const Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Lời nhắc gửi lại thư xác minh nếu email chưa xác minh
          if (!user.emailVerified && user.authProvider == 'email') ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: () async {
                final success = await auth.resendVerificationEmail();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? (auth.successMessage ?? 'Đã gửi lại thư xác minh!')
                            : (auth.errorMessage ?? 'Không thể gửi thư xác minh.'),
                      ),
                      backgroundColor: success ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                    ),
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.forward_to_inbox_rounded, size: 16, color: Color(0xFF2563EB)),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Bấm để gửi lại thư xác minh vào email của bạn',
                        style: TextStyle(fontSize: 12, color: Color(0xFF1D4ED8), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              side: BorderSide(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
            ),
            icon: Icon(Icons.tune_rounded, size: 17, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
            label: Text(
              'Cập nhật sở thích & lộ trình cá nhân hóa',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF334155)),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OnboardingTargetScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- Khối 2: Mục tiêu câu/ngày ---
  Widget _buildDailyGoalCard(BuildContext context, SettingsController controller) {
    const goals = [10, 20, 30];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: AppStrings.dailyTargetSection,
            icon: Icons.track_changes_rounded,
          ),
          const SizedBox(height: AppTokens.space8),
          Row(
            children: goals.map((goal) {
              final isSelected = controller.dailyGoal == goal;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: InkWell(
                    onTap: () => controller.setDailyGoal(goal),
                    borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTokens.primary
                            : (isDark ? const Color(0xFF1E293B) : Colors.white),
                        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
                        border: Border.all(
              color: isSelected ? (isDark ? const Color(0xFF3B82F6) : AppTokens.primary) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$goal',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : (isDark ? Colors.white : AppTokens.textMain),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppStrings.questionsDoneUnit,
                            style: TextStyle(
                              fontSize: 11,
                              color: isSelected ? Colors.white70 : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // --- Khối 3: Trung tâm thông báo & Nhắc nhở dự án ---
  Widget _buildNotificationCenterCard(BuildContext context, SettingsController controller) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final formattedTime =
        '${controller.reminderTime.hour.toString().padLeft(2, '0')}:${controller.reminderTime.minute.toString().padLeft(2, '0')}';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Trung tâm thông báo & Nhắc học',
            icon: Icons.notifications_active_rounded,
          ),
          const SizedBox(height: AppTokens.space8),
          Text(
            'Quản lý nhắc nhở duy trì Streak và nhận thông báo phân nhóm dự án.',
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 14),

          // 1. Khối Nhắc nhở Streak hàng ngày (Giờ học)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: controller.reminderEnabled
                    ? (isDark ? const Color(0xFF3B82F6) : AppTokens.primary)
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                width: controller.reminderEnabled ? 1.5 : 1,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withAlpha(25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.alarm_rounded, color: Color(0xFFD97706), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Nhắc học hằng ngày (Bảo vệ Streak)',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                          ),
                          Text(
                            controller.reminderEnabled ? 'Đang bật lúc $formattedTime' : 'Đang tắt',
                            style: TextStyle(
                              fontSize: 12,
                              color: controller.reminderEnabled
                                  ? (isDark ? const Color(0xFF60A5FA) : AppTokens.primary)
                                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (controller.isProcessingReminder)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Switch(
                        value: controller.reminderEnabled,
                        onChanged: (val) => controller.toggleReminder(val),
                      ),
                  ],
                ),
                if (controller.reminderEnabled) ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Thời gian nhắc học:',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: controller.isProcessingReminder
                            ? null
                            : () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: controller.reminderTime,
                                  initialEntryMode: TimePickerEntryMode.input,
                                  helpText: 'CHỌN GIỜ NHẮC HỌC HẰNG NGÀY',
                                  cancelText: 'HỦY',
                                  confirmText: 'XÁC NHẬN',
                                );
                                if (picked != null) {
                                  controller.setReminderTime(picked);
                                }
                              },
                        icon: const Icon(Icons.access_time_rounded, size: 16),
                        label: Text(
                          formattedTime,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          if (controller.reminderStatusMessage != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFCD34D)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFB45309)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      controller.reminderStatusMessage!,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
          const Text(
            'Kênh thông báo chi tiết',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),

          _buildNotificationChannelTile(
            icon: Icons.campaign_rounded,
            iconColor: const Color(0xFF2563EB),
            title: 'Thông báo chung & Bảo trì',
            subtitle: 'Lịch bảo trì máy chủ, sách mới và tin tức quan trọng',
            value: controller.notifyAnnouncements,
            onChanged: (val) => controller.toggleNotifyAnnouncements(val),
          ),
          const Divider(height: 1),
          _buildNotificationChannelTile(
            icon: Icons.assignment_rounded,
            iconColor: const Color(0xFF0D9488),
            title: 'Bài tập & Hạn thi mới',
            subtitle: 'Nhắc nhở khi thầy cô giao đề hoặc sắp hết hạn làm bài',
            value: controller.notifyAssignments,
            onChanged: (val) => controller.toggleNotifyAssignments(val),
          ),
          const Divider(height: 1),
          _buildNotificationChannelTile(
            icon: Icons.local_fire_department_rounded,
            iconColor: const Color(0xFFEA580C),
            title: 'Cảnh báo nguy cơ mất chuỗi Streak',
            subtitle: 'Nhắc nhở lúc chiều tối nếu bạn chưa hoàn thành mục tiêu',
            value: controller.notifyStreak,
            onChanged: (val) => controller.toggleNotifyStreak(val),
          ),
          const Divider(height: 1),
          _buildNotificationChannelTile(
            icon: Icons.emoji_events_rounded,
            iconColor: const Color(0xFFEAB308),
            title: 'Bảng xếp hạng & Vinh danh',
            subtitle: 'Thông báo khi bạn thăng hạng hoặc có biến động thứ hạng',
            value: controller.notifyLeaderboard,
            onChanged: (val) => controller.toggleNotifyLeaderboard(val),
          ),
          const Divider(height: 1),
          _buildNotificationChannelTile(
            icon: Icons.volume_up_rounded,
            iconColor: const Color(0xFF6366F1),
            title: 'Hiệu ứng âm thanh',
            subtitle: 'Phát âm thanh thông báo nhẹ khi nhận thông báo',
            value: controller.soundEnabled,
            onChanged: (val) => controller.toggleSoundEnabled(val),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationChannelTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: iconColor.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: value,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  // --- Khối 4: Giao diện Sáng / Tối ---
  Widget _buildThemeModeCard(BuildContext context) {
    ThemeController? themeCtrl;
    try {
      themeCtrl = context.watch<ThemeController>();
    } catch (_) {
      themeCtrl = null;
    }
    final currentMode = themeCtrl?.themeMode ?? ThemeMode.system;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Giao diện ứng dụng',
            icon: Icons.palette_outlined,
          ),
          const SizedBox(height: AppTokens.space8),
          const Text(
            'Chọn chế độ hiển thị phù hợp với môi trường học của bạn.',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildThemeOption(
                context,
                title: 'Tự động',
                subtitle: 'Hệ thống',
                icon: Icons.brightness_auto_rounded,
                isSelected: currentMode == ThemeMode.system,
                onTap: () => themeCtrl?.setThemeMode(ThemeMode.system),
              ),
              const SizedBox(width: 8),
              _buildThemeOption(
                context,
                title: 'Sáng',
                subtitle: 'Light',
                icon: Icons.light_mode_rounded,
                isSelected: currentMode == ThemeMode.light,
                onTap: () => themeCtrl?.setThemeMode(ThemeMode.light),
              ),
              const SizedBox(width: 8),
              _buildThemeOption(
                context,
                title: 'Tối',
                subtitle: 'Dark',
                icon: Icons.dark_mode_rounded,
                isSelected: currentMode == ThemeMode.dark,
                onTap: () => themeCtrl?.setThemeMode(ThemeMode.dark),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTokens.primary.withAlpha(isDark ? 50 : 25)
                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? (isDark ? const Color(0xFF3B82F6) : AppTokens.primary) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              width: isSelected ? 1.8 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 22,
                color: isSelected ? (isDark ? const Color(0xFF60A5FA) : AppTokens.primary) : (isDark ? Colors.white70 : const Color(0xFF64748B)),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? (isDark ? const Color(0xFF60A5FA) : AppTokens.primary) : (isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10.5,
                  color: isSelected
                      ? (isDark ? const Color(0xFF93C5FD) : AppTokens.primary.withAlpha(200))
                      : (isDark ? Colors.white54 : const Color(0xFF94A3B8)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Khối 5: Trạng thái đồng bộ ---
  Widget _buildSyncCard(BuildContext context, SettingsController controller) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = AuthController.instance;
    final isGuest = !auth.isAuthenticated || auth.user.isGuest;

    if (isGuest) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: SectionHeader(
                    title: 'Lưu trữ & Đồng bộ',
                    icon: Icons.storage_rounded,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                  ),
                  child: Text(
                    'Lưu trên thiết bị',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.space8),
            Text(
              'Dữ liệu học tập và bài làm của bạn đang được lưu an toàn trên máy. Đăng nhập để đồng bộ tiến độ và kết quả học lên máy chủ đám mây.',
              style: TextStyle(fontSize: 12.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: AppTokens.space12),
            AppButton(
              label: 'Đăng nhập để đồng bộ',
              icon: Icons.login_rounded,
              variant: AppButtonVariant.primary,
              isFullWidth: true,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                side: BorderSide(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
              ),
              icon: Icon(Icons.cleaning_services_rounded, size: 17, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
              label: Text(
                'Dọn dẹp bộ nhớ đệm hình ảnh (Cache)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF334155)),
              ),
              onPressed: () {
                PaintingBinding.instance.imageCache.clear();
                PaintingBinding.instance.imageCache.clearLiveImages();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã dọn dẹp bộ nhớ đệm thành công!'),
                    backgroundColor: AppTokens.successGreen,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        ),
      );
    }

    // Giao diện đồng bộ dành cho Học viên đã đăng nhập
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: SectionHeader(
                  title: 'Đồng bộ dữ liệu đám mây',
                  icon: Icons.cloud_sync_outlined,
                ),
              ),
              SyncStatusBadge(
                state: controller.syncState,
                onRetry: () => controller.syncNow(),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space4),
          Text(
            controller.formattedLastSynced,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          if (controller.syncMessage != null) ...[
            const SizedBox(height: AppTokens.space8),
            Text(
              controller.syncMessage!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: controller.syncState == SyncState.error
                    ? AppTokens.errorRed
                    : (controller.syncState == SyncState.synced
                        ? AppTokens.successGreen
                        : const Color(0xFF64748B)),
              ),
            ),
          ],
          const SizedBox(height: AppTokens.space12),
          AppButton(
            label: controller.syncState == SyncState.syncing
                ? 'Đang đồng bộ...'
                : 'Đồng bộ ngay',
            icon: Icons.sync_rounded,
            isLoading: controller.syncState == SyncState.syncing,
            variant: AppButtonVariant.primary,
            isFullWidth: true,
            onPressed: () async {
              await controller.syncNow();
              if (context.mounted && controller.syncMessage != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(controller.syncMessage!),
                    backgroundColor: controller.syncState == SyncState.error
                        ? AppTokens.errorRed
                        : (controller.syncState == SyncState.synced
                            ? AppTokens.successGreen
                            : AppTokens.primary),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              side: BorderSide(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
            ),
            icon: Icon(Icons.cleaning_services_rounded, size: 17, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
            label: Text(
              'Dọn dẹp bộ nhớ đệm (Cache) & Tải lại hình ảnh',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF334155)),
            ),
            onPressed: () {
              PaintingBinding.instance.imageCache.clear();
              PaintingBinding.instance.imageCache.clearLiveImages();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã dọn dẹp bộ nhớ đệm thành công!'),
                  backgroundColor: AppTokens.successGreen,
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- Khối 6: Thông tin & Đăng xuất ---
  Widget _buildAppInfoAndLogout(BuildContext context, {required bool isAuthenticated}) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Text(
          AppStrings.appVersion,
          style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
        ),
        const SizedBox(height: AppTokens.space8),
        Text(
          'Dữ liệu học tập được bảo vệ trên thiết bị này.',
          style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
        ),
        if (isAuthenticated) ...[
          const SizedBox(height: AppTokens.space16),
          AppButton(
            label: AppStrings.logout,
            icon: Icons.logout_rounded,
            variant: AppButtonVariant.text,
            onPressed: () {
              _showLogoutConfirmDialog(context);
            },
          ),
        ],
      ],
    );
  }

  void _showEditProfileDialog(BuildContext context, SettingsController controller) {
    final nameCtrl = TextEditingController(text: controller.name);
    final targetCtrl = TextEditingController(
      text: controller.hasTargetScore ? controller.targetScore!.toString() : '',
    );

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Chỉnh sửa hồ sơ'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: AppStrings.fullName,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: targetCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: AppStrings.targetScore,
                  hintText: 'Ví dụ: 8.5',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text(AppStrings.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                final newName = nameCtrl.text.trim();
                final newTarget = double.tryParse(targetCtrl.text.trim()) ?? controller.targetScore ?? 8.0;
                if (newName.isNotEmpty) {
                  controller.updateProfile(
                    name: newName,
                    grade: 12,
                    targetScore: newTarget,
                  );
                }
                Navigator.pop(dialogCtx);
              },
              child: const Text(AppStrings.save),
            ),
          ],
        );
      },
    );
  }

  void _confirmResetGuestData(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Xóa dữ liệu học thử?'),
          content: const Text(
            'Toàn bộ lịch sử làm bài offline, câu hỏi luyện tập và bộ nhớ đệm trên thiết bị này sẽ được dọn dẹp về trạng thái ban đầu.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTokens.errorRed),
              onPressed: () async {
                Navigator.pop(dialogCtx);
                PaintingBinding.instance.imageCache.clear();
                PaintingBinding.instance.imageCache.clearLiveImages();
                await _repo.clearLearningSession('guest');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã dọn dẹp và đặt lại dữ liệu học thử!'),
                      backgroundColor: AppTokens.primary,
                    ),
                  );
                }
              },
              child: const Text('Xác nhận xóa', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showLogoutConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text(AppStrings.logout),
          content: const Text(AppStrings.confirmLogout),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text(AppStrings.cancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTokens.errorRed),
              onPressed: () {
                Navigator.pop(dialogCtx);
                if (widget.onLogout != null) {
                  widget.onLogout!();
                } else {
                  SharedPreferences.getInstance().then((prefs) {
                    prefs.setBool('has_completed_onboarding', false);
                  });
                  AuthController.instance.logout();
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                    (route) => false,
                  );
                }
              },
              child: const Text(AppStrings.logout, style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}
