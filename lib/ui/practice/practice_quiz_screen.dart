import 'package:flutter/material.dart';

import '../../data/models/question.dart';

class PracticeQuizScreen extends StatefulWidget {
  final String title;
  final List<Question> questions;

  const PracticeQuizScreen({
    super.key,
    required this.title,
    required this.questions,
  });

  @override
  State<PracticeQuizScreen> createState() => _PracticeQuizScreenState();
}

class _PracticeQuizScreenState extends State<PracticeQuizScreen> {
  int currentIndex = 0;
  late final List<int?> selectedAnswers;
  bool submitted = false;

  @override
  void initState() {
    super.initState();

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
              setState(() => submitted = true);
            },
            child: const Text('Nộp bài'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final questions = widget.questions;

    if (questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: const Center(child: Text('Không có câu hỏi để luyện tập.')),
      );
    }

    final question = questions[currentIndex];
    final selected = selectedAnswers[currentIndex];

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          LinearProgressIndicator(value: (currentIndex + 1) / questions.length),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Câu ${currentIndex + 1}/${questions.length}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  question.stem,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 24),

                ...List.generate(question.options.length, (index) {
                  final isSelected = selected == index;
                  final isCorrect = question.correctIndex == index;

                  Color? tileColor;

                  if (submitted && isCorrect) {
                    tileColor = Colors.green.withValues(alpha: 0.15);
                  } else if (submitted && isSelected && !isCorrect) {
                    tileColor = Colors.red.withValues(alpha: 0.15);
                  }

                  return Card(
                    color: tileColor,
                    child: ListTile(
                      onTap: submitted ? null : () => selectAnswer(index),
                      leading: Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      title: Text(
                        '${String.fromCharCode(65 + index)}. '
                        '${question.options[index]}',
                      ),
                      trailing: submitted && isCorrect
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : null,
                    ),
                  );
                }),

                if (submitted) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Đáp án đúng: '
                    '${String.fromCharCode(65 + question.correctIndex)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(question.explanation),
                ],
              ],
            ),
          ),

          if (submitted)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'Kết quả: $score/${questions.length} câu đúng',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                OutlinedButton(
                  onPressed: currentIndex > 0 ? previousQuestion : null,
                  child: const Text('Câu trước'),
                ),
                const Spacer(),
                if (currentIndex < questions.length - 1)
                  FilledButton(
                    onPressed: nextQuestion,
                    child: const Text('Câu tiếp'),
                  )
                else if (!submitted)
                  FilledButton(
                    onPressed: submitQuiz,
                    child: const Text('Nộp bài'),
                  )
                else
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Hoàn thành'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
