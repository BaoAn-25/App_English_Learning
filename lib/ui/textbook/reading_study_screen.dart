import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import '../../data/app_repository.dart';
import '../../data/models/attempt.dart';
import '../../data/models/attempt_answer.dart';
import '../../data/models/daily_stat.dart';
import '../../data/models/learning_session.dart';
import '../../data/models/word_progress.dart';
import '../../data/models/wrong_book_entry.dart';
import '../auth/auth_controller.dart';
import '../auth/register_screen.dart';
import '../theme/app_tokens.dart';
import '../theme/components/app_button.dart';

class ReadingStudyScreen extends StatefulWidget {
  final int unitNumber;
  final String unitTitle;
  final String articleTitle;

  const ReadingStudyScreen({
    super.key,
    this.unitNumber = 1,
    this.unitTitle = 'Life Stories We Admire',
    this.articleTitle = 'Steve Jobs: Life and Achievements',
  });

  @override
  State<ReadingStudyScreen> createState() => _ReadingStudyScreenState();
}

class _ReadingStudyScreenState extends State<ReadingStudyScreen> {
  double _fontSize = 16.0;
  final FlutterTts _tts = FlutterTts();

  // Từ điển SGK Unit 1: Steve Jobs (trang 13-14)
  static final Map<String, Map<String, String>> _unit1Dict = {
    'adopted': {
      'word': 'adopted',
      'phonetic': "/əˈdɒptɪd/",
      'pos': '(adj/v-ed)',
      'meaning': 'được nhận nuôi',
      'example': 'He was adopted by Clara and Paul Jobs.',
    },
    'dropped': {
      'word': 'drop out',
      'phonetic': "/drɒp aʊt/",
      'pos': '(phr v)',
      'meaning': 'bỏ học giữa chừng',
      'example': 'Jobs attended Reed College, but dropped out after six months.',
    },
    'electronics': {
      'word': 'electronics',
      'phonetic': "/ɪˌlekˈtrɒnɪks/",
      'pos': '(n)',
      'meaning': 'thiết bị điện tử',
      'example': 'They bonded over their love of electronics.',
    },
    'garage': {
      'word': 'garage',
      'phonetic': "/ˈɡærɑːʒ/",
      'pos': '(n)',
      'meaning': 'nhà để xe',
      'example': 'They started Apple Computers in Jobs\' family garage.',
    },
    'accessible': {
      'word': 'accessible',
      'phonetic': "/əkˈsesəbl/",
      'pos': '(adj)',
      'meaning': 'dễ tiếp cận, dễ sử dụng',
      'example': 'Making computers smaller, cheaper, and accessible to everyday users.',
    },
    'cuttingedge': {
      'word': 'cutting-edge',
      'phonetic': "/ˌkʌtɪŋ ˈedʒ/",
      'pos': '(adj)',
      'meaning': 'tiên tiến, hiện đại nhất',
      'example': 'Apple products were designed to be cutting-edge technology.',
    },
    'animation': {
      'word': 'animation',
      'phonetic': "/ˌænɪˈmeɪʃn/",
      'pos': '(n)',
      'meaning': 'hoạt hình máy tính',
      'example': 'Jobs contributed to computer animation with Pixar.',
    },
    'cancer': {
      'word': 'cancer',
      'phonetic': "/ˈkænsə(r)/",
      'pos': '(n)',
      'meaning': 'bệnh ung thư',
      'example': 'Jobs was diagnosed with a rare form of pancreatic cancer.',
    },
    'passed': {
      'word': 'pass away',
      'phonetic': "/pɑːs əˈweɪ/",
      'pos': '(phr v)',
      'meaning': 'qua đời, mất',
      'example': 'Two months later, he passed away.',
    },
    'genius': {
      'word': 'genius',
      'phonetic': "/ˈdʒiːniəs/",
      'pos': '(n)',
      'meaning': 'thiên tài',
      'example': 'Apple has lost a visionary and creative genius.',
    },
  };

