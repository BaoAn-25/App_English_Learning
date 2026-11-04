import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../data/app_repository.dart';
import '../../data/models/word.dart';
import '../../data/trial_lesson_repository.dart';
import '../../navigation/main_shell.dart';
import '../auth/auth_controller.dart';
import '../theme/app_tokens.dart';
import '../theme/components/engpass_mascot.dart';

enum MatchCardType { english, vietnamese }
enum MatchCardStatus { normal, selected, matched, wrong }

class MatchCardItem {
  final String id; // ID duy nhất của thẻ
  final String wordId; // ID cặp từ để so khớp
  final String text;
  final MatchCardType type;
  MatchCardStatus status;

  MatchCardItem({
    required this.id,
    required this.wordId,
    required this.text,
    required this.type,
    this.status = MatchCardStatus.normal,
  });
}

/// Màn hình trò chơi Ghép Thẻ Từ Vựng (Match Game) chuẩn SGK Tiếng Anh 12
class MatchGameScreen extends StatefulWidget {
  final int? initialUnit;
  final List<Word>? customWords;
  final bool isEmbedded;

  const MatchGameScreen({
    super.key,
    this.initialUnit,
    this.customWords,
    this.isEmbedded = false,
  });

  @override
  State<MatchGameScreen> createState() => _MatchGameScreenState();
}

class _MatchGameScreenState extends State<MatchGameScreen> {
  final AppRepository _repo = AppRepository();
  int _selectedUnitFilter = 1; // 0: Tất cả, 1..10: Unit tương ứng

  List<Word> _availableWords = [];
  List<MatchCardItem> _cards = [];
  MatchCardItem? _firstSelectedCard;
  bool _isChecking = false;

  // Đo thời gian thực tế
  late final Stopwatch _stopwatch;
  Timer? _timer;
  int _elapsedSeconds = 0;
  int _matchedPairsCount = 0;
  int _totalPairsCount = 0;
  int _wrongAttempts = 0;

