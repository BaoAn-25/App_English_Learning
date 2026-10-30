import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/word.dart';
import 'vocab_provider.dart';
import 'vocab_load_error.dart';

/// Màn hình Ôn luyện ngắt quãng (Spaced Repetition System)
/// Hiện các từ đến hạn ôn và phân loại đúng/sai
class SrsReviewScreen extends StatefulWidget {
  const SrsReviewScreen({super.key});

  @override
  State<SrsReviewScreen> createState() => _SrsReviewScreenState();
}

class _SrsReviewScreenState extends State<SrsReviewScreen> {
  List<Word> _dueWords = [];
  bool _loading = true;
  bool _loadFailed = false;
  int _reviewed = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadDueWords();
    });
  }

  Future<void> _loadDueWords() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    final provider = context.read<VocabProvider>();
    await provider.loadDueWords();
    if (mounted) {
      setState(() {
        _dueWords = List.from(provider.dueWords)..shuffle();
        _loading = false;
        _loadFailed = provider.dueLoadFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Ôn Luyện Ngắt Quãng'),
        centerTitle: true,
        actions: [
          if (!_loading && _dueWords.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '$_reviewed/${_dueWords.length}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadFailed
          ? VocabLoadError(onRetry: _loadDueWords)
          : _dueWords.isEmpty
          ? _EmptyState()
          : _ReviewContent(
              dueWords: _dueWords,
              onComplete: (reviewed, correct) {
                setState(() {
                  _reviewed = reviewed;
                });
                _showSummary(reviewed, correct);
              },
            ),
    );
  }

  void _showSummary(int reviewed, int correct) {
    if (reviewed < _dueWords.length) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.emoji_events_rounded, color: Colors.amber),
            SizedBox(width: 8),
            Expanded(child: Text('Kết quả ôn tập')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Hoàn thành $reviewed từ',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _SummaryChip(count: correct, label: 'Nhớ', color: Colors.green),
                _SummaryChip(
                  count: reviewed - correct,
                  label: 'Chưa nhớ',
                  color: Colors.red,
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Xong'),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  const _SummaryChip({
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}

// ── Màn hình rỗng ─────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 80,
              color: Colors.green.withAlpha(200),
            ),
            const SizedBox(height: 20),
            Text(
              'Không có từ nào cần ôn!',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Học từ vựng qua Flashcard để bắt đầu lịch ôn luyện ngắt quãng.',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface.withAlpha(160),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Quay lại học từ'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Nội dung ôn tập ───────────────────────────────────────────────────────
class _ReviewContent extends StatefulWidget {
  final List<Word> dueWords;
  final void Function(int reviewed, int correct) onComplete;

  const _ReviewContent({required this.dueWords, required this.onComplete});

  @override
  State<_ReviewContent> createState() => _ReviewContentState();
}

class _ReviewContentState extends State<_ReviewContent> {
  int _index = 0;
  int _correct = 0;
  bool _showAnswer = false;
  bool _saving = false;
  bool _completed = false;

  Word get _current => widget.dueWords[_index];

  void _reveal() => setState(() => _showAnswer = true);

  Future<void> _answer(bool isCorrect) async {
    if (_saving || _completed) return;
    setState(() => _saving = true);
    try {
      final provider = context.read<VocabProvider>();
      final id = _current.id;
      if (isCorrect) {
        await provider.markWordCorrect(id);
      } else {
        await provider.markWordWrong(id);
      }
      if (!mounted) return;
      if (isCorrect) _correct++;
      final reviewed = _index + 1;
      _completed = reviewed == widget.dueWords.length;
      widget.onComplete(reviewed, _correct);
      if (!_completed) {
        setState(() {
          _index++;
          _showAnswer = false;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa lưu được tiến độ. Vui lòng thử lại.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final provider = context.watch<VocabProvider>();
    final progress = (_index + 1) / widget.dueWords.length;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // ── Progress ──────────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
          ),
          const SizedBox(height: 24),

          // ── Thẻ câu hỏi ───────────────────────────────────────────
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primaryContainer,
                    colorScheme.secondaryContainer,
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(15),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Label
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withAlpha(30),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Từ tiếng Anh',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.primary,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Từ tiếng Anh
                  Text(
                    _current.english,
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // IPA
                  Text(
                    _current.ipa,
                    style: TextStyle(
                      fontSize: 16,
                      color: colorScheme.onPrimaryContainer.withAlpha(160),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Nút phát âm
                  OutlinedButton.icon(
                    onPressed: () => provider.speak(_current.english),
                    icon: Icon(
                      Icons.volume_up_rounded,
                      color: colorScheme.primary,
                    ),
                    label: Text(
                      'Phát âm',
                      style: TextStyle(color: colorScheme.primary),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: colorScheme.primary),
                    ),
                  ),

                  // ── Câu trả lời (khi đã reveal) ──────────────────
                  if (_showAnswer) ...[
                    const SizedBox(height: 28),
                    const Divider(),
                    const SizedBox(height: 16),
                    Text(
                      _current.meaningVi,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimaryContainer,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _current.example,
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: colorScheme.onPrimaryContainer.withAlpha(180),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Nút hành động ─────────────────────────────────────────
          if (!_showAnswer)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _reveal,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Xem nghĩa', style: TextStyle(fontSize: 16)),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saving || _completed
                        ? null
                        : () => _answer(false),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    label: const Text(
                      'Chưa nhớ',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF5350),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saving || _completed
                        ? null
                        : () => _answer(true),
                    icon: const Icon(Icons.check_rounded, color: Colors.white),
                    label: const Text(
                      'Đã nhớ',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF66BB6A),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
