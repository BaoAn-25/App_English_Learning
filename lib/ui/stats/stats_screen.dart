import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_repository.dart';
import '../practice/practice_quiz_screen.dart';
import '../practice/wrong_book_screen.dart';
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
                  // 0. Thẻ mở nhanh Sổ tay câu sai (WrongBookScreen)
                  _buildWrongBookEntryCard(context),
                  const SizedBox(height: AppTokens.space16),

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

  // --- 0. Thẻ mở nhanh Sổ tay câu sai ---
  Widget _buildWrongBookEntryCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppCard(
      color: isDark ? const Color(0xFF1E2430) : Colors.white,
      border: Border.all(
        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF7F1D1D).withAlpha(110) : const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.menu_book_rounded,
              color: isDark ? const Color(0xFFF87171) : AppTokens.errorRed,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sổ tay câu sai',
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Xem lại lời giải chi tiết và luyện các câu từng làm sai',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTokens.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WrongBookScreen()),
              );
            },
            child: const Text(
              'Mở sổ sai',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
        ],
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
    final isDark = theme.brightness == Brightness.dark;
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
              color: s.questionsDone > 0
                  ? AppTokens.primary
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppCard(
      color: isDark ? const Color(0xFF2E1E0F) : const Color(0xFFFFF9EE),
      border: Border.all(color: AppTokens.accentYellow, width: 1.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFE65100),
                size: 22,
              ),
              const SizedBox(width: AppTokens.space8),
              Expanded(
                child: Text(
                  '${AppStrings.weakestTypeAlert}: ${weakest.displayName}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF943A00),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF78350F) : const Color(0xFFFFE0B2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Đúng ${weakest.accuracy.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFFFDE68A) : const Color(0xFFB23B00),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space8),
          Text(
            AppStrings.recommendPractice,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? const Color(0xFFFCD34D) : const Color(0xFF703200),
            ),
          ),
          const SizedBox(height: AppTokens.space12),
          AppButton(
            label: '${AppStrings.practiceNow} dạng ${weakest.displayName}',
            icon: Icons.flash_on_rounded,
            variant: AppButtonVariant.secondary,
            isFullWidth: true,
            onPressed: () async {
              if (onPracticeType != null) {
                onPracticeType!(weakest.type);
                return;
              }
              final repo = repository ?? AppRepository();
              final allQuestions = await repo.getAllQuestions();
              final typedQuestions = allQuestions
                  .where((q) => q.type == weakest.type)
                  .toList()
                ..shuffle();
              final quizQuestions = (typedQuestions.isNotEmpty ? typedQuestions : allQuestions)
                  .take(10)
                  .toList();
              if (context.mounted && quizQuestions.isNotEmpty) {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PracticeQuizScreen(
                      title: 'Luyện dạng: ${weakest.displayName}',
                      questions: quizQuestions,
                    ),
                  ),
                );
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
                      Expanded(
                        child: Text(
                          item.displayName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
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
