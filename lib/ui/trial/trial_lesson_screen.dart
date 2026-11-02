import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_repository.dart';
import '../../data/models/attempt.dart';
import '../../data/models/attempt_answer.dart';
import '../../data/models/daily_stat.dart';
import '../../data/models/learning_session.dart';
import '../../data/models/wrong_book_entry.dart';
import '../../data/trial_policy.dart';
import '../../navigation/main_shell.dart';
import '../auth/auth_controller.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';
import '../theme/app_tokens.dart';
import '../theme/components/app_button.dart';

/// Màn hình bài học thử có hướng dẫn dành cho khách mới.
///
/// Nội dung chuẩn SGK Tiếng Anh 12 Global Success Unit 1:
/// - Bài đọc: Steve Jobs: Life and Achievements (Trang in 11)
/// - Từ điển 10 từ vựng cốt lõi in đậm
/// - 5 câu hỏi Activity 2 theo SGK trang in 12
/// - Chấm điểm thật, giải thích chuẩn, đo thời gian thực tế, lưu tiến độ và kết quả vào SQLite
class TrialLessonScreen extends StatefulWidget {
  final int initialStep; // 0: Đọc bài, 1: Làm câu hỏi, 2: Kết quả
  final int initialQuestionIndex;
  final List<int?>? initialAnswers;
  final bool autoOpenQuestions;

  const TrialLessonScreen({
    super.key,
    this.initialStep = 0,
    this.initialQuestionIndex = 0,
    this.initialAnswers,
    this.autoOpenQuestions = false,
  });

  @override
  State<TrialLessonScreen> createState() => _TrialLessonScreenState();
}

