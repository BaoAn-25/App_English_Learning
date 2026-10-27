import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_repository.dart';
import '../../data/models/topic.dart';
import '../strings.dart';
import '../theme/app_tokens.dart';
import '../theme/components/app_button.dart';
import '../theme/components/app_card.dart';
import '../theme/components/app_progress_bar.dart';
import '../theme/components/section_header.dart';
import '../theme/components/stat_chip.dart';
import '../theme/components/sync_status_badge.dart';
import 'home_controller.dart';

/// Màn hình Trang Chủ (Home).
/// Xuất widget công khai để MainShell gắn vào NavigationBar.
/// Nhận callback điều hướng qua [onContinueLearning] và [onSelectTopic].
class HomeScreen extends StatelessWidget {
  final AppRepository? repository;
  final VoidCallback? onContinueLearning;
  final ValueChanged<Topic>? onSelectTopic;

  const HomeScreen({
    super.key,
    this.repository,
    this.onContinueLearning,
    this.onSelectTopic,
  });

  @override
  Widget build(BuildContext context) {
    AppRepository repo;
    try {
      repo = repository ?? Provider.of<AppRepository>(context, listen: false);
    } catch (_) {
      repo = AppRepository();
    }

    return ChangeNotifierProvider<HomeController>(
      create: (_) => HomeController(repo: repo),
      child: Scaffold(
        appBar: AppBar(
          title: const Text(AppStrings.appName),
          actions: [
            Consumer<HomeController>(
              builder: (context, controller, child) {
                return Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: SyncStatusBadge(
                    state: controller.syncState,
                    compact: true,
                    onRetry: () => controller.refresh(),
                  ),
                );
              },
            ),
          ],
        ),
        body: Consumer<HomeController>(
          builder: (context, controller, child) {
            if (controller.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            return RefreshIndicator(
              onRefresh: () => controller.refresh(),
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.space16,
                  vertical: AppTokens.space8,
                ),
                children: [
                  // 1. Lời chào & Chỉ số Streak, XP, Level
                  _buildHeaderStats(context, controller),
                  const SizedBox(height: AppTokens.space16),

                  // 2. Thẻ Kế hoạch hôm nay & Vòng tròn tiến độ ngày
                  _buildTodayPlanCard(context, controller),
                  const SizedBox(height: AppTokens.space20),

                  // 3. Lộ trình chuyên đề lớp 12
                  _buildRoadmapSection(context, controller),
                  const SizedBox(height: AppTokens.space32),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // --- 1. Lời chào & Huy hiệu chỉ số ---
  Widget _buildHeaderStats(BuildContext context, HomeController controller) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.greeting,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Cùng chinh phục kỳ thi THPT 2026',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
            StatChip(
              type: StatChipType.custom,
              value: 'Cấp ${controller.level}',
              customIcon: Icons.military_tech_rounded,
              customColor: AppTokens.primary,
            ),
          ],
        ),
        const SizedBox(height: AppTokens.space12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatChip(
              type: StatChipType.streak,
              value: '${controller.streak} ngày',
              label: 'liên tiếp',
            ),
            StatChip(
              type: StatChipType.xp,
              value: '${controller.totalXp} XP',
            ),
          ],
        ),
      ],
    );
  }

  // --- 2. Thẻ Kế hoạch hôm nay với Vòng tròn tiến độ ---
  Widget _buildTodayPlanCard(BuildContext context, HomeController controller) {
    final theme = Theme.of(context);

    final ratio = controller.todayProgressRatio;
    final percent = (ratio * 100).toInt();

    return AppCard(
      color: theme.brightness == Brightness.dark
          ? const Color(0xFF1E2838)
          : const Color(0xFFFFFFFF),
      border: Border.all(
        color: AppTokens.primary.withAlpha(50),
        width: 1.5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Vòng tròn tiến độ mục tiêu ngày
              SizedBox(
                width: 68,
                height: 68,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: ratio,
                      strokeWidth: 6,
                      backgroundColor: theme.brightness == Brightness.dark
                          ? const Color(0xFF2C3545)
                          : const Color(0xFFE2EAF8),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        controller.isDailyGoalCompleted
                            ? AppTokens.successGreen
                            : AppTokens.primary,
                      ),
                    ),
                    Text(
                      '$percent%',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTokens.space16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      AppStrings.todayPlan,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppTokens.space4),
                    Text(
                      'Đã làm ${controller.todayQuestionsDone}/${controller.dailyGoal} ${AppStrings.questionsDoneUnit}',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.outline,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (controller.isDailyGoalCompleted) ...[
                      const SizedBox(height: 2),
                      const Text(
                        'Tuyệt vời! Bạn đã hoàn thành mục tiêu hôm nay 🎉',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTokens.successGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space16),
          AppButton(
            label: AppStrings.continueLearning,
            icon: Icons.play_arrow_rounded,
            isFullWidth: true,
            variant: AppButtonVariant.primary,
            onPressed: () {
              if (onContinueLearning != null) {
                onContinueLearning!();
              }
            },
          ),
        ],
      ),
    );
  }

  // --- 3. Lộ trình chuyên đề lớp 12 ---
  Widget _buildRoadmapSection(BuildContext context, HomeController controller) {
    final topics = controller.roadmapTopics;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: AppStrings.roadmapTitle,
          icon: Icons.alt_route_rounded,
        ),
        if (topics.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text(AppStrings.emptyData)),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: topics.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppTokens.space12),
            itemBuilder: (context, index) {
              final item = topics[index];
              return _buildRoadmapTopicItem(context, item, index);
            },
          ),
      ],
    );
  }

  Widget _buildRoadmapTopicItem(
    BuildContext context,
    TopicProgressItem item,
    int index,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isUnlocked = item.isUnlocked;
    final isCompleted = item.isCompleted;

    Color iconBg;
    Color iconColor;
    IconData icon;

    if (isCompleted) {
      iconBg = AppTokens.successGreen.withAlpha(25);
      iconColor = AppTokens.successGreen;
      icon = Icons.check_circle_rounded;
    } else if (isUnlocked) {
      iconBg = AppTokens.primary.withAlpha(25);
      iconColor = AppTokens.primary;
      icon = Icons.school_rounded;
    } else {
      iconBg = isDark ? const Color(0xFF2C3545) : const Color(0xFFE2E8F0);
      iconColor = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
      icon = Icons.lock_rounded;
    }

    return AppCard(
      padding: const EdgeInsets.all(AppTokens.space16),
      color: isUnlocked ? null : (isDark ? const Color(0xFF161B26) : const Color(0xFFF8FAFC)),
      onTap: isUnlocked
          ? () {
              if (onSelectTopic != null) {
                onSelectTopic!(item.topic);
              }
            }
          : null,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: AppTokens.space16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Chuyên đề ${index + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isUnlocked ? AppTokens.primary : const Color(0xFF94A3B8),
                      ),
                    ),
                    if (isCompleted)
                      const Text(
                        AppStrings.completedTopic,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTokens.successGreen,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  item.topic.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isUnlocked
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: AppTokens.space8),
                if (isUnlocked)
                  AppProgressBar(
                    value: item.progressRatio,
                    height: 6,
                    color: isCompleted ? AppTokens.successGreen : AppTokens.primary,
                  )
                else
                  const Text(
                    AppStrings.lockedTopic,
                    style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppTokens.space8),
          Icon(
            isUnlocked ? Icons.chevron_right_rounded : Icons.lock_outline_rounded,
            size: 20,
            color: isUnlocked ? theme.colorScheme.outline : const Color(0xFFCBD5E1),
          ),
        ],
      ),
    );
  }
}
