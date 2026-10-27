import 'package:flutter/material.dart';

import '../services/exam_diagnostic_service.dart';

/// Widget hiển thị biểu đồ thanh ngang phân tích kết quả theo dạng bài
/// và đề xuất dạng bài cần ưu tiên luyện tập thêm.
class ExamDiagnosticCard extends StatelessWidget {
  final ExamDiagnosticResult diagnostic;

  /// Callback khi người dùng nhấn nút "Luyện tập dạng bài này"
  final Future<void> Function(String type, String typeTitle)? onStartRemediation;

  const ExamDiagnosticCard({
    super.key,
    required this.diagnostic,
    this.onStartRemediation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (!diagnostic.hasData) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: colorScheme.outline),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Không có dữ liệu phân tích dạng bài.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Card Biểu đồ thanh ngang phân tích theo dạng bài
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.7),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.bar_chart_rounded,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Phân tích theo dạng bài',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Tỷ lệ trả lời đúng theo từng chuyên đề trong đề thi',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 14),

              // Danh sách từng dạng bài
              ...diagnostic.breakdown.map((item) {
                final accuracy = item.accuracy;
                final barColor = accuracy >= 80
                    ? Colors.green.shade600
                    : (accuracy >= 50
                        ? Colors.orange.shade600
                        : Colors.red.shade600);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              item.typeTitle,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${item.correct}/${item.total} câu (${accuracy.toStringAsFixed(0)}%)',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: barColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: accuracy / 100,
                          minHeight: 7,
                          backgroundColor:
                              colorScheme.outlineVariant.withValues(alpha: 0.3),
                          valueColor: AlwaysStoppedAnimation<Color>(barColor),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 2. Card Đề xuất cải thiện điểm yếu hoặc Chúc mừng điểm tuyệt đối
        if (diagnostic.isPerfectScore)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.green.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.verified_rounded,
                  color: Colors.green.shade700,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Xuất sắc! Điểm số tuyệt đối',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Bạn đã trả lời chính xác tất cả câu hỏi trong mọi dạng bài. Hãy duy trì phong độ này cho kỳ thi chính thức!',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.green.shade900,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else if (diagnostic.weakestType != null) ...[
          _buildWeaknessCard(context, diagnostic.weakestType!),
        ],
      ],
    );
  }

  Widget _buildWeaknessCard(BuildContext context, TypePerformance weakest) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isSmall = weakest.isSmallSample;
    final titleText = 'Điểm cần cải thiện: ${weakest.typeTitle}';
    final explanationText = isSmall
        ? 'Dạng bài này đạt ${weakest.accuracy.toStringAsFixed(0)}% (${weakest.correct}/${weakest.total} câu). Số lượng câu trong đề ít (${weakest.total} câu), hãy luyện tập thêm để đánh giá chuẩn xác hơn.'
        : 'Dạng bài này đạt ${weakest.accuracy.toStringAsFixed(0)}% (${weakest.correct}/${weakest.total} câu), thấp nhất trong đề thi. Tập trung ôn luyện chuyên đề này sẽ giúp bạn bứt phá điểm số nhanh nhất!';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_rounded,
                color: Colors.orange.shade800,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  titleText,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            explanationText,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.orange.shade900,
              height: 1.35,
            ),
          ),
          if (onStartRemediation != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => onStartRemediation!(
                  weakest.type,
                  weakest.typeTitle,
                ),
                icon: const Icon(Icons.fitness_center_rounded, size: 18),
                label: Text('Luyện tập ngay dạng ${weakest.typeTitle}'),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
