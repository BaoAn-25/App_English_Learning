import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_repository.dart';
import '../strings.dart';
import '../theme/app_tokens.dart';
import '../theme/components/app_button.dart';
import '../theme/components/app_card.dart';
import '../theme/components/app_progress_bar.dart';
import '../theme/components/empty_state.dart';
import '../theme/components/section_header.dart';
import '../theme/components/sync_status_badge.dart';
import 'stats_calculator.dart';
import 'stats_controller.dart';

/// Màn hình Thống kê tiến độ học tập và luyện đề.
/// Sử dụng fl_chart để trực quan hóa số liệu 7/30 ngày và phân tích 8 dạng câu hỏi THPT.
class StatsScreen extends StatelessWidget {
  final AppRepository? repository;
  final ValueChanged<String>? onPracticeType;
  final bool showAppBar;

  const StatsScreen({
    super.key,
    this.repository,
    this.onPracticeType,
    this.showAppBar = false,
  });

  @override
  Widget build(BuildContext context) {
    AppRepository repo;
    try {
      repo = repository ?? Provider.of<AppRepository>(context, listen: false);
    } catch (_) {
      repo = AppRepository();
    }

    return ChangeNotifierProvider<StatsController>(
      create: (_) => StatsController(repo: repo),
      child: Scaffold(
        appBar: showAppBar
            ? AppBar(
                title: const Text(AppStrings.statsTitle),
                actions: [
                  Consumer<StatsController>(
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
              )
            : null,
        body: Consumer<StatsController>(
          builder: (context, controller, child) {
            if (controller.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            final summary = controller.summary;
            if (summary == null) {
              return EmptyState(
                title: AppStrings.emptyData,
                actionLabel: AppStrings.retry,
                onAction: () => controller.loadStats(),
              );
            }

            return RefreshIndicator(
              onRefresh: () => controller.refresh(),
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.space16,
                  vertical: AppTokens.space8,
                ),
                children: [
                  // 1. Bộ chọn thời gian: 7 ngày / 30 ngày
                  _buildRangeSelector(context, controller),
                  const SizedBox(height: AppTokens.space16),

                  // 2. Ba thẻ số liệu nhanh (Tổng câu, Tỷ lệ đúng, Thời gian)
                  _buildQuickStats(context, summary),
                  const SizedBox(height: AppTokens.space16),

                  // 3. Biểu đồ cột fl_chart theo ngày
                  _buildBarChartCard(context, summary, controller.rangeDays),
                  const SizedBox(height: AppTokens.space16),

                  // 4. Thẻ gợi ý dạng bài yếu nhất (nếu có)
                  if (summary.weakestType != null) ...[
                    _buildWeakestTypeAlert(context, summary.weakestType!),
                    const SizedBox(height: AppTokens.space16),
                  ],

                  // 5. Kết quả theo 8 dạng bài thi THPT
                  _buildQuestionTypeBreakdown(context, summary.typeSummaries),
                  const SizedBox(height: AppTokens.space32),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // --- 1. Bộ chọn 7/30 ngày ---
  Widget _buildRangeSelector(BuildContext context, StatsController controller) {
    return Center(
      child: SegmentedButton<int>(
        segments: const [
          ButtonSegment<int>(
            value: 7,
            label: Text(AppStrings.statsRange7Days),
          ),
          ButtonSegment<int>(
            value: 30,
            label: Text(AppStrings.statsRange30Days),
          ),
        ],
        selected: {controller.rangeDays},
        onSelectionChanged: (Set<int> newSelection) {
          controller.setRangeDays(newSelection.first);
        },
      ),
    );
  }

  // --- 2. Thẻ số liệu tổng quan ---
  Widget _buildQuickStats(BuildContext context, OverallStatsSummary summary) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(
            context,
            icon: Icons.quiz_outlined,
            title: AppStrings.totalQuestions,
            value: '${summary.totalQuestions}',
            color: AppTokens.primary,
          ),
        ),
        const SizedBox(width: AppTokens.space8),
        Expanded(
          child: _buildMetricTile(
            context,
            icon: Icons.check_circle_outline_rounded,
            title: AppStrings.accuracyRate,
            value: '${summary.overallAccuracy.toStringAsFixed(1)}%',
            color: AppTokens.successGreen,
          ),
        ),
        const SizedBox(width: AppTokens.space8),
        Expanded(
          child: _buildMetricTile(
            context,
            icon: Icons.schedule_rounded,
            title: AppStrings.totalTime,
            value: '${summary.totalMinutes} ${AppStrings.minutesUnit}',
            color: const Color(0xFFFF9800),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withAlpha(isDark ? 50 : 25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: AppTokens.space8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.outline,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // --- 3. Biểu đồ cột fl_chart ---
  Widget _buildBarChartCard(
    BuildContext context,
    OverallStatsSummary summary,
    int rangeDays,
  ) {
    final theme = Theme.of(context);
    final stats = summary.rangeStats;

    // Tìm giá trị max để scale trục Y
    double maxY = 10;
    for (final s in stats) {
      if (s.questionsDone > maxY) {
        maxY = s.questionsDone.toDouble();
      }
    }
    maxY = (maxY * 1.25).ceilToDouble();

    final barGroups = <BarChartGroupData>[];
    for (int i = 0; i < stats.length; i++) {
      final s = stats[i];
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: s.questionsDone.toDouble(),
              color: s.questionsDone > 0 ? AppTokens.primary : const Color(0xFFE2E8F0),
              width: rangeDays == 7 ? 18 : 6,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Biểu đồ luyện tập ($rangeDays ngày)',
            icon: Icons.bar_chart_rounded,
          ),
          const SizedBox(height: AppTokens.space16),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final item = stats[group.x];
                      return BarTooltipItem(
                        '${item.date}\n${rod.toY.toInt()} câu (${item.correct} đúng)',
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (val, meta) {
                        if (val == 0 || val == (maxY / 2).round() || val == maxY) {
                          return Text(
                            val.toInt().toString(),
                            style: TextStyle(fontSize: 10, color: theme.colorScheme.outline),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (val, meta) {
                        final index = val.toInt();
                        if (index >= 0 && index < stats.length) {
                          // Nếu là 7 ngày: hiển thị tất cả; Nếu 30 ngày: hiển thị cách 5 ngày
                          if (rangeDays == 7 || index % 5 == 0 || index == stats.length - 1) {
                            final parts = stats[index].date.split('-');
                            final label = parts.length == 3 ? '${parts[2]}/${parts[1]}' : '';
                            return Text(
                              label,
                              style: TextStyle(
                                fontSize: 9,
                                color: theme.colorScheme.outline,
                              ),
                            );
                          }
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: barGroups,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 4. Thẻ cảnh báo dạng bài yếu nhất ---
  Widget _buildWeakestTypeAlert(
    BuildContext context,
    TypeAccuracySummary weakest,
  ) {
    return AppCard(
      color: const Color(0xFFFFF9EE),
      border: Border.all(color: AppTokens.accentYellow, width: 1.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFE65100),
                size: 22,
              ),
              const SizedBox(width: AppTokens.space8),
              Expanded(
                child: Text(
                  '${AppStrings.weakestTypeAlert}: ${weakest.displayName}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF943A00),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE0B2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Đúng ${weakest.accuracy.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFB23B00),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space8),
          const Text(
            AppStrings.recommendPractice,
            style: TextStyle(fontSize: 13, color: Color(0xFF703200)),
          ),
          const SizedBox(height: AppTokens.space12),
          AppButton(
            label: '${AppStrings.practiceNow} dạng ${weakest.displayName}',
            icon: Icons.flash_on_rounded,
            variant: AppButtonVariant.secondary,
            isFullWidth: true,
            onPressed: () {
              if (onPracticeType != null) {
                onPracticeType!(weakest.type);
              }
            },
          ),
        ],
      ),
    );
  }

  // --- 5. Thống kê theo 8 dạng câu hỏi THPT ---
  Widget _buildQuestionTypeBreakdown(
    BuildContext context,
    List<TypeAccuracySummary> types,
  ) {
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: AppStrings.performanceByType,
            icon: Icons.checklist_rounded,
          ),
          const SizedBox(height: AppTokens.space8),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: types.length,
            separatorBuilder: (_, _) => const Divider(height: 20),
            itemBuilder: (context, index) {
              final item = types[index];
              final ratio = item.totalQuestions > 0
                  ? (item.correctQuestions / item.totalQuestions)
                  : 0.0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.displayName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        item.totalQuestions > 0
                            ? '${item.correctQuestions}/${item.totalQuestions} câu (${item.accuracy.toStringAsFixed(0)}%)'
                            : 'Chưa làm',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: item.totalQuestions > 0
                              ? (item.accuracy >= 70
                                  ? AppTokens.successGreen
                                  : (item.accuracy >= 50
                                      ? const Color(0xFFFF9800)
                                      : AppTokens.errorRed))
                              : theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  AppProgressBar(
                    value: ratio,
                    height: 6,
                    color: item.accuracy >= 70
                        ? AppTokens.successGreen
                        : (item.accuracy >= 50 ? AppTokens.accentYellow : AppTokens.errorRed),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
