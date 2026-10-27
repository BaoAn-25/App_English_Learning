import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_repository.dart';
import '../../data/models/attempt.dart';
import 'practice_review_screen.dart';

class MockExamHistoryScreen extends StatefulWidget {
  const MockExamHistoryScreen({super.key});

  @override
  State<MockExamHistoryScreen> createState() => _MockExamHistoryScreenState();
}

class _MockExamHistoryScreenState extends State<MockExamHistoryScreen> {
  late Future<List<Attempt>> historyFuture;

  @override
  void initState() {
    super.initState();
    historyFuture = loadHistory();
  }

  Future<List<Attempt>> loadHistory() async {
    final repository = context.read<AppRepository>();
    final attempts = await repository.getAllAttempts();

    final exams = attempts
        .where((attempt) => attempt.mode == 'mock_exam')
        .toList();

    exams.sort((a, b) => b.startedAt.compareTo(a.startedAt));

    return exams;
  }

  String formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);

    String twoDigits(int value) => value.toString().padLeft(2, '0');

    return '${twoDigits(date.day)}/'
        '${twoDigits(date.month)}/${date.year} '
        '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
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

    return Scaffold(
      appBar: AppBar(title: const Text('Lịch sử thi thử')),
      body: FutureBuilder<List<Attempt>>(
        future: historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Không thể tải lịch sử: ${snapshot.error}'),
            );
          }

          final exams = snapshot.data ?? [];

          if (exams.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.assignment_late_outlined,
                      size: 64,
                      color: colorScheme.outline,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Chưa có lịch sử thi thử',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Hãy tham gia thi thử THPT để rèn luyện kỹ năng và xem lại tiến độ tại đây.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: exams.length,
            itemBuilder: (context, index) {
              final exam = exams[index];
              final accuracy = exam.total == 0
                  ? 0.0
                  : exam.score / exam.total * 100;

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
                color: colorScheme.surface,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: exam.id == null
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  PracticeReviewScreen(attempt: exam),
                            ),
                          );
                        },
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        // Huy hiệu điểm số
                        Container(
                          width: 52,
                          height: 52,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: accuracy >= 80
                                ? Colors.green.withValues(alpha: 0.15)
                                : (accuracy >= 50
                                      ? Colors.orange.withValues(alpha: 0.15)
                                      : Colors.red.withValues(alpha: 0.12)),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${exam.score}/${exam.total}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: accuracy >= 80
                                  ? Colors.green.shade800
                                  : (accuracy >= 50
                                        ? Colors.orange.shade800
                                        : Colors.red.shade700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Nội dung chi tiết
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Kết quả: ${exam.score}/${exam.total} câu đúng',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 14,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    formatDate(exam.startedAt),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: accuracy >= 80
                                          ? Colors.green.withValues(alpha: 0.12)
                                          : (accuracy >= 50
                                                ? Colors.orange.withValues(
                                                    alpha: 0.12,
                                                  )
                                                : Colors.red.withValues(
                                                    alpha: 0.12,
                                                  )),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Chính xác: ${accuracy.toStringAsFixed(1)}%',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                        color: accuracy >= 80
                                            ? Colors.green.shade800
                                            : (accuracy >= 50
                                                  ? Colors.orange.shade800
                                                  : Colors.red.shade700),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    formatDuration(exam.durationSec),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.outline,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 8),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: colorScheme.outline,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
