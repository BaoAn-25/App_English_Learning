import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_repository.dart';
import '../../data/models/attempt.dart';
import '../../data/models/attempt_answer.dart';
import '../../data/models/daily_stat.dart';
import '../../data/models/question.dart';
import '../../data/models/wrong_book_entry.dart';
import 'practice_review_screen.dart';
import 'services/option_shuffler.dart';
import 'widgets/question_stem_view.dart';
import 'widgets/quiz_option_card.dart';

class MockExamQuizScreen extends StatefulWidget {
  final List<Question> questions;
  final int durationMinutes;

  /// Đồng hồ hệ thống (có thể thay thế khi kiểm thử đếm ngược).
  final DateTime Function()? clock;

  /// Ánh xạ thứ tự hiển thị phương án (tùy chọn, mặc định xáo trộn ngẫu nhiên).
  final List<QuestionOptionMapping>? optionMappings;

  const MockExamQuizScreen({
    super.key,
    required this.questions,
    required this.durationMinutes,
    this.clock,
    this.optionMappings,
  });

  @override
  State<MockExamQuizScreen> createState() => _MockExamQuizScreenState();
}

class _MockExamQuizScreenState extends State<MockExamQuizScreen> {
  late final List<int?> selectedAnswers;
  late final List<QuestionOptionMapping> optionMappings;
  late final DateTime startedAt;
  late final DateTime deadline;

  Timer? timer;

  DateTime _now() => (widget.clock ?? DateTime.now)();

  int currentIndex = 0;
  int remainingSeconds = 0;

  bool isSaving = false;
  bool submitted = false;
  bool isSubmitDialogOpen = false;
  Attempt? savedAttempt;
  int usedSeconds = 0;

  @override
  void initState() {
    super.initState();

    selectedAnswers = List<int?>.filled(widget.questions.length, null);

    startedAt = _now();

    deadline = startedAt.add(Duration(minutes: widget.durationMinutes));

    remainingSeconds = widget.durationMinutes * 60;

    timer = Timer.periodic(const Duration(seconds: 1), (_) => updateTimer());

    optionMappings = widget.optionMappings ??
        List.generate(
          widget.questions.length,
          (i) => QuestionOptionMapping.shuffled(
            widget.questions[i].options.length,
          ),
        );
  }

  void updateTimer() {
    if (!mounted || submitted || isSaving) return;

    final seconds = deadline.difference(_now()).inSeconds;

    if (seconds <= 0) {
      timer?.cancel();

      if (isSubmitDialogOpen) {
        isSubmitDialogOpen = false;
        Navigator.of(context, rootNavigator: true).pop();
      }

      setState(() {
        remainingSeconds = 0;
      });

      saveExamResult();
      return;
    }

    setState(() {
      remainingSeconds = seconds;
    });
  }

  int get score {
    int correct = 0;

    for (int i = 0; i < widget.questions.length; i++) {
      if (selectedAnswers[i] == widget.questions[i].correctIndex) {
        correct++;
      }
    }

    return correct;
  }

  int get answeredCount {
    return selectedAnswers.where((answer) => answer != null).length;
  }

