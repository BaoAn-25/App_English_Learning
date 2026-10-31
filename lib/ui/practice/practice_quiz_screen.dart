import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_repository.dart';
import '../../data/models/attempt.dart';
import '../../data/models/attempt_answer.dart';
import '../../data/models/daily_stat.dart';
import '../../data/models/learning_session.dart';
import '../../data/models/question.dart';
import '../../data/models/wrong_book_entry.dart';
import '../auth/auth_controller.dart';
import '../auth/register_screen.dart';
import 'services/option_shuffler.dart';
import 'widgets/question_stem_view.dart';
import 'widgets/quiz_option_card.dart';

class PracticeQuizScreen extends StatefulWidget {
  final String title;
  final List<Question> questions;
  final String mode;
  final int initialIndex;
  final List<int?>? initialAnswers;
  final String? lessonId;
  final String? nextLessonTitle;

  /// Ánh xạ thứ tự hiển thị phương án (tùy chọn, mặc định xáo trộn ngẫu nhiên).
  final List<QuestionOptionMapping>? optionMappings;

  const PracticeQuizScreen({
    super.key,
    required this.title,
    required this.questions,
    this.mode = 'practice',
    this.initialIndex = 0,
    this.initialAnswers,
    this.lessonId,
    this.nextLessonTitle,
    this.optionMappings,
  });

  @override
  State<PracticeQuizScreen> createState() => _PracticeQuizScreenState();
}

class _PracticeQuizScreenState extends State<PracticeQuizScreen> {
  int currentIndex = 0;
  late final List<int?> selectedAnswers;
  late final List<QuestionOptionMapping> optionMappings;
  bool submitted = false;
  bool isSaving = false;
  bool _dismissedRegisterInvitation = false;
  late final DateTime startedAt;

