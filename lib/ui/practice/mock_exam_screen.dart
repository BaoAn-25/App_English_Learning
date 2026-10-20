import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_repository.dart';
import '../../data/models/question.dart';
import 'mock_exam_history_screen.dart';
import 'mock_exam_quiz_screen.dart';

class MockExamScreen extends StatefulWidget {
  const MockExamScreen({super.key});

  @override
  State<MockExamScreen> createState() => _MockExamScreenState();
}

class _MockExamMode {
  final String title;
  final String subtitle;
  final int questionCount;
  final int durationMinutes;
  final IconData icon;
  final String tag;

  const _MockExamMode({
    required this.title,
    required this.subtitle,
    required this.questionCount,
    required this.durationMinutes,
    required this.icon,
    required this.tag,
  });
}

class _MockExamScreenState extends State<MockExamScreen> {
  late Future<List<Question>> questionsFuture;

  static const List<_MockExamMode> examModes = [
    _MockExamMode(
      title: 'Thi nhanh',
      subtitle: 'Ôn tập nhanh từ vựng, ngữ pháp và phản xạ cốt lõi',
      questionCount: 10,
      durationMinutes: 10,
      icon: Icons.bolt_rounded,
      tag: '10 câu / 10 phút',
    ),
    _MockExamMode(
      title: 'Thi thử rút gọn',
      subtitle: 'Rèn luyện tốc độ làm bài và đánh giá năng lực vừa phải',
      questionCount: 20,
      durationMinutes: 20,
      icon: Icons.timer_outlined,
      tag: '20 câu / 20 phút',
    ),
    _MockExamMode(
      title: 'Thi thử THPT',
      subtitle: 'Mô phỏng đầy đủ cấu trúc và thời gian thi tốt nghiệp THPT',
      questionCount: 50,
      durationMinutes: 60,
      icon: Icons.school_rounded,
      tag: '50 câu / 60 phút',
    ),
  ];

  int selectedModeIndex = 0;

  _MockExamMode get selectedMode => examModes[selectedModeIndex];

  @override
  void initState() {
    super.initState();
    questionsFuture = context.read<AppRepository>().getQuestionsByGrade(12);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Thi thử THPT')),
      body: FutureBuilder<List<Question>>(
        future: questionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Không thể tải câu hỏi: ${snapshot.error}'),
            );
          }

          final questions = snapshot.data ?? [];
          final currentMode = selectedMode;
          final canStart = questions.length >= currentMode.questionCount;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Biểu tượng Hero học thuật
                Center(
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(
                        alpha: 0.6,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.school_rounded,
                      size: 46,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'Thi thử tiếng Anh THPT',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Đề thi mô phỏng định dạng tốt nghiệp THPT Quốc gia',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),

                // Lựa chọn chế độ thi
                Row(
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Chọn chế độ thi',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Danh sách 3 chế độ thi
                ...List.generate(examModes.length, (index) {
                  final mode = examModes[index];
                  final isSelected = selectedModeIndex == index;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: isSelected
                          ? colorScheme.primaryContainer.withValues(alpha: 0.28)
                          : colorScheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.outlineVariant.withValues(
                                  alpha: 0.6,
                                ),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            selectedModeIndex = index;
                          });
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              // Icon tròn chế độ
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? colorScheme.primary
                                      : colorScheme.surfaceContainerHighest,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  mode.icon,
                                  size: 22,
                                  color: isSelected
                                      ? colorScheme.onPrimary
                                      : colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Thông tin chế độ
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            mode.title,
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: isSelected
                                                      ? colorScheme.primary
                                                      : colorScheme.onSurface,
                                                ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? colorScheme.primary
                                                      .withValues(alpha: 0.15)
                                                : colorScheme
                                                      .surfaceContainerHighest,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            mode.tag,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isSelected
                                                  ? colorScheme.primary
                                                  : colorScheme
                                                        .onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      mode.subtitle,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),

                              // Chỉ báo chọn (Radio indicator)
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? colorScheme.primary
                                        : colorScheme.outline,
                                    width: 2,
                                  ),
                                ),
                                child: isSelected
                                    ? Center(
                                        child: Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: colorScheme.primary,
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 14),

                // Card thông số đề thi
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.45,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Thông số phòng thi',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _buildParamTile(
                              context,
                              icon: Icons.quiz_outlined,
                              label: 'Số câu hỏi',
                              value: '${currentMode.questionCount} câu',
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 38,
                            color: colorScheme.outlineVariant,
                          ),
                          Expanded(
                            child: _buildParamTile(
                              context,
                              icon: Icons.timer_outlined,
                              label: 'Thời gian',
                              value: '${currentMode.durationMinutes} phút',
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 38,
                            color: colorScheme.outlineVariant,
                          ),
                          Expanded(
                            child: _buildParamTile(
                              context,
                              icon: Icons.inventory_2_outlined,
                              label: 'Ngân hàng',
                              value: '${questions.length} câu',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Card lưu ý phòng thi
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Quy chế thi',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildRuleRow(
                        context,
                        'Đồng hồ đếm ngược tự động nộp bài khi hết thời gian quy định.',
                      ),
                      const SizedBox(height: 6),
                      _buildRuleRow(
                        context,
                        'Kết quả và đáp án chi tiết sẽ hiển thị ngay sau khi nộp bài.',
                      ),
                      const SizedBox(height: 6),
                      _buildRuleRow(
                        context,
                        'Nếu thoát giữa chừng, bài làm hiện tại sẽ không được lưu.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                if (!canStart) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.orange.shade800,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Ngân hàng hiện có ${questions.length} câu, chưa đủ ${currentMode.questionCount} câu để tạo đề thi chế độ này.',
                            style: TextStyle(
                              color: Colors.orange.shade900,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                FilledButton.icon(
                  onPressed: canStart
                      ? () {
                          final examQuestions = List<Question>.from(questions)
                            ..shuffle();

                          final selectedQuestions = examQuestions
                              .take(currentMode.questionCount)
                              .toList();

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MockExamQuizScreen(
                                questions: selectedQuestions,
                                durationMinutes: currentMode.durationMinutes,
                              ),
                            ),
                          );
                        }
                      : null,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    'Bắt đầu làm bài (${currentMode.questionCount} câu)',
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 12),

                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MockExamHistoryScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.history_rounded),
                  label: const Text('Xem lịch sử thi thử'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildParamTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: colorScheme.primary),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRuleRow(BuildContext context, String text) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
