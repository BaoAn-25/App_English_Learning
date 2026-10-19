import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_repository.dart';
import '../../data/models/question.dart';
import 'practice_quiz_screen.dart';

class PracticeScreen extends StatelessWidget {
  const PracticeScreen({super.key});

  static const Map<String, String> questionTypes = {
    'grammar': 'Ngữ pháp',
    'arrange': 'Sắp xếp câu',
    'vocab': 'Từ vựng',
    'synonym_antonym': 'Đồng nghĩa - Trái nghĩa',
    'communication': 'Giao tiếp',
    'signs': 'Biển báo',
    'cloze': 'Điền từ',
    'reading': 'Đọc hiểu',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Luyện Theo Dạng Bài')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: questionTypes.entries.map((entry) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.quiz_outlined),
              title: Text(entry.value),
              subtitle: const Text('Luyện tập theo dạng câu hỏi'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        QuestionListScreen(type: entry.key, title: entry.value),
                  ),
                );
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}

class QuestionListScreen extends StatefulWidget {
  final String type;
  final String title;

  const QuestionListScreen({
    super.key,
    required this.type,
    required this.title,
  });

  @override
  State<QuestionListScreen> createState() => _QuestionListScreenState();
}

class _QuestionListScreenState extends State<QuestionListScreen> {
  late Future<List<Question>> questionsFuture;

  @override
  void initState() {
    super.initState();
    questionsFuture = context.read<AppRepository>().getQuestionsByType(
      widget.type,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: FutureBuilder<List<Question>>(
        future: questionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Lỗi tải câu hỏi: ${snapshot.error}'));
          }

          final questions = snapshot.data ?? [];

          if (questions.isEmpty) {
            return const Center(
              child: Text('Chưa có câu hỏi cho dạng bài này.'),
            );
          }

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.quiz, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'Có ${questions.length} câu hỏi trong ngân hàng.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      final shuffled = List<Question>.of(questions)..shuffle();

                      final quizQuestions = shuffled.take(10).toList();

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PracticeQuizScreen(
                            title: widget.title,
                            questions: quizQuestions,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Bắt đầu luyện tập'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