  // Từ điển SGK Unit 3 tương thích ngược
  static final Map<String, Map<String, String>> _unit3Dict = {
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
  };

  Map<String, Map<String, String>> get _activeDictionary =>
      widget.unitNumber == 3 ? _unit3Dict : _unit1Dict;

  Map<String, String>? _selectedWordData;
  bool _isSaved = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final firstKey = _activeDictionary.keys.first;
    _selectedWordData = _activeDictionary[firstKey];
    _initTts();
    _checkSavedState(firstKey);
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
    if (_activeDictionary.containsKey(clean)) {
      setState(() {
        _selectedWordData = _activeDictionary[clean];
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
                      color: AppTokens.primary,
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

  // Danh sách câu hỏi Activity 2 chuẩn SGK Tiếng Anh 12 Unit 1 trang 14
  List<_QuestionItem> _getQuestions() {
    if (widget.unitNumber == 3) {
      return [
        _QuestionItem(
          id: 'u3_rd_q1',
          word: 'What are the students mainly talking about in this passage?',
          options: [
            'A school trip to the forest',
            'Green habits and protecting the environment',
            'Repairing old motorbikes',
            'Buying sports events tickets',
          ],
          correctIndex: 1,
          explanation:
              'Đoạn văn nói về các thói quen xanh (mang bình nước cá nhân, đi bộ, xe đạp) giúp bảo vệ môi trường.',
        ),
      ];
    }

    return [
      _QuestionItem(
        id: 'u1_rd_q1',
        word: '1. adopted (SGK trang 14)',
        options: [
          'A. given birth to',
          'B. taken by another family as their own child',
        ],
        correctIndex: 1,
        explanation:
            'Đoạn A: "His biological parents were not married and gave him up for adoption. He was adopted by Clara and Paul Jobs." -> Được nhận làm con nuôi bởi gia đình khác.',
      ),
      _QuestionItem(
        id: 'u1_rd_q2',
        word: '2. dropped out (SGK trang 14)',
        options: [
          'A. continued to study',
          'B. left school/college before completing your studies',
        ],
        correctIndex: 1,
        explanation:
            'Đoạn A: "Jobs attended Reed College in Oregon, but found the classes boring and dropped out after six months." -> Nghỉ học trước khi tốt nghiệp.',
      ),
      _QuestionItem(
        id: 'u1_rd_q3',
        word: '3. cancer (SGK trang 14)',
        options: [
          'A. a serious disease',
          'B. a dangerous animal',
        ],
        correctIndex: 0,
        explanation:
            'Đoạn C: "In 2003, Jobs was diagnosed with a rare form of pancreatic cancer. He fought the disease for several years..." -> Bệnh hiểm nghèo (ung thư).',
      ),
      _QuestionItem(
        id: 'u1_rd_q4',
        word: '4. passed away (SGK trang 14)',
        options: [
          'A. died',
          'B. went past something',
        ],
        correctIndex: 0,
        explanation:
            'Đoạn C: "He stopped working in August, 2011. Two months later, he passed away." -> Qua đời, mất (cách diễn đạt trang trọng).',
      ),
      _QuestionItem(
        id: 'u1_rd_q5',
        word: '5. genius (SGK trang 14)',
        options: [
          'A. a very intelligent person',
          'B. an ordinary person',
        ],
        correctIndex: 0,
        explanation:
            'Đoạn C: "\'Apple has lost a visionary and creative genius...\'" -> Người xuất chúng, thiên tài.',
      ),
    ];
  }

  void _startQuiz() {
    final questions = _getQuestions();
    final answers = List<int?>.filled(questions.length, null);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (bottomSheetContext, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Bài tập đọc hiểu Activity 2 (${questions.length} câu)',
                      style: const TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppTokens.primary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Text(
                  'Chọn nghĩa phù hợp nhất với các từ/cụm từ in đậm trong SGK trang 13-14.',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: questions.length,
                    separatorBuilder: (context, index) => const Divider(height: 24),
                    itemBuilder: (context, qIdx) {
                      final q = questions[qIdx];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            q.word,
                            style: const TextStyle(
                              fontFamily: 'BeVietnamPro',
                              fontWeight: FontWeight.w700,
                              fontSize: 15.5,
                              color: AppTokens.textMain,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...q.options.asMap().entries.map((opt) {
                            final oIdx = opt.key;
                            final isSel = answers[qIdx] == oIdx;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  setModalState(() {
                                    answers[qIdx] = oIdx;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isSel ? const Color(0xFFEFF6FF) : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSel ? AppTokens.primary : const Color(0xFFE2E8F0),
                                      width: isSel ? 2 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isSel ? Icons.radio_button_checked : Icons.radio_button_off,
                                        color: isSel ? AppTokens.primary : const Color(0xFF94A3B8),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          opt.value,
                                          style: TextStyle(
                                            fontFamily: 'BeVietnamPro',
                                            fontSize: 14,
                                            fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                            color: isSel ? const Color(0xFF1D4ED8) : AppTokens.textMain,
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
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                AppButton(
                  label: 'Nộp bài & Chấm điểm thật',
                  isFullWidth: true,
                  variant: AppButtonVariant.primary,
                  onPressed: () async {
                    if (answers.any((a) => a == null)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Vui lòng hoàn thành tất cả câu hỏi trước khi nộp bài.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      return;
                    }

                    Navigator.pop(ctx);
                    await _submitAndShowResult(questions, answers.cast<int>());
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _submitAndShowResult(
    List<_QuestionItem> questions,
    List<int> answers,
  ) async {
    int correctCount = 0;
    for (int i = 0; i < questions.length; i++) {
      if (answers[i] == questions[i].correctIndex) {
        correctCount++;
      }
    }

    final double score = (correctCount / questions.length) * 10.0;
    final now = DateTime.now();

    AppRepository repo;
    try {
      repo = context.read<AppRepository>();
    } catch (_) {
      repo = AppRepository();
    }

    final authCtrl = AuthController.instance;
    final String ownerId = authCtrl.user.id.isNotEmpty
        ? authCtrl.user.id
        : await repo.getOrCreateGuestSessionId();

    try {
      // 1. Lưu kết quả thi vào SQLite (Attempt + AttemptAnswers + WrongBook + DailyStat)
      final finishedAtEpoch = now.millisecondsSinceEpoch;
      final attempt = Attempt(
        mode: 'practice',
        type: 'reading_study',
        startedAt: finishedAtEpoch - 60000,
        durationSec: 60,
        score: correctCount,
        total: questions.length,
      );

      final wrongEntries = <WrongBookEntry>[];
      final nextReviewAt = now.add(const Duration(days: 1)).millisecondsSinceEpoch;
      for (int i = 0; i < questions.length; i++) {
        if (answers[i] != questions[i].correctIndex) {
          wrongEntries.add(
            WrongBookEntry(
              questionId: questions[i].id,
              wrongCount: 1,
              lastWrongAt: finishedAtEpoch,
              nextReviewAt: nextReviewAt,
            ),
          );
        }
      }

      final dateStr =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final dailyStat = DailyStat(
        date: dateStr,
        xp: correctCount * 10,
        questionsDone: questions.length,
        correct: correctCount,
        minutes: 2,
      );

      await repo.savePracticeResult(
        attempt: attempt,
        buildAnswers: (attemptId) {
          return List.generate(questions.length, (i) {
            final isCorrect = answers[i] == questions[i].correctIndex;
            return AttemptAnswer(
              attemptId: attemptId,
              questionId: questions[i].id,
              chosenIndex: answers[i],
              isCorrect: isCorrect,
            );
          });
        },
        wrongEntries: wrongEntries,
        dailyStat: dailyStat,
        ownerId: ownerId,
      );

      // 2. Cập nhật LearningSession
      await repo.saveLearningSession(
        LearningSession(
          ownerId: ownerId,
          lessonId: 'reading_u${widget.unitNumber}',
          lessonTitle: 'Reading Unit ${widget.unitNumber}: ${widget.articleTitle}',
          lessonType: 'topic',
          status: 'completed',
          currentQuestionIndex: questions.length,
          totalQuestions: questions.length,
          score: correctCount,
          questionIds: questions.map((q) => q.id).toList(),
          selectedAnswers: answers,
        ),
      );
    } catch (e) {
      debugPrint('Error saving reading attempt: $e');
    }

    if (!mounted) return;

    // Hiển thị màn hình kết quả thật với lời mời đăng ký ở cuối (không che kết quả)
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (resultCtx) => Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Kết quả bài làm',
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: AppTokens.textMain,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(resultCtx),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: ListView(
                children: [
                  // Thẻ điểm
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: score >= 6.0 ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: score >= 6.0 ? const Color(0xFF86EFAC) : const Color(0xFFFECACA),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          score >= 6.0 ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                          color: score >= 6.0 ? AppTokens.successGreen : AppTokens.errorRed,
                          size: 36,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Điểm số: ${score.toStringAsFixed(1)} / 10.0',
                                style: TextStyle(
                                  fontFamily: 'BeVietnamPro',
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  color: score >= 6.0 ? AppTokens.successGreen : AppTokens.errorRed,
                                ),
                              ),
                              Text(
                                'Bạn đã trả lời đúng $correctCount / ${questions.length} câu hỏi theo SGK.',
                                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Chi tiết từng câu hỏi & Giải thích SGK:',
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppTokens.textMain,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...questions.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final q = entry.value;
                    final userAns = answers[idx];
                    final isCorrect = userAns == q.correctIndex;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isCorrect ? const Color(0xFFBBF7D0) : const Color(0xFFFECDD3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                color: isCorrect ? AppTokens.successGreen : AppTokens.errorRed,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  q.word,
                                  style: const TextStyle(
                                    fontFamily: 'BeVietnamPro',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14.5,
                                    color: AppTokens.textMain,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Bạn chọn: ${q.options[userAns]}',
                            style: TextStyle(
                              fontSize: 13,
                              color: isCorrect ? AppTokens.successGreen : AppTokens.errorRed,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (!isCorrect)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Đáp án đúng: ${q.options[q.correctIndex]}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTokens.successGreen,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Giải thích: ${q.explanation}',
                              style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 16),

                  // Lời mời đăng ký (chỉ hiển thị nếu là khách, đặt ở cuối kết quả không che lấp)
                  if (authCtrl.user.isGuest) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF93C5FD)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.workspace_premium_rounded, color: AppTokens.primary),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Lưu kết quả học tập vĩnh viễn',
                                  style: TextStyle(
                                    fontFamily: 'BeVietnamPro',
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: AppTokens.textMain,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Kết quả bài làm vừa rồi đang được lưu tạm trên thiết bị này. Đăng ký tài khoản miễn phí để:\n'
                            '• Giữ lại điểm số và sổ câu sai vừa làm.\n'
                            '• Mở khóa bài tập cho toàn bộ 10 Unit.\n'
                            '• Không mất tiến độ khi cài lại máy.',
                            style: TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
                          ),
                          const SizedBox(height: 14),
                          AppButton(
                            label: 'Tạo tài khoản lưu kết quả',
                            variant: AppButtonVariant.primary,
                            isFullWidth: true,
                            onPressed: () {
                              Navigator.pop(resultCtx);
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const RegisterScreen()),
                              );
                            },
                          ),
                          const SizedBox(height: 6),
                          Center(
                            child: TextButton(
                              onPressed: () => Navigator.pop(resultCtx),
                              child: const Text(
                                'Để sau, tiếp tục học thử',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String paragraphA = widget.unitNumber == 3
        ? "Many students today are looking for small ways to protect the environment. Some bring their own bottles to school. Others walk or cycle instead of taking a motorbike. These habits look simple, but when thousands of people share them, they make a massive difference. Adopting green living not only cleans our air but also preserves natural resources for the next generations."
        : "Steven Paul Jobs was born on 24 February, 1955 in San Francisco, USA. His biological parents were not married and gave him up for adoption. He was adopted by Clara and Paul Jobs. In 1971, Jobs met Steve Wozniak, who was five years older than him, but they bonded over their love of electronics. After high school, Jobs attended Reed College in Oregon, but found the classes boring and dropped out after six months.";

    final String paragraphB = widget.unitNumber == 3
        ? ""
        : "When Jobs was 21, he and Wozniak started Apple Computers in Jobs' family garage with money they got by selling Jobs' van and Wozniak's scientific calculator. By making computers smaller, cheaper, and accessible to everyday users, their company became a huge success and sales quickly increased. Although Jobs left Apple in 1985, he returned to his post in 1997 when the company needed new ideas. He helped invent new products such as the iMac, the iBook for students, the iPod music player, and iTunes music software. In 2007, he introduced the touch-screen iPhone which changed the way phones were used. Apple products were not only designed to be cutting-edge technology, but also to be stylish and easy to use. In addition, Jobs contributed to computer animation. In 1986, he bought a small company, which later became Pixar Animation Studios. It produced the first full-length computer-animated film Toy Story, followed by other blockbusters.";

    final String paragraphC = widget.unitNumber == 3
        ? ""
        : "In 2003, Jobs was diagnosed with a rare form of pancreatic cancer. He fought the disease for several years, and stopped working in August, 2011. Two months later, he passed away. He had four children, three with his wife of 20 years and one from a previous relationship. On an Apple web page, a statement reads, 'Apple has lost a visionary and creative genius, and the world has lost an amazing human being.'";

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
                color: AppTokens.primary,
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
                    const SizedBox(height: 6),
                    Text(
                      'SGK Tiếng Anh 12 Global Success · Trang ${widget.unitNumber == 1 ? "13-14" : "36"}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Đoạn A
                    _buildSectionHeader('Đoạn A'),
                    _buildInteractiveParagraph(paragraphA),
                    const SizedBox(height: 16),

                    // Đoạn B (nếu có)
                    if (paragraphB.isNotEmpty) ...[
                      _buildSectionHeader('Đoạn B'),
                      _buildInteractiveParagraph(paragraphB),
                      const SizedBox(height: 16),
                    ],

                    // Đoạn C (nếu có)
                    if (paragraphC.isNotEmpty) ...[
                      _buildSectionHeader('Đoạn C'),
                      _buildInteractiveParagraph(paragraphC),
                      const SizedBox(height: 20),
                    ],

                    // Card Tra Từ Điển Inline
                    if (_selectedWordData != null) _buildInlineDictionaryCard(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Nút "Làm bài tập Activity 2" cố định dưới đáy
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: AppButton(
                label: 'Làm bài tập đọc hiểu SGK (Activity 2)',
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: 'BeVietnamPro',
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: AppTokens.primary,
        ),
      ),
    );
  }

  Widget _buildInteractiveParagraph(String paragraph) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: paragraph.split(' ').map((word) {
        final clean = word.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
        final isHighlighted = clean == (_selectedWordData?['word']?.toLowerCase() ?? '');
        final isKeyWord = _activeDictionary.containsKey(clean);

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
        border: Border.all(color: AppTokens.primary, width: 2),
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
                icon: const Icon(Icons.volume_up_rounded, color: AppTokens.primary),
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
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppTokens.primary),
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

          // Nút Lưu vào sổ từ & Nút AI
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
                        await repo.upsertWordProgress(WordProgress.newWord(matchedWord.id));
                      }

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

class _QuestionItem {
  final String id;
  final String word;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  _QuestionItem({
    required this.id,
    required this.word,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });
}
