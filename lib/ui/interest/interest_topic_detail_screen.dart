import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/app_repository.dart';
import '../../data/asset_seeder.dart';
import '../../data/interest_repository.dart';
import '../../data/models/interest_topic.dart';
import '../../data/models/interest_word.dart';
import '../../navigation/main_shell.dart';
import '../theme/components/app_button.dart';
import '../theme/components/engpass_mascot.dart';

/// Màn hình Chi tiết Lộ trình Học theo Chủ đề Sở thích (Tree Path kiểu EngPass)
/// Tích hợp:
/// - Banner Header chuẩn bản sắc EngPass (Xanh #2563EB) có nút [ 📑 HƯỚNG DẪN ]
/// - Sổ tay Guidebook: Mẹo ngữ pháp & Cụm từ chính có phát âm TTS
/// - Cây Nốt Ziczac 5 mốc liên hoàn (Visual Cards -> Bắt âm phản xạ -> Rương XP -> Flashcards -> Ghép câu)
/// - Linh vật Chú chim xanh EngPass đứng cạnh cổ vũ (không che nốt, không chặn click)
/// - Lưu trữ tiến độ mở khóa cây nốt theo từng chủ đề bền vững qua SharedPreferences
/// - Mỗi Cửa có bộ câu hỏi phong phú (tối thiểu 8-10 câu), học sinh luyện tập sâu và hiệu quả
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

  // Tiến độ cây nốt: 1 đến 5 (lưu SharedPreferences)
  int _unlockedNode = 1;
  int _totalXpEarned = 0;

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadSavedProgress();
    _loadWords();
  }

  void _initTts() {
    _tts.setLanguage('en-US').catchError((_) => null);
    _tts.setSpeechRate(0.44).catchError((_) => null);
  }

  void _speak(String text) {
    _tts.stop().catchError((_) => null);
    _tts.speak(text).catchError((_) => null);
  }

  /// Tải tiến độ mở khóa nốt đã lưu của chủ đề này
  Future<void> _loadSavedProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedNode = prefs.getInt('interest_node_${widget.topic.id}') ?? 1;
      final savedXp = prefs.getInt('interest_xp_${widget.topic.id}') ?? 0;
      if (mounted) {
        setState(() {
          _unlockedNode = savedNode;
          _totalXpEarned = savedXp;
        });
      }
    } catch (_) {}
  }

  /// Lưu tiến độ mở khóa nốt
  Future<void> _saveProgress(int node, int earnedXp) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('interest_node_${widget.topic.id}', node);
      await prefs.setInt('interest_xp_${widget.topic.id}', earnedXp);
    } catch (_) {}
  }

  /// Nạp từ vựng và câu đàm thoại (đồng bộ từ SQLite và fallback từ asset JSON)
  Future<void> _loadWords() async {
    List<InterestWord> words = [];

    // 1. Thử tải từ DB
    try {
      await AssetSeeder.syncInterestWords();
      final repo = InterestRepository();
      words = await repo.getWordsByTopic(widget.topic.id);
    } catch (_) {}

    // 2. Fallback: nếu DB chưa kịp cập nhật hoặc trong test, nạp trực tiếp từ asset json
    if (words.length < 10) {
      try {
        final jsonStr = await rootBundle.loadString('assets/data/interest_words.json');
        final decoded = jsonDecode(jsonStr);
        if (decoded is List) {
          final assetWords = decoded
              .whereType<Map<String, dynamic>>()
              .map(InterestWord.fromMap)
              .where((w) => w.topicId == widget.topic.id)
              .toList();
          if (assetWords.isNotEmpty) {
            words = assetWords;
          }
        }
      } catch (_) {}
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
        return '• Cảm thán trên sân cỏ: "What an incredible goal!"\n• Ra hiệu chuyền bóng: "Pass the ball to me!"\n• Vị trí thi đấu: "He plays as a central striker."';
      case 'it_family':
        return '• Hỏi về anh chị em: "Do you have any brothers or sisters?"\n• Miêu tả tính cách: "My aunt is very kind and supportive."\n• Dùng thì hiện tại đơn để nói về gia đình.';
      case 'it_airport':
        return '• Hỏi vị trí cổng bay: "Where is Gate 14, please?"\n• Chúc thượng lộ bình an: "Have a safe and pleasant flight!"\n• Xuất trình giấy tờ: "Please show your passport and boarding pass."';
      case 'it_dining':
        return '• Đặt bàn: "A table for two, please."\n• Xem thực đơn: "Could we have the menu, please?"\n• Xin hóa đơn: "Could I have the bill, please?"';
      case 'it_gym':
        return '• Hỏi hiệp tập: "How many sets do you have left?"\n• Lời khuyên: "Always warm up before lifting weights."\n• Nhờ đỡ tạ: "Could you spot me on this bench press?"';
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
    if (lower.contains('coffee') || lower.contains('latte') || lower.contains('cappuccino') || lower.contains('espresso')) return Icons.local_cafe_rounded;
    if (lower.contains('tea') || lower.contains('matcha')) return Icons.emoji_food_beverage_rounded;
    if (lower.contains('milk')) return Icons.local_drink_rounded;
    if (lower.contains('sugar') || lower.contains('sweetness')) return Icons.grain_rounded;
    if (lower.contains('bubble') || lower.contains('pearl')) return Icons.bubble_chart_rounded;
    if (lower.contains('ball') || lower.contains('striker') || lower.contains('goal') || lower.contains('penalty') || lower.contains('champion')) return Icons.sports_soccer_rounded;
    if (lower.contains('passport')) return Icons.badge_outlined;
    if (lower.contains('ticket') || lower.contains('boarding')) return Icons.airplane_ticket_rounded;
    if (lower.contains('luggage') || lower.contains('baggage')) return Icons.luggage_rounded;
    if (lower.contains('flight') || lower.contains('gate') || lower.contains('terminal')) return Icons.flight_takeoff_rounded;
    if (lower.contains('sister') || lower.contains('aunt') || lower.contains('mother') || lower.contains('niece')) return Icons.face_3_rounded;
    if (lower.contains('brother') || lower.contains('uncle') || lower.contains('father') || lower.contains('nephew')) return Icons.face_rounded;
    if (lower.contains('workout') || lower.contains('muscle') || lower.contains('dumbbell') || lower.contains('barbell') || lower.contains('gym')) return Icons.fitness_center_rounded;
    if (lower.contains('menu') || lower.contains('food') || lower.contains('delicious') || lower.contains('appetizer') || lower.contains('course')) return Icons.restaurant_rounded;
    if (lower.contains('outfit') || lower.contains('fashion') || lower.contains('shirt') || lower.contains('dress')) return Icons.checkroom_rounded;
    if (lower.contains('movie') || lower.contains('blockbuster') || lower.contains('popcorn') || lower.contains('cinema')) return Icons.movie_filter_rounded;
    if (lower.contains('music') || lower.contains('melody') || lower.contains('concert') || lower.contains('song')) return Icons.music_note_rounded;
    if (lower.contains('code') || lower.contains('developer') || lower.contains('database') || lower.contains('bug') || lower.contains('software')) return Icons.terminal_rounded;
    if (lower.contains('puppy') || lower.contains('dog') || lower.contains('cat') || lower.contains('kitten') || lower.contains('pet')) return Icons.pets_rounded;
    return Icons.menu_book_rounded;
  }

  // --- MỞ BÀI TẬP TƯƠNG TÁC THEO TỪNG CỬA (8-10 CÂU HỎI MỖI CỬA) ---
  void _openInteractiveLesson(int stepNumber) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _InteractiveLessonScreen(
          topic: widget.topic,
          words: _words,
          stepNumber: stepNumber,
          onCompleted: () {
            final nextNode = max(_unlockedNode, stepNumber + 1);
            final newXp = _totalXpEarned + 20;
            setState(() {
              _unlockedNode = nextNode;
              _totalXpEarned = newXp;
            });
            _saveProgress(nextNode, newXp);
            AppRepository().recordStudyReward(
              xp: 20,
              minutes: 3,
              questionsDone: 8,
              correct: 8,
            );
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
                final nextNode = max(_unlockedNode, 4);
                final newXp = _totalXpEarned + 20;
                setState(() {
                  _unlockedNode = nextNode;
                  _totalXpEarned = newXp;
                });
                _saveProgress(nextNode, newXp);
                AppRepository().recordStudyReward(
                  xp: 20,
                  minutes: 2,
                  questionsDone: 1,
                  correct: 1,
                );
                MainShell.markFirstLessonCompleted(context);
              },
              child: const Text('NHẬN THƯỞNG', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _handleBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        body: SafeArea(
          child: Column(
            children: [
              // 1. BANNER HEADER BẢN SẮC ENGPASS (CÓ NÚT HƯỚNG DẪN)
              _buildHeaderBanner(context, isDark),

              // 2. CÂY LỘ TRÌNH NỐT ZICZAC
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                        child: Column(
                          children: [
                            const SizedBox(height: 10),

                            // Cây nốt ziczac kèm Linh vật chim xanh EngPass đứng cạnh (không che nút, không chặn click)
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
                                      badgeLabel: _unlockedNode == 1 ? 'BẮT ĐẦU' : null,
                                      icon: Icons.star_rounded,
                                      offsetX: -40,
                                      isUnlocked: _unlockedNode >= 1,
                                      isCurrent: _unlockedNode == 1,
                                      onTap: () => _openInteractiveLesson(1),
                                      isDark: isDark,
                                    ),
                                    const SizedBox(height: 48),

                                    // NỐT 2: BẮT ÂM & PHẢN XẠ (LISTENING & AUDIO)
                                    _buildTreeNode(
                                      stepNumber: 2,
                                      title: 'Cửa 2: Bắt âm & Phản xạ',
                                      badgeLabel: _unlockedNode == 2 ? 'TIẾP TỤC' : null,
                                      icon: Icons.headphones_rounded,
                                      offsetX: 30,
                                      isUnlocked: _unlockedNode >= 2,
                                      isCurrent: _unlockedNode == 2,
                                      onTap: () => _openInteractiveLesson(2),
                                      isDark: isDark,
                                    ),
                                    const SizedBox(height: 48),

                                    // NỐT 3: RƯƠNG KHO BÁU KINH NGHIỆM
                                    _buildTreeNode(
                                      stepNumber: 3,
                                      title: 'Cửa 3: Rương kinh nghiệm',
                                      badgeLabel: _unlockedNode == 3 ? 'MỞ RƯƠNG' : null,
                                      icon: Icons.card_giftcard_rounded,
                                      offsetX: -20,
                                      isUnlocked: _unlockedNode >= 3,
                                      isCurrent: _unlockedNode == 3,
                                      isChest: true,
                                      onTap: _openTreasureChest,
                                      isDark: isDark,
                                    ),
                                    const SizedBox(height: 48),

                                    // NỐT 4: THỬ THÁCH FLASHCARD NHỚ SÂU
                                    _buildTreeNode(
                                      stepNumber: 4,
                                      title: 'Cửa 4: Flashcard nhớ sâu',
                                      badgeLabel: _unlockedNode == 4 ? 'TIẾP TỤC' : null,
                                      icon: Icons.bolt_rounded,
                                      offsetX: 35,
                                      isUnlocked: _unlockedNode >= 4,
                                      isCurrent: _unlockedNode == 4,
                                      onTap: () => _openInteractiveLesson(4),
                                      isDark: isDark,
                                    ),
                                    const SizedBox(height: 48),

                                    // NỐT 5: VỀ ĐÍCH - GHÉP CÂU ĐÀM THOẠI
                                    _buildTreeNode(
                                      stepNumber: 5,
                                      title: 'Cửa 5: Về đích - Ghép câu',
                                      badgeLabel: _unlockedNode == 5 ? 'VỀ ĐÍCH' : null,
                                      icon: Icons.emoji_events_rounded,
                                      offsetX: 0,
                                      isUnlocked: _unlockedNode >= 5,
                                      isCurrent: _unlockedNode == 5,
                                      onTap: () => _openInteractiveLesson(5),
                                      isDark: isDark,
                                    ),
                                  ],
                                ),

                                // LINH VẬT CHÚ CHIM XANH ENGPASS ĐỨNG CỔ VŨ
                                // Đặt ở right: 12, top: 10 (ngang hàng Cửa 1 vốn lệch trái -40px)
                                // Tuyệt đối KHÔNG đè lên Cửa 2 (vốn nằm ở top: 114, offsetX: +30)
                                // Có IgnorePointer để KHÔNG BAO GIỜ nuốt sự kiện bấm nút của người dùng!
                                Positioned(
                                  right: 12,
                                  top: 10,
                                  child: IgnorePointer(
                                    child: Column(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                                        const EngPassMascot(
                                          mood: MascotMood.cheer,
                                          size: 64,
                                        ),
                                      ],
                                    ),
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
      ),
    );
  }

  // --- WIDGET HEADER BANNER ---
  Widget _buildHeaderBanner(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
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
            onPressed: _handleBack,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'LỘ TRÌNH SỞ THÍCH • CỬA $_unlockedNode/5',
                        style: const TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          color: Colors.white70,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_totalXpEarned > 0) ...[
                      const SizedBox(width: 6),
                      Text(
                        '⚡ +$_totalXpEarned XP',
                        style: const TextStyle(
                          color: Color(0xFFFDE68A),
                          fontWeight: FontWeight.bold,
                          fontSize: 10.5,
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
                    fontSize: 16,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),

          // NÚT HƯỚNG DẪN NỔI BẬT TRÊN BANNER
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF2563EB),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.menu_book_rounded, size: 15),
            label: const Text(
              'HƯỚNG DẪN',
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontWeight: FontWeight.w900,
                fontSize: 11,
                letterSpacing: 0.2,
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
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isUnlocked ? onTap : null,
        child: Column(
          children: [
            // Badge phía trên
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
            Container(
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
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// MODEL CÂU HỎI BÀI HỌC TƯƠNG TÁC
// -----------------------------------------------------------------------------
enum _LessonQuestionType {
  visualChoice,       // Chọn card hình ảnh + từ vựng theo nghĩa tiếng Việt
  listenAndPickWord,  // Nghe audio phát âm -> chọn từ đúng
  listenAndPickMean,  // Nghe audio phát âm -> chọn nghĩa tiếng Việt đúng
  meaningQuiz,        // Trắc nghiệm nghĩa từ vựng
  sentenceBuilder,    // Ghép câu đàm thoại hoàn chỉnh từ các từ xáo trộn
  fillBlank,          // Chọn từ điền vào chỗ trống câu đàm thoại
  flashcard,          // Lật thẻ nhớ sâu 2 mặt (Tiếng Anh <-> Tiếng Việt)
}

class _LessonQuestion {
  final _LessonQuestionType type;
  final String title;
  final String prompt;
  final String? audioText;
  final InterestWord? targetWord;
  final List<InterestWord> wordOptions;
  final List<String> textOptions;
  final int correctOptionIndex;
  final String targetSentence;
  final String sentenceMeaningVi;
  final List<String> scrambledTokens;
  final String? explanation;

  _LessonQuestion({
    required this.type,
    required this.title,
    required this.prompt,
    this.audioText,
    this.targetWord,
    this.wordOptions = const [],
    this.textOptions = const [],
    this.correctOptionIndex = 0,
    this.targetSentence = '',
    this.sentenceMeaningVi = '',
    this.scrambledTokens = const [],
    this.explanation,
  });
}

// -----------------------------------------------------------------------------
// MÀN HÌNH BÀI HỌC TƯƠNG TÁC CHUYÊN SÂU (8-10 CÂU HỎI MỖI CỬA)
// -----------------------------------------------------------------------------
class _InteractiveLessonScreen extends StatefulWidget {
  final InterestTopic topic;
  final List<InterestWord> words;
  final int stepNumber; // 1, 2, 4, 5
  final VoidCallback onCompleted;

  const _InteractiveLessonScreen({
    required this.topic,
    required this.words,
    required this.stepNumber,
    required this.onCompleted,
  });

  @override
  State<_InteractiveLessonScreen> createState() => _InteractiveLessonScreenState();
}

class _InteractiveLessonScreenState extends State<_InteractiveLessonScreen> {
  final FlutterTts _tts = FlutterTts();
  List<_LessonQuestion> _questions = [];
  int _currentIndex = 0;

  // Trạng thái câu hiện tại
  int? _selectedOptionIndex;
  bool _isChecked = false;
  bool _isCorrect = false;
  bool _isFlashcardFlipped = false;

  // Dành riêng cho Sentence Builder
  final List<String> _assembledTokens = [];
  List<String> _activeScrambledTokens = [];

  @override
  void initState() {
    super.initState();
    _initTts();
    _buildQuestionSuite();
  }

  void _initTts() {
    _tts.setLanguage('en-US').catchError((_) => null);
    _tts.setSpeechRate(0.44).catchError((_) => null);
  }

  void _speak(String text) {
    _tts.stop().catchError((_) => null);
    _tts.speak(text).catchError((_) => null);
  }

  /// Sinh bộ 8 - 10 câu hỏi đa dạng theo từng Cửa
  void _buildQuestionSuite() {
    final words = widget.words.where((w) => w.category == 'word').toList();
    final phrases = widget.words.where((w) => w.category == 'phrase').toList();
    final allWords = List<InterestWord>.from(widget.words);

    final questions = <_LessonQuestion>[];
    final rand = Random(widget.stepNumber * 31);

    if (widget.stepNumber == 1) {
      // CỬA 1: TỪ VỰNG TRỰC QUAN (8 CÂU)
      // Dạng 1: Visual Choice (4 câu)
      final sampleWords = List<InterestWord>.from(words)..shuffle(rand);
      for (int i = 0; i < min(4, sampleWords.length); i++) {
        final target = sampleWords[i];
        final options = <InterestWord>[target];
        final pool = words.where((w) => w.id != target.id).toList()..shuffle(rand);
        options.addAll(pool.take(2));
        options.shuffle(rand);

        questions.add(_LessonQuestion(
          type: _LessonQuestionType.visualChoice,
          title: 'TỪ MỚI TRỰC QUAN',
          prompt: 'Đâu là "${target.meaningVi}"?',
          audioText: target.english,
          targetWord: target,
          wordOptions: options,
          correctOptionIndex: options.indexOf(target),
          explanation: '${target.english} (${target.ipa}): ${target.meaningVi}',
        ));
      }

      // Dạng 2: Meaning Quiz (4 câu)
      final quizPool = List<InterestWord>.from(words.reversed)..shuffle(rand);
      for (int i = 0; i < min(4, quizPool.length); i++) {
        final target = quizPool[i];
        final wrongMeanings = words.where((w) => w.id != target.id).map((w) => w.meaningVi).toList()..shuffle(rand);
        final opts = <String>[target.meaningVi, ...wrongMeanings.take(3)]..shuffle(rand);

        questions.add(_LessonQuestion(
          type: _LessonQuestionType.meaningQuiz,
          title: 'TRẮC NGHIỆM TỪ VỰNG',
          prompt: 'Từ "${target.english}" có nghĩa là gì?',
          audioText: target.english,
          targetWord: target,
          textOptions: opts,
          correctOptionIndex: opts.indexOf(target.meaningVi),
          explanation: '${target.english} nghĩa là "${target.meaningVi}". Ví dụ: ${target.exampleEn}',
        ));
      }
    } else if (widget.stepNumber == 2) {
      // CỬA 2: BẮT ÂM & PHẢN XẠ (8 CÂU)
      // Dạng 1: Nghe phát âm chọn từ tiếng Anh (4 câu)
      final listenWords = List<InterestWord>.from(words)..shuffle(rand);
      for (int i = 0; i < min(4, listenWords.length); i++) {
        final target = listenWords[i];
        final wrongWords = words.where((w) => w.id != target.id).map((w) => w.english).toList()..shuffle(rand);
        final opts = <String>[target.english, ...wrongWords.take(3)]..shuffle(rand);

        questions.add(_LessonQuestion(
          type: _LessonQuestionType.listenAndPickWord,
          title: 'BẮT ÂM TỪ VỰNG',
          prompt: 'Bấm vào loa và chọn từ bạn nghe được:',
          audioText: target.english,
          targetWord: target,
          textOptions: opts,
          correctOptionIndex: opts.indexOf(target.english),
          explanation: '${target.english} (${target.ipa}): ${target.meaningVi}',
        ));
      }

      // Dạng 2: Nghe câu đàm thoại chọn nghĩa đúng (4 câu)
      final listenPhrases = List<InterestWord>.from(phrases.isNotEmpty ? phrases : allWords)..shuffle(rand);
      for (int i = 0; i < min(4, listenPhrases.length); i++) {
        final target = listenPhrases[i];
        final wrongMeanings = allWords.where((w) => w.id != target.id).map((w) => w.meaningVi).toList()..shuffle(rand);
        final opts = <String>[target.meaningVi, ...wrongMeanings.take(3)]..shuffle(rand);

        questions.add(_LessonQuestion(
          type: _LessonQuestionType.listenAndPickMean,
          title: 'PHẢN XẠ ĐÀM THOẠI',
          prompt: 'Bấm loa nghe câu và chọn nghĩa tiếng Việt chính xác:',
          audioText: target.english,
          targetWord: target,
          textOptions: opts,
          correctOptionIndex: opts.indexOf(target.meaningVi),
          explanation: '${target.english}\n➜ ${target.meaningVi}',
        ));
      }
    } else if (widget.stepNumber == 4) {
      // CỬA 4: FLASHCARD NHỚ SÂU & NỐI NGHĨA (8 THẺ / CÂU)
      final flashWords = List<InterestWord>.from(words)..shuffle(rand);
      for (int i = 0; i < min(5, flashWords.length); i++) {
        final w = flashWords[i];
        questions.add(_LessonQuestion(
          type: _LessonQuestionType.flashcard,
          title: 'LẬT THẺ NHỚ SÂU',
          prompt: 'Chạm vào thẻ để lật xem phiên âm, nghĩa và ví dụ:',
          audioText: w.english,
          targetWord: w,
          explanation: 'Đã hoàn thành ôn tập thẻ "${w.english}".',
        ));
      }

      // 3 câu điền từ củng cố
      for (int i = 0; i < min(3, phrases.length); i++) {
        final p = phrases[i];
        final cleanSentence = p.english.replaceAll(RegExp(r'[.!?]'), '').trim();
        final tokens = cleanSentence.split(' ');
        if (tokens.length >= 3) {
          final missingIndex = rand.nextInt(tokens.length);
          final missingWord = tokens[missingIndex];
          final promptSentence = tokens.map((t) => t == missingWord ? '_____' : t).join(' ');

          final wrongWords = words.map((w) => w.english).where((w) => w.toLowerCase() != missingWord.toLowerCase()).toList()..shuffle(rand);
          final opts = <String>[missingWord, ...wrongWords.take(3)]..shuffle(rand);

          questions.add(_LessonQuestion(
            type: _LessonQuestionType.fillBlank,
            title: 'ĐIỀN TỪ HOÀN CHỈNH',
            prompt: 'Chọn từ chính xác để hoàn thành câu:\n"$promptSentence"',
            audioText: p.english,
            targetWord: p,
            textOptions: opts,
            correctOptionIndex: opts.indexOf(missingWord),
            explanation: 'Câu hoàn chỉnh: "${p.english}" (${p.meaningVi})',
          ));
        }
      }
    } else {
      // CỬA 5: VỀ ĐÍCH - GHÉP CÂU ĐÀM THOẠI (6 - 8 CÂU)
      final targetPhrases = List<InterestWord>.from(phrases.isNotEmpty ? phrases : allWords)..shuffle(rand);
      final count = min(6, targetPhrases.length);
      for (int i = 0; i < count; i++) {
        final p = targetPhrases[i];
        final cleanSentence = p.english.replaceAll(RegExp(r'[.!?]'), '').trim();
        final tokens = cleanSentence.split(' ');
        final scrambled = List<String>.from(tokens)..shuffle(Random(rand.nextInt(100) + 1));

        questions.add(_LessonQuestion(
          type: _LessonQuestionType.sentenceBuilder,
          title: 'GHÉP CÂU ĐÀM THOẠI',
          prompt: 'Ghép các từ bên dưới để tạo thành câu hoàn chỉnh:',
          audioText: p.english,
          targetWord: p,
          targetSentence: cleanSentence,
          sentenceMeaningVi: p.meaningVi,
          scrambledTokens: scrambled,
          explanation: 'Câu giao tiếp chuẩn: "${p.english}" (${p.meaningVi})',
        ));
      }
    }

    // Nếu questions rỗng (đề phòng dữ liệu lỗi), fallback ít nhất 3 câu
    if (questions.isEmpty && widget.words.isNotEmpty) {
      final w = widget.words.first;
      questions.add(_LessonQuestion(
        type: _LessonQuestionType.meaningQuiz,
        title: 'TỪ VỰNG CHỦ ĐỀ',
        prompt: 'Từ "${w.english}" có nghĩa là gì?',
        audioText: w.english,
        targetWord: w,
        textOptions: [w.meaningVi, 'Nghĩa khác 1', 'Nghĩa khác 2'],
        correctOptionIndex: 0,
      ));
    }

    setState(() {
      _questions = questions;
      _resetCurrentQuestionState();
    });
  }

  void _resetCurrentQuestionState() {
    _selectedOptionIndex = null;
    _isChecked = false;
    _isCorrect = false;
    _isFlashcardFlipped = false;
    _assembledTokens.clear();

    if (_currentIndex < _questions.length) {
      final q = _questions[_currentIndex];
      _activeScrambledTokens = List<String>.from(q.scrambledTokens);
      // Tự động phát âm từ/câu khi mở câu hỏi
      if (q.audioText != null && q.audioText!.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _speak(q.audioText!);
        });
      }
    }
  }

  void _handleClose() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isCompleted = _currentIndex >= _questions.length;
    final progress = _questions.isEmpty
        ? 1.0
        : (_currentIndex / _questions.length).clamp(0.0, 1.0);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleClose();
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.close_rounded, color: isDark ? Colors.white : const Color(0xFF0F172A)),
            onPressed: _handleClose,
          ),
          title: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  'Câu ${_currentIndex + 1}/${max(1, _questions.length)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                    fontSize: 12.5,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: isCompleted
                    ? _buildCompletionStep(isDark)
                    : _buildCurrentQuestion(isDark),
              ),
              if (!isCompleted) _buildBottomBar(isDark),
            ],
          ),
        ),
      ),
    );
  }

  // --- RENDER CÂU HỎI HIỆN TẠI ---
  Widget _buildCurrentQuestion(bool isDark) {
    if (_currentIndex >= _questions.length) return const SizedBox.shrink();
    final q = _questions[_currentIndex];

    switch (q.type) {
      case _LessonQuestionType.visualChoice:
        return _buildVisualChoiceView(q, isDark);
      case _LessonQuestionType.listenAndPickWord:
      case _LessonQuestionType.listenAndPickMean:
      case _LessonQuestionType.meaningQuiz:
      case _LessonQuestionType.fillBlank:
        return _buildMultipleChoiceView(q, isDark);
      case _LessonQuestionType.sentenceBuilder:
        return _buildSentenceBuilderView(q, isDark);
      case _LessonQuestionType.flashcard:
        return _buildFlashcardView(q, isDark);
    }
  }

  // --- DẠNG 1: VISUAL CHOICE CARDS ---
  Widget _buildVisualChoiceView(_LessonQuestion q, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBadge(q.title, const Color(0xFF8B5CF6)),
          const SizedBox(height: 12),
          Text(
            q.prompt,
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontWeight: FontWeight.w900,
              fontSize: 22,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: q.wordOptions.asMap().entries.map((entry) {
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
                          const SizedBox(height: 12),
                          Text(
                            word.english,
                            style: TextStyle(
                              fontFamily: 'BeVietnamPro',
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: isSelected ? const Color(0xFF2563EB) : (isDark ? Colors.white : const Color(0xFF0F172A)),
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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

  // --- DẠNG 2: MULTIPLE CHOICE (TRẮC NGHIỆM / NGHE ÂM THANH) ---
  Widget _buildMultipleChoiceView(_LessonQuestion q, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: ListView(
        children: [
          _buildBadge(q.title, const Color(0xFF2563EB)),
          const SizedBox(height: 12),
          Text(
            q.prompt,
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontWeight: FontWeight.w900,
              fontSize: 20,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),

          // Nút nghe âm thanh nổi bật nếu có audioText
          if (q.audioText != null && q.audioText!.isNotEmpty)
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 20),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.volume_up_rounded, size: 28),
                  label: const Text(
                    'NGHE PHÁT ÂM',
                    style: TextStyle(fontFamily: 'BeVietnamPro', fontWeight: FontWeight.w900, fontSize: 14),
                  ),
                  onPressed: () => _speak(q.audioText!),
                ),
              ),
            ),

          // Danh sách các lựa chọn đáp án
          ...q.textOptions.asMap().entries.map((entry) {
            final idx = entry.key;
            final text = entry.value;
            final isSelected = _selectedOptionIndex == idx;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: _isChecked ? null : () => setState(() => _selectedOptionIndex = idx),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF))
                        : (isDark ? const Color(0xFF1E293B) : Colors.white),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      width: isSelected ? 2.2 : 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
                          border: Border.all(
                            color: isSelected ? const Color(0xFF2563EB) : (isDark ? Colors.white38 : const Color(0xFFCBD5E1)),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            String.fromCharCode(65 + idx),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          text,
                          style: TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: isSelected
                                ? const Color(0xFF2563EB)
                                : (isDark ? Colors.white : const Color(0xFF0F172A)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // --- DẠNG 3: SENTENCE BUILDER (GHÉP CÂU HOÀN CHỈNH) ---
  Widget _buildSentenceBuilderView(_LessonQuestion q, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: ListView(
        children: [
          _buildBadge(q.title, const Color(0xFF10B981)),
          const SizedBox(height: 12),
          Text(
            q.prompt,
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontWeight: FontWeight.w900,
              fontSize: 20,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Ý nghĩa: "${q.sentenceMeaningVi}"',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(height: 20),

          // Khay các từ đã ghép
          Container(
            constraints: const BoxConstraints(minHeight: 74),
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
                      return InkWell(
                        onTap: _isChecked
                            ? null
                            : () {
                                setState(() {
                                  _assembledTokens.removeAt(entry.key);
                                  _activeScrambledTokens.add(token);
                                });
                              },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            token,
                            style: const TextStyle(
                              fontFamily: 'BeVietnamPro',
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 24),

          // Khay các từ xáo trộn để người học chọn
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _activeScrambledTokens.asMap().entries.map((entry) {
              final token = entry.value;
              return InkWell(
                onTap: _isChecked
                    ? null
                    : () {
                        setState(() {
                          _activeScrambledTokens.removeAt(entry.key);
                          _assembledTokens.add(token);
                        });
                        _speak(token);
                      },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    token,
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
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

  // --- DẠNG 4: FLASHCARD LẬT THẺ NHỚ SÂU ---
  Widget _buildFlashcardView(_LessonQuestion q, bool isDark) {
    final word = q.targetWord;
    if (word == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        children: [
          _buildBadge(q.title, const Color(0xFFF59E0B)),
          const SizedBox(height: 12),
          Text(
            q.prompt,
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Thẻ Flashcard tương tác lật 2 mặt
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _isFlashcardFlipped = !_isFlashcardFlipped);
                _speak(word.english);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _isFlashcardFlipped ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withAlpha(25),
                      offset: const Offset(0, 8),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isFlashcardFlipped ? Icons.translate_rounded : Icons.touch_app_rounded,
                      size: 40,
                      color: _isFlashcardFlipped ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      word.english,
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontWeight: FontWeight.w900,
                        fontSize: 26,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      word.ipa,
                      style: const TextStyle(fontSize: 15, color: Color(0xFF2563EB), fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 14),
                    if (_isFlashcardFlipped) ...[
                      Text(
                        word.meaningVi,
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Ví dụ: "${word.exampleEn}"\n(${word.exampleVi})',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontStyle: FontStyle.italic,
                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ] else ...[
                      Text(
                        'Chạm để xem nghĩa tiếng Việt & Ví dụ',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }

  // --- MÀN HÌNH HOÀN THÀNH VINH DANH ---
  Widget _buildCompletionStep(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              const EngPassMascot(
                mood: MascotMood.celebrate,
                size: 112,
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? const Color(0xFF0F172A) : Colors.white,
                    width: 2.5,
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 22),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Hoàn thành Cửa ${widget.stepNumber}!',
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontWeight: FontWeight.w900,
              fontSize: 23,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bạn đã hoàn thành xuất sắc toàn bộ ${_questions.length} câu hỏi luyện tập của Cửa ${widget.stepNumber}.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: isDark ? Colors.white70 : const Color(0xFF64748B),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('⚡', style: TextStyle(fontSize: 22)),
                SizedBox(width: 8),
                Text(
                  '+20 XP KINH NGHIỆM',
                  style: TextStyle(fontFamily: 'BeVietnamPro', fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFFF59E0B)),
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
    if (_currentIndex >= _questions.length) return const SizedBox.shrink();
    final q = _questions[_currentIndex];

    // Đối với Flashcard, chỉ cần nút "ĐÃ THUỘC TỪ NÀY"
    if (q.type == _LessonQuestionType.flashcard) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), width: 1.5)),
        ),
        child: AppButton(
          label: 'ĐÃ THUỘC TỪ NÀY → TIẾP TỤC',
          variant: AppButtonVariant.primary,
          height: 48,
          onPressed: () {
            setState(() {
              _currentIndex++;
              _resetCurrentQuestionState();
            });
          },
        ),
      );
    }

    // Nếu đã bấm Kiểm tra: hiện thông báo Đúng/Sai kèm nút Tiếp tục
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
                    _isCorrect ? 'Chính xác! Làm rất tốt! 🎉' : 'Chưa chính xác!',
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
            if (!_isCorrect && q.explanation != null) ...[
              const SizedBox(height: 6),
              Text(
                'Giải thích: ${q.explanation}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
            const SizedBox(height: 12),
            AppButton(
              label: 'TIẾP TỤC',
              variant: _isCorrect ? AppButtonVariant.success : AppButtonVariant.primary,
              height: 48,
              onPressed: () {
                setState(() {
                  _currentIndex++;
                  _resetCurrentQuestionState();
                });
              },
            ),
          ],
        ),
      );
    }

    // Trạng thái chờ người dùng chọn đáp án và bấm Kiểm tra
    final canCheck = (q.type == _LessonQuestionType.sentenceBuilder && _assembledTokens.isNotEmpty) ||
        (q.type != _LessonQuestionType.sentenceBuilder && _selectedOptionIndex != null);

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
                  _currentIndex++;
                  _resetCurrentQuestionState();
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
              onPressed: canCheck
                  ? () {
                      bool correct = false;
                      if (q.type == _LessonQuestionType.sentenceBuilder) {
                        final assembled = _assembledTokens.join(' ').trim().toLowerCase();
                        final target = q.targetSentence.trim().toLowerCase();
                        correct = (assembled == target);
                      } else {
                        correct = (_selectedOptionIndex == q.correctOptionIndex);
                      }
                      setState(() {
                        _isChecked = true;
                        _isCorrect = correct;
                      });
                      if (correct && q.audioText != null) {
                        _speak(q.audioText!);
                      }
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getWordIcon(String english) {
    final lower = english.toLowerCase();
    if (lower.contains('coffee') || lower.contains('latte') || lower.contains('cappuccino') || lower.contains('espresso')) return Icons.local_cafe_rounded;
    if (lower.contains('tea') || lower.contains('matcha')) return Icons.emoji_food_beverage_rounded;
    if (lower.contains('milk')) return Icons.local_drink_rounded;
    if (lower.contains('sugar') || lower.contains('sweetness')) return Icons.grain_rounded;
    if (lower.contains('bubble') || lower.contains('pearl')) return Icons.bubble_chart_rounded;
    if (lower.contains('ball') || lower.contains('striker') || lower.contains('goal') || lower.contains('penalty')) return Icons.sports_soccer_rounded;
    if (lower.contains('passport')) return Icons.badge_outlined;
    if (lower.contains('ticket') || lower.contains('boarding')) return Icons.airplane_ticket_rounded;
    if (lower.contains('luggage') || lower.contains('baggage')) return Icons.luggage_rounded;
    if (lower.contains('workout') || lower.contains('muscle') || lower.contains('dumbbell') || lower.contains('barbell')) return Icons.fitness_center_rounded;
    if (lower.contains('menu') || lower.contains('food') || lower.contains('delicious')) return Icons.restaurant_rounded;
    return Icons.menu_book_rounded;
  }
}
