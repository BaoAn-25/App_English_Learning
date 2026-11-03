import '../auth/welcome_screen.dart';
import '../auth/auth_controller.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';
import '../theme/theme_controller.dart';
import '../onboarding/onboarding_target_screen.dart';
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

                // 2. Mục tiêu luyện tập hàng ngày
                _buildDailyGoalCard(context, controller),
                const SizedBox(height: AppTokens.space16),

                // 3. Nhắc nhở học tập offline
                _buildReminderCard(context, controller),
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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTokens.primary.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  size: 28,
                  color: AppTokens.primary,
                ),
              ),
              const SizedBox(width: AppTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bạn đang học thử',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: isDark ? Colors.white : AppTokens.textMain,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Kết quả đang lưu trên thiết bị này.',
                      style: TextStyle(
                        fontSize: 12.5,
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
            label: 'Tạo tài khoản',
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
                'Đã có tài khoản? Đăng nhập',
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
        ],
      ),
    );
  }

  // --- Khối 1B: Hồ sơ học sinh đã đăng nhập ---
  Widget _buildProfileCard(BuildContext context, SettingsController controller) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final auth = AuthController.instance;
    final user = auth.user;
    final initialLetter = user.displayName.isNotEmpty
        ? user.displayName.trim()[0].toUpperCase()
        : 'H';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar người dùng thật (hoặc chữ cái đầu tên)
              if (user.avatarUrl.isNotEmpty)
                CircleAvatar(
                  radius: 28,
                  backgroundImage: NetworkImage(user.avatarUrl),
                )
              else
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTokens.primary,
                  child: Text(
                    initialLetter,
                    style: const TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
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
                    if (user.email.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        user.email,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppTokens.space4),
                    Text(
                      controller.hasTargetScore
                          ? 'Mục tiêu: ${controller.targetScore!.toStringAsFixed(1)} đ • Kế hoạch: ${controller.dailyGoal} câu/ngày'
                          : 'Chưa chọn mục tiêu điểm số',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: theme.colorScheme.outline,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                tooltip: 'Chỉnh sửa hồ sơ',
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
                          color: isSelected ? AppTokens.primary : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
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

  // --- Khối 3: Nhắc nhở học tập ---
  Widget _buildReminderCard(BuildContext context, SettingsController controller) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final formattedTime =
        '${controller.reminderTime.hour.toString().padLeft(2, '0')}:${controller.reminderTime.minute.toString().padLeft(2, '0')}';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.alarm_rounded, color: AppTokens.primary, size: 22),
              const SizedBox(width: AppTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      AppStrings.enableDailyReminder,
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    Text(
                      'Nhắc duy trì streak mỗi ngày',
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
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

          // Hiển thị thông báo trạng thái/lỗi phản ánh trung thực
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

          if (controller.reminderEnabled) ...[
            const Divider(height: 24),
            InkWell(
              onTap: controller.isProcessingReminder
                  ? null
                  : () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: controller.reminderTime,
                        initialEntryMode: TimePickerEntryMode.input,
                        helpText: 'CHỌN GIỜ NHẮC HỌC HẰNG NGÀY',
                        cancelText: 'HỦY',
                        confirmText: 'XÁC NHẬN',
                        hourLabelText: 'Giờ',
                        minuteLabelText: 'Phút',
                        errorInvalidText: 'Giờ hoặc phút không hợp lệ',
                      );
                      if (picked != null) {
                        controller.setReminderTime(picked);
                      }
                    },
              borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        AppStrings.reminderTime,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E3A8A).withAlpha(120) : AppTokens.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
                      ),
                      child: Text(
                        formattedTime,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFF93C5FD) : AppTokens.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Thông báo có thể đến muộn do cài đặt hệ thống.',
              style: TextStyle(
                fontSize: 11.5,
                color: theme.colorScheme.outline,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- Khối 4: Giao diện Sáng / Tối ---
  Widget _buildThemeModeCard(BuildContext context) {
    final themeCtrl = context.watch<ThemeController>();
    final currentMode = themeCtrl.themeMode;

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
                onTap: () => themeCtrl.setThemeMode(ThemeMode.system),
              ),
              const SizedBox(width: 8),
              _buildThemeOption(
                context,
                title: 'Sáng',
                subtitle: 'Light',
                icon: Icons.light_mode_rounded,
                isSelected: currentMode == ThemeMode.light,
                onTap: () => themeCtrl.setThemeMode(ThemeMode.light),
              ),
              const SizedBox(width: 8),
              _buildThemeOption(
                context,
                title: 'Tối',
                subtitle: 'Dark',
                icon: Icons.dark_mode_rounded,
                isSelected: currentMode == ThemeMode.dark,
                onTap: () => themeCtrl.setThemeMode(ThemeMode.dark),
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
              color: isSelected ? AppTokens.primary : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              width: isSelected ? 1.8 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 22,
                color: isSelected ? AppTokens.primary : (isDark ? Colors.white70 : const Color(0xFF64748B)),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? AppTokens.primary : (isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10.5,
                  color: isSelected
                      ? AppTokens.primary.withAlpha(200)
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
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: const Text(
                    'Lưu trên thiết bị',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.space8),
            const Text(
              'Dữ liệu học tập và bài làm của bạn đang được lưu an toàn trên máy. Đăng nhập để đồng bộ tiến độ và kết quả học lên máy chủ đám mây.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.4),
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
