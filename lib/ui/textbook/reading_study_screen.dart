import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import '../../data/app_repository.dart';
import '../../data/models/word_progress.dart';
import '../theme/components/app_button.dart';

class ReadingStudyScreen extends StatefulWidget {
  final int unitNumber;
  final String unitTitle;
  final String articleTitle;

  const ReadingStudyScreen({
    super.key,
    this.unitNumber = 3,
    this.unitTitle = 'Green Living',
    this.articleTitle = 'Green Habits for a Better Future',
  });

  @override
  State<ReadingStudyScreen> createState() => _ReadingStudyScreenState();
}

class _ReadingStudyScreenState extends State<ReadingStudyScreen> {
  double _fontSize = 16.0;
  final FlutterTts _tts = FlutterTts();

  // Từ điển tích hợp sẵn các từ khóa của bài đọc SGK 12 Unit 3
  final Map<String, Map<String, String>> _dictionary = {
    'environment': {
      'word': 'environment',
      'phonetic': "/ɪnˈvaɪrənmənt/",
      'pos': '(n)',
      'meaning': 'môi trường',
      'example': 'We should protect the environment.',
    },
    'habits': {
      'word': 'habits',
      'phonetic': "/ˈhæbɪts/",
      'pos': '(n, số nhiều)',
      'meaning': 'thói quen, tập quán',
      'example': 'Good eating habits improve health.',
    },
    'protect': {
      'word': 'protect',
      'phonetic': "/prəˈtekt/",
      'pos': '(v)',
      'meaning': 'bảo vệ, gìn giữ',
      'example': 'We must protect wildlife from extinction.',
    },
    'bottles': {
      'word': 'bottle',
      'phonetic': "/ˈbɒtl/",
      'pos': '(n)',
      'meaning': 'chai, lọ',
      'example': 'Some bring reusable bottles to school.',
    },
    'cycle': {
      'word': 'cycle',
      'phonetic': "/ˈsaɪkl/",
      'pos': '(v)',
      'meaning': 'đi xe đạp',
      'example': 'Cycling reduces carbon emissions.',
    },
    'carbon': {
      'word': 'carbon footprint',
      'phonetic': "/ˌkɑːbən ˈfʊtprɪnt/",
      'pos': '(n)',
      'meaning': 'dấu chân carbon, lượng khí thải',
      'example': 'Switching off lights reduces our carbon footprint.',
    },
    'thousands': {
      'word': 'thousands',
      'phonetic': "/ˈθaʊzndz/",
      'pos': '(n)',
      'meaning': 'hàng nghìn',
      'example': 'Thousands of students join green campaigns.',
    },
  };

