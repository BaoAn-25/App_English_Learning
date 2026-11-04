import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_repository.dart';
import '../../data/models/attempt.dart';
import 'practice_review_screen.dart';

class PracticeHistoryScreen extends StatefulWidget {
  final String type;
  final String title;

  const PracticeHistoryScreen({
    super.key,
    required this.type,
    required this.title,
  });

  @override
  State<PracticeHistoryScreen> createState() => _PracticeHistoryScreenState();
}

class _PracticeHistoryScreenState extends State<PracticeHistoryScreen> {
  late Future<List<Attempt>> historyFuture;

  @override
  void initState() {
    super.initState();
    loadHistory();
  }

  void loadHistory() {
    historyFuture = context.read<AppRepository>().getAllAttempts().then(
      (attempts) => attempts.where((attempt) {
        return attempt.mode == 'practice' && attempt.type == widget.type;
      }).toList()..sort((a, b) => b.startedAt.compareTo(a.startedAt)),
    );
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
      appBar: AppBar(title: Text('Lịch sử ${widget.title}')),
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

          final attempts = snapshot.data ?? [];

          if (attempts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.history_toggle_off_rounded,
                      size: 64,
                      color: colorScheme.outline,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Chưa có lịch sử làm bài',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Hãy bắt đầu luyện tập dạng ${widget.title} để ghi nhận kết quả tại đây.',
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
            itemCount: attempts.length,
            itemBuilder: (context, index) {
              final attempt = attempts[index];
              final accuracy = attempt.total == 0
                  ? 0.0
                  : attempt.score / attempt.total * 100;

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
                  onTap: attempt.id == null
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  PracticeReviewScreen(attempt: attempt),
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
                            '${attempt.score}/${attempt.total}',
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
                                '${attempt.score}/${attempt.total} câu đúng',
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
                                  Expanded(
                                    child: Text(
                                      formatDate(attempt.startedAt),
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
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
                                      'Chính xác: ${accuracy.toStringAsFixed(0)}%',
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
                                    formatDuration(attempt.durationSec),
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
