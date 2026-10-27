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
/// Thiết kế UI/UX Refinement: Tối giản, tập trung hành động nhanh, không gây quá tải thông tin.
class AdaptiveLearningSection extends StatefulWidget {
  const AdaptiveLearningSection({super.key});

  @override
  State<AdaptiveLearningSection> createState() =>
      AdaptiveLearningSectionState();
}

class AdaptiveLearningSectionState extends State<AdaptiveLearningSection> {
  bool _isLoading = true;
  bool _isFetching = false;
  bool _hasPendingRefresh = false;
  String? _errorMessage;
  _AdaptiveData? _data;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Làm mới lại dữ liệu từ SQLite (ví dụ khi quay về từ màn hình làm bài)
  void reload() {
    _loadData(showLoadingState: false);
  }

  /// Tải dữ liệu thực tế từ SQLite qua AppRepository và tính toán lộ trình thích ứng
  Future<void> _loadData({bool showLoadingState = true}) async {
    if (!mounted) return;

    if (_isFetching) {
      // Đang có lượt nạp chạy: ghi nhớ yêu cầu làm mới để kích hoạt ngay khi xong
      _hasPendingRefresh = true;
      return;
    }

    _isFetching = true;

    if (showLoadingState && _data == null) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

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
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Không thể tải lộ trình học tập: $e';
        _isLoading = false;
      });
    } finally {
      _isFetching = false;
      if (_hasPendingRefresh && mounted) {
        _hasPendingRefresh = false;
        _loadData(showLoadingState: false);
      }
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
    _loadData(showLoadingState: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Center(
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
                  'Đang chuẩn bị bài luyện cho bạn...',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
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
            const Expanded(child: Text('Chưa có câu hỏi trong ngân hàng đề.')),
          ],
        ),
      );
    }

    final profile = _data!.profile;
    final plan = _data!.plan;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. KHU VỰC "HÔM NAY HỌC GÌ?" (Hero Focus Card)
        _buildHeroCard(context, profile, plan),

        const SizedBox(height: 18),

        // 2. KHU VỰC "LỘ TRÌNH CỦA BẠN" (Tối đa 3 nhiệm vụ)
        if (plan.hasTasks) ...[
          _buildLearningPathSection(context, plan),
          const SizedBox(height: 18),
        ],

        // 3. KHU VỰC "TIẾN BỘ CỦA TÔI" (Chỉ hiển thị khi có dữ liệu thật)
        _buildProgressSection(context, profile),
      ],
    );
  }

  // ===========================================================================
  // 1. KHU VỰC: "HÔM NAY HỌC GÌ?" (Hero Focus Card)
  // ===========================================================================
  Widget _buildHeroCard(
    BuildContext context,
    AdaptiveStudentProfile profile,
    AdaptiveLearningPlan plan,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (!plan.hasTasks) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Bạn đã hoàn thành các bài tập đề xuất hôm nay!'),
            ),
          ],
        ),
      );
    }

    final heroTask = plan.tasks.first;
    final isColdStart = !profile.hasAnyHistory;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.25),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nhãn tiêu đề khu vực & Badge loại bài
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'HÔM NAY HỌC GÌ?',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (!isColdStart)
                Text(
                  '${heroTask.questionCount} câu hỏi',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Tiêu đề gợi ý ngắn gọn
          if (isColdStart) ...[
            Text(
              'Bắt đầu khám phá trình độ của bạn',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Làm nhanh ${heroTask.questionCount} câu để ứng dụng nắm bắt năng lực và đề xuất lộ trình phù hợp.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ] else ...[
            Text(
              heroTask.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              heroTask.subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Nút hành động chính (Chạm là học ngay)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: () => _startTask(heroTask),
              icon: const Icon(Icons.play_arrow_rounded, size: 22),
              label: Text(
                isColdStart ? 'Bắt đầu' : 'Học ngay',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. KHU VỰC: "LỘ TRÌNH CỦA BẠN" (Danh sách 3 nhiệm vụ ngắn gọn)
  // ===========================================================================
  Widget _buildLearningPathSection(
    BuildContext context,
    AdaptiveLearningPlan plan,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Lộ trình của bạn',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            Text(
              '${plan.tasks.length} nhiệm vụ',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.outline,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Danh sách thẻ nhiệm vụ tinh giản
        ...plan.tasks.map((task) => _buildSimpleTaskCard(context, task)),
      ],
    );
  }

  Widget _buildSimpleTaskCard(BuildContext context, AdaptiveTask task) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final badge = _getBadgeInfo(task.type);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      color: colorScheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: task.isValid ? () => _startTask(task) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Icon đại diện loại nhiệm vụ
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: badge.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(badge.icon, color: badge.color, size: 20),
              ),
              const SizedBox(width: 12),

              // Tiêu đề & Thông số ngắn
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${task.questionCount} câu',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: badge.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badge.label,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: badge.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Nút "Vì sao?" (Mở BottomSheet giải thích lý do thật)
              IconButton(
                icon: Icon(
                  Icons.help_outline_rounded,
                  size: 20,
                  color: colorScheme.outline,
                ),
                tooltip: 'Vì sao đề xuất?',
                onPressed: () => _showReasoningBottomSheet(context, task),
              ),

              // Icon mũi tên chuyển tiếp
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.outlineVariant,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 3. KHU VỰC: "TIẾN BỘ CỦA TÔI" (Chỉ hiện khi có đủ dữ liệu xác thực)
  // ===========================================================================
  Widget _buildProgressSection(
    BuildContext context,
    AdaptiveStudentProfile profile,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Kiểm tra xem đã có dạng bài nào thoát khỏi insufficientData hay chưa
    final hasAssessedSkills = profile.skills.any((s) => s.hasSufficientData);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                'Tiến bộ của tôi',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (hasAssessedSkills)
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => _showProgressDetails(context, profile),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Xem chi tiết',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (!hasAssessedSkills) ...[
            // Trạng thái chưa đủ dữ liệu: KHÔNG HIỂN THỊ ĐIỂM 50/100 MẶC ĐỊNH
            Row(
              children: [
                Icon(
                  Icons.insights_rounded,
                  size: 22,
                  color: colorScheme.outline,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Đang khảo sát năng lực',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        profile.totalQuestionsDone > 0
                            ? 'Đã làm ${profile.totalQuestionsDone} câu. Cần thêm bài làm để đánh giá chính xác.'
                            : 'Hãy hoàn thành bài luyện đầu tiên để hệ thống đánh giá trình độ của bạn.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ] else ...[
            // Đã có dữ liệu xác thực
            Row(
              children: [
                // Điểm năng lực ước tính
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text.rich(
                    TextSpan(
                      text: profile.overallMastery.toStringAsFixed(0),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                      children: [
                        TextSpan(
                          text: ' / 100',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Thông điệp ngắn dễ hiểu
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.primaryWeakness != null
                            ? 'Cần tập trung: ${profile.primaryWeakness!.typeTitle}'
                            : (profile.overallMastery >= 75
                                  ? 'Năng lực tiếng Anh rất vững vàng'
                                  : 'Đang duy trì tiến độ học tốt'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Đã hoàn thành ${profile.totalQuestionsDone} câu hỏi',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Thanh tiến độ trực quan
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (profile.overallMastery / 100.0).clamp(0.0, 1.0),
                minHeight: 5,
                backgroundColor: colorScheme.surfaceContainerHighest,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // 4. BOTTOM SHEET: "VÌ SAO ĐỀ XUẤT?"
  // ===========================================================================
  void _showReasoningBottomSheet(BuildContext context, AdaptiveTask task) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Icon(
                      Icons.help_outline_rounded,
                      color: colorScheme.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Vì sao đề xuất bài này?',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Tên bài
                Text(
                  task.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),

                // Lời giải thích thực tế từ task.reasoning
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.4,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    task.reasoning,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Nút Bắt đầu làm ngay trong sheet
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _startTask(task);
                    },
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text(
                      'Bắt đầu luyện tập',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // 5. BOTTOM SHEET: "CHI TIẾT TIẾN BỘ 8 CHUYÊN ĐỀ"
  // ===========================================================================
  void _showProgressDetails(
    BuildContext context,
    AdaptiveStudentProfile profile,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (_, scrollController) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Chi tiết năng lực 8 dạng bài',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(height: 1),
                    const SizedBox(height: 8),

                    Expanded(
                      child: ListView.separated(
                        controller: scrollController,
                        itemCount: profile.skills.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (_, index) {
                          final skill = profile.skills[index];
                          final statusText = _getSkillStatusText(skill.level);

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        skill.typeTitle,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        skill.totalAttempts > 0
                                            ? 'Đúng ${skill.totalCorrect}/${skill.totalAttempts} câu (${skill.rawAccuracy.toStringAsFixed(0)}%)'
                                            : 'Chưa làm câu nào',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    statusText,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 8),
                    Text(
                      '* Đánh giá được tính toán nội bộ từ lịch sử làm bài thực tế của bạn.',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.outline,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _getSkillStatusText(AdaptiveSkillLevel level) {
    switch (level) {
      case AdaptiveSkillLevel.weak:
        return 'Cần cải thiện';
      case AdaptiveSkillLevel.moderate:
        return 'Trung bình';
      case AdaptiveSkillLevel.strong:
        return 'Vững vàng';
      case AdaptiveSkillLevel.insufficientData:
        return 'Đang khảo sát';
    }
  }

  /// Thông tin huy hiệu thị giác theo loại nhiệm vụ
  _BadgeInfo _getBadgeInfo(AdaptiveTaskType type) {
    switch (type) {
      case AdaptiveTaskType.weaknessRemediation:
        return _BadgeInfo(
          label: 'Cần cải thiện',
          color: Colors.red.shade700,
          icon: Icons.track_changes_rounded,
        );
      case AdaptiveTaskType.surveyUnassessed:
        return _BadgeInfo(
          label: 'Khảo sát',
          color: Colors.blue.shade700,
          icon: Icons.radar_rounded,
        );
      case AdaptiveTaskType.skillReinforcement:
        return _BadgeInfo(
          label: 'Củng cố',
          color: Colors.teal.shade700,
          icon: Icons.trending_up_rounded,
        );
      case AdaptiveTaskType.wrongBookReview:
        return _BadgeInfo(
          label: 'Ôn câu sai',
          color: Colors.amber.shade900,
          icon: Icons.bookmark_border_rounded,
        );
      case AdaptiveTaskType.masteryMaintenance:
        return _BadgeInfo(
          label: 'Duy trì',
          color: Colors.green.shade700,
          icon: Icons.verified_rounded,
        );
      case AdaptiveTaskType.comprehensiveCheck:
        return _BadgeInfo(
          label: 'Tổng hợp',
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