  Map<String, String>? _selectedWordData;
  bool _isSaved = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Khởi tạo từ điển mở sẵn từ 'environment'
    _selectedWordData = _dictionary['environment'];
    _initTts();
    _checkSavedState('environment');
  }

  Future<void> _checkSavedState(String rawWord) async {
    final clean = rawWord.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    try {
      AppRepository repo;
      try {
        repo = context.read<AppRepository>();
      } catch (_) {
        repo = AppRepository();
      }
      final allWords = await repo.getAllWords();
      final matchedWord = allWords.where(
        (w) => w.english.trim().toLowerCase() == clean,
      ).firstOrNull;

      if (matchedWord != null) {
        final progress = await repo.getWordProgress(matchedWord.id);
        if (mounted) {
          setState(() {
            _isSaved = progress != null;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isSaved = false;
          });
        }
      }
    } catch (_) {
      // Giữ an toàn
    }
  }

  void _initTts() {
    _tts.setLanguage('en-US');
    _tts.setSpeechRate(0.5);
  }

  Future<void> _speak(String text) async {
    await _tts.speak(text);
  }

  void _onWordTapped(String rawWord) {
    final clean = rawWord.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    if (_dictionary.containsKey(clean)) {
      setState(() {
        _selectedWordData = _dictionary[clean];
        _isSaved = false;
      });
    } else {
      setState(() {
        _selectedWordData = {
          'word': clean,
          'phonetic': "/$clean/",
          'pos': '(từ)',
          'meaning': 'Từ trong SGK Tiếng Anh 12',
          'example': 'Tra từ điển nhanh trong bài đọc Unit ${widget.unitNumber}.',
        };
        _isSaved = false;
      });
    }
    _checkSavedState(clean);
  }

  void _showFontSizeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Cỡ chữ bài đọc'),
          children: [14.0, 16.0, 18.0, 20.0].map((size) {
            return SimpleDialogOption(
              onPressed: () {
                setState(() => _fontSize = size);
                Navigator.pop(context);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      _fontSize == size ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: const Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 12),
                    Text('${size.toInt()} pt', style: TextStyle(fontSize: size)),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  void _startQuiz() {
    // Chuyển sang màn hình quiz đọc hiểu hoặc màn hình chúc mừng
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _buildQuizSheet(ctx),
    );
  }

  Widget _buildQuizSheet(BuildContext ctx) {
    int? selectedAnswer;
    return StatefulBuilder(
      builder: (context, setSheetState) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Câu hỏi luyện tập đọc hiểu (1 câu minh họa)',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'What are the students mainly talking about in this passage?',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 16),
              ...[
                'A school trip to the forest',
                'Green habits and protecting the environment',
                'Repairing old motorbikes',
                'Buying sports events tickets',
              ].asMap().entries.map((entry) {
                final idx = entry.key;
                final text = entry.value;
                final isSelected = selectedAnswer == idx;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => setSheetState(() => selectedAnswer = idx),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Text(
                        text,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const Spacer(),
              AppButton(
                label: 'Kiểm tra câu trả lời',
                isFullWidth: true,
                variant: AppButtonVariant.primary,
                onPressed: () {
                  if (selectedAnswer == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Vui lòng chọn một đáp án trước khi kiểm tra.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  final bool isCorrect = selectedAnswer == 1; // 'Green habits and protecting the environment'
                  if (!mounted) return;
                  showDialog(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: Row(
                        children: [
                          Icon(
                            isCorrect ? Icons.check_circle_rounded : Icons.highlight_off_rounded,
                            color: isCorrect ? const Color(0xFF16A34A) : const Color(0xFFEF4444),
                          ),
                          const SizedBox(width: 8),
                          Text(isCorrect ? 'Chính xác!' : 'Chưa chính xác'),
                        ],
                      ),
                      content: Text(
                        isCorrect
                            ? 'Đáp án đúng là B: Green habits and protecting the environment.\n\nLưu ý: Đây là câu hỏi đọc hiểu luyện tập minh họa và chưa được tính vào điểm số/tiến độ chính thức.'
                            : 'Đáp án đúng là B: Green habits and protecting the environment.\n\nLưu ý: Đây là câu hỏi đọc hiểu luyện tập minh họa và chưa được tính vào điểm số/tiến độ chính thức.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dCtx),
                          child: const Text('Đóng'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const rawParagraph =
        "Many students today are looking for small ways to protect the environment. Some bring their own bottles to school. Others walk or cycle instead of taking a motorbike. These habits look simple, but when thousands of people share them, they make a massive difference. Adopting green living not only cleans our air but also preserves natural resources for the next generations.";

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Unit ${widget.unitNumber} · Reading',
          style: const TextStyle(
            fontFamily: 'BeVietnamPro',
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Chỉnh cỡ chữ',
            icon: const Text(
              'Aa',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: Color(0xFF2563EB),
              ),
            ),
            onPressed: _showFontSizeDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Tiêu đề bài đọc
                    Text(
                      widget.articleTitle,
                      style: const TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Nội dung bài đọc tách từ vựng tương tác
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: rawParagraph.split(' ').map((word) {
                        final clean = word.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
                        final isHighlighted = clean == (_selectedWordData?['word']?.toLowerCase() ?? '');
                        final isKeyWord = _dictionary.containsKey(clean);

                        return GestureDetector(
                          onTap: () => _onWordTapped(clean),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                            decoration: BoxDecoration(
                              color: isHighlighted
                                  ? const Color(0xFFFEF08A)
                                  : (isKeyWord ? const Color(0xFFE0F2FE) : Colors.transparent),
                              borderRadius: BorderRadius.circular(4),
                              border: isHighlighted
                                  ? Border.all(color: const Color(0xFFF59E0B), width: 1.5)
                                  : null,
                            ),
                            child: Text(
                              word,
                              style: TextStyle(
                                fontFamily: 'BeVietnamPro',
                                fontSize: _fontSize,
                                height: 1.6,
                                fontWeight: isHighlighted
                                    ? FontWeight.w800
                                    : (isKeyWord ? FontWeight.w600 : FontWeight.w400),
                                color: isHighlighted
                                    ? const Color(0xFFB45309)
                                    : (isKeyWord ? const Color(0xFF0369A1) : const Color(0xFF1E293B)),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Card Tra Từ Điển Inline Pop-up (Wireframe Cột Bài đọc Ảnh 2)
                    if (_selectedWordData != null) _buildInlineDictionaryCard(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Nút "Làm câu hỏi đọc hiểu" cố định dưới đáy
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: AppButton(
                label: 'Làm câu hỏi đọc hiểu minh họa',
                isFullWidth: true,
                variant: AppButtonVariant.primary,
                height: 52,
                onPressed: _startQuiz,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineDictionaryCard() {
    final word = _selectedWordData!['word'] ?? '';
    final phonetic = _selectedWordData!['phonetic'] ?? '';
    final pos = _selectedWordData!['pos'] ?? '';
    final meaning = _selectedWordData!['meaning'] ?? '';
    final example = _selectedWordData!['example'] ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF3B82F6), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x182563EB),
            offset: Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                word,
                style: const TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                phonetic,
                style: const TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  fontStyle: FontStyle.italic,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.volume_up_rounded, color: Color(0xFF2563EB)),
                onPressed: () => _speak(word),
              ),
            ],
          ),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              style: const TextStyle(fontFamily: 'BeVietnamPro', fontSize: 14, color: Color(0xFF1E293B)),
              children: [
                TextSpan(
                  text: '$pos ',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                ),
                TextSpan(text: meaning),
              ],
            ),
          ),
          if (example.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                example,
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                  color: Color(0xFF475569),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),

          // 2 nút Lưu vào sổ từ & Hỏi gia sư AI
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: _isSaved ? 'Đã lưu vào sổ từ' : 'Lưu vào sổ từ',
                  variant: _isSaved ? AppButtonVariant.success : AppButtonVariant.primary,
                  height: 44,
                  icon: _isSaved ? Icons.check_rounded : Icons.bookmark_add_rounded,
                  onPressed: _isSaving ? null : () async {
                    setState(() {
                      _isSaving = true;
                    });
                    try {
                      AppRepository repo;
                      try {
                        repo = context.read<AppRepository>();
                      } catch (_) {
                        repo = AppRepository();
                      }
                      final allWords = await repo.getAllWords();
                      final matchedWord = allWords.where(
                        (w) => w.english.trim().toLowerCase() == word.trim().toLowerCase(),
                      ).firstOrNull;

                      if (matchedWord == null) {
                        if (!mounted) return;
                        setState(() {
                          _isSaving = false;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Từ "$word" chưa có trong danh mục từ vựng SGK của hệ thống.'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                        return;
                      }

                      final existingProgress = await repo.getWordProgress(matchedWord.id);
                      if (existingProgress == null) {
                        // Chỉ tạo tiến độ mới khi chưa có
                        await repo.upsertWordProgress(WordProgress.newWord(matchedWord.id));
                      }
                      // Nếu đã có tiến độ, giữ nguyên lịch ôn và số lần ôn

                      if (!mounted) return;
                      setState(() {
                        _isSaved = true;
                        _isSaving = false;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Đã lưu từ "$word" vào CSDL ôn tập SRS thành công!'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    } catch (_) {
                      if (!mounted) return;
                      setState(() {
                        _isSaving = false;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Không thể lưu từ "$word" lúc này. Vui lòng thử lại.'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: 'Hỏi gia sư AI',
                  variant: AppButtonVariant.outlined,
                  height: 44,
                  icon: Icons.auto_awesome_rounded,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Gia sư AI: Từ "$word" thường xuất hiện trong đề thi THPT dạng Đọc hiểu & Đồng nghĩa!'),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
