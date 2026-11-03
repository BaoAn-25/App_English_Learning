import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/interest_topic.dart';
import '../../data/models/interest_word.dart';
import '../theme/components/app_button.dart';
import 'interest_controller.dart';

/// Màn hình Chi tiết Chủ đề với 3 Chế độ học độc đáo: Flashcard (Quizlet) | Nối cặp âm (Duolingo) | Sổ tay Guidebook
class InterestTopicDetailScreen extends StatefulWidget {
  final InterestTopic topic;

  const InterestTopicDetailScreen({super.key, required this.topic});

  @override
  State<InterestTopicDetailScreen> createState() => _InterestTopicDetailScreenState();
}

class _InterestTopicDetailScreenState extends State<InterestTopicDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<InterestWord> _words = [];
  bool _isLoading = true;

  // Flashcard state
  int _cardIndex = 0;
  bool _showBack = false;

  // Audio Matching Game state (Ảnh 3 đợt 2)
  int? _selectedAudioIndex;
  int? _selectedWordIndex;
  final Set<int> _matchedPairs = {}; // Lưu các index đã nối đúng
  List<InterestWord> _gameWords = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadWords();
  }

  Future<void> _loadWords() async {
    final controller = InterestController();
    _words = await controller.getWordsForTopic(widget.topic.id);
    if (_words.isEmpty) {
      // Fallback nếu chủ đề chưa có từ vựng riêng
      _words = await controller.getAllWords();
    }
    // Lấy tối đa 4 từ cho game nối cặp âm thanh
    _gameWords = _words.take(4).toList();

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<InterestController>(
      create: (_) => InterestController(),
      child: Consumer<InterestController>(
        builder: (context, controller, child) {
          return Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0.5,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF0F172A)),
                onPressed: () => Navigator.pop(context),
              ),
              title: Column(
                children: [
                  Text(
                    widget.topic.title,
                    style: const TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    widget.topic.titleVi,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
              bottom: TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF2563EB),
                unselectedLabelColor: const Color(0xFF64748B),
                indicatorColor: const Color(0xFF2563EB),
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontFamily: 'BeVietnamPro', fontWeight: FontWeight.bold, fontSize: 13),
                tabs: const [
                  Tab(icon: Icon(Icons.style_rounded, size: 18), text: 'Flashcard'),
                  Tab(icon: Icon(Icons.extension_rounded, size: 18), text: 'Nối cặp âm'),
                  Tab(icon: Icon(Icons.auto_stories_rounded, size: 18), text: 'Cụm từ chính'),
                ],
              ),
            ),
            body: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildFlashcardTab(controller),
                      _buildAudioMatchingTab(controller),
                      _buildGuidebookTab(controller),
                    ],
                  ),
          );
        },
      ),
    );
  }

  // ==========================================
  // TAB 1: FLASHCARD LẬT 2 MẶT (CHUẨN QUIZLET)
  // ==========================================
  Widget _buildFlashcardTab(InterestController controller) {
    if (_words.isEmpty) return const Center(child: Text('Chưa có từ vựng cho chủ đề này.'));

    final currentWord = _words[_cardIndex];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            // Thanh đếm tiến độ
            Text(
              'Thẻ ${_cardIndex + 1} / ${_words.length}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 13),
            ),
            const SizedBox(height: 12),

            // Thẻ Flashcard chính (Lật 2 mặt)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() => _showBack = !_showBack);
                  if (!_showBack) {
                    controller.speak(currentWord.english);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0C0F172A),
                        offset: Offset(0, 8),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: !_showBack
                      ? _buildCardFront(currentWord, controller)
                      : _buildCardBack(currentWord),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Các nút chuyển thẻ
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Thẻ trước',
                    variant: AppButtonVariant.outlined,
                    height: 48,
                    onPressed: _cardIndex > 0
                        ? () {
                            setState(() {
                              _cardIndex--;
                              _showBack = false;
                            });
                          }
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: AppButton(
                    label: _cardIndex < _words.length - 1 ? 'Thẻ tiếp theo' : 'Hoàn thành',
                    variant: AppButtonVariant.primary,
                    height: 48,
                    onPressed: () {
                      if (_cardIndex < _words.length - 1) {
                        setState(() {
                          _cardIndex++;
                          _showBack = false;
                        });
                        controller.speak(_words[_cardIndex].english);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('🎉 Bạn đã lướt qua toàn bộ Flashcard chủ đề này!'),
                            backgroundColor: Color(0xFF16A34A),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardFront(InterestWord word, InterestController controller) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.volume_up_rounded, color: Color(0xFF2563EB), size: 36),
          onPressed: () => controller.speak(word.english),
        ),
        const SizedBox(height: 12),
        Text(
          word.english,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'BeVietnamPro',
            fontWeight: FontWeight.w900,
            fontSize: 28,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          word.ipa,
          style: const TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 15,
            color: Color(0xFF64748B),
          ),
        ),
        const Spacer(),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.touch_app_rounded, size: 16, color: Color(0xFF94A3B8)),
            SizedBox(width: 6),
            Text(
              'Chạm vào thẻ để xem nghĩa tiếng Việt',
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCardBack(InterestWord word) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text('Ý NGHĨA', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB), fontSize: 11)),
        ),
        const SizedBox(height: 14),
        Text(
          word.meaningVi,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'BeVietnamPro',
            fontWeight: FontWeight.w900,
            fontSize: 24,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 20),
        const Divider(color: Color(0xFFE2E8F0)),
        const SizedBox(height: 14),
        Text(
          '"${word.exampleEn}"',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'BeVietnamPro',
            fontStyle: FontStyle.italic,
            fontSize: 14.5,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          word.exampleVi,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF64748B),
          ),
        ),
        const Spacer(),
        const Text(
          'Chạm để quay lại mặt trước',
          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  // ==============================================================
  // TAB 2: MINI-GAME NỐI CẶP ÂM THANH - CHỮ VIẾT (ẢNH 3 ĐỢT 2)
  // ==============================================================
  Widget _buildAudioMatchingTab(InterestController controller) {
    if (_gameWords.isEmpty) return const Center(child: Text('Không đủ từ vựng để chơi game.'));

    final isAllMatched = _matchedPairs.length == _gameWords.length;

    return Container(
      color: const Color(0xFF131F24), // Tông màu tối đặc trưng Duolingo
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Chọn cặp từ',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontWeight: FontWeight.w900,
              fontSize: 22,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Chạm vào loa bên trái nghe âm thanh rồi chạm nối với từ bên phải',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF778D97)),
          ),
          const SizedBox(height: 24),

          // Lưới 2 cột: Cột trái (4 loa sóng âm) vs Cột phải (4 từ)
          Expanded(
            child: Row(
              children: [
                // CỘT TRÁI: LOA PHÁT SÓNG ÂM
                Expanded(
                  child: Column(
                    children: List.generate(_gameWords.length, (index) {
                      final isMatched = _matchedPairs.contains(index);
                      final isSelected = _selectedAudioIndex == index;

                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: GestureDetector(
                            onTap: isMatched
                                ? null
                                : () {
                                    setState(() => _selectedAudioIndex = index);
                                    controller.speak(_gameWords[index].english);
                                    _checkPairMatch();
                                  },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 100),
                              decoration: BoxDecoration(
                                color: isMatched
                                    ? const Color(0xFF1B2A32).withValues(alpha: 0.3)
                                    : (isSelected ? const Color(0xFF1CB0F6).withValues(alpha: 0.25) : const Color(0xFF202F36)),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isMatched
                                      ? const Color(0xFF58CC02)
                                      : (isSelected ? const Color(0xFF1CB0F6) : const Color(0xFF37464F)),
                                  width: isSelected || isMatched ? 2.2 : 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('${index + 1}', style: const TextStyle(fontSize: 12, color: Color(0xFF778D97), fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 8),
                                  Icon(
                                    isMatched ? Icons.check_circle_rounded : Icons.volume_up_rounded,
                                    color: isMatched ? const Color(0xFF58CC02) : const Color(0xFF1CB0F6),
                                    size: 22,
                                  ),
                                  const SizedBox(width: 6),
                                  const Text('||||||||', style: TextStyle(color: Color(0xFF1CB0F6), fontSize: 13, letterSpacing: 1.5, fontWeight: FontWeight.w900)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(width: 14),

                // CỘT PHẢI: TỪ TIẾNG ANH TƯƠNG ỨNG
                Expanded(
                  child: Column(
                    children: List.generate(_gameWords.length, (index) {
                      final isMatched = _matchedPairs.contains(index);
                      final isSelected = _selectedWordIndex == index;

                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: GestureDetector(
                            onTap: isMatched
                                ? null
                                : () {
                                    setState(() => _selectedWordIndex = index);
                                    _checkPairMatch();
                                  },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 100),
                              decoration: BoxDecoration(
                                color: isMatched
                                    ? const Color(0xFF1B2A32).withValues(alpha: 0.3)
                                    : (isSelected ? const Color(0xFF1CB0F6).withValues(alpha: 0.25) : const Color(0xFF202F36)),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isMatched
                                      ? const Color(0xFF58CC02)
                                      : (isSelected ? const Color(0xFF1CB0F6) : const Color(0xFF37464F)),
                                  width: isSelected || isMatched ? 2.2 : 1.5,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                _gameWords[index].english,
                                style: TextStyle(
                                  fontFamily: 'BeVietnamPro',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: isMatched ? const Color(0xFF58CC02) : Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (isAllMatched) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF20382A),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded, color: Color(0xFF58CC02)),
                  SizedBox(width: 10),
                  Text('Xuất sắc! Bạn đã nối đúng tất cả các cặp từ.', style: TextStyle(color: Color(0xFF58CC02), fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          AppButton(
            label: isAllMatched ? 'CHƠI LẠI VÒNG NÀY' : 'ĐANG GHÉP NỐI...',
            variant: isAllMatched ? AppButtonVariant.success : AppButtonVariant.outlined,
            height: 48,
            onPressed: isAllMatched
                ? () {
                    setState(() {
                      _matchedPairs.clear();
                      _selectedAudioIndex = null;
                      _selectedWordIndex = null;
                    });
                  }
                : null,
          ),
        ],
      ),
    );
  }

  void _checkPairMatch() {
    if (_selectedAudioIndex != null && _selectedWordIndex != null) {
      if (_selectedAudioIndex == _selectedWordIndex) {
        // Nối đúng cặp!
        setState(() {
          _matchedPairs.add(_selectedAudioIndex!);
          _selectedAudioIndex = null;
          _selectedWordIndex = null;
        });
      } else {
        // Nối sai -> giải phóng sau 350ms
        Future.delayed(const Duration(milliseconds: 350), () {
          if (mounted) {
            setState(() {
              _selectedAudioIndex = null;
              _selectedWordIndex = null;
            });
          }
        });
      }
    }
  }

  // ==========================================================
  // TAB 3: SỔ TAY GUIDEBOOK CỤM TỪ ĐÀM THOẠI (ẢNH 5 ĐỢT 2)
  // ==========================================================
  Widget _buildGuidebookTab(InterestController controller) {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _words.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final w = _words[index];

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x060F172A),
                offset: Offset(0, 3),
                blurRadius: 6,
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nút loa tròn phát âm câu
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: IconButton(
                  icon: const Icon(Icons.volume_up_rounded, color: Color(0xFF2563EB), size: 22),
                  onPressed: () => controller.speak(w.english),
                ),
              ),
              const SizedBox(width: 14),

              // Câu đàm thoại và bản dịch tiếng Việt
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      w.english,
                      style: const TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      w.meaningVi,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: Color(0xFF64748B),
                        height: 1.35,
                      ),
                    ),
                    if (w.exampleEn.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                        ),
                        child: Text(
                          'Ví dụ: ${w.exampleEn}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
