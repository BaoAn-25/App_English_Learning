import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_repository.dart';
import '../../data/models/question.dart';
import '../../data/models/wrong_book_entry.dart';
import 'practice_quiz_screen.dart';
import 'widgets/question_stem_view.dart';

class WrongBookScreen extends StatefulWidget {
  const WrongBookScreen({super.key});

  @override
  State<WrongBookScreen> createState() => _WrongBookScreenState();
}

class _WrongBookScreenState extends State<WrongBookScreen> {
  late Future<List<_WrongQuestion>> wrongQuestionsFuture;

  bool showDueOnly = false;

  @override
  void initState() {
    super.initState();
    loadWrongQuestions();
  }

  void loadWrongQuestions() {
    wrongQuestionsFuture = fetchWrongQuestions();
  }

  Future<List<_WrongQuestion>> fetchWrongQuestions() async {
    final repository = context.read<AppRepository>();

    final entries = await repository.getAllWrongBookEntries();
    final questions = await repository.getAllQuestions();

    final questionMap = {
      for (final question in questions) question.id: question,
    };

    final result = <_WrongQuestion>[];

    for (final entry in entries) {
      final question = questionMap[entry.questionId];

      if (question != null) {
        result.add(_WrongQuestion(question: question, entry: entry));
      }
    }

    result.sort((a, b) => b.entry.wrongCount.compareTo(a.entry.wrongCount));

    return result;
  }

  void refresh() {
    setState(() {
      loadWrongQuestions();
    });
  }

  Future<void> startWrongPractice(
    List<_WrongQuestion> items,
    String title,
  ) async {
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có câu hỏi để luyện tập.')),
      );
      return;
    }

    final questions = items.map((item) => item.question).toList();

    questions.shuffle();

    final quizQuestions = questions.take(10).toList();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PracticeQuizScreen(
          title: title,
          questions: quizQuestions,
          mode: 'wrong_review',
        ),
      ),
    );

    if (!mounted) return;

    refresh();
  }

  String formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);

    String twoDigits(int value) => value.toString().padLeft(2, '0');

    return '${twoDigits(date.day)}/'
        '${twoDigits(date.month)}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sổ câu sai'),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<_WrongQuestion>>(
        future: wrongQuestionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Không thể tải sổ câu sai: ${snapshot.error}'),
            );
          }

          final allItems = snapshot.data ?? [];
          final now = DateTime.now().millisecondsSinceEpoch;

          final dueCount = allItems
              .where((item) => item.entry.nextReviewAt <= now)
              .length;

          final visibleItems = showDueOnly
              ? allItems
                    .where((item) => item.entry.nextReviewAt <= now)
                    .toList()
              : allItems;

          final dueItems = allItems
              .where((item) => item.entry.nextReviewAt <= now)
              .toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              // Thống kê 2 khối tổng quan
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 14,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.45,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.bookmark_border_rounded,
                                size: 20,
                                color: colorScheme.primary,
                              ),
                              const Spacer(),
                              Text(
                                '${allItems.length}',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tổng câu đã sai',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 14,
                      ),
                      decoration: BoxDecoration(
                        color: dueCount > 0
                            ? Colors.orange.withValues(alpha: 0.1)
                            : colorScheme.surfaceContainerHighest.withValues(
                                alpha: 0.45,
                              ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: dueCount > 0
                              ? Colors.orange.withValues(alpha: 0.5)
                              : colorScheme.outlineVariant.withValues(
                                  alpha: 0.6,
                                ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.alarm_on_rounded,
                                size: 20,
                                color: dueCount > 0
                                    ? Colors.orange.shade800
                                    : colorScheme.outline,
                              ),
                              const Spacer(),
                              Text(
                                '$dueCount',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: dueCount > 0
                                      ? Colors.orange.shade800
                                      : colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Câu đến hạn ôn',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Các nút hành động luyện tập
              FilledButton(
                onPressed: allItems.isEmpty
                    ? null
                    : () => startWrongPractice(allItems, 'Luyện lại câu sai'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.play_arrow_rounded),
                      const SizedBox(width: 8),
                      Text('Luyện lại tất cả câu sai (${allItems.length})'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              FilledButton.tonal(
                onPressed: dueItems.isEmpty
                    ? null
                    : () => startWrongPractice(
                        dueItems,
                        'Ôn tập câu sai đến hạn',
                      ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.event_available_rounded),
                      const SizedBox(width: 8),
                      Text('Luyện câu đến hạn ôn (${dueItems.length})'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Bộ lọc: Chỉ hiện câu đến hạn ôn
              Card(
                elevation: 0,
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
                child: SwitchListTile(
                  secondary: Icon(
                    Icons.filter_list_rounded,
                    color: colorScheme.primary,
                  ),
                  title: const Text('Chỉ hiện câu đến hạn ôn'),
                  subtitle: const Text(
                    'Lọc câu cần củng cố theo chu kỳ ngắt quãng',
                  ),
                  value: showDueOnly,
                  onChanged: (value) {
                    setState(() {
                      showDueOnly = value;
                    });
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Trạng thái trống
              if (allItems.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 64,
                          color: Colors.green.shade600,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Sổ câu sai trống!',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Bạn chưa có câu nào bị sai. Tiếp tục phát huy nhé!',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (visibleItems.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.event_available_rounded,
                          size: 60,
                          color: colorScheme.outline,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Không có câu nào đến hạn ôn tập lúc này.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Danh sách các câu hỏi sai
              ...visibleItems.map((item) {
                final question = item.question;
                final entry = item.entry;
                final isDue = entry.nextReviewAt <= now;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ExpansionTile(
                    title: QuestionStemView(
                      stem: question.stem,
                      type: question.type,
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Sai ${entry.wrongCount} lần',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isDue
                                  ? Colors.orange.withValues(alpha: 0.15)
                                  : Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isDue ? 'Đến hạn ôn' : 'Chưa đến hạn',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: isDue
                                    ? Colors.orange.shade800
                                    : Colors.green.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    children: [
                      const Divider(height: 1),
                      const SizedBox(height: 12),

                      // Danh sách đáp án của câu hỏi
                      ...List.generate(question.options.length, (index) {
                        final isCorrect = index == question.correctIndex;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isCorrect
                                ? Colors.green.withValues(alpha: 0.1)
                                : colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isCorrect
                                  ? Colors.green.withValues(alpha: 0.5)
                                  : colorScheme.outlineVariant.withValues(
                                      alpha: 0.4,
                                    ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isCorrect
                                    ? Icons.check_circle_rounded
                                    : Icons.circle_outlined,
                                size: 18,
                                color: isCorrect
                                    ? Colors.green
                                    : colorScheme.outline,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${String.fromCharCode(65 + index)}. '
                                  '${question.options[index]}',
                                  style: TextStyle(
                                    fontWeight: isCorrect
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isCorrect
                                        ? Colors.green.shade800
                                        : colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 10),

                      // Giải thích
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.lightbulb_rounded,
                              size: 18,
                              color: Colors.amber.shade800,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Giải thích: ${question.explanation}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Metadata thời gian
                      Row(
                        children: [
                          Icon(
                            Icons.history_rounded,
                            size: 15,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Sai gần nhất: ${formatDate(entry.lastWrongAt)}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.update_rounded,
                            size: 15,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Ôn tiếp: ${formatDate(entry.nextReviewAt)}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
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

class _WrongQuestion {
  final Question question;
  final WrongBookEntry entry;

  const _WrongQuestion({required this.question, required this.entry});
}
