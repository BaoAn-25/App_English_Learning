import '../textbook/word_source_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/topic.dart';
import '../../data/models/word.dart';
import 'flashcard_screen.dart';
import 'topic_quiz_screen.dart';
import 'vocab_provider.dart';

/// Màn hình danh sách 20 từ của một chủ đề + nút học Flashcard & Quiz
class WordListScreen extends StatelessWidget {
  final Topic topic;
  const WordListScreen({super.key, required this.topic});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Consumer<VocabProvider>(
      builder: (context, provider, _) {
        final words = provider.words;

        return Scaffold(
          backgroundColor: colorScheme.surface,
          body: CustomScrollView(
            slivers: [
              // ── App Bar ──────────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 130,
                floating: false,
                pinned: true,
                backgroundColor: colorScheme.surface,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.fromLTRB(56, 0, 16, 14),
                  title: Text(
                    topic.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  background: _TopicHeader(topic: topic),
                ),
                actions: [
                  // Nút Flashcard
                  if (words.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.style_rounded),
                      tooltip: 'Flashcard',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChangeNotifierProvider.value(
                            value: provider,
                            child: FlashcardScreen(
                              words: words,
                              topicTitle: topic.title,
                              topic: topic,
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Nút Quiz kiểm tra nhanh
                  IconButton(
                    icon: const Icon(Icons.quiz_rounded),
                    tooltip: 'Kiểm tra chủ đề (Quiz)',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TopicQuizScreen(topic: topic),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),

              // ── Tiến độ chủ đề ───────────────────────────────────────
              SliverToBoxAdapter(
                child: _TopicProgressSection(
                  words: words,
                  provider: provider,
                  topic: topic,
                ),
              ),

              // ── Danh sách từ ─────────────────────────────────────────
              if (provider.isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final word = words[index];
                      final progress = provider.progressOf(word.id);
                      return _WordCard(
                        word: word,
                        index: index,
                        isLearned: progress.isLearned,
                        isMastered: progress.isMastered,
                        onSpeak: () => provider.speak(word.english),
                      );
                    }, childCount: words.length),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── Header chủ đề ─────────────────────────────────────────────────────────
class _TopicHeader extends StatelessWidget {
  final Topic topic;

  static const List<List<Color>> _gradients = [
    [Color(0xFF5C6BC0), Color(0xFF3F51B5)],
    [Color(0xFF26A69A), Color(0xFF00796B)],
    [Color(0xFF66BB6A), Color(0xFF388E3C)],
    [Color(0xFFEF5350), Color(0xFFC62828)],
    [Color(0xFFAB47BC), Color(0xFF7B1FA2)],
    [Color(0xFF29B6F6), Color(0xFF0277BD)],
    [Color(0xFFFF7043), Color(0xFFBF360C)],
    [Color(0xFF26C6DA), Color(0xFF00838F)],
    [Color(0xFF9CCC65), Color(0xFF558B2F)],
    [Color(0xFFFFCA28), Color(0xFFF57F17)],
  ];

  const _TopicHeader({required this.topic});

  @override
  Widget build(BuildContext context) {
    final idx = (topic.order - 1).clamp(0, _gradients.length - 1);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _gradients[idx],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 70, 20, 0),
      child: Row(
        children: [
          Text(
            'Chủ đề ${topic.order}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            '20 từ',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ── Progress tổng quan ─────────────────────────────────────────────────────
class _TopicProgressSection extends StatelessWidget {
  final List<Word> words;
  final VocabProvider provider;
  final Topic topic;
  const _TopicProgressSection({
    required this.words,
    required this.provider,
    required this.topic,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final learned = words
        .where((w) => provider.progressOf(w.id).isLearned)
        .length;
    final mastered = words
        .where((w) => provider.progressOf(w.id).isMastered)
        .length;
    final total = words.length;
    final progress = total > 0 ? learned / total : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '$learned/$total từ đã học',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 14,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$mastered thành thạo',
                      style: const TextStyle(fontSize: 12, color: Colors.amber),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: words.isEmpty
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChangeNotifierProvider.value(
                              value: provider,
                              child: FlashcardScreen(
                                words: words,
                                topicTitle: topic.title,
                                topic: topic,
                              ),
                            ),
                          ),
                        ),
                  icon: const Icon(Icons.style_rounded, size: 18),
                  label: const Text('Flashcard'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TopicQuizScreen(topic: topic),
                    ),
                  ),
                  icon: const Icon(Icons.quiz_rounded, size: 18),
                  label: const Text('Kiểm tra'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
        ],
      ),
    );
  }
}

// ── Card từ vựng ──────────────────────────────────────────────────────────
class _WordCard extends StatefulWidget {
  final Word word;
  final int index;
  final bool isLearned;
  final bool isMastered;
  final VoidCallback onSpeak;

  const _WordCard({
    required this.word,
    required this.index,
    required this.isLearned,
    required this.isMastered,
    required this.onSpeak,
  });

  @override
  State<_WordCard> createState() => _WordCardState();
}

class _WordCardState extends State<_WordCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Color statusColor;
    IconData statusIcon;
    if (widget.isMastered) {
      statusColor = Colors.amber;
      statusIcon = Icons.star_rounded;
    } else if (widget.isLearned) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle_rounded;
    } else {
      statusColor = colorScheme.outline;
      statusIcon = Icons.radio_button_unchecked_rounded;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.isLearned
                ? statusColor.withAlpha(80)
                : colorScheme.outlineVariant.withAlpha(80),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(12),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Hàng chính ──────────────────────────────────────
                Row(
                  children: [
                    // Số thứ tự
                    SizedBox(
                      width: 28,
                      child: Text(
                        '${widget.index + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.outline,
                        ),
                      ),
                    ),
                    // Từ tiếng Anh
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.word.english,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            widget.word.ipa,
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.primary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Nút phát âm
                    Consumer<VocabProvider>(
                      builder: (context2, prov, child) => IconButton(
                        icon: Icon(
                          prov.isSpeaking
                              ? Icons.volume_up_rounded
                              : Icons.volume_up_outlined,
                          size: 22,
                          color: colorScheme.primary,
                        ),
                        onPressed: widget.onSpeak,
                        tooltip: 'Phát âm',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Trạng thái
                    Icon(statusIcon, size: 18, color: statusColor),
                    const SizedBox(width: 4),
                    // Mở rộng
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: colorScheme.outline,
                    ),
                  ],
                ),

                // ── Nghĩa (luôn hiển thị) ────────────────────────────
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 28),
                  child: Text(
                    widget.word.meaningVi,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurface.withAlpha(180),
                    ),
                  ),
                ),

                // ── Ví dụ (khi mở rộng) ──────────────────────────────
                if (_expanded) ...[
                  const SizedBox(height: 8),
                  Container(
                    margin: const EdgeInsets.only(left: 28),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withAlpha(60),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.format_quote_rounded,
                          size: 16,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: widget.word.id.startsWith('gs12_')
                              ? WordSourceButton(wordId: widget.word.id)
                              : Text(
                                  widget.word.example,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                    color: colorScheme.onSurface.withAlpha(200),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