  @override
  void initState() {
    super.initState();

    startedAt = DateTime.now();
    currentIndex = widget.initialIndex.clamp(
      0,
      widget.questions.isNotEmpty ? widget.questions.length - 1 : 0,
    );
    selectedAnswers = widget.initialAnswers != null
        ? List<int?>.from(widget.initialAnswers!)
        : List<int?>.filled(widget.questions.length, null);
    optionMappings =
        widget.optionMappings ??
        List.generate(
          widget.questions.length,
          (i) => QuestionOptionMapping.shuffled(
            widget.questions[i].options.length,
          ),
        );

    // Lưu trạng thái làm bài dở nếu có câu hỏi
    if (widget.questions.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _persistSession(isCompleted: false);
      });
    }
  }

  Future<void> _persistSession({bool isCompleted = false, int? completedScore}) async {
    try {
      final repository = context.read<AppRepository>();
      String? ownerId;
      try {
        final auth = AuthController.instance;
        if (auth.isAuthenticated) {
          ownerId = auth.user.id;
        } else {
          ownerId = await repository.getOrCreateGuestSessionId();
        }
      } catch (_) {
        return;
      }

      final currentType = widget.questions.isNotEmpty ? widget.questions.first.type : 'practice';
      final lessonId = widget.lessonId ?? 'type_$currentType';
      final (nextId, nextTitle) = _determineNextLesson(currentType);

      final session = LearningSession(
        ownerId: ownerId,
        lessonId: lessonId,
        lessonTitle: widget.title,
        lessonType: 'question_type',
        status: isCompleted ? 'completed' : 'in_progress',
        currentQuestionIndex: currentIndex,
        totalQuestions: widget.questions.length,
        score: completedScore,
        questionIds: widget.questions.map((q) => q.id).toList(),
        selectedAnswers: selectedAnswers,
        nextLessonId: nextId,
        nextLessonTitle: nextTitle,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      await repository.saveLearningSession(session);
    } catch (_) {}
  }

  (String, String) _determineNextLesson(String currentType) {
    const sequence = [
      ('grammar', 'Ngữ pháp', 'vocab', 'Luyện tập Từ vựng'),
      ('vocab', 'Từ vựng', 'arrange', 'Sắp xếp câu'),
      ('arrange', 'Sắp xếp câu', 'synonym_antonym', 'Đồng nghĩa - Trái nghĩa'),
      ('synonym_antonym', 'Đồng nghĩa - Trái nghĩa', 'communication', 'Giao tiếp'),
      ('communication', 'Giao tiếp', 'signs', 'Biển báo'),
      ('signs', 'Biển báo', 'cloze', 'Điền từ'),
      ('cloze', 'Điền từ', 'reading', 'Đọc hiểu'),
      ('reading', 'Đọc hiểu', 'grammar', 'Luyện tập Ngữ pháp'),
    ];

    for (final s in sequence) {
      if (s.$1 == currentType) {
        return (s.$3, s.$4);
      }
    }
    return ('type_vocab', 'Luyện tập Từ vựng');
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
    if (submitted || isSaving) return;

    setState(() {
      selectedAnswers[currentIndex] = optionIndex;
    });
    _persistSession(isCompleted: false);
  }

  void nextQuestion() {
    if (currentIndex < widget.questions.length - 1) {
      setState(() => currentIndex++);
      _persistSession(isCompleted: false);
    }
  }

  void previousQuestion() {
    if (currentIndex > 0) {
      setState(() => currentIndex--);
      _persistSession(isCompleted: false);
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
      String? ownerId;
      try {
        final auth = AuthController.instance;
        if (auth.isAuthenticated) {
          ownerId = auth.user.id;
        } else {
          ownerId = await repository.getOrCreateGuestSessionId();
        }
      } catch (_) {
        ownerId = null;
      }

      final finishedAt = DateTime.now();
      final durationSec = finishedAt.difference(startedAt).inSeconds;

      final hasMultipleTypes =
          widget.questions.map((q) => q.type).toSet().length > 1;
      final attemptType =
          (widget.mode == 'wrong_review' ||
              widget.mode == 'mock_exam' ||
              hasMultipleTypes)
          ? null
          : (widget.questions.isNotEmpty ? widget.questions.first.type : null);

      final attempt = Attempt(
        mode: widget.mode,
        type: attemptType,
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
        ownerId: ownerId,
      );

      await _persistSession(isCompleted: true, completedScore: score);

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

                // Danh sách các lựa chọn đáp án (được xáo trộn hiển thị)
                Builder(
                  builder: (_) {
                    final mapping = optionMappings[currentIndex];
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(mapping.length, (slotIndex) {
                        final originalIndex = mapping.originalIndexAt(
                          slotIndex,
                        );
                        final isSelected = selected == originalIndex;
                        final isCorrect =
                            question.correctIndex == originalIndex;

                        return QuizOptionCard(
                          index: slotIndex,
                          text: question.options[originalIndex],
                          isSelected: isSelected,
                          isSubmitted: submitted,
                          isCorrect: isCorrect,
                          onTap: submitted || isSaving
                              ? null
                              : () => selectAnswer(originalIndex),
                        );
                      }),
                    );
                  },
                ),

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
                            Expanded(
                              child: Text(
                                'Lời giải chi tiết',
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
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
                                'Đáp án đúng: ${optionMappings[currentIndex].displayLetterOfOriginal(question.correctIndex)}',
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
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Kết quả: $score/${questions.length} câu đúng '
                        '(${(score / questions.length * 100).toStringAsFixed(0)}%)',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Lời mời tạo tài khoản sau khi xem kết quả (dành riêng cho khách, không che kết quả)
          if (submitted && !AuthController.instance.isAuthenticated && !_dismissedRegisterInvitation)
            _buildGuestRegisterPrompt(context, colorScheme),

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

  Widget _buildGuestRegisterPrompt(BuildContext context, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF93C5FD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.bookmark_added_rounded, color: Color(0xFF2563EB), size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Lưu kết quả học thử vào tài khoản',
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFF1E40AF),
                  ),
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                tooltip: 'Đóng lời mời',
                onPressed: () {
                  setState(() {
                    _dismissedRegisterInvitation = true;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Kết quả $score/${widget.questions.length} câu đúng đang được lưu trên thiết bị này. Tạo tài khoản để gắn kết quả bài làm vào tài khoản của bạn.',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF334155),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  );
                },
                child: const Text(
                  'Tạo tài khoản',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () {
                  setState(() {
                    _dismissedRegisterInvitation = true;
                  });
                },
                child: const Text(
                  'Để sau',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
