import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_repository.dart';
import '../../data/models/attempt.dart';
import '../../data/models/attempt_answer.dart';
import '../../data/models/question.dart';
import 'widgets/question_stem_view.dart';

class PracticeReviewScreen extends StatefulWidget {
  final Attempt attempt;

  const PracticeReviewScreen({super.key, required this.attempt});

  @override
  State<PracticeReviewScreen> createState() => _PracticeReviewScreenState();
}

class _PracticeReviewScreenState extends State<PracticeReviewScreen> {
  late Future<List<_ReviewItem>> reviewFuture;

  @override
  void initState() {
    super.initState();
    reviewFuture = loadReview();
  }

  Future<List<_ReviewItem>> loadReview() async {
    final repository = context.read<AppRepository>();
    final attemptId = widget.attempt.id;

    if (attemptId == null) {
      return [];
    }

    final answers = await repository.getAttemptAnswers(attemptId);
    final questions = await repository.getAllQuestions();

    final questionMap = {
      for (final question in questions) question.id: question,
    };

    return answers
        .where((answer) => questionMap.containsKey(answer.questionId))
        .map(
          (answer) => _ReviewItem(
            question: questionMap[answer.questionId]!,
            answer: answer,
          ),
        )
        .toList();
  }

  String answerLabel(Question question, int answerIndex) {
    if (answerIndex < 0 || answerIndex >= question.options.length) {
      return 'Chưa trả lời';
    }

    return '${String.fromCharCode(65 + answerIndex)}. '
        '${question.options[answerIndex]}';
  }

  String formatDuration(int sec) {
    if (sec >= 60) {
      final mins = sec ~/ 60;
      final remainingSecs = sec % 60;
      return '$mins phút $remainingSecs giây';
    }
    return '$sec giây';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final total = widget.attempt.total;
    final score = widget.attempt.score;
    final accuracy = total == 0 ? 0.0 : (score / total * 100);

    return Scaffold(
      appBar: AppBar(title: const Text('Xem lại bài làm')),
      body: FutureBuilder<List<_ReviewItem>>(
        future: reviewFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Không thể tải bài làm: ${snapshot.error}'),
            );
          }

          final items = snapshot.data ?? [];

          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.find_in_page_outlined,
                    size: 64,
                    color: colorScheme.outline,
                  ),
                  const SizedBox(height: 12),
                  const Text('Không tìm thấy chi tiết bài làm.'),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              // Card tổng kết bài làm
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.45,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.7),
                  ),
                ),
                child: Row(
                  children: [
                    // Điểm số nổi bật
                    Container(
                      width: 68,
                      height: 68,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$score/$total',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Thông tin phụ
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: accuracy >= 80
                                      ? Colors.green.withValues(alpha: 0.15)
                                      : (accuracy >= 50
                                            ? Colors.orange.withValues(
                                                alpha: 0.15,
                                              )
                                            : Colors.red.withValues(
                                                alpha: 0.15,
                                              )),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Chính xác: ${accuracy.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: accuracy >= 80
                                        ? Colors.green.shade700
                                        : (accuracy >= 50
                                              ? Colors.orange.shade800
                                              : Colors.red.shade700),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                size: 16,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Thời gian: ${formatDuration(widget.attempt.durationSec)}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Danh sách từng câu hỏi và giải thích
              ...List.generate(items.length, (index) {
                final item = items[index];
                final question = item.question;
                final answer = item.answer;
                final isUnanswered = answer.chosenIndex < 0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: answer.isCorrect
                            ? Colors.green.withValues(alpha: 0.4)
                            : Colors.red.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Hàng tiêu đề câu hỏi và trạng thái đúng/sai
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Câu ${index + 1}',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: answer.isCorrect
                                    ? Colors.green.withValues(alpha: 0.12)
                                    : (isUnanswered
                                          ? Colors.orange.withValues(
                                              alpha: 0.12,
                                            )
                                          : Colors.red.withValues(alpha: 0.12)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    answer.isCorrect
                                        ? Icons.check_circle_rounded
                                        : (isUnanswered
                                              ? Icons
                                                    .remove_circle_outline_rounded
                                              : Icons.cancel_rounded),
                                    size: 16,
                                    color: answer.isCorrect
                                        ? Colors.green.shade700
                                        : (isUnanswered
                                              ? Colors.orange.shade800
                                              : Colors.red.shade700),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    answer.isCorrect
                                        ? 'Chính xác'
                                        : (isUnanswered
                                              ? 'Bỏ trống'
                                              : 'Chưa đúng'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: answer.isCorrect
                                          ? Colors.green.shade700
                                          : (isUnanswered
                                                ? Colors.orange.shade800
                                                : Colors.red.shade700),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Thân câu hỏi định dạng thông minh
                        QuestionStemView(
                          stem: question.stem,
                          type: question.type,
                        ),
                        const SizedBox(height: 16),

                        // So sánh: Bạn chọn vs Đáp án đúng
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Bạn chọn
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Bạn chọn: ',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      answerLabel(question, answer.chosenIndex),
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: answer.isCorrect
                                                ? Colors.green.shade700
                                                : (isUnanswered
                                                      ? Colors.orange.shade800
                                                      : Colors.red.shade700),
                                          ),
                                    ),
                                  ),
                                ],
                              ),

                              // Đáp án đúng (nếu bạn chọn sai hoặc bỏ trống)
                              if (!answer.isCorrect) ...[
                                const SizedBox(height: 6),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Đáp án đúng: ',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        answerLabel(
                                          question,
                                          question.correctIndex,
                                        ),
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green.shade700,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Lời giải thích chi tiết
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.amber.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.lightbulb_rounded,
                                size: 20,
                                color: Colors.amber.shade800,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Giải thích:',
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.amber.shade900,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      question.explanation,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            height: 1.4,
                                            color: colorScheme.onSurface,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _ReviewItem {
  final Question question;
  final AttemptAnswer answer;

  const _ReviewItem({required this.question, required this.answer});
}