  @override
  void initState() {
    super.initState();
    _selectedUnitFilter = widget.initialUnit ?? 1;
    _stopwatch = Stopwatch()..start();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _stopwatch.isRunning) {
        setState(() {
          _elapsedSeconds = _stopwatch.elapsed.inSeconds;
        });
      }
    });

    _loadWordsAndStartGame();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  void _loadWordsAndStartGame() {
    List<Word> words = [];

    if (widget.customWords != null && widget.customWords!.isNotEmpty) {
      words = List.from(widget.customWords!);
    } else {
      // Nạp từ vựng SGK 12 từ TrialLessonRepository
      if (_selectedUnitFilter == 0) {
        // Tất cả 10 Unit
        for (int u = 1; u <= 10; u++) {
          final l = TrialLessonRepository.instance.getLessonByUnit(u);
          if (l != null) {
            l.vocabulary.forEach((en, vi) {
              words.add(Word(
                id: 'w_${u}_$en',
                topicId: 'topic_12_u$u',
                grade: 12,
                english: en,
                ipa: '',
                meaningVi: vi,
                example: '',
              ));
            });
          }
        }
      } else {
        // Theo Unit cụ thể
        final l = TrialLessonRepository.instance.getLessonByUnit(_selectedUnitFilter);
        if (l != null) {
          l.vocabulary.forEach((en, vi) {
            words.add(Word(
              id: 'w_${_selectedUnitFilter}_$en',
              topicId: 'topic_12_u$_selectedUnitFilter',
              grade: 12,
              english: en,
              ipa: '',
              meaningVi: vi,
              example: '',
            ));
          });
        }
      }
    }

    _availableWords = words;
    _startNewRound();
  }

  void _startNewRound() {
    if (_availableWords.isEmpty) {
      setState(() {
        _cards = [];
      });
      return;
    }

    // Lọc bỏ các từ có nghĩa trùng lặp để tránh mơ hồ
    final uniqueWords = <String, Word>{};
    for (final w in _availableWords) {
      final cleanVi = w.meaningVi.trim().toLowerCase();
      if (!uniqueWords.containsKey(cleanVi)) {
        uniqueWords[cleanVi] = w;
      }
    }

    final pool = uniqueWords.values.toList()..shuffle(Random());
    // Chọn 4 cặp từ cho một ván chơi (8 thẻ trên màn hình)
    final selectedWords = pool.take(min(4, pool.length)).toList();
    _totalPairsCount = selectedWords.length;
    _matchedPairsCount = 0;
    _firstSelectedCard = null;
    _isChecking = false;

    final cardList = <MatchCardItem>[];
    for (int i = 0; i < selectedWords.length; i++) {
      final w = selectedWords[i];
      // Thẻ tiếng Anh
      cardList.add(MatchCardItem(
        id: 'card_en_$i',
        wordId: w.id,
        text: w.english,
        type: MatchCardType.english,
      ));
      // Thẻ nghĩa tiếng Việt
      cardList.add(MatchCardItem(
        id: 'card_vi_$i',
        wordId: w.id,
        text: w.meaningVi,
        type: MatchCardType.vietnamese,
      ));
    }

    // Trộn ngẫu nhiên vị trí các thẻ
    cardList.shuffle(Random());

    _stopwatch.reset();
    _stopwatch.start();
    _elapsedSeconds = 0;

    setState(() {
      _cards = cardList;
    });
  }

  void _onCardTap(MatchCardItem card) async {
    if (_isChecking || card.status == MatchCardStatus.matched) return;

    // Nếu bấm lại chính thẻ đang chọn -> bỏ chọn
    if (_firstSelectedCard?.id == card.id) {
      setState(() {
        card.status = MatchCardStatus.normal;
        _firstSelectedCard = null;
      });
      return;
    }

    // Bấm thẻ đầu tiên
    if (_firstSelectedCard == null) {
      setState(() {
        card.status = MatchCardStatus.selected;
        _firstSelectedCard = card;
      });
      return;
    }

    // Bấm thẻ thứ hai -> Kiểm tra khớp
    final first = _firstSelectedCard!;
    setState(() {
      card.status = MatchCardStatus.selected;
      _isChecking = true;
    });

    // Điều kiện đúng: 1 thẻ tiếng Anh + 1 thẻ tiếng Việt có cùng wordId
    final isMatch = (first.wordId == card.wordId) && (first.type != card.type);

    if (isMatch) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      setState(() {
        first.status = MatchCardStatus.matched;
        card.status = MatchCardStatus.matched;
        _matchedPairsCount++;
        _firstSelectedCard = null;
        _isChecking = false;
      });

      // Kiểm tra hoàn thành ván
      if (_matchedPairsCount >= _totalPairsCount && _totalPairsCount > 0) {
        _stopwatch.stop();
        _onGameCompleted();
      }
    } else {
      // Ghép sai -> Đổi trạng thái wrong, cho thử lại
      _wrongAttempts++;
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      setState(() {
        first.status = MatchCardStatus.wrong;
        card.status = MatchCardStatus.wrong;
      });

      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      setState(() {
        first.status = MatchCardStatus.normal;
        card.status = MatchCardStatus.normal;
        _firstSelectedCard = null;
        _isChecking = false;
      });
    }
  }

  Future<void> _onGameCompleted() async {
    final auth = AuthController.instance;
    final ownerId = auth.isAuthenticated && !auth.user.isGuest
        ? auth.user.id
        : await _repo.getOrCreateGuestSessionId();

    // Lưu kết quả thời gian thực tế vào SQLite
    await _repo.setSetting(
      'match_game_best_${ownerId}_u$_selectedUnitFilter',
      _elapsedSeconds.toString(),
    );
    await _repo.recordStudyReward(
      xp: 15,
      minutes: 2,
      questionsDone: _totalPairsCount,
      correct: _totalPairsCount,
      ownerId: ownerId,
    );

    if (!mounted) return;
    await MainShell.markFirstLessonCompleted(context);
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const EngPassMascot(
                mood: MascotMood.celebrate,
                size: 48,
              ),
              const SizedBox(width: 12),
              Text(
                'Hoàn thành! (+15 XP)',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bạn đã ghép chính xác toàn bộ $_totalPairsCount cặp từ vựng Unit $_selectedUnitFilter!',
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text('Thời gian', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        const SizedBox(height: 2),
                        Text(
                          '${_elapsedSeconds}s',
                          style: TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? const Color(0xFF60A5FA) : AppTokens.primary,
                          ),
                        ),
                      ],
                    ),
                    Container(width: 1, height: 28, color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    Column(
                      children: [
                        Text('Số lần thử lại', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        const SizedBox(height: 2),
                        Text(
                          '$_wrongAttempts',
                          style: TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _wrongAttempts == 0 ? AppTokens.successGreen : const Color(0xFFE11D48),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _startNewRound();
              },
              child: const Text('Chơi lại lượt mới'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTokens.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                if (_selectedUnitFilter < 10) {
                  setState(() {
                    _selectedUnitFilter++;
                  });
                  _loadWordsAndStartGame();
                } else {
                  Navigator.pop(context);
                }
              },
              child: Text(
                _selectedUnitFilter < 10 ? 'Sang Unit ${_selectedUnitFilter + 1}' : 'Đóng',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121620) : const Color(0xFFF8FAFC),
      appBar: widget.isEmbedded
          ? null
          : AppBar(
              backgroundColor: isDark ? const Color(0xFF1E2430) : Colors.white,
              elevation: 0.5,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: isDark ? Colors.white : const Color(0xFF1E293B)),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'Ghép Thẻ Từ Vựng (Match Game)',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),
      body: SafeArea(
        child: Column(
          children: [
            // Bộ lọc chọn Unit
            Container(
              color: isDark ? const Color(0xFF1E2430) : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('Tất cả', 0, isDark),
                    ...List.generate(10, (idx) {
                      final u = idx + 1;
                      return _buildFilterChip('Unit $u', u, isDark);
                    }),
                  ],
                ),
              ),
            ),
            Divider(height: 1, thickness: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),

            // Thanh trạng thái: Thời gian + Nút Trộn lại
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Row(
                    children: [
                      Icon(Icons.timer_outlined, size: 18, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                      const SizedBox(width: 6),
                      Text(
                        'Thời gian: ${_elapsedSeconds}s',
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFF60A5FA) : AppTokens.primary,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Trộn lại', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                    onPressed: _startNewRound,
                  ),
                ],
              ),
            ),

            // Lưới các thẻ từ vựng (Match Cards Grid)
            Expanded(
              child: _cards.isEmpty
                  ? const Center(child: Text('Không có từ vựng phù hợp cho chủ đề này.'))
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GridView.builder(
                        itemCount: _cards.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.55,
                        ),
                        itemBuilder: (ctx, idx) {
                          final card = _cards[idx];
                          return _buildCardWidget(card, isDark);
                        },
                      ),
                    ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, int unit, bool isDark) {
    final isSelected = _selectedUnitFilter == unit;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppTokens.primary,
        backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: isSelected ? Colors.white : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
        ),
        onSelected: (val) {
          if (val && _selectedUnitFilter != unit) {
            setState(() {
              _selectedUnitFilter = unit;
            });
            _loadWordsAndStartGame();
          }
        },
      ),
    );
  }

  Widget _buildCardWidget(MatchCardItem card, bool isDark) {
    Color bg = isDark ? const Color(0xFF1E2430) : Colors.white;
    Color border = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
    Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    Widget? trailingIcon;

    switch (card.status) {
      case MatchCardStatus.normal:
        bg = isDark ? const Color(0xFF1E2430) : Colors.white;
        border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
        textColor = isDark ? Colors.white : const Color(0xFF0F172A);
        break;
      case MatchCardStatus.selected:
        bg = isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF);
        border = isDark ? const Color(0xFF60A5FA) : AppTokens.primary;
        textColor = isDark ? const Color(0xFF93C5FD) : AppTokens.primary;
        break;
      case MatchCardStatus.matched:
        bg = isDark ? const Color(0xFF064E3B) : const Color(0xFFF0FDF4);
        border = isDark ? const Color(0xFF059669) : const Color(0xFF86EFAC);
        textColor = isDark ? const Color(0xFF4ADE80) : const Color(0xFF166534);
        trailingIcon = Icon(Icons.check_circle_rounded, color: isDark ? const Color(0xFF4ADE80) : AppTokens.successGreen, size: 24);
        break;
      case MatchCardStatus.wrong:
        bg = isDark ? const Color(0xFF4C0519) : const Color(0xFFFFF1F2);
        border = isDark ? const Color(0xFFE11D48) : const Color(0xFFFDA4AF);
        textColor = isDark ? const Color(0xFFFDA4AF) : const Color(0xFFBE123C);
        trailingIcon = const Icon(Icons.cancel_rounded, color: AppTokens.errorRed, size: 20);
        break;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _onCardTap(card),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: card.status == MatchCardStatus.normal ? 1.0 : 1.8),
            boxShadow: [
              if (card.status == MatchCardStatus.selected)
                const BoxShadow(
                  color: Color(0x181E3A8A),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                )
              else
                const BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
            ],
          ),
          child: Center(
            child: trailingIcon != null && card.status == MatchCardStatus.matched
                ? trailingIcon
                : Text(
                    card.text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: card.type == MatchCardType.english ? 14 : 12.5,
                      fontWeight: card.type == MatchCardType.english ? FontWeight.w700 : FontWeight.w500,
                      color: textColor,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
        ),
      ),
    );
  }
}
