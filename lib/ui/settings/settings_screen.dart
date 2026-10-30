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
class SettingsScreen extends StatelessWidget {
  final AppRepository? repository;
  final VoidCallback? onLogout;

  const SettingsScreen({
    super.key,
    this.repository,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    AppRepository repo;
    try {
      repo = repository ?? Provider.of<AppRepository>(context, listen: false);
    } catch (_) {
      repo = AppRepository();
    }

    return ChangeNotifierProvider<SettingsController>(
      create: (_) => SettingsController(repo: repo),
      child: Scaffold(
        appBar: AppBar(
          title: const Text(AppStrings.settingsTitle),
        ),
        body: Consumer<SettingsController>(
          builder: (context, controller, child) {
            return ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.space16,
                vertical: AppTokens.space8,
              ),
              children: [
                // 1. Hồ sơ cá nhân
                _buildProfileCard(context, controller),
                const SizedBox(height: AppTokens.space16),

                // 2. Mục tiêu luyện tập hàng ngày
                _buildDailyGoalCard(context, controller),
                const SizedBox(height: AppTokens.space16),

                // 3. Nhắc nhở học tập offline
                _buildReminderCard(context, controller),
                const SizedBox(height: AppTokens.space16),


                // 5. Trạng thái đồng bộ đám mây (Offline-first)
                _buildSyncCard(context, controller),
                const SizedBox(height: AppTokens.space16),

                // 6. Thông tin ứng dụng & Đăng xuất
                _buildAppInfoAndLogout(context),
                const SizedBox(height: AppTokens.space32),
              ],
            );
          },
        ),
      ),
    );
  }

  // --- Khối 1: Hồ sơ học sinh ---
  Widget _buildProfileCard(BuildContext context, SettingsController controller) {
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppTokens.primary.withAlpha(25),
                child: const Icon(
                  Icons.person_rounded,
                  size: 32,
                  color: AppTokens.primary,
                ),
              ),
              const SizedBox(width: AppTokens.space16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      controller.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: AppTokens.space4),
                    Text(
                      'Lớp ${controller.grade} • Mục tiêu: ${controller.targetScore.toStringAsFixed(1)} đ',
                      style: TextStyle(
                        fontSize: 13,
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
        ],
      ),
    );
  }

  // --- Khối 2: Mục tiêu câu/ngày ---
  Widget _buildDailyGoalCard(BuildContext context, SettingsController controller) {
    const goals = [10, 20, 30];

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
                            : Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
                        border: Border.all(
                          color: isSelected ? AppTokens.primary : const Color(0xFFE2E8F0),
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
                              color: isSelected ? Colors.white : AppTokens.textMain,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppStrings.questionsDoneUnit,
                            style: TextStyle(
                              fontSize: 11,
                              color: isSelected ? Colors.white70 : const Color(0xFF64748B),
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
    final formattedTime =
        '${controller.reminderTime.hour.toString().padLeft(2, '0')}:${controller.reminderTime.minute.toString().padLeft(2, '0')}';

    return AppCard(
      child: Column(
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
              Switch(
                value: controller.reminderEnabled,
                onChanged: (val) => controller.toggleReminder(val),
              ),
            ],
          ),
          if (controller.reminderEnabled) ...[
            const Divider(height: 24),
            InkWell(
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: controller.reminderTime,
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
                    const Text(
                      AppStrings.reminderTime,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTokens.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
                      ),
                      child: Text(
                        formattedTime,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTokens.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }


  // --- Khối 5: Trạng thái đồng bộ ---
  Widget _buildSyncCard(BuildContext context, SettingsController controller) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: SectionHeader(
                  title: 'Đồng bộ dữ liệu',
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
            '${AppStrings.lastSyncedAt} ${controller.formattedLastSynced}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: AppTokens.space12),
          AppButton(
            label: AppStrings.syncNow,
            icon: Icons.refresh_rounded,
            isLoading: controller.syncState == SyncState.syncing,
            variant: AppButtonVariant.outlined,
            isFullWidth: true,
            onPressed: () => controller.syncNow(),
          ),
        ],
      ),
    );
  }

  // --- Khối 6: Thông tin & Đăng xuất ---
  Widget _buildAppInfoAndLogout(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Text(
          AppStrings.appVersion,
          style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
        ),
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
    );
  }

  void _showEditProfileDialog(BuildContext context, SettingsController controller) {
    final nameCtrl = TextEditingController(text: controller.name);
    final targetCtrl = TextEditingController(text: controller.targetScore.toString());

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
                final newTarget = double.tryParse(targetCtrl.text.trim()) ?? controller.targetScore;
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
                if (onLogout != null) {
                  onLogout!();
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
