import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/app_repository.dart';
import '../models/adaptive_models.dart';
import '../models/adaptive_plan_models.dart';
import '../practice_quiz_screen.dart';
import '../services/adaptive_learning_service.dart';
import '../services/adaptive_plan_generator.dart';

/// Dữ liệu tổng hợp của khu vực Luyện tập thích ứng
class _AdaptiveData {
  final AdaptiveStudentProfile profile;
  final AdaptiveLearningPlan plan;

  const _AdaptiveData({required this.profile, required this.plan});
}

/// Widget hiển thị Hồ sơ năng lực thích ứng và Danh sách nhiệm vụ học tập cá nhân hóa
class AdaptiveLearningSection extends StatefulWidget {
  const AdaptiveLearningSection({super.key});

  @override
  State<AdaptiveLearningSection> createState() =>
      _AdaptiveLearningSectionState();
}

class _AdaptiveLearningSectionState extends State<AdaptiveLearningSection> {
  bool _isLoading = true;
  String? _errorMessage;
  _AdaptiveData? _data;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Tải dữ liệu thực tế từ SQLite qua AppRepository và tính toán lộ trình thích ứng
  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repository = context.read<AppRepository>();

      // Đọc song song dữ liệu lịch sử từ SQLite
      final results = await Future.wait([
        repository.getAllQuestions(),
        repository.getAllAttempts(),
        repository.getAllAttemptAnswers(),
        repository.getAllWrongBookEntries(),
      ]);

      final allQuestions = results[0] as List<dynamic>;
      final allAttempts = results[1] as List<dynamic>;
      final allAnswers = results[2] as List<dynamic>;
      final wrongEntries = results[3] as List<dynamic>;

