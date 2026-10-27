import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';

import '../../data/app_repository.dart';
import '../../data/models/attempt.dart';
import '../../data/models/attempt_answer.dart';
import '../../data/models/question.dart';
import '../../data/models/topic.dart';
import '../../data/models/wrong_book_entry.dart';

/// Màn hình kiểm tra nhanh trắc nghiệm từ vựng & đồng nghĩa - trái nghĩa cuối chủ đề
/// Tận dụng bộ máy câu hỏi Question, ghi nhận Attempt & WrongBook
class TopicQuizScreen extends StatefulWidget {
  final Topic topic;
  final List<Question>? initialQuestions;

  const TopicQuizScreen({
    super.key,
    required this.topic,
    this.initialQuestions,
  });

  @override
  State<TopicQuizScreen> createState() => _TopicQuizScreenState();
}

class _TopicQuizScreenState extends State<TopicQuizScreen> {
  List<Question> _questions = [];
  bool _isLoading = true;
  int _currentIndex = 0;
  int? _selectedOption;
  bool _answered = false;
  int _score = 0;
  final List<AttemptAnswer> _answers = [];
  late DateTime _startTime;
  bool _quizFinished = false;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    if (widget.initialQuestions != null && widget.initialQuestions!.isNotEmpty) {
      _questions = List.from(widget.initialQuestions!)..shuffle();
      _isLoading = false;
    } else {
      _loadQuestions();
    }
  }

  Future<void> _loadQuestions() async {
    List<Question> loaded = [];
    try {
      final repo = context.read<AppRepository>();
      loaded = await repo.getQuestionsByTopicId(widget.topic.id);
    } catch (_) {
      loaded = [];
    }

    // Fallback: nếu DB chưa seed hoặc rỗng, đọc trực tiếp từ assets
    if (loaded.isEmpty) {
      try {
        final jsonStr = await rootBundle.loadString('assets/data/questions.json');
        final dynamic decoded = jsonDecode(jsonStr);
        if (decoded is List) {
          loaded = decoded
              .map((e) => Question.fromMap(e as Map<String, dynamic>))
              .where((q) => q.topicId == widget.topic.id)
              .toList();
        }
      } catch (e) {
        debugPrint('Fallback questions load error: $e');
      }
    }

    if (mounted) {
      setState(() {
        _questions = loaded..shuffle();
        _isLoading = false;
      });
    }
  }

  void _submitAnswer() {
    if (_selectedOption == null || _answered) return;

    final q = _questions[_currentIndex];
    final isCorrect = _selectedOption == q.correctIndex;
    if (isCorrect) _score++;

    _answers.add(
      AttemptAnswer(
        attemptId: 0, // Sẽ cập nhật khi lưu attempt
        questionId: q.id,
        chosenIndex: _selectedOption!,
        isCorrect: isCorrect,
      ),
    );

    setState(() {
      _answered = true;
    });
  }

  Future<void> _nextQuestion() async {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedOption = null;
        _answered = false;
      });
    } else {
      await _finishQuiz();
    }
  }

  Future<void> _finishQuiz() async {
    setState(() {
      _quizFinished = true;
    });

    try {
      final repo = context.read<AppRepository>();
      final duration = DateTime.now().difference(_startTime).inSeconds;
      final attempt = Attempt(
        mode: 'practice',
        type: widget.topic.id,
        startedAt: _startTime.millisecondsSinceEpoch,
        durationSec: duration,
        score: _score,
        total: _questions.length,
      );

      final attemptId = await repo.insertAttempt(attempt);

      if (_answers.isNotEmpty) {
        final answersWithId = _answers.map((a) {
          return AttemptAnswer(
            attemptId: attemptId,
            questionId: a.questionId,
            chosenIndex: a.chosenIndex,
            isCorrect: a.isCorrect,
          );
        }).toList();
        await repo.insertAttemptAnswers(answersWithId);

        // Lưu sổ câu sai nếu có
        for (final a in answersWithId) {
          if (!a.isCorrect) {
            final now = DateTime.now().millisecondsSinceEpoch;
            await repo.upsertWrongBookEntry(
              WrongBookEntry(
                questionId: a.questionId,
                wrongCount: 1,
                lastWrongAt: now,
                nextReviewAt: now + const Duration(days: 1).inMilliseconds,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error saving quiz attempt: $e');
    }
  }

  void _restartQuiz() {
    setState(() {
      _questions.shuffle();
      _currentIndex = 0;
      _selectedOption = null;
      _answered = false;
      _score = 0;
      _answers.clear();
      _quizFinished = false;
      _startTime = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('Kiểm tra: ${widget.topic.title}')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('Kiểm tra: ${widget.topic.title}')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.quiz_outlined, size: 64, color: colorScheme.outline),
                const SizedBox(height: 16),
                const Text(
                  'Chưa có câu hỏi cho chủ đề này',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Quay lại'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_quizFinished) {
      return _buildResultScreen(theme, colorScheme);
    }

    final q = _questions[_currentIndex];
    final progress = (_currentIndex + 1) / _questions.length;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Kiểm tra: ${widget.topic.title}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
          ),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_currentIndex + 1}/${_questions.length}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badge phân loại câu hỏi
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: q.type == 'vocab'
                        ? Colors.blue.withAlpha(25)
                        : Colors.purple.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: q.type == 'vocab'
                          ? Colors.blue.withAlpha(60)
                          : Colors.purple.withAlpha(60),
                    ),
                  ),
                  child: Text(
                    q.type == 'vocab' ? 'Từ vựng ngữ cảnh' : 'Đồng nghĩa / Trái nghĩa',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: q.type == 'vocab' ? Colors.blue : Colors.purple,
                    ),
                  ),
                ),
                const Spacer(),
                Row(
                  children: List.generate(
                    q.difficulty.clamp(0, 5),
                    (_) => const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Đề bài (Stem)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colorScheme.outlineVariant.withAlpha(80)),
              ),
              child: Text(
                q.stem,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Các lựa chọn đáp án (A, B, C, D)
            ...List.generate(q.options.length, (idx) {
              final optionText = q.options[idx];
              final isSelected = _selectedOption == idx;
              final isCorrect = idx == q.correctIndex;

              Color borderColor = colorScheme.outlineVariant.withAlpha(80);
              Color bgColor = colorScheme.surface;
              Widget? trailingIcon;

              if (_answered) {
                if (isCorrect) {
                  borderColor = Colors.green;
                  bgColor = Colors.green.withAlpha(25);
                  trailingIcon = const Icon(Icons.check_circle_rounded, color: Colors.green);
                } else if (isSelected) {
                  borderColor = Colors.red;
                  bgColor = Colors.red.withAlpha(25);
                  trailingIcon = const Icon(Icons.cancel_rounded, color: Colors.red);
                }
              } else if (isSelected) {
                borderColor = colorScheme.primary;
                bgColor = colorScheme.primary.withAlpha(20);
              }

              final optionPrefix = String.fromCharCode(65 + idx); // A, B, C, D

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _answered ? null : () => setState(() => _selectedOption = idx),
                    borderRadius: BorderRadius.circular(14),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderColor, width: isSelected || (_answered && isCorrect) ? 2 : 1),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? colorScheme.primary
                                  : colorScheme.surfaceContainerHighest,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                optionPrefix,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? colorScheme.onPrimary
                                      : colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              optionText,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ),
                          ?trailingIcon,
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),

            // Giải thích chi tiết khi đã trả lời
            if (_answered) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha(15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.blue.withAlpha(60)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lightbulb_outline_rounded, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Giải thích chi tiết:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      q.explanation,
                      style: const TextStyle(fontSize: 14, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: !_answered
              ? FilledButton(
                  onPressed: _selectedOption != null ? _submitAnswer : null,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Kiểm tra đáp án', style: TextStyle(fontSize: 16)),
                )
              : FilledButton.icon(
                  onPressed: _nextQuestion,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(
                    _currentIndex < _questions.length - 1 ? 'Câu tiếp theo' : 'Xem kết quả',
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildResultScreen(ThemeData theme, ColorScheme colorScheme) {
    final total = _questions.length;
    final percent = total > 0 ? (_score / total * 100).round() : 0;
    final isPassed = percent >= 70;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Kết Quả Kiểm Tra'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: isPassed ? Colors.amber.withAlpha(30) : Colors.orange.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPassed ? Icons.emoji_events_rounded : Icons.auto_stories_rounded,
                  size: 56,
                  color: isPassed ? Colors.amber[800] : Colors.orange[800],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isPassed ? 'Xuất Sắc!' : 'Cố Gắng Lên!',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isPassed ? Colors.green : Colors.orange[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Chủ đề: ${widget.topic.title}',
                style: TextStyle(fontSize: 16, color: colorScheme.onSurface.withAlpha(160)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Thẻ điểm
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colorScheme.outlineVariant.withAlpha(80)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      children: [
                        Text(
                          '$_score/$total',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            color: isPassed ? Colors.green : Colors.orange,
                          ),
                        ),
                        const Text('Câu đúng', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                    const SizedBox(width: 32),
                    Container(height: 40, width: 1, color: colorScheme.outlineVariant),
                    const SizedBox(width: 32),
                    Column(
                      children: [
                        Text(
                          '$percent%',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            color: isPassed ? Colors.green : Colors.orange,
                          ),
                        ),
                        const Text('Độ chính xác', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isPassed
                    ? 'Bạn đã làm chủ tốt từ vựng & cấu trúc ngữ nghĩa của chủ đề này!'
                    : 'Hãy ôn lại các câu chưa làm đúng và dùng Flashcard để ghi nhớ sâu hơn nhé!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: colorScheme.onSurface.withAlpha(170)),
              ),
              const SizedBox(height: 36),

              // Nút hành động
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _restartQuiz,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Làm lại bài kiểm tra'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Quay lại danh sách từ'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
