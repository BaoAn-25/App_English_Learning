import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../data/models/interest_topic.dart';
import '../../data/models/interest_word.dart';
import '../../navigation/main_shell.dart';
import '../theme/components/app_button.dart';
import 'interest_controller.dart';

/// Màn hình Chi tiết Lộ trình Học theo Chủ đề Sở thích (Tree Path kiểu EngPass)
/// Tích hợp:
/// - Banner Header chuẩn bản sắc EngPass (Xanh #2563EB) có nút [ 📑 HƯỚNG DẪN ]
/// - Sổ tay Guidebook: Mẹo ngữ pháp & Cụm từ chính có phát âm TTS
/// - Cây Nốt Ziczac 5 mốc liên hoàn (Visual Cards -> Nối âm -> Rương XP -> Flashcards -> Ghép câu)
/// - Linh vật Chú chim xanh EngPass đứng cạnh cổ vũ
/// - Dạng bài Visual Choice Cards ("Đâu là 'đường'?") & Sentence Builder (Ghép từ thành câu)
/// - Hỗ trợ cả Light Theme và Dark Theme
class InterestTopicDetailScreen extends StatefulWidget {
  final InterestTopic topic;

  const InterestTopicDetailScreen({super.key, required this.topic});

  @override
  State<InterestTopicDetailScreen> createState() => _InterestTopicDetailScreenState();
}

class _InterestTopicDetailScreenState extends State<InterestTopicDetailScreen> {
  final FlutterTts _tts = FlutterTts();
  List<InterestWord> _words = [];
  bool _isLoading = true;