      final questions = allQuestions
          .cast<dynamic>()
          .map((e) => e as dynamic)
          .toList();
      if (questions.isEmpty) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _data = null;
        });
        return;
      }

      // Đánh giá năng lực học sinh
      final profile = AdaptiveLearningService.evaluateStudentProfile(
        questions: allQuestions.cast(),
        attempts: allAttempts.cast(),
        answers: allAnswers.cast(),
        wrongEntries: wrongEntries.cast(),
      );

      // Sinh kế hoạch học tập cá nhân hóa
      final plan = AdaptivePlanGenerator().generatePlan(
        profile: profile,
        allQuestions: allQuestions.cast(),
        allAnswers: allAnswers.cast(),
        allAttempts: allAttempts.cast(),
        wrongBookEntries: wrongEntries.cast(),
      );

      if (!mounted) return;

      setState(() {
        _data = _AdaptiveData(profile: profile, plan: plan);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Không thể tải lộ trình học tập: $e';
        _isLoading = false;
      });
    }
  }

  /// Điều hướng sang màn hình làm bài thực tế với đúng danh sách câu hỏi đã chọn
  Future<void> _startTask(AdaptiveTask task) async {
    if (!task.isValid) return;

    // Phân biệt chế độ làm bài:
    // - Nhiệm vụ Ôn tập sổ câu sai: mode 'wrong_review'
    // - Các nhiệm vụ còn lại (kể cả Kiểm tra tổng hợp): mode 'practice'
    // Không dùng 'mock_exam' để tránh bị ghi nhận nhầm vào Lịch sử thi thử THPT truyền thống
    final String mode = task.type == AdaptiveTaskType.wrongBookReview
        ? 'wrong_review'
        : 'practice';

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PracticeQuizScreen(
          title: task.title,
          questions: task.questions,
          mode: mode,
        ),
      ),
    );

    // Khi người dùng hoàn thành bài làm hoặc thoát bài quay lại PracticeScreen:
    // Tự động tải lại dữ liệu SQLite mới nhất để cập nhật lại hồ sơ năng lực và nhiệm vụ!
    if (!mounted) return;
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    'Đang phân tích năng lực và sinh lộ trình...',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.error.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: colorScheme.error,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Thử lại'),
              ),
            ),
          ],
        ),
      );
    }

    if (_data == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.inbox_outlined, color: colorScheme.outline),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Chưa có dữ liệu câu hỏi trong ngân hàng đề.'),
            ),
          ],
        ),
      );
    }

    final profile = _data!.profile;
    final plan = _data!.plan;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Thẻ Hồ sơ Năng lực Thích ứng
        _buildProfileCard(context, profile),

        const SizedBox(height: 16),

        // 2. Danh sách Nhiệm vụ Cá nhân hóa
        if (plan.hasTasks) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Nhiệm vụ đề xuất hôm nay',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${plan.tasks.length} nhiệm vụ',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...plan.tasks.map((task) => _buildTaskCard(context, task)),
        ],
      ],
    );
  }

  /// Thẻ tổng quan Hồ sơ năng lực học sinh
  Widget _buildProfileCard(
    BuildContext context,
    AdaptiveStudentProfile profile,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final hasHistory = profile.hasAnyHistory;
    final weakness = profile.primaryWeakness;
    final overallScore = profile.overallMastery.toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.psychology_rounded,
                  color: colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lộ trình thích ứng cá nhân hóa',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Phân tích năng lực cục bộ theo 8 chuyên đề',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
                child: Text(
                  'Offline',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.outline,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Chỉ số năng lực tổng hợp
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text.rich(
                  TextSpan(
                    text: 'Thành thạo: ',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    children: [
                      TextSpan(
                        text: '$overallScore/100',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                hasHistory
                    ? 'Đã làm ${profile.totalQuestionsDone} câu'
                    : 'Chưa có lịch sử làm bài',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Tóm tắt trọng tâm cải thiện hoặc thông báo khảo sát
          if (weakness != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_rounded,
                    size: 16,
                    color: Colors.orange.shade800,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cần tập trung: ${weakness.typeTitle} (Độ chính xác: ${weakness.rawAccuracy.toStringAsFixed(0)}% — Điểm thành thạo: ${weakness.masteryScore.toStringAsFixed(0)})',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.explore_outlined,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hasHistory
                          ? 'Đang tiếp tục khảo sát năng lực các chuyên đề còn lại'
                          : 'Bắt đầu các bài luyện bên dưới để hệ thống nhận diện điểm mạnh và điểm yếu của bạn',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),
          Text(
            '* Đánh giá được tính toán cục bộ offline từ lịch sử bằng mô hình mượt Bayes, không sử dụng dịch vụ AI trực tuyến.',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.outline,
              fontStyle: FontStyle.italic,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Thẻ hiển thị một nhiệm vụ cá nhân hóa cụ thể
  Widget _buildTaskCard(BuildContext context, AdaptiveTask task) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final badgeInfo = _getBadgeInfo(task.type);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.7),
          width: 1.1,
        ),
      ),
      color: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hàng Header: Huy hiệu loại nhiệm vụ + Số câu thực tế
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: badgeInfo.color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: badgeInfo.color.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(badgeInfo.icon, size: 13, color: badgeInfo.color),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            badgeInfo.label,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: badgeInfo.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${task.questionCount} câu hỏi',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Tiêu đề và mô tả nhiệm vụ
            Text(
              task.title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              task.subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),

            // Hộp giải thích lý do đề xuất
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.35,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      task.reasoning,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11.5,
                        color: colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Nút Bắt đầu luyện tập
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: task.isValid ? () => _startTask(task) : null,
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Bắt đầu luyện tập'),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Thông tin huy hiệu thị giác theo loại nhiệm vụ
  _BadgeInfo _getBadgeInfo(AdaptiveTaskType type) {
    switch (type) {
      case AdaptiveTaskType.weaknessRemediation:
        return _BadgeInfo(
          label: 'Cải thiện điểm yếu',
          color: Colors.red.shade700,
          icon: Icons.track_changes_rounded,
        );
      case AdaptiveTaskType.surveyUnassessed:
        return _BadgeInfo(
          label: 'Khảo sát năng lực',
          color: Colors.blue.shade700,
          icon: Icons.radar_rounded,
        );
      case AdaptiveTaskType.skillReinforcement:
        return _BadgeInfo(
          label: 'Củng cố chuyên đề',
          color: Colors.teal.shade700,
          icon: Icons.trending_up_rounded,
        );
      case AdaptiveTaskType.wrongBookReview:
        return _BadgeInfo(
          label: 'Ôn tập câu sai',
          color: Colors.amber.shade900,
          icon: Icons.bookmark_border_rounded,
        );
      case AdaptiveTaskType.masteryMaintenance:
        return _BadgeInfo(
          label: 'Duy trì phong độ',
          color: Colors.green.shade700,
          icon: Icons.verified_rounded,
        );
      case AdaptiveTaskType.comprehensiveCheck:
        return _BadgeInfo(
          label: 'Kiểm tra tổng hợp',
          color: Colors.purple.shade700,
          icon: Icons.assignment_outlined,
        );
    }
  }
}

class _BadgeInfo {
  final String label;
  final Color color;
  final IconData icon;

  const _BadgeInfo({
    required this.label,
    required this.color,
    required this.icon,
  });
}
