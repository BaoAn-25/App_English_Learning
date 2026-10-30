import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/app_repository.dart';
import '../../data/models/question.dart';
import '../practice/practice_quiz_screen.dart';
import '../practice/practice_history_screen.dart';
import '../practice/wrong_book_screen.dart';
import '../vocab/vocab_screen.dart';

/// The textbook bank is not an official graduation-exam matrix.
class BookPracticeScreen extends StatefulWidget {
  const BookPracticeScreen({super.key});
  @override
  State<BookPracticeScreen> createState() => _BookPracticeScreenState();
}

class _BookPracticeScreenState extends State<BookPracticeScreen> {
  late Future<List<Question>> questions;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    questions = context.read<AppRepository>().getAllQuestions();
  }

  Future<void> _quiz(List<Question> bank, String title) async {
    final selected = List<Question>.from(bank)..shuffle();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PracticeQuizScreen(
          title: title,
          questions: selected.take(20).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ôn tập theo sách')),
    body: FutureBuilder<List<Question>>(
      future: questions,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: FilledButton(
              onPressed: () => setState(_load),
              child: const Text('Thử lại'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final bank = snapshot.data!;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Ghi nhớ từ vựng Global Success 12',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Câu hỏi được biên soạn từ Glossary, có chấm điểm và giải thích kèm trang nguồn. '
                  'Đây là bài ôn từ vựng, không phải đề thi tốt nghiệp hoặc bộ đáp án chính thức của sách. '
                  'Các bài Reading, Language, Listening, Speaking, Writing và Project nằm trong tab Sách, kèm vở bài làm.',
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: bank.isEmpty
                      ? null
                      : () => _quiz(bank, 'Ôn tập Glossary · 20 câu'),
                  icon: const Icon(Icons.quiz_outlined),
                  label: const Text('Ôn tổng hợp 20 câu'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const VocabScreen()),
                  ),
                  icon: const Icon(Icons.style_outlined),
                  label: const Text('Flashcard & ôn từ đến hạn'),
                ),
                const SizedBox(height: 16),
                for (int unit = 1; unit <= 10; unit++)
                  Builder(
                    builder: (context) {
                      final subset = bank
                          .where(
                            (q) =>
                                q.topicId == 'topic_12_u$unit' ||
                                q.topicId == 'topic_12_unit$unit' ||
                                q.topicId ==
                                'gs12_u${unit.toString().padLeft(2, '0')}',
                          )
                          .toList();
                      return Card(
                        child: ListTile(
                          title: Text('Unit $unit'),
                          subtitle: Text('${subset.length} câu ôn từ vựng'),
                          trailing: const Icon(Icons.play_arrow),
                          onTap: subset.isEmpty
                              ? null
                              : () => _quiz(subset, 'Glossary · Unit $unit'),
                        ),
                      );
                    },
                  ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('Lịch sử ôn tập'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PracticeHistoryScreen(type: 'vocab', title: 'Lịch sử ôn Glossary'),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.bookmark_outline),
                  title: const Text('Sổ câu sai'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WrongBookScreen()),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
