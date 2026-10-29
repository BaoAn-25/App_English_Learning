import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/topic.dart';
import '../../data/models/word.dart';
import 'topic_quiz_screen.dart';
import 'vocab_provider.dart';

/// Màn hình Flashcard – lật thẻ với animation 3D
/// Mặt trước: từ tiếng Anh + IPA
/// Mặt sau: nghĩa tiếng Việt + ví dụ
class FlashcardScreen extends StatefulWidget {
  final List<Word> words;
  final String topicTitle;
  final Topic? topic;

  const FlashcardScreen({
    super.key,
    required this.words,
    required this.topicTitle,
    this.topic,
  });

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen>
    with TickerProviderStateMixin {
  late List<Word> _deck;
  int _currentIndex = 0;
  bool _showBack = false;
  bool _hasAnswered = false;
  bool _busy = false;

  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _deck = List.from(widget.words)..shuffle(math.Random());

    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutCubic),
    );

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation =
        Tween<Offset>(begin: Offset.zero, end: const Offset(1.5, 0)).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeInCubic),
        );
  }

  @override
  void dispose() {
    _flipController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  // ── Lật thẻ ─────────────────────────────────────────────────────────────
  void _saveError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chưa lưu được tiến độ. Vui lòng thử lại.')),
    );
  }

  Future<void> _flip() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (_showBack) {
        await _flipController.reverse().orCancel;
      } else {
        if (!_hasAnswered) {
          await context.read<VocabProvider>().markWordSeen(
            _deck[_currentIndex].id,
          );
        }
        if (!mounted) return;
        await _flipController.forward().orCancel;
      }
      if (mounted) setState(() => _showBack = !_showBack);
    } catch (_) {
      _saveError();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _answer(bool correct) async {
    if (_busy || _hasAnswered) return;
    setState(() => _busy = true);
    try {
      final provider = context.read<VocabProvider>();
      final id = _deck[_currentIndex].id;
      if (correct) {
        await provider.markWordCorrect(id);
      } else {
        await provider.markWordWrong(id);
      }
      if (!mounted) return;
      _hasAnswered = true;
      await _nextCard();
    } catch (_) {
      _saveError();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _skipCard() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _nextCard();
    } on TickerCanceled {
      // The route was closed while its transition was running.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _nextCard() async {
    if (_currentIndex >= _deck.length - 1) {
      _showFinished();
      return;
    }
    // Animate slide out
    await _slideController.forward().orCancel;
    if (!mounted) return;
    setState(() {
      _currentIndex++;
      _showBack = false;
      _hasAnswered = false;
    });
    _flipController.reset();
    _slideController.reset();
  }

  void _showFinished() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.celebration_rounded, color: Colors.amber),
            SizedBox(width: 8),
            Text('Hoàn thành!'),
          ],
        ),
        content: Text(
          'Bạn đã ôn xong ${_deck.length} thẻ của chủ đề\n"${widget.topicTitle}".',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _deck.shuffle(math.Random());
                _currentIndex = 0;
                _showBack = false;
                _hasAnswered = false;
                _flipController.reset();
              });
            },
            child: const Text('Học lại'),
          ),
          if (widget.topic != null)
            FilledButton.tonalIcon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TopicQuizScreen(topic: widget.topic!),
                  ),
                );
              },
              icon: const Icon(Icons.quiz_rounded, size: 18),
              label: const Text('Làm bài Quiz'),
            ),
          FilledButton(
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

  @override
  Widget build(BuildContext context) {
    if (_deck.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.topicTitle)),
        body: const Center(child: Text('Chưa có thẻ từ vựng nào.')),
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final word = _deck[_currentIndex];
    final provider = context.watch<VocabProvider>();

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              widget.topicTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${_currentIndex + 1}/${_deck.length}',
              style: TextStyle(fontSize: 12, color: colorScheme.outline),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          children: [
            // ── Progress bar ──────────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (_currentIndex + 1) / _deck.length,
                minHeight: 6,
                backgroundColor: colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
            ),
            const SizedBox(height: 24),

            // ── Thẻ flashcard ─────────────────────────────────────────
            Expanded(
              child: GestureDetector(
                onTap: _busy ? null : _flip,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: AnimatedBuilder(
                    animation: _flipAnimation,
                    builder: (context, child) {
                      final isShowingFront = _flipAnimation.value < 0.5;
                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateY(math.pi * _flipAnimation.value),
                        child: isShowingFront
                            ? _CardFront(word: word, provider: provider)
                            : Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.identity()..rotateY(math.pi),
                                child: _CardBack(
                                  word: word,
                                  provider: provider,
                                ),
                              ),
                      );
                    },
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Hướng dẫn lật ────────────────────────────────────────
            if (!_showBack) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.touch_app_rounded,
                    size: 16,
                    color: colorScheme.outline,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Chạm để xem nghĩa',
                    style: TextStyle(fontSize: 13, color: colorScheme.outline),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // ── Nút đánh giá (chỉ khi đã lật) ───────────────────────
            if (_showBack) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _AnswerButton(
                      label: 'Chưa nhớ',
                      icon: Icons.close_rounded,
                      color: const Color(0xFFEF5350),
                      onPressed: _busy || _hasAnswered
                          ? null
                          : () => _answer(false),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _AnswerButton(
                      label: 'Đã nhớ',
                      icon: Icons.check_rounded,
                      color: const Color(0xFF66BB6A),
                      onPressed: _busy || _hasAnswered
                          ? null
                          : () => _answer(true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // ── Nút bỏ qua ────────────────────────────────────────────
            TextButton(
              onPressed: _busy ? null : _skipCard,
              child: Text(
                _currentIndex < _deck.length - 1 ? 'Bỏ qua →' : 'Hoàn thành',
                style: TextStyle(color: colorScheme.outline),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Mặt trước thẻ ─────────────────────────────────────────────────────────
class _CardFront extends StatelessWidget {
  final Word word;
  final VocabProvider provider;
  const _CardFront({required this.word, required this.provider});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colorScheme.primary, colorScheme.primary.withAlpha(180)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withAlpha(80),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Từ tiếng Anh',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withAlpha(160),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            word.english,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            word.ipa,
            style: TextStyle(
              fontSize: 18,
              color: Colors.white.withAlpha(200),
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 28),
          // Nút phát âm
          InkWell(
            onTap: () => provider.speak(word.english),
            borderRadius: BorderRadius.circular(32),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(40),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white.withAlpha(60)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.volume_up_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Phát âm',
                    style: TextStyle(
                      color: Colors.white.withAlpha(230),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mặt sau thẻ ───────────────────────────────────────────────────────────
class _CardBack extends StatelessWidget {
  final Word word;
  final VocabProvider provider;
  const _CardBack({required this.word, required this.provider});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.primary.withAlpha(80),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Nghĩa tiếng Việt',
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.outline,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            word.meaningVi,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            'Ví dụ',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.outline,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            word.example,
            style: TextStyle(
              fontSize: 15,
              fontStyle: FontStyle.italic,
              color: colorScheme.onSurface.withAlpha(200),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          // Nút phát âm
          InkWell(
            onTap: () => provider.speak(word.english),
            borderRadius: BorderRadius.circular(32),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(32),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.volume_up_rounded,
                    color: colorScheme.onPrimaryContainer,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    word.english,
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Nút đánh giá ─────────────────────────────────────────────────────────
class _AnswerButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  const _AnswerButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white, size: 20),
      label: Text(label, style: const TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 2,
      ),
    );
  }
}