  String get formattedTime {
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  void selectAnswer(int index) {
    if (submitted || isSaving) return;

    setState(() {
      selectedAnswers[currentIndex] = index;
    });
  }

  void nextQuestion() {
    if (currentIndex >= widget.questions.length - 1) {
      return;
    }

    setState(() {
      currentIndex++;
    });
  }

  void previousQuestion() {
    if (currentIndex <= 0) return;

    setState(() {
      currentIndex--;
    });
  }

  Future<void> confirmExitExam() async {
    if (isSaving || submitted) return;

    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Thoát bài thi?'),
          content: const Text(
            'Nếu thoát bây giờ, các đáp án đã chọn '
            'sẽ không được lưu. Bạn có chắc chắn '
            'muốn thoát không?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Tiếp tục làm bài'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Thoát bài thi'),
            ),
          ],
        );
      },
    );

    if (!mounted || isSaving || submitted) return;

    if (shouldExit == true) {
      timer?.cancel();
      Navigator.pop(context);
    }
  }

  Future<void> confirmSubmit() async {
    if (submitted || isSaving || isSubmitDialogOpen) return;

    isSubmitDialogOpen = true;

    final shouldSubmit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Nộp bài thi?'),
          content: Text(
            'Bạn đã trả lời $answeredCount/'
            '${widget.questions.length} câu.\n'
            'Bạn có chắc chắn muốn nộp bài?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Tiếp tục làm'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Nộp bài'),
            ),
          ],
        );
      },
    );

    isSubmitDialogOpen = false;

    if (!mounted || submitted || isSaving) return;

    if (shouldSubmit == true) {
      await saveExamResult();
    }
  }

  Future<void> saveExamResult() async {
    if (submitted || isSaving) return;

    timer?.cancel();

    setState(() {
      isSaving = true;
    });

    try {
      final repository = context.read<AppRepository>();
      final finishedAt = _now();

      final elapsedSeconds = finishedAt.difference(startedAt).inSeconds;

      final durationSec = elapsedSeconds.clamp(0, widget.durationMinutes * 60);
      usedSeconds = durationSec;

      final attempt = Attempt(
        mode: 'mock_exam',
        type: null,
        startedAt: startedAt.millisecondsSinceEpoch,
        durationSec: durationSec,
        score: score,
        total: widget.questions.length,
      );

      final wrongEntries = <WrongBookEntry>[];

      for (int i = 0; i < widget.questions.length; i++) {
        final question = widget.questions[i];
        final chosenIndex = selectedAnswers[i] ?? -1;

        if (chosenIndex != question.correctIndex) {
          wrongEntries.add(
            WrongBookEntry(
              questionId: question.id,
              wrongCount: 1,
              lastWrongAt: finishedAt.millisecondsSinceEpoch,
              nextReviewAt: finishedAt
                  .add(const Duration(days: 1))
                  .millisecondsSinceEpoch,
            ),
          );
        }
      }

      final date =
          '${finishedAt.year.toString().padLeft(4, '0')}-'
          '${finishedAt.month.toString().padLeft(2, '0')}-'
          '${finishedAt.day.toString().padLeft(2, '0')}';

      final dailyStat = DailyStat(
        date: date,
        xp: score * 10,
        questionsDone: widget.questions.length,
        correct: score,
        minutes: (durationSec / 60).ceil(),
      );

      await repository.savePracticeResult(
        attempt: attempt,
        buildAnswers: (attemptId) {
          return List.generate(widget.questions.length, (i) {
            final question = widget.questions[i];
            final chosenIndex = selectedAnswers[i] ?? -1;

            return AttemptAnswer(
              attemptId: attemptId,
              questionId: question.id,
              chosenIndex: chosenIndex,
              isCorrect: chosenIndex == question.correctIndex,
            );
          });
        },
        wrongEntries: wrongEntries,
        dailyStat: dailyStat,
      );

      final attempts = await repository.getAllAttempts();

      final matchingAttempts = attempts.where((item) {
        return item.mode == 'mock_exam' &&
            item.startedAt == startedAt.millisecondsSinceEpoch;
      }).toList();

      if (matchingAttempts.isNotEmpty) {
        matchingAttempts.sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
        savedAttempt = matchingAttempts.first;
      }

      if (!mounted) return;

      setState(() {
        submitted = true;
        isSaving = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể lưu bài thi: $error')));
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (widget.questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Thi thử THPT')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined, size: 64, color: colorScheme.outline),
              const SizedBox(height: 12),
              const Text('Không có câu hỏi để thi.'),
            ],
          ),
        ),
      );
    }

    if (submitted) {
      final total = widget.questions.length;
      final wrong = total - score;
      final accuracy = total == 0 ? 0.0 : score / total * 100;

      return Scaffold(
        appBar: AppBar(
          title: const Text('Kết quả thi thử'),
          automaticallyImplyLeading: false,
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Biểu tượng hoàn thành
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.emoji_events_rounded,
                    size: 52,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'Hoàn thành bài thi thử!',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Môn Tiếng Anh — Chuẩn cấu trúc THPT',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),

                // Card tổng quan kết quả
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.4,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.7),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$score',
                            style: theme.textTheme.displayMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                          Text(
                            ' / $total',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: accuracy >= 80
                              ? Colors.green.withValues(alpha: 0.15)
                              : (accuracy >= 50
                                    ? Colors.orange.withValues(alpha: 0.15)
                                    : Colors.red.withValues(alpha: 0.15)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Độ chính xác: ${accuracy.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: accuracy >= 80
                                ? Colors.green.shade700
                                : (accuracy >= 50
                                      ? Colors.orange.shade800
                                      : Colors.red.shade700),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 12),

                      // Chi tiết đúng / sai / thời gian
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricTile(
                              context,
                              icon: Icons.check_circle_rounded,
                              iconColor: Colors.green,
                              label: 'Câu đúng',
                              value: '$score',
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 36,
                            color: colorScheme.outlineVariant,
                          ),
                          Expanded(
                            child: _buildMetricTile(
                              context,
                              icon: Icons.cancel_rounded,
                              iconColor: Colors.red,
                              label: 'Sai / Trống',
                              value: '$wrong',
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 36,
                            color: colorScheme.outlineVariant,
                          ),
                          Expanded(
                            child: _buildMetricTile(
                              context,
                              icon: Icons.timer_outlined,
                              iconColor: colorScheme.primary,
                              label: 'Thời gian',
                              value:
                                  '${(usedSeconds ~/ 60).toString().padLeft(2, '0')}:'
                                  '${(usedSeconds % 60).toString().padLeft(2, '0')}',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                if (savedAttempt != null)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                PracticeReviewScreen(attempt: savedAttempt!),
                          ),
                        );
                      },
                      icon: const Icon(Icons.visibility_rounded),
                      label: const Text('Xem lại bài thi'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.done_all_rounded),
                    label: const Text('Hoàn thành'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final question = widget.questions[currentIndex];
    final isUrgent = remainingSeconds <= 30;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          confirmExitExam();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Thoát bài thi',
            onPressed: isSaving ? null : confirmExitExam,
          ),
          title: const Text('Thi thử THPT'),
          actions: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 14),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isUrgent
                      ? Colors.red.withValues(alpha: 0.15)
                      : colorScheme.primaryContainer.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isUrgent
                        ? Colors.red.shade400
                        : colorScheme.primary.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isUrgent ? Icons.alarm_on_rounded : Icons.timer_outlined,
                      size: 16,
                      color: isUrgent
                          ? Colors.red.shade700
                          : colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      formattedTime,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isUrgent
                            ? Colors.red.shade700
                            : colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: (currentIndex + 1) / widget.questions.length,
                minHeight: 4,
                backgroundColor: colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isUrgent ? Colors.red : colorScheme.primary,
                ),
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            // Header phụ: Số câu và số lượng đã trả lời
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: colorScheme.surface,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Câu ${currentIndex + 1}/${widget.questions.length}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Đã làm: $answeredCount/${widget.questions.length}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1),

            // Danh sách nội dung câu hỏi (có padding đáy 80dp và reset scroll khi đổi câu)
            Expanded(
              child: ListView(
                key: ValueKey<int>(currentIndex),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                children: [
                  QuestionStemView(stem: question.stem, type: question.type),
                  const SizedBox(height: 20),

                  Builder(
                    builder: (_) {
                      final mapping = optionMappings[currentIndex];
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(mapping.length, (slotIndex) {
                          final originalIndex = mapping.originalIndexAt(slotIndex);
                          final isSelected =
                              selectedAnswers[currentIndex] == originalIndex;

                          return QuizOptionCard(
                            index: slotIndex,
                            text: question.options[originalIndex],
                            isSelected: isSelected,
                            isSubmitted: false,
                            onTap: isSaving
                                ? null
                                : () => selectAnswer(originalIndex),
                          );
                        }),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Thanh điều hướng responsive, an toàn tuyệt đối, chống lỗi RenderFlex overflow
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    offset: const Offset(0, -2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final hasNext =
                          currentIndex < widget.questions.length - 1;

                      return Row(
                        children: [
                          // Nút Câu trước
                          Expanded(
                            flex: hasNext ? 10 : 1,
                            child: OutlinedButton(
                              onPressed: currentIndex > 0
                                  ? previousQuestion
                                  : null,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 10,
                                ),
                                minimumSize: const Size(0, 46),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.arrow_back_rounded, size: 16),
                                    SizedBox(width: 4),
                                    Text(
                                      'Câu trước',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: hasNext ? 6 : 10),

                          // Nút Câu tiếp (hiển thị khi chưa tới câu cuối)
                          if (hasNext) ...[
                            Expanded(
                              flex: 10,
                              child: OutlinedButton(
                                onPressed: nextQuestion,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 10,
                                  ),
                                  minimumSize: const Size(0, 46),
                                  side: BorderSide(
                                    color: colorScheme.primary.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Câu tiếp',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 16,
                                        color: colorScheme.primary,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],

                          // Nút Nộp bài
                          Expanded(
                            flex: hasNext ? 11 : 1,
                            child: FilledButton(
                              onPressed: isSaving ? null : confirmSubmit,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 10,
                                ),
                                minimumSize: const Size(0, 46),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (isSaving)
                                      const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    else
                                      const Icon(Icons.check_rounded, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      isSaving ? 'Đang lưu...' : 'Nộp bài',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 4),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
