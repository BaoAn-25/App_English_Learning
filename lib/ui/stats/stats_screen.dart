import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_repository.dart';
import 'learning_summary.dart';

class StatsScreen extends StatefulWidget {
  final bool active;

  const StatsScreen({super.key, this.active = true});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  Future<LearningSummary>? _summary;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.active && _summary == null) _refresh();
  }

  @override
  void didUpdateWidget(StatsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _refresh();
  }

  void _refresh() {
    setState(() {
      _summary = context.read<AppRepository>().getAllDailyStats().then(
        (stats) => LearningSummary.fromStats(stats, now: DateTime.now()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thống kê tiến độ'),
        actions: [
          IconButton(
            onPressed: _refresh,
            tooltip: 'Làm mới thống kê',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<LearningSummary>(
          future: _summary,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Không tải được thống kê.'),
                    TextButton(
                      onPressed: _refresh,
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              );
            }
            final summary = snapshot.requireData;
            final maxQuestions = summary.week.fold<int>(
              1,
              (max, day) => day.questionsDone > max ? day.questionsDone : max,
            );
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Tổng quan học tập',
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 24),
                        Wrap(
                          spacing: 24,
                          runSpacing: 24,
                          children: [
                            _Metric(
                              label: 'Điểm tích lũy',
                              value: '${summary.totalXp} XP',
                            ),
                            _Metric(
                              label: 'Đã trả lời',
                              value: '${summary.totalQuestions} câu',
                            ),
                            _Metric(
                              label: 'Độ chính xác',
                              value: summary.accuracy == null
                                  ? '—'
                                  : '${(summary.accuracy! * 100).round()}%',
                            ),
                            _Metric(
                              label: 'Thời gian học',
                              value: '${summary.totalMinutes} phút',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          summary.totalQuestions == 0
                              ? 'Chưa có câu trả lời. Hãy bắt đầu một bài luyện tập.'
                              : '${summary.totalCorrect}/${summary.totalQuestions} câu trả lời đúng từ các bài đã lưu.',
                        ),
                        const SizedBox(height: 32),
                        Text(
                          '7 ngày gần nhất',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        const Text('Số câu đã trả lời mỗi ngày'),
                        const SizedBox(height: 16),
                        for (final day in summary.week)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Semantics(
                              label: '${day.date}: ${day.questionsDone} câu',
                              excludeSemantics: true,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    '${day.date.substring(8)}/${day.date.substring(5, 7)} · ${day.questionsDone} câu',
                                  ),
                                  const SizedBox(height: 8),
                                  LinearProgressIndicator(
                                    value: (day.questionsDone / maxQuestions)
                                        .clamp(0.0, 1.0),
                                    minHeight: 8,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 200,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.headlineSmall),
      ],
    ),
  );
}
