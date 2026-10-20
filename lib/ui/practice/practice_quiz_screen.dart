import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_repository.dart';
import '../../data/models/attempt.dart';
import '../../data/models/attempt_answer.dart';
import '../../data/models/daily_stat.dart';
import '../../data/models/question.dart';
import '../../data/models/wrong_book_entry.dart';
import 'widgets/question_stem_view.dart';
import 'widgets/quiz_option_card.dart';

class PracticeQuizScreen extends StatefulWidget {
  final String title;
  final List<Question> questions;
  final String mode;

  const PracticeQuizScreen({
    super.key,
    required this.title,
    required this.questions,
    this.mode = 'practice',
  });

  @override
  State<PracticeQuizScreen> createState() => _PracticeQuizScreenState();
}

class _PracticeQuizScreenState extends State<PracticeQuizScreen> {
  int currentIndex = 0;
  late final List<int?> selectedAnswers;
  bool submitted = false;
  bool isSaving = false;
  late final DateTime startedAt;

  @override
  void initState() {
    super.initState();

    startedAt = DateTime.now();
    selectedAnswers = List<int?>.filled(widget.questions.length, null);
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

  void selectAnswer(int optionIndex) {
    if (submitted) return;

    setState(() {
      selectedAnswers[currentIndex] = optionIndex;
    });
  }

  void nextQuestion() {
    if (currentIndex < widget.questions.length - 1) {
      setState(() => currentIndex++);
    }
  }

  void previousQuestion() {
    if (currentIndex > 0) {
      setState(() => currentIndex--);
    }
  }

  void submitQuiz() {
    final unanswered = selectedAnswers.where((answer) => answer == null).length;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xác nhận nộp bài'),
        content: Text(
          unanswered > 0
              ? 'Bạn còn $unanswered câu chưa trả lời. '
                    'Bạn vẫn muốn nộp bài?'
              : 'Bạn có chắc muốn nộp bài?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              saveQuizResult();
            },
            child: const Text('Nộp bài'),
          ),
        ],
      ),
    );
  }

  Future<void> saveQuizResult() async {
    if (submitted || isSaving) return;

    setState(() {
      isSaving = true;
    });

    try {
      final repository = context.read<AppRepository>();
      final finishedAt = DateTime.now();
      final durationSec = finishedAt.difference(startedAt).inSeconds;

      final attempt = Attempt(
        mode: widget.mode,
        type: widget.mode == 'wrong_review'
            ? null
            : widget.questions.first.type,
        startedAt: startedAt.millisecondsSinceEpoch,
        durationSec: durationSec,
        score: score,
        total: widget.questions.length,
      );

      final wrongEntries = <WrongBookEntry>[];
      final wrongAt = finishedAt.millisecondsSinceEpoch;
      final nextReviewAt = finishedAt
          .add(const Duration(days: 1))
          .millisecondsSinceEpoch;

      for (int i = 0; i < widget.questions.length; i++) {
        final question = widget.questions[i];
        final chosenIndex = selectedAnswers[i] ?? -1;

        if (chosenIndex != question.correctIndex) {
          wrongEntries.add(
            WrongBookEntry(
              questionId: question.id,
              wrongCount: 1,
              lastWrongAt: wrongAt,
              nextReviewAt: nextReviewAt,
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

      if (!mounted) return;

      setState(() {
        submitted = true;
        isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu kết quả luyện tập!')),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể lưu kết quả: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final questions = widget.questions;

    if (questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined, size: 64, color: colorScheme.outline),
              const SizedBox(height: 12),
              const Text('Không có câu hỏi để luyện tập.'),
            ],
          ),
        ),
      );
    }

    final question = questions[currentIndex];
    final selected = selectedAnswers[currentIndex];
    final progress = (currentIndex + 1) / questions.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Header câu hỏi & tiến độ
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
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Câu ${currentIndex + 1}/${questions.length}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (submitted)
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Đúng: $score/${questions.length}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Đã chọn ${selectedAnswers.where((e) => e != null).length}/${questions.length}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),

          // Vùng nội dung câu hỏi & danh sách đáp án
          Expanded(
            child: ListView(
              key: ValueKey<int>(currentIndex),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              children: [
                // Thân câu hỏi định dạng thông minh
                QuestionStemView(stem: question.stem, type: question.type),
                const SizedBox(height: 20),

                // Danh sách các lựa chọn đáp án
                ...List.generate(question.options.length, (index) {
                  final isSelected = selected == index;
                  final isCorrect = question.correctIndex == index;

                  return QuizOptionCard(
                    index: index,
                    text: question.options[index],
                    isSelected: isSelected,
                    isSubmitted: submitted,
                    isCorrect: isCorrect,
                    onTap: submitted ? null : () => selectAnswer(index),
                  );
                }),

                // Khung giải thích chi tiết khi đã nộp bài
                if (submitted) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
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
                              Icons.lightbulb_rounded,
                              color: Colors.amber.shade700,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Lời giải chi tiết',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Đáp án: ${String.fromCharCode(65 + question.correctIndex)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          question.explanation,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.45,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Banner thông báo kết quả sau khi nộp
          if (submitted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    score >= (questions.length * 0.8)
                        ? Icons.emoji_events_rounded
                        : Icons.check_circle_outline_rounded,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Kết quả: $score/${questions.length} câu đúng '
                    '(${(score / questions.length * 100).toStringAsFixed(0)}%)',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),

          // Thanh điều hướng phía dưới - Tương thích an toàn tuyệt đối với SafeArea
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
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    // Nút Câu trước
                    Expanded(
                      child: OutlinedButton(
                        onPressed: currentIndex > 0 ? previousQuestion : null,
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
                              SizedBox(width: 6),
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
                    const SizedBox(width: 8),

                    // Nút hành động tiếp theo
                    Expanded(
                      child: currentIndex < questions.length - 1
                          ? FilledButton(
                              onPressed: nextQuestion,
                              style: FilledButton.styleFrom(
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
                                    Text(
                                      'Câu tiếp',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    SizedBox(width: 6),
                                    Icon(Icons.arrow_forward_rounded, size: 16),
                                  ],
                                ),
                              ),
                            )
                          : (!submitted
                                ? FilledButton(
                                    onPressed: isSaving ? null : submitQuiz,
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 10,
                                      ),
                                      minimumSize: const Size(0, 46),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
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
                                            const Icon(
                                              Icons.check_rounded,
                                              size: 16,
                                            ),
                                          const SizedBox(width: 6),
                                          Text(
                                            isSaving
                                                ? 'Đang lưu...'
                                                : 'Nộp bài',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : FilledButton(
                                    onPressed: () => Navigator.pop(context),
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 10,
                                      ),
                                      minimumSize: const Size(0, 46),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.done_all_rounded,
                                            size: 16,
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            'Hoàn thành',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