class _TrialLessonScreenState extends State<TrialLessonScreen>
    with WidgetsBindingObserver {
  late int _currentStep; // 0: Reading, 1: Questions, 2: Result
  late int _currentQuestionIndex;
  late List<int?> _selectedAnswers;
  late List<bool> _checkedStates;
  bool _isResultSaved = false;
  String? _selectedVocabWord;
  String? _selectedVocabMeaning;

  // Đo thời gian học thực tế
  late final Stopwatch _stopwatch;
  late final int _startedAtEpoch;

  final List<TrialQuestion> _questions = TrialPolicy.unit1Questions;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _stopwatch = Stopwatch()..start();
    _startedAtEpoch = DateTime.now().millisecondsSinceEpoch;

    _currentStep = widget.initialStep;
    _currentQuestionIndex =
        widget.initialQuestionIndex.clamp(0, _questions.length - 1);

    if (widget.initialAnswers != null &&
        widget.initialAnswers!.length == _questions.length) {
      _selectedAnswers = List<int?>.from(widget.initialAnswers!);
    } else {
      _selectedAnswers = List<int?>.filled(_questions.length, null);
    }

    // Đánh dấu các câu đã hoàn thành trước đó khi tiếp tục bài dở
    _checkedStates = List<bool>.generate(_questions.length, (i) {
      return i < _currentQuestionIndex && _selectedAnswers[i] != null;
    });

    if (widget.autoOpenQuestions) {
      _currentStep = 1;
    }

    // Nếu câu hiện tại đã có đáp án và đã được check
    if (_selectedAnswers[_currentQuestionIndex] != null &&
        _currentQuestionIndex < widget.initialQuestionIndex) {
      _checkedStates[_currentQuestionIndex] = true;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopwatch.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Tạm dừng đếm giờ khi app ẩn vào nền, tiếp tục khi mở lại (tránh ghost time)
    if (state == AppLifecycleState.resumed) {
      if (!_stopwatch.isRunning) {
        _stopwatch.start();
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (_stopwatch.isRunning) {
        _stopwatch.stop();
      }
    }
  }

  int get _actualDurationSeconds {
    final secs = _stopwatch.elapsed.inSeconds;
    return secs > 0 ? secs : 1;
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m > 0) {
      return '$m phút ${s.toString().padLeft(2, '0')} giây';
    }
    return '$s giây';
  }

  // --- LƯU TIẾN ĐỘ ĐANG LÀM DỞ ---
  Future<void> _saveInProgressSession() async {
    final repo = _getRepository();
    final authCtrl = AuthController.instance;
    final ownerId = authCtrl.user.id.isNotEmpty
        ? authCtrl.user.id
        : await repo.getOrCreateGuestSessionId();

    final session = LearningSession(
      ownerId: ownerId,
      lessonId: TrialPolicy.trialLessonId,
      lessonTitle: 'Unit 1: ${TrialPolicy.trialArticleTitle}',
      lessonType: 'trial',
      status: 'in_progress',
      currentQuestionIndex: _currentQuestionIndex,
      totalQuestions: _questions.length,
      questionIds: _questions.map((q) => q.id).toList(),
      selectedAnswers: _selectedAnswers,
      nextLessonTitle: 'Hoàn thành bài đọc hiểu Unit 1',
    );

    await repo.saveLearningSession(session);
  }

  // --- LƯU KẾT QUẢ KHI HOÀN THÀNH ---
  Future<void> _saveCompletedResult() async {
    if (_isResultSaved) return;

    final repo = _getRepository();
    final authCtrl = AuthController.instance;
    final ownerId = authCtrl.user.id.isNotEmpty
        ? authCtrl.user.id
        : await repo.getOrCreateGuestSessionId();

    int correctCount = 0;
    for (int i = 0; i < _questions.length; i++) {
      if (_selectedAnswers[i] == _questions[i].correctIndex) {
        correctCount++;
      }
    }

    final durationSec = _actualDurationSeconds;
    final minutes = (durationSec / 60).ceil().clamp(1, 120);
    final now = DateTime.now();
    final finishedAtEpoch = now.millisecondsSinceEpoch;

    try {
      // Đảm bảo các câu hỏi học thử tồn tại trong database để WrongBook tra cứu được
      await repo.insertQuestions(TrialPolicy.questionsAsStandardQuestions);

      final attempt = Attempt(
        mode: 'trial',
        type: 'unit1_reading',
        startedAt: _startedAtEpoch,
        durationSec: durationSec,
        score: correctCount,
        total: _questions.length,
      );

      final wrongEntries = <WrongBookEntry>[];
      final nextReviewAt =
          now.add(const Duration(days: 1)).millisecondsSinceEpoch;
      for (int i = 0; i < _questions.length; i++) {
        if (_selectedAnswers[i] != _questions[i].correctIndex) {
          wrongEntries.add(
            WrongBookEntry(
              questionId: _questions[i].id,
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
        questionsDone: _questions.length,
        correct: correctCount,
        minutes: minutes,
      );

      await repo.savePracticeResult(
        attempt: attempt,
        buildAnswers: (attemptId) {
          return List.generate(_questions.length, (i) {
            final isCorrect =
                _selectedAnswers[i] == _questions[i].correctIndex;
            return AttemptAnswer(
              attemptId: attemptId,
              questionId: _questions[i].id,
              chosenIndex: _selectedAnswers[i] ?? -1,
              isCorrect: isCorrect,
            );
          });
        },
        wrongEntries: wrongEntries,
        dailyStat: dailyStat,
        ownerId: ownerId,
      );

      // Cập nhật session hoàn thành
      await repo.saveLearningSession(
        LearningSession(
          ownerId: ownerId,
          lessonId: TrialPolicy.trialLessonId,
          lessonTitle: 'Unit 1: ${TrialPolicy.trialArticleTitle}',
          lessonType: 'trial',
          status: 'completed',
          currentQuestionIndex: _questions.length,
          totalQuestions: _questions.length,
          score: correctCount,
          questionIds: _questions.map((q) => q.id).toList(),
          selectedAnswers: _selectedAnswers,
          nextLessonTitle: 'Đăng ký tài khoản để mở khóa 10 Unit',
        ),
      );

      _isResultSaved = true;
    } catch (e) {
      debugPrint('Error saving trial result: $e');
    }
  }

  AppRepository _getRepository() {
    try {
      return Provider.of<AppRepository>(context, listen: false);
    } catch (_) {
      return AppRepository();
    }
  }

  // --- XỬ LÝ KHI BẤM BACK / TẠM DỪNG ---
  Future<bool> _handleWillPop() async {
    if (_currentStep == 1) {
      // Đang làm câu hỏi dở, hỏi người dùng trước khi thoát
      final shouldLeave = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.pause_circle_outline_rounded,
                  color: AppTokens.primary),
              SizedBox(width: 8),
              Text(
                'Tạm dừng bài học thử?',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: const Text(
            'Tiến độ và các câu đã làm sẽ được lưu lại. Bạn có thể tiếp tục bất cứ lúc nào từ Trang chủ.',
            style: TextStyle(fontSize: 13.5, color: Color(0xFF475569)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Ở lại học tiếp',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF1F5F9),
                foregroundColor: const Color(0xFF0F172A),
                elevation: 0,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Về Trang chủ'),
            ),
          ],
        ),
      );

      if (shouldLeave == true) {
        await _saveInProgressSession();
        _navigateToHome();
        return false;
      }
      return false;
    } else if (_currentStep == 2) {
      _navigateToHome();
      return false;
    }
    return true;
  }

  void _navigateToHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainShell()),
      (route) => false,
    );
  }

  // --- MỞ MODAL XEM LẠI BÀI ĐỌC (KHÔNG LÀM MẤT TRẠNG THÁI LÀM BÀI) ---
  void _openReadingBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (sheetCtx, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Thanh kéo handle
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Tiêu đề modal
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.menu_book_rounded,
                            color: AppTokens.primary, size: 22),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bài đọc SGK: Steve Jobs (Trang in 11)',
                                style: TextStyle(
                                  fontFamily: 'BeVietnamPro',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Global Success 12 · Unit 1: Life Stories We Admire',
                                style: TextStyle(
                                    fontSize: 12, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: Color(0xFF64748B)),
                          onPressed: () => Navigator.pop(sheetCtx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  // Nội dung bài đọc
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(18),
                      children: [
                        _buildParagraphCard(
                          label: 'Đoạn A: Thời niên thiếu và học tập',
                          text: TrialPolicy.paragraphA,
                        ),
                        const SizedBox(height: 14),
                        _buildParagraphCard(
                          label: 'Đoạn B: Sự nghiệp tại Apple & Pixar',
                          text: TrialPolicy.paragraphB,
                        ),
                        const SizedBox(height: 14),
                        _buildParagraphCard(
                          label: 'Đoạn C: Thử thách, di sản & tôn vinh',
                          text: TrialPolicy.paragraphC,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTokens.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          onPressed: () => Navigator.pop(sheetCtx),
                          child: const Text('Quay lại làm câu hỏi',
                              style: TextStyle(
                                  fontFamily: 'BeVietnamPro',
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentStep == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleWillPop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 20, color: Color(0xFF1E293B)),
            onPressed: () async {
              final nav = Navigator.of(context);
              final canLeave = await _handleWillPop();
              if (canLeave && mounted) {
                nav.pop();
              }
            },
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _currentStep == 0
                    ? '1. Đọc bài & Từ vựng'
                    : (_currentStep == 1
                        ? '2. Bài tập đọc hiểu SGK'
                        : '3. Kết quả bài học'),
                style: const TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTokens.primary,
                ),
              ),
              const Text(
                'Unit 1: Steve Jobs (Trang in 11-12)',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          actions: [
            if (_currentStep == 1) ...[
              // Nút xem lại bài đọc tiện lợi mà không thoát
              IconButton(
                tooltip: 'Xem lại bài đọc SGK',
                icon: const Icon(Icons.menu_book_rounded,
                    color: AppTokens.primary),
                onPressed: _openReadingBottomSheet,
              ),
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Câu ${_currentQuestionIndex + 1}/${_questions.length}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: AppTokens.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        body: SafeArea(
          child: _buildCurrentStepContent(),
        ),
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildReadingStep();
      case 1:
        return _buildQuestionsStep();
      case 2:
      default:
        return _buildResultStep();
    }
  }

  // ==========================================
  // HOẠT ĐỘNG 1: ĐỌC BÀI & TỪ VỰNG SGK TRANG IN 11
  // ==========================================
  Widget _buildReadingStep() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            children: [
              // Banner nguồn gốc rõ ràng theo SGK Global Success 12
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.menu_book_rounded,
                        color: AppTokens.primary, size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bài học thử: Steve Jobs (Trang in 11-12)',
                            style: TextStyle(
                              fontFamily: 'BeVietnamPro',
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: Color(0xFF1E40AF),
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Đọc tiểu sử trang in 11, chạm từ in đậm để tra nghĩa và làm 5 câu hỏi Activity 2 chuẩn SGK Global Success 12 trang in 12.',
                            style: TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF334155),
                                height: 1.35),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Pop-up giải thích từ vựng khi chạm vào từ
              if (_selectedVocabWord != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lightbulb_rounded,
                          color: Color(0xFFD97706), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Từ vựng: "$_selectedVocabWord" nghĩa là $_selectedVocabMeaning',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            size: 16, color: Color(0xFF92400E)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          setState(() {
                            _selectedVocabWord = null;
                            _selectedVocabMeaning = null;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Danh sách 10 từ vựng cốt lõi dạng chip chạm nhanh
              const Text(
                '10 từ vựng trọng tâm trong bài (chạm để xem nghĩa):',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: TrialPolicy.keyVocabulary.entries.map((entry) {
                  final isSelected = _selectedVocabWord == entry.key;
                  return ActionChip(
                    label: Text(
                      entry.key,
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color:
                            isSelected ? Colors.white : const Color(0xFF1E40AF),
                      ),
                    ),
                    backgroundColor:
                        isSelected ? AppTokens.primary : const Color(0xFFEFF6FF),
                    side: const BorderSide(color: Color(0xFFBFDBFE)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    onPressed: () {
                      setState(() {
                        _selectedVocabWord = entry.key;
                        _selectedVocabMeaning = entry.value;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),

              // Thẻ văn bản bài đọc SGK với các từ in đậm được bôi đậm & highlight
              _buildParagraphCard(
                label: 'Đoạn A: Thời niên thiếu và học tập (SGK trang in 11)',
                text: TrialPolicy.paragraphA,
              ),
              const SizedBox(height: 14),
              _buildParagraphCard(
                label: 'Đoạn B: Sự nghiệp tại Apple & Pixar (SGK trang in 11)',
                text: TrialPolicy.paragraphB,
              ),
              const SizedBox(height: 14),
              _buildParagraphCard(
                label: 'Đoạn C: Thử thách, di sản & tôn vinh (SGK trang in 11)',
                text: TrialPolicy.paragraphC,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),

        // Nút chuyển sang làm bài tập
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: AppButton(
            label: 'Làm bài tập đọc hiểu (5 câu) →',
            isFullWidth: true,
            variant: AppButtonVariant.primary,
            height: 52,
            onPressed: () {
              setState(() {
                _currentStep = 1;
              });
              _saveInProgressSession();
            },
          ),
        ),
      ],
    );
  }

  /// Thẻ hiển thị đoạn văn bản có các từ in đậm được làm nổi bật thực tế
  Widget _buildParagraphCard({required String label, required String text}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _buildHighlightedArticleText(text),
        ],
      ),
    );
  }

  /// Bôi đậm và tạo tương tác cho các từ vựng trọng tâm trong bài đọc
  Widget _buildHighlightedArticleText(String text) {
    // Sắp xếp các cụm từ theo độ dài giảm dần để ưu tiên khớp cụm từ nhiều chữ trước
    final keys = TrialPolicy.keyVocabulary.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    final pattern = RegExp(
      '\\b(${keys.map((k) => RegExp.escape(k)).join('|')})\\b',
      caseSensitive: false,
    );

    final spans = <TextSpan>[];
    int start = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(
          text: text.substring(start, match.start),
          style: const TextStyle(
            fontSize: 14.5,
            height: 1.6,
            color: Color(0xFF1E293B),
          ),
        ));
      }

      final matchedWord = match.group(0)!;
      final matchedKey = keys.firstWhere(
        (k) => k.toLowerCase() == matchedWord.toLowerCase(),
        orElse: () => matchedWord,
      );
      final meaning = TrialPolicy.keyVocabulary[matchedKey] ?? '';

      spans.add(
        TextSpan(
          text: matchedWord,
          style: const TextStyle(
            fontSize: 14.5,
            height: 1.6,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1D4ED8),
            backgroundColor: Color(0xFFE0E7FF),
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              setState(() {
                _selectedVocabWord = matchedWord;
                _selectedVocabMeaning = meaning;
              });
            },
        ),
      );

      start = match.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: const TextStyle(
          fontSize: 14.5,
          height: 1.6,
          color: Color(0xFF1E293B),
        ),
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  // ==========================================
  // HOẠT ĐỘNG 2: LÀM BÀI TẬP ACTIVITY 2 (5 CÂU HỎI SGK TRANG IN 12)
  // ==========================================
  Widget _buildQuestionsStep() {
    final question = _questions[_currentQuestionIndex];
    final selectedOption = _selectedAnswers[_currentQuestionIndex];
    final isChecked = _checkedStates[_currentQuestionIndex];
    final isLastQuestion = _currentQuestionIndex == _questions.length - 1;

    return Column(
      children: [
        // Thanh tiến trình trên cùng
        LinearProgressIndicator(
          value: (_currentQuestionIndex + 1) / _questions.length,
          minHeight: 4,
          backgroundColor: const Color(0xFFE2E8F0),
          valueColor: const AlwaysStoppedAnimation<Color>(AppTokens.primary),
        ),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            children: [
              // Tiêu đề hướng dẫn chuẩn SGK trang in 12
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Activity 2 (SGK trang in 12): Chọn nghĩa phù hợp với từ in đậm:',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.menu_book_outlined,
                        size: 16, color: AppTokens.primary),
                    label: const Text(
                      'Đọc lại bài',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppTokens.primary),
                    ),
                    onPressed: _openReadingBottomSheet,
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Tên câu hỏi
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      question.word,
                      style: const TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // KHỐI NGỮ CẢNH CÂU VĂN TRÍCH TỪ SGK (CHƯA DỊCH NGHĨA TRƯỚC KHI NỘP)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.format_quote_rounded,
                                  size: 16, color: Color(0xFF64748B)),
                              SizedBox(width: 6),
                              Text(
                                'Ngữ cảnh trong bài đọc (SGK trang in 11):',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _buildContextSentenceWithHighlight(
                            question.contextSentence,
                            question.targetWord,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Danh sách các lựa chọn
              ...question.options.asMap().entries.map((entry) {
                final optionIdx = entry.key;
                final optionText = entry.value;
                final isSelected = selectedOption == optionIdx;

                Color itemBg = Colors.white;
                Color itemBorder = const Color(0xFFE2E8F0);
                Widget leadingIcon = Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color:
                      isSelected ? AppTokens.primary : const Color(0xFF94A3B8),
                  size: 20,
                );

                if (isChecked) {
                  if (optionIdx == question.correctIndex) {
                    itemBg = const Color(0xFFF0FDF4);
                    itemBorder = const Color(0xFF22C55E);
                    leadingIcon = const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF16A34A), size: 20);
                  } else if (isSelected && optionIdx != question.correctIndex) {
                    itemBg = const Color(0xFFFEF2F2);
                    itemBorder = AppTokens.errorRed;
                    leadingIcon = const Icon(Icons.cancel_rounded,
                        color: AppTokens.errorRed, size: 20);
                  }
                } else if (isSelected) {
                  itemBg = const Color(0xFFEFF6FF);
                  itemBorder = AppTokens.primary;
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: isChecked
                        ? null
                        : () {
                            setState(() {
                              _selectedAnswers[_currentQuestionIndex] = optionIdx;
                            });
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: itemBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: itemBorder, width: isSelected ? 1.8 : 1.0),
                      ),
                      child: Row(
                        children: [
                          leadingIcon,
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              optionText,
                              style: TextStyle(
                                fontFamily: 'BeVietnamPro',
                                fontSize: 14.5,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              // Hộp giải thích xuất hiện ngay sau khi bấm Kiểm tra
              if (isChecked) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: selectedOption == question.correctIndex
                        ? const Color(0xFFF0FDF4)
                        : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selectedOption == question.correctIndex
                          ? const Color(0xFFBBF7D0)
                          : const Color(0xFFFECACA),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Icon(
                              selectedOption == question.correctIndex
                                  ? Icons.check_circle_rounded
                                  : Icons.info_outline_rounded,
                              size: 18,
                              color: selectedOption == question.correctIndex
                                  ? const Color(0xFF16A34A)
                                  : AppTokens.errorRed,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              selectedOption == question.correctIndex
                                  ? 'Chính xác!'
                                  : 'Chưa chính xác (Đáp án đúng: ${question.options[question.correctIndex]})',
                              style: TextStyle(
                                fontFamily: 'BeVietnamPro',
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: selectedOption == question.correctIndex
                                    ? const Color(0xFF16A34A)
                                    : AppTokens.errorRed,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Phân định rõ ràng: Trích đoạn SGK vs Lời giải biên soạn
                      Text(
                        '• Trích dẫn SGK (trang in 11): "${question.textbookQuote}"',
                        style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF334155),
                            height: 1.4),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '• Lời giải biên soạn: ${question.explanation}',
                        style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                            height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // Nút hành động ở đáy màn hình
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: !isChecked
              ? AppButton(
                  label: 'Kiểm tra',
                  isFullWidth: true,
                  variant: AppButtonVariant.primary,
                  height: 50,
                  onPressed: selectedOption == null
                      ? null
                      : () {
                          setState(() {
                            _checkedStates[_currentQuestionIndex] = true;
                          });
                          _saveInProgressSession();
                        },
                )
              : AppButton(
                  label: isLastQuestion
                      ? 'Xem kết quả bài học →'
                      : 'Tiếp tục câu tiếp theo →',
                  isFullWidth: true,
                  variant: AppButtonVariant.primary,
                  height: 50,
                  onPressed: () async {
                    if (isLastQuestion) {
                      await _saveCompletedResult();
                      setState(() {
                        _currentStep = 2;
                      });
                    } else {
                      setState(() {
                        _currentQuestionIndex++;
                      });
                      _saveInProgressSession();
                    }
                  },
                ),
        ),
      ],
    );
  }

  /// Trích xuất câu văn ngữ cảnh và bôi đậm từ hỏi mà KHÔNG tiết lộ đáp án
  Widget _buildContextSentenceWithHighlight(
      String contextSentence, String targetWord) {
    final lowerSentence = contextSentence.toLowerCase();
    final lowerTarget = targetWord.toLowerCase();
    final index = lowerSentence.indexOf(lowerTarget);

    if (index == -1) {
      return Text(
        '"$contextSentence"',
        style: const TextStyle(
          fontSize: 13,
          fontStyle: FontStyle.italic,
          color: Color(0xFF1E293B),
          height: 1.45,
        ),
      );
    }

    final before = contextSentence.substring(0, index);
    final match =
        contextSentence.substring(index, index + targetWord.length);
    final after = contextSentence.substring(index + targetWord.length);

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 13,
          fontStyle: FontStyle.italic,
          color: Color(0xFF334155),
          height: 1.45,
        ),
        children: [
          const TextSpan(text: '"'),
          TextSpan(text: before),
          TextSpan(
            text: match,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.normal,
              color: Color(0xFF1D4ED8),
              backgroundColor: Color(0xFFDBEAFE),
            ),
          ),
          TextSpan(text: after),
          const TextSpan(text: '"'),
        ],
      ),
    );
  }

  // ==========================================
  // HOẠT ĐỘNG 3: KẾT QUẢ THẬT & ĐỊNH HƯỚNG
  // ==========================================
  Widget _buildResultStep() {
    int correctCount = 0;
    for (int i = 0; i < _questions.length; i++) {
      if (_selectedAnswers[i] == _questions[i].correctIndex) {
        correctCount++;
      }
    }
    final double score = (correctCount / _questions.length) * 10.0;
    final authCtrl = AuthController.instance;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // Thẻ điểm số thật & thời gian học thực tế
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: score >= 6.0
                  ? const Color(0xFF86EFAC)
                  : const Color(0xFFFECACA),
              width: 1.5,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                offset: Offset(0, 4),
                blurRadius: 10,
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(
                score >= 6.0
                    ? Icons.emoji_events_rounded
                    : Icons.psychology_rounded,
                color: score >= 6.0
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFF59E0B),
                size: 48,
              ),
              const SizedBox(height: 8),
              Text(
                'Điểm số của bạn: ${score.toStringAsFixed(1)} / 10.0',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: score >= 6.0
                      ? const Color(0xFF15803D)
                      : const Color(0xFFB45309),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Bạn đã hoàn thành chính xác $correctCount / ${_questions.length} câu hỏi theo SGK.',
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 8),
              // Hiển thị thời gian thực tế đã học
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_outlined,
                        size: 16, color: Color(0xFF475569)),
                    const SizedBox(width: 6),
                    Text(
                      'Thời gian hoàn thành: ${_formatDuration(_actualDurationSeconds)}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Chi tiết từng câu hỏi & giải thích
        const Text(
          'Chi tiết bài làm & Giải thích đáp án:',
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 10),

        ..._questions.asMap().entries.map((entry) {
          final idx = entry.key;
          final q = entry.value;
          final userAns = _selectedAnswers[idx];
          final isCorrect = userAns == q.correctIndex;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isCorrect
                    ? const Color(0xFFBBF7D0)
                    : const Color(0xFFFECDD3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isCorrect
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      color: isCorrect
                          ? const Color(0xFF16A34A)
                          : AppTokens.errorRed,
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
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Bạn chọn: ${userAns != null ? q.options[userAns] : 'Chưa chọn'}',
                  style: TextStyle(
                    fontSize: 13,
                    color: isCorrect
                        ? const Color(0xFF16A34A)
                        : AppTokens.errorRed,
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
                        color: Color(0xFF15803D),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trích dẫn SGK (trang in 11): "${q.textbookQuote}"',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Giải nghĩa biên soạn: ${q.explanation}',
                        style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 20),

        // LỜI MỜI TẠO TÀI KHOẢN (ĐẶT SAU KẾT QUẢ THẬT, KHÔNG CHE CHẮN)
        if (authCtrl.user.isGuest) ...[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF93C5FD)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(Icons.workspace_premium_rounded,
                        color: AppTokens.primary, size: 24),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Lưu kết quả học tập vào tài khoản',
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontWeight: FontWeight.w800,
                          fontSize: 15.5,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Bài học thử vừa rồi đã được ghi nhận trên thiết bị này. Đăng ký tài khoản miễn phí để:\n'
                  '• Lưu điểm số, lịch sử bài làm và sổ câu sai.\n'
                  '• Mở khóa lộ trình học cho toàn bộ 10 Unit trong SGK 12.\n'
                  '• Tiếp tục luyện 8 dạng bài thi tốt nghiệp THPT.',
                  style: TextStyle(
                      fontSize: 13, color: Color(0xFF334155), height: 1.4),
                ),
                const SizedBox(height: 16),
                AppButton(
                  label: 'Tạo tài khoản lưu kết quả',
                  isFullWidth: true,
                  variant: AppButtonVariant.primary,
                  height: 48,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const RegisterScreen()),
                    );
                  },
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    child: const Text(
                      'Đã có tài khoản? Đăng nhập',
                      style: TextStyle(
                        color: AppTokens.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // NÚT KHÁM PHÁ TRANG CHỦ HOẶC ÔN LẠI BÀI THỬ
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Khám phá Trang chủ',
                variant: AppButtonVariant.outlined,
                height: 48,
                onPressed: _navigateToHome,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppButton(
                label: 'Làm lại bài thử',
                variant: AppButtonVariant.secondary,
                height: 48,
                onPressed: () {
                  setState(() {
                    _currentStep = 0;
                    _currentQuestionIndex = 0;
                    _selectedAnswers =
                        List<int?>.filled(_questions.length, null);
                    _checkedStates =
                        List<bool>.filled(_questions.length, false);
                    _isResultSaved = false;
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