  // Tiến độ cây nốt: 1 đến 5
  int _unlockedNode = 1;
  int _totalXpEarned = 0;

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadWords();
  }

  void _initTts() {
    try {
      _tts.setLanguage('en-US');
      _tts.setSpeechRate(0.44);
    } catch (_) {}
  }

  void _speak(String text) {
    try {
      _tts.stop();
      _tts.speak(text);
    } catch (_) {}
  }

  Future<void> _loadWords() async {
    final controller = InterestController();
    var words = await controller.getWordsForTopic(widget.topic.id);
    if (words.isEmpty) {
      words = await controller.getAllWords();
    }
    if (!mounted) return;
    setState(() {
      _words = words;
      _isLoading = false;
    });
  }

  // --- MỞ SỔ TAY HƯỚNG DẪN & CỤM TỪ CHÍNH (NÚT HƯỚNG DẪN TRÊN BANNER) ---
  void _openGuidebookModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final phrases = _words.where((w) => w.category == 'phrase').toList();
    final keyWords = _words.where((w) => w.category == 'word').toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollCtrl) {
            return Column(
              children: [
                // Thanh kéo
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                // Tiêu đề BottomSheet
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withAlpha(30),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.menu_book_rounded, color: Color(0xFF2563EB), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sổ tay hướng dẫn & Cụm từ chính',
                              style: TextStyle(
                                fontFamily: 'BeVietnamPro',
                                fontWeight: FontWeight.w800,
                                fontSize: 16.5,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              widget.topic.titleVi,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF2563EB),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Nội dung hướng dẫn
                Expanded(
                  child: ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Khối 1: Mẹo & Cấu trúc ngữ pháp ngắn gọn
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? const Color(0xFF3B82F6) : const Color(0xFFBFDBFE),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.tips_and_updates_rounded, color: Color(0xFF2563EB), size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Cấu trúc câu then chốt',
                                  style: TextStyle(
                                    fontFamily: 'BeVietnamPro',
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14.5,
                                    color: isDark ? Colors.white : const Color(0xFF1E40AF),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _getGrammarTip(widget.topic.id),
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white70 : const Color(0xFF334155),
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Khối 2: Cụm từ chính có loa phát âm
                      Text(
                        'Cụm từ giao tiếp then chốt (Bấm loa nghe âm thanh)',
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (phrases.isEmpty)
                        Text(
                          'Đang cập nhật thêm cụm từ...',
                          style: TextStyle(color: isDark ? Colors.white54 : const Color(0xFF64748B)),
                        ),

                      ...phrases.map((phrase) => _buildPhraseCard(phrase, isDark)),

                      const SizedBox(height: 16),
                      Text(
                        'Từ vựng trọng tâm',
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...keyWords.map((word) => _buildWordCard(word, isDark)),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _getGrammarTip(String topicId) {
    switch (topicId) {
      case 'it_cafe':
        return '• Cách gọi đồ uống lịch sự: "Can I get an iced latte, please?"\n• Hỏi lựa chọn: "Coffee or tea?"\n• Tùy chỉnh khẩu vị: "Fifty percent sweetness and less ice."';
      case 'it_football':
        return '• Cảm thán trên sân cỏ: "What an incredible goal!"\n• Ra hiệu chuyền bóng: "Pass the ball to me!"\n• Vị trí thi đấu: "He plays as a striker."';
      case 'it_family':
        return '• Hỏi về anh chị em: "Do you have a sister or a brother?"\n• Miêu tả tính cách: "My aunt is very funny and kind."\n• Dùng thì hiện tại đơn để nói về gia đình.';
      case 'it_airport':
        return '• Hỏi vị trí cổng bay: "Where is Gate 14, please?"\n• Chúc thượng lộ bình an: "Have a safe flight!"\n• Xuất trình giấy tờ: "Please show your passport and boarding pass."';
      default:
        return '• Sử dụng các mẫu câu ngắn gọn, trực diện.\n• Chú ý ngữ điệu lên giọng ở cuối câu hỏi Yes/No và xuống giọng ở câu hỏi Wh-question.';
    }
  }

  Widget _buildPhraseCard(InterestWord phrase, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          IconButton(
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB).withAlpha(isDark ? 50 : 25),
            ),
            icon: const Icon(Icons.volume_up_rounded, color: Color(0xFF2563EB), size: 22),
            onPressed: () => _speak(phrase.english),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  phrase.english,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  phrase.ipa,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  phrase.meaningVi,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordCard(InterestWord word, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(_getVisualIcon(word.english), size: 20, color: const Color(0xFF2563EB)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${word.english} (${word.ipa}): ${word.meaningVi}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.volume_up_rounded, size: 18, color: Color(0xFF2563EB)),
            onPressed: () => _speak(word.english),
          ),
        ],
      ),
    );
  }

  IconData _getVisualIcon(String english) {
    final lower = english.toLowerCase();
    if (lower.contains('coffee')) return Icons.local_cafe_rounded;
    if (lower.contains('tea')) return Icons.emoji_food_beverage_rounded;
    if (lower.contains('milk')) return Icons.local_drink_rounded;
    if (lower.contains('sugar')) return Icons.grain_rounded;
    if (lower.contains('ball') || lower.contains('striker') || lower.contains('goal')) return Icons.sports_soccer_rounded;
    if (lower.contains('passport')) return Icons.badge_outlined;
    if (lower.contains('ticket') || lower.contains('boarding')) return Icons.airplane_ticket_rounded;
    if (lower.contains('luggage')) return Icons.luggage_rounded;
    if (lower.contains('sister') || lower.contains('aunt')) return Icons.face_3_rounded;
    if (lower.contains('brother') || lower.contains('uncle')) return Icons.face_rounded;
    if (lower.contains('workout') || lower.contains('muscle') || lower.contains('dumbbell')) return Icons.fitness_center_rounded;
    if (lower.contains('menu') || lower.contains('food') || lower.contains('delicious')) return Icons.restaurant_rounded;
    if (lower.contains('outfit') || lower.contains('fashion')) return Icons.checkroom_rounded;
    if (lower.contains('movie') || lower.contains('blockbuster') || lower.contains('popcorn')) return Icons.movie_filter_rounded;
    if (lower.contains('music') || lower.contains('melody') || lower.contains('concert')) return Icons.music_note_rounded;
    if (lower.contains('code') || lower.contains('developer') || lower.contains('database') || lower.contains('bug')) return Icons.terminal_rounded;
    if (lower.contains('puppy') || lower.contains('dog') || lower.contains('cat') || lower.contains('kitten') || lower.contains('pet')) return Icons.pets_rounded;
    return Icons.menu_book_rounded;
  }

  // --- MỞ BÀI TẬP CỬA 1: VISUAL CHOICE CARDS ("ĐÂU LÀ 'ĐƯỜNG'?") ---
  void _openVisualLesson() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _VisualChoiceLessonScreen(
          topic: widget.topic,
          words: _words,
          onCompleted: () {
            setState(() {
              _unlockedNode = max(_unlockedNode, 2);
              _totalXpEarned += 20;
            });
            MainShell.markFirstLessonCompleted(context);
          },
        ),
      ),
    );
  }

  // --- MỞ RƯƠNG XP (CỬA 3) ---
  void _openTreasureChest() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF3C7),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('🎁', style: TextStyle(fontSize: 44)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Mở rương kho báu!',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontWeight: FontWeight.w900,
                  fontSize: 19,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Bạn được thưởng +20 XP vì đã hoàn thành xuất sắc các chặng thử thách.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFCD34D)),
                ),
                child: const Text(
                  '⚡ +20 XP KINH NGHIỆM',
                  style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFB45309)),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(dialogCtx);
                setState(() {
                  _unlockedNode = max(_unlockedNode, 4);
                  _totalXpEarned += 20;
                });
                MainShell.markFirstLessonCompleted(context);
              },
              child: const Text('NHẬN THƯỞNG', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
            : Column(
                children: [
                  // 1. BANNER HEADER BẢN SẮC ENGPASS (CÓ NÚT HƯỚNG DẪN)
                  _buildHeaderBanner(context, isDark),

                  // 2. CÂY LỘ TRÌNH NỐT ZICZAC
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      child: Column(
                        children: [
                          const SizedBox(height: 10),

                          // Cây nốt ziczac kèm Linh vật chim xanh EngPass đứng cạnh
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // Đường nối các nốt
                              Positioned.fill(
                                child: Align(
                                  alignment: Alignment.center,
                                  child: Container(
                                    width: 4,
                                    margin: const EdgeInsets.symmetric(vertical: 40),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                              ),

                              // Danh sách 5 Nốt
                              Column(
                                children: [
                                  // NỐT 1: TỪ VỰNG TRỰC QUAN (VISUAL CARDS)
                                  _buildTreeNode(
                                    stepNumber: 1,
                                    title: 'Cửa 1: Từ vựng trực quan',
                                    badgeLabel: 'BẮT ĐẦU',
                                    icon: Icons.star_rounded,
                                    offsetX: -40,
                                    isUnlocked: _unlockedNode >= 1,
                                    isCurrent: _unlockedNode == 1,
                                    onTap: _openVisualLesson,
                                    isDark: isDark,
                                  ),
                                  const SizedBox(height: 48),

                                  // NỐT 2: NỐI ÂM THANH
                                  _buildTreeNode(
                                    stepNumber: 2,
                                    title: 'Cửa 2: Bắt âm & Phản xạ',
                                    icon: Icons.headphones_rounded,
                                    offsetX: 30,
                                    isUnlocked: _unlockedNode >= 2,
                                    isCurrent: _unlockedNode == 2,
                                    onTap: _openVisualLesson,
                                    isDark: isDark,
                                  ),
                                  const SizedBox(height: 48),

                                  // NỐT 3: RƯƠNG KHO BÁU
                                  _buildTreeNode(
                                    stepNumber: 3,
                                    title: 'Cửa 3: Rương kinh nghiệm',
                                    icon: Icons.card_giftcard_rounded,
                                    offsetX: -20,
                                    isUnlocked: _unlockedNode >= 3,
                                    isCurrent: _unlockedNode == 3,
                                    isChest: true,
                                    onTap: _openTreasureChest,
                                    isDark: isDark,
                                  ),
                                  const SizedBox(height: 48),

                                  // NỐT 4: THỬ THÁCH LẬT THẺ
                                  _buildTreeNode(
                                    stepNumber: 4,
                                    title: 'Cửa 4: Flashcard nhớ sâu',
                                    icon: Icons.bolt_rounded,
                                    offsetX: 35,
                                    isUnlocked: _unlockedNode >= 4,
                                    isCurrent: _unlockedNode == 4,
                                    onTap: _openVisualLesson,
                                    isDark: isDark,
                                  ),
                                  const SizedBox(height: 48),

                                  // NỐT 5: GHÉP CÂU HOÀN CHỈNH
                                  _buildTreeNode(
                                    stepNumber: 5,
                                    title: 'Cửa 5: Về đích - Ghép câu',
                                    icon: Icons.emoji_events_rounded,
                                    offsetX: 0,
                                    isUnlocked: _unlockedNode >= 5,
                                    isCurrent: _unlockedNode == 5,
                                    onTap: _openVisualLesson,
                                    isDark: isDark,
                                  ),
                                ],
                              ),

                              // LINH VẬT CHÚ CHIM XANH ENGPASS ĐỨNG CỔ VŨ
                              Positioned(
                                right: 10,
                                top: 90,
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFF2563EB).withAlpha(100)),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x10000000),
                                            offset: Offset(0, 2),
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                      child: const Text(
                                        'Cố lên bạn ơi! 🚀',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF2563EB),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      width: 68,
                                      height: 68,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x202563EB),
                                            offset: Offset(0, 4),
                                            blurRadius: 10,
                                          ),
                                        ],
                                      ),
                                      child: ClipOval(
                                        child: Image.asset('assets/images/app_logo.png', fit: BoxFit.cover),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 36),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // --- WIDGET HEADER BANNER ---
  Widget _buildHeaderBanner(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x202563EB),
            offset: Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'PHẦN 1, CỬA 1',
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                        color: Colors.white70,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (_totalXpEarned > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        '⚡ +$_totalXpEarned XP',
                        style: const TextStyle(
                          color: Color(0xFFFDE68A),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  widget.topic.titleVi,
                  style: const TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontWeight: FontWeight.w900,
                    fontSize: 16.5,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // NÚT HƯỚNG DẪN NỔI BẬT TRÊN BANNER
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF2563EB),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            icon: const Icon(Icons.menu_book_rounded, size: 16),
            label: const Text(
              'HƯỚNG DẪN',
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontWeight: FontWeight.w900,
                fontSize: 11.5,
                letterSpacing: 0.3,
              ),
            ),
            onPressed: _openGuidebookModal,
          ),
        ],
      ),
    );
  }

  // --- WIDGET NỐT TRONG CÂY LỘ TRÌNH ---
  Widget _buildTreeNode({
    required int stepNumber,
    required String title,
    required IconData icon,
    required double offsetX,
    required bool isUnlocked,
    required bool isCurrent,
    required VoidCallback onTap,
    required bool isDark,
    String? badgeLabel,
    bool isChest = false,
  }) {
    final nodeColor = isUnlocked
        ? (isChest ? const Color(0xFFF59E0B) : const Color(0xFF2563EB))
        : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1));

    return Transform.translate(
      offset: Offset(offsetX, 0),
      child: Column(
        children: [
          // Badge "BẮT ĐẦU" phía trên
          if (badgeLabel != null && isCurrent)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badgeLabel,
                style: const TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  color: Colors.white,
                ),
              ),
            ),

          // Nút tròn
          GestureDetector(
            onTap: isUnlocked ? onTap : null,
            child: Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: nodeColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCurrent ? Colors.white : Colors.transparent,
                  width: isCurrent ? 3.5 : 0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: nodeColor.withAlpha(isUnlocked ? 90 : 20),
                    offset: const Offset(0, 6),
                    blurRadius: 14,
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  isUnlocked ? icon : Icons.lock_rounded,
                  color: Colors.white,
                  size: isChest ? 32 : 30,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: isUnlocked
                  ? (isDark ? Colors.white : const Color(0xFF0F172A))
                  : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Màn hình bài tập tương tác Cửa 1: Visual Choice Cards ("Đâu là 'đường'?") & Sentence Builder
class _VisualChoiceLessonScreen extends StatefulWidget {
  final InterestTopic topic;
  final List<InterestWord> words;
  final VoidCallback onCompleted;

  const _VisualChoiceLessonScreen({
    required this.topic,
    required this.words,
    required this.onCompleted,
  });

  @override
  State<_VisualChoiceLessonScreen> createState() => _VisualChoiceLessonScreenState();
}

class _VisualChoiceLessonScreenState extends State<_VisualChoiceLessonScreen> {
  final FlutterTts _tts = FlutterTts();
  int _currentStep = 0; // 0: Visual Choice, 1: Sentence Builder, 2: Kết quả

  // State Step 0 (Visual Choice)
  late InterestWord _targetWord;
  late List<InterestWord> _options;
  int? _selectedOptionIndex;
  bool _isChecked = false;
  bool _isCorrect = false;

  // State Step 1 (Sentence Builder)
  late String _builderSentence;
  late String _builderSentenceVi;
  late List<String> _scrambledTokens;
  final List<String> _assembledTokens = [];

  @override
  void initState() {
    super.initState();
    _initTts();
    _setupQuestions();
  }

  void _initTts() {
    try {
      _tts.setLanguage('en-US');
      _tts.setSpeechRate(0.44);
    } catch (_) {}
  }

  void _speak(String text) {
    try {
      _tts.stop();
      _tts.speak(text);
    } catch (_) {}
  }

  void _setupQuestions() {
    final vocabWords = widget.words.where((w) => w.category == 'word').toList();
    if (vocabWords.isEmpty) {
      _targetWord = widget.words.first;
      _options = widget.words.take(3).toList();
    } else {
      _targetWord = vocabWords.first;
      final shuffled = List<InterestWord>.from(vocabWords)..shuffle(Random(42));
      _options = shuffled.take(3).toList();
      if (!_options.contains(_targetWord)) {
        _options[0] = _targetWord;
      }
    }

    final phraseList = widget.words.where((w) => w.category == 'phrase').toList();
    if (phraseList.isNotEmpty) {
      final p = phraseList.first;
      _builderSentence = p.english.replaceAll(RegExp(r'[.!?]'), '').trim();
      _builderSentenceVi = p.meaningVi;
    } else {
      _builderSentence = 'What an incredible goal';
      _builderSentenceVi = 'Thật là một bàn thắng không thể tin nổi!';
    }
    _scrambledTokens = _builderSentence.split(' ')..shuffle(Random(12));
  }

  IconData _getWordIcon(String english) {
    final lower = english.toLowerCase();
    if (lower.contains('coffee')) return Icons.local_cafe_rounded;
    if (lower.contains('tea')) return Icons.emoji_food_beverage_rounded;
    if (lower.contains('milk')) return Icons.local_drink_rounded;
    if (lower.contains('sugar')) return Icons.grain_rounded;
    if (lower.contains('ball') || lower.contains('striker') || lower.contains('goal')) return Icons.sports_soccer_rounded;
    if (lower.contains('passport')) return Icons.badge_outlined;
    if (lower.contains('ticket') || lower.contains('boarding')) return Icons.airplane_ticket_rounded;
    if (lower.contains('luggage')) return Icons.luggage_rounded;
    if (lower.contains('sister') || lower.contains('aunt')) return Icons.face_3_rounded;
    if (lower.contains('brother') || lower.contains('uncle')) return Icons.face_rounded;
    if (lower.contains('workout') || lower.contains('muscle') || lower.contains('dumbbell')) return Icons.fitness_center_rounded;
    if (lower.contains('menu') || lower.contains('food')) return Icons.restaurant_rounded;
    return Icons.menu_book_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: _currentStep == 0 ? 0.45 : (_currentStep == 1 ? 0.85 : 1.0),
            minHeight: 8,
            backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '⚡ +20 XP',
                style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFD97706), fontSize: 13),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _currentStep == 0
                  ? _buildVisualChoiceStep(isDark)
                  : (_currentStep == 1 ? _buildSentenceBuilderStep(isDark) : _buildCompletionStep(isDark)),
            ),
            if (_currentStep < 2) _buildBottomBar(isDark),
          ],
        ),
      ),
    );
  }

  // --- STEP 0: VISUAL CHOICE CARDS ("ĐÂU LÀ 'ĐƯỜNG'?") ---
  Widget _buildVisualChoiceStep(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome_rounded, size: 14, color: Color(0xFF8B5CF6)),
                SizedBox(width: 4),
                Text(
                  'TỪ MỚI TRỰC QUAN',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF8B5CF6)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Đâu là "${_targetWord.meaningVi}"?',
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontWeight: FontWeight.w900,
              fontSize: 22,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 24),

          // Lưới các Card hình ảnh trực quan
          Row(
            children: _options.asMap().entries.map((entry) {
              final idx = entry.key;
              final word = entry.value;
              final isSelected = _selectedOptionIndex == idx;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: InkWell(
                    onTap: _isChecked
                        ? null
                        : () {
                            setState(() => _selectedOptionIndex = idx);
                            _speak(word.english);
                          },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 160,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF))
                            : (isDark ? const Color(0xFF1E293B) : Colors.white),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          width: isSelected ? 2.2 : 1.2,
                        ),
                        boxShadow: [
                          if (isSelected)
                            const BoxShadow(
                              color: Color(0x202563EB),
                              offset: Offset(0, 4),
                              blurRadius: 10,
                            ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _getWordIcon(word.english),
                            size: 44,
                            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            word.english,
                            style: TextStyle(
                              fontFamily: 'BeVietnamPro',
                              fontWeight: FontWeight.w800,
                              fontSize: 14.5,
                              color: isSelected ? const Color(0xFF2563EB) : (isDark ? Colors.white : const Color(0xFF0F172A)),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            word.ipa,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // --- STEP 1: SENTENCE BUILDER (GHÉP CÂU) ---
  Widget _buildSentenceBuilderStep(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.dashboard_customize_rounded, size: 14, color: Color(0xFF2563EB)),
                SizedBox(width: 4),
                Text(
                  'GHÉP CÂU HOÀN CHỈNH',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Ghép các từ để tạo thành câu:',
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontWeight: FontWeight.w900,
              fontSize: 20,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Ý nghĩa: "$_builderSentenceVi"',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(height: 24),

          // Ô chứa các từ đã ghép
          Container(
            constraints: const BoxConstraints(minHeight: 70),
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1), width: 1.5),
            ),
            child: _assembledTokens.isEmpty
                ? Center(
                    child: Text(
                      'Chạm vào các từ bên dưới để ghép vào đây',
                      style: TextStyle(color: isDark ? Colors.white38 : const Color(0xFF94A3B8), fontSize: 13),
                    ),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _assembledTokens.asMap().entries.map((entry) {
                      final token = entry.value;
                      return ActionChip(
                        label: Text(token, style: const TextStyle(fontWeight: FontWeight.w700)),
                        backgroundColor: const Color(0xFF2563EB),
                        labelStyle: const TextStyle(color: Colors.white),
                        onPressed: _isChecked
                            ? null
                            : () {
                                setState(() {
                                  _assembledTokens.removeAt(entry.key);
                                  _scrambledTokens.add(token);
                                });
                              },
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 24),

          // Khay các từ xáo trộn để người học chọn
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _scrambledTokens.asMap().entries.map((entry) {
              final token = entry.value;
              return ActionChip(
                label: Text(token, style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                onPressed: _isChecked
                    ? null
                    : () {
                        setState(() {
                          _scrambledTokens.removeAt(entry.key);
                          _assembledTokens.add(token);
                        });
                        _speak(token);
                      },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // --- STEP 2: HOÀN THÀNH VINH DANH ---
  Widget _buildCompletionStep(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: const BoxDecoration(
              color: Color(0xFFDCFCE7),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 64),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Hoàn thành Cửa 1!',
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontWeight: FontWeight.w900,
              fontSize: 22,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Bạn đã hoàn thành xuất sắc các câu hỏi từ vựng trực quan và ghép câu đàm thoại.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: Color(0xFF64748B), height: 1.4),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('⚡', style: TextStyle(fontSize: 22)),
                SizedBox(width: 8),
                Text(
                  '+20 XP KINH NGHIỆM',
                  style: TextStyle(fontFamily: 'BeVietnamPro', fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFFD97706)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          AppButton(
            label: 'TIẾP TỤC CÂY LỘ TRÌNH →',
            isFullWidth: true,
            height: 52,
            variant: AppButtonVariant.primary,
            onPressed: () {
              widget.onCompleted();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  // --- THANH ĐÁY KIỂM TRA ĐỒNG BỘ ---
  Widget _buildBottomBar(bool isDark) {
    if (_isChecked) {
      final color = _isCorrect ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
      final bgColor = _isCorrect
          ? (isDark ? const Color(0xFF143320) : const Color(0xFFDCFCE7))
          : (isDark ? const Color(0xFF3E1D22) : const Color(0xFFFEE2E2));

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(top: BorderSide(color: color, width: 1.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(_isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded, color: color, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _isCorrect ? 'Chính xác! Làm rất tốt!' : 'Chưa chính xác, thử lại nhé!',
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AppButton(
              label: 'TIẾP TỤC',
              variant: _isCorrect ? AppButtonVariant.success : AppButtonVariant.primary,
              height: 48,
              onPressed: () {
                setState(() {
                  _isChecked = false;
                  if (_currentStep == 0) {
                    _currentStep = 1;
                  } else if (_currentStep == 1) {
                    _currentStep = 2;
                  }
                });
              },
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: AppButton(
              label: 'BỎ QUA',
              variant: AppButtonVariant.outlined,
              height: 48,
              onPressed: () {
                setState(() {
                  if (_currentStep == 0) {
                    _currentStep = 1;
                  } else {
                    _currentStep = 2;
                  }
                });
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: AppButton(
              label: 'KIỂM TRA',
              variant: AppButtonVariant.primary,
              height: 48,
              onPressed: () {
                if (_currentStep == 0) {
                  if (_selectedOptionIndex == null) return;
                  final selected = _options[_selectedOptionIndex!];
                  final correct = selected.id == _targetWord.id;
                  setState(() {
                    _isChecked = true;
                    _isCorrect = correct;
                  });
                } else if (_currentStep == 1) {
                  final assembled = _assembledTokens.join(' ');
                  final correct = assembled.toLowerCase() == _builderSentence.toLowerCase();
                  setState(() {
                    _isChecked = true;
                    _isCorrect = correct;
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
