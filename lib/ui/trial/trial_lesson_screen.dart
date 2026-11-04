import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_repository.dart';
import '../../data/audio_repository.dart';
import '../../data/models/attempt.dart';
import '../../data/models/attempt_answer.dart';
import '../../data/models/daily_stat.dart';
import '../../data/models/learning_session.dart';
import '../../data/models/wrong_book_entry.dart';
import '../../data/trial_lesson_repository.dart';
import '../../data/trial_policy.dart';
import '../../navigation/main_shell.dart';
import '../auth/auth_controller.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';
import '../audio/app_audio_controller.dart';
import '../audio/app_audio_player_widget.dart';
import '../theme/app_tokens.dart';
import '../theme/components/app_button.dart';
import '../theme/components/engpass_mascot.dart';
import 'interactive_reading_text.dart';
import 'trial_lesson_picker_screen.dart';

/// Màn hình bài học đọc hiểu tương tác chuẩn SGK Tiếng Anh 12 Global Success.
///
/// Hỗ trợ đầy đủ:
/// - Khách tự do chọn bất kỳ bài học thử nào đã sẵn sàng trong 10 Unit.
/// - Đọc bài với hỗ trợ chạm từ tra nghĩa ngoại tuyến, bôi đen dịch, nút dịch đoạn.
/// - 4-5 câu hỏi Activity chuẩn SGK thực tế, trích dẫn đối chiếu và lời giải biên soạn.
/// - Tùy chọn xem lại bài đọc bất cứ lúc nào trong khi làm câu hỏi mà không mất trạng thái.
/// - Ghi nhận trung thực việc dùng hỗ trợ trước khi nộp, đo thời gian học thực tế.
/// - Lưu kết quả và sổ câu sai đúng chủ sở hữu (guestSessionId / tài khoản thật).
class TrialLessonScreen extends StatefulWidget {
  final String lessonId;
  final int initialStep; // 0: Đọc bài, 1: Làm câu hỏi, 2: Kết quả
  final int initialQuestionIndex;
  final List<int?>? initialAnswers;
  final bool autoOpenQuestions;
  final bool initialUsedReadingAssistance;
  final Set<int>? initialAssistedQuestions;

  const TrialLessonScreen({
    super.key,
    this.lessonId = TrialPolicy.trialLessonId,
    this.initialStep = 0,
    this.initialQuestionIndex = 0,
    this.initialAnswers,
    this.autoOpenQuestions = false,
    this.initialUsedReadingAssistance = false,
    this.initialAssistedQuestions,
  });

  @override
  State<TrialLessonScreen> createState() => _TrialLessonScreenState();
}

class _TrialLessonScreenState extends State<TrialLessonScreen>
    with WidgetsBindingObserver {
  late final TrialLessonData _lesson;
  late final List<TrialQuestionData> _questions;

  late int _currentStep; // 0: Reading, 1: Questions, 2: Result
  late int _currentQuestionIndex;
  late List<int?> _selectedAnswers;
  late List<bool> _checkedStates;

  // Ghi nhận trung thực việc dùng hỗ trợ
  final Set<int> _assistedQuestionsBeforeCheck = {};
  bool _usedReadingAssistance = false;
  bool _isResultSaved = false;
  bool _isInteractingWithText = false; // Ngăn vô tình chọn phương án khi chạm/bôi đen tra từ

  // Đo thời gian học thực tế (loại trừ thời gian app nằm nền)
  late final Stopwatch _stopwatch;
  late final int _startedAtEpoch;

  String? _selectedVocabWord;
  String? _selectedVocabMeaning;
  String? _lessonLoadError;
  String? _saveErrorMessage;
  AudioTrack? _readingTrack;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _stopwatch = Stopwatch()..start();
    _startedAtEpoch = DateTime.now().millisecondsSinceEpoch;

    _initReadingAudio();

    // Tải bài học từ Repository theo đúng lessonId, không tự ý gán Unit 1 làm fallback
    final repoLesson = TrialLessonRepository.instance.getLessonById(widget.lessonId);
    if (repoLesson == null) {
      _lessonLoadError =
          'Không tìm thấy dữ liệu cho bài học "${widget.lessonId}". Bài học không tồn tại hoặc chưa được nạp.';
      _lesson = TrialLessonData(
        lessonId: widget.lessonId,
        unitNumber: 0,
        unitTitle: 'Không tìm thấy bài học',
        lessonTitle: 'Bài học không tồn tại',
        textbookSource: '',
        activityName: '',
        paragraphs: const [],
        questions: const [],
        vocabulary: const {},
        isReady: false,
      );
      _questions = const [];
      _selectedAnswers = [];
      _checkedStates = [];
      _currentStep = 0;
      _currentQuestionIndex = 0;
      return;
    }

    _lesson = repoLesson;
    _questions = _lesson.questions;

    _currentStep = widget.initialStep;
    _currentQuestionIndex =
        _questions.isNotEmpty ? widget.initialQuestionIndex.clamp(0, _questions.length - 1) : 0;

    // Khởi tạo danh sách đáp án, kiểm tra tính tương thích số câu hỏi
    if (widget.initialAnswers != null &&
        widget.initialAnswers!.length == _questions.length) {
      _selectedAnswers = List<int?>.from(widget.initialAnswers!);
    } else {
      _selectedAnswers = List<int?>.filled(_questions.length, null);
    }

    _checkedStates = List<bool>.generate(_questions.length, (i) {
      return i < _currentQuestionIndex && _selectedAnswers[i] != null;
    });

    if (widget.autoOpenQuestions) {
      _currentStep = 1;
    }

    if (_selectedAnswers.isNotEmpty &&
        _selectedAnswers[_currentQuestionIndex] != null &&
        _currentQuestionIndex < widget.initialQuestionIndex) {
      _checkedStates[_currentQuestionIndex] = true;
    }

    _usedReadingAssistance = widget.initialUsedReadingAssistance;
    if (widget.initialAssistedQuestions != null) {
      _assistedQuestionsBeforeCheck.addAll(widget.initialAssistedQuestions!);
    }

    if (widget.initialAnswers == null && _questions.isNotEmpty) {
      _restoreInProgressIfAny();
    }
  }

  Future<void> _restoreInProgressIfAny() async {
    final repo = _getRepository();
    final authCtrl = AuthController.instance;
    final ownerId = authCtrl.user.id.isNotEmpty
        ? authCtrl.user.id
        : await repo.getOrCreateGuestSessionId();
    final session = await repo.getLearningSession(
      ownerId,
      lessonId: _lesson.lessonId,
    );
    if (session != null &&
        session.lessonId == _lesson.lessonId &&
        session.selectedAnswers.length == _questions.length &&
        session.isInProgress &&
        mounted &&
        _currentStep == 0) {
      setState(() {
        _selectedAnswers = List<int?>.from(session.selectedAnswers);
        _currentQuestionIndex = session.currentQuestionIndex.clamp(
          0,
          _questions.length - 1,
        );
        _checkedStates = List<bool>.generate(_questions.length, (i) {
          return i < _currentQuestionIndex && _selectedAnswers[i] != null;
        });
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopwatch.stop();
    AppAudioController.instance.stop();
    super.dispose();
  }

  Future<void> _initReadingAudio() async {
    try {
      if (!AudioRepository.instance.isLoaded) {
        await AudioRepository.instance.load();
      }
      final track = AudioRepository.instance.getReadingTrack(
        lessonKey: 'unit-${_lesson.unitNumber.toString().padLeft(2, '0')}',
      );
      if (mounted) {
        setState(() {
          _readingTrack = track;
        });
      }
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Tạm dừng đếm giờ khi app vào nền, tiếp tục khi mở lại để tránh đếm thời gian chết
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

  AppRepository _getRepository() {
    try {
      return Provider.of<AppRepository>(context, listen: false);
    } catch (_) {
      return AppRepository();
    }
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
      lessonId: _lesson.lessonId,
      lessonTitle: 'Unit ${_lesson.unitNumber}: ${_lesson.lessonTitle}',
      lessonType: 'trial',
      status: 'in_progress',
      currentQuestionIndex: _currentQuestionIndex,
      totalQuestions: _questions.length,
      questionIds: _questions.map((q) => q.id).toList(),
      selectedAnswers: _selectedAnswers,
      nextLessonTitle: 'Hoàn thành bài đọc hiểu Unit ${_lesson.unitNumber}',
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
      // Đảm bảo câu hỏi tồn tại trong SQLite để WrongBook tra cứu được
      await repo.insertQuestions(_lesson.questionsAsStandardQuestions);

      final attempt = Attempt(
        mode: 'trial',
        type: _lesson.lessonId,
        startedAt: _startedAtEpoch,
        durationSec: durationSec,
        score: correctCount,
        total: _questions.length,
      );

      final wrongEntries = <WrongBookEntry>[];
      final nextReviewAt = now.add(const Duration(days: 1)).millisecondsSinceEpoch;
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
            final isCorrect = _selectedAnswers[i] == _questions[i].correctIndex;
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

      // Ghi nhận bài học thử đã hoàn thành cho chủ sở hữu này
      await repo.setCompletedTrialLessonId(ownerId, _lesson.lessonId);

      // Cập nhật session hoàn thành
      await repo.saveLearningSession(
        LearningSession(
          ownerId: ownerId,
          lessonId: _lesson.lessonId,
          lessonTitle: 'Unit ${_lesson.unitNumber}: ${_lesson.lessonTitle}',
          lessonType: 'trial',
          status: 'completed',
          currentQuestionIndex: _questions.length,
          totalQuestions: _questions.length,
          score: correctCount,
          questionIds: _questions.map((q) => q.id).toList(),
          selectedAnswers: _selectedAnswers,
          nextLessonTitle: 'Đăng ký tài khoản để mở khóa toàn bộ 10 Unit',
        ),
      );

      _isResultSaved = true;
      if (mounted) {
        MainShell.markFirstLessonCompleted(context);
        setState(() {
          _saveErrorMessage = null;
        });
      }
    } catch (e) {
      debugPrint('Error saving trial result: $e');
      if (mounted) {
        setState(() {
          _saveErrorMessage = 'Lỗi lưu trữ dữ liệu vào thiết bị ($e). Điểm số chưa được lưu.';
        });
      }
    }
  }

  // --- XỬ LÝ KHI BẤM BACK / TẠM DỪNG ---
  Future<bool> _handleWillPop() async {
    if (_currentStep == 1) {
      final shouldLeave = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.pause_circle_outline_rounded, color: AppTokens.primary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tạm dừng bài học thử?',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: const Text(
            'Tiến độ và các câu đã làm sẽ được lưu lại. Bạn có thể tiếp tục bất cứ lúc nào từ Trang chủ hoặc đổi sang bài khác.',
            style: TextStyle(fontSize: 13.5, color: Color(0xFF475569)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Ở lại học tiếp', style: TextStyle(fontWeight: FontWeight.bold)),
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

  void _openLessonPicker() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TrialLessonPickerScreen(currentLessonId: _lesson.lessonId),
      ),
    );
  }

  // --- MỞ MODAL XEM LẠI BÀI ĐỌC (CÓ ĐỦ HỖ TRỢ ĐỌC HIỂU TƯƠNG TÁC) ---
  void _openReadingBottomSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.88,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (sheetCtx, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF121620) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.menu_book_rounded,
                          color: isDark ? const Color(0xFF60A5FA) : AppTokens.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bài đọc: ${_lesson.lessonTitle}',
                                style: TextStyle(
                                  fontFamily: 'BeVietnamPro',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Unit ${_lesson.unitNumber}: ${_lesson.unitTitle} · ${_lesson.textbookSource}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                          onPressed: () => Navigator.pop(sheetCtx),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(18),
                      children: [
                        ..._lesson.paragraphs.map((p) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _buildParagraphCard(p),
                          );
                        }),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTokens.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          onPressed: () => Navigator.pop(sheetCtx),
                          child: const Text(
                            'Quay lại làm câu hỏi',
                            style: TextStyle(fontFamily: 'BeVietnamPro', fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(height: 16),
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

  Future<void> _safeExit() async {
    final canLeave = await _handleWillPop();
    if (!canLeave || !mounted) return;
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _safeExit();
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF121620) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF1E2430) : Colors.white,
          elevation: 0.5,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
            onPressed: _safeExit,
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _currentStep == 0
                    ? '1. Đọc bài & Tra từ vựng'
                    : (_currentStep == 1
                        ? '2. Câu hỏi đọc hiểu SGK'
                        : '3. Kết quả bài học'),
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF60A5FA) : AppTokens.primary,
                ),
              ),
              Text(
                'Unit ${_lesson.unitNumber}: ${_lesson.lessonTitle}',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          actions: [
            // Nút đổi bài học thử
            if (_currentStep == 0)
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.swap_horiz_rounded, size: 18, color: AppTokens.primary),
                label: const Text(
                  'Đổi bài',
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: AppTokens.primary,
                  ),
                ),
                onPressed: _openLessonPicker,
              ),

            // Nút xem lại bài đọc khi đang làm câu hỏi
            if (_currentStep == 1) ...[
              IconButton(
                tooltip: 'Xem lại bài đọc SGK',
                icon: const Icon(Icons.menu_book_rounded, color: AppTokens.primary),
                onPressed: _openReadingBottomSheet,
              ),
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
    if (_lessonLoadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppTokens.errorRed, size: 54),
              const SizedBox(height: 16),
              Text(
                _lessonLoadError!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 20),
              AppButton(
                label: 'Chọn bài học khác',
                onPressed: _openLessonPicker,
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _navigateToHome,
                child: const Text('Về Trang chủ'),
              ),
            ],
          ),
        ),
      );
    }

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
  // BƯỚC 1: ĐỌC BÀI VÀ HỖ TRỢ NGÔN NGỮ
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
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.menu_book_rounded, color: AppTokens.primary, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Unit ${_lesson.unitNumber}: ${_lesson.lessonTitle}',
                                  style: const TextStyle(
                                    fontFamily: 'BeVietnamPro',
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: Color(0xFF1E40AF),
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: _openLessonPicker,
                                child: const Text(
                                  'Đổi bài khác >',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${_lesson.textbookSource} • ${_lesson.activityName} (${_questions.length} câu đối chiếu thực tế).',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.35),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Hướng dẫn tương tác ngắn gọn
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.touch_app_rounded, size: 16, color: Color(0xFF475569)),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Chạm từ để tra nghĩa · Bôi đen để dịch một đoạn · Bấm nút "Dịch đoạn" bên dưới mỗi đoạn.',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Chip các từ vựng trọng tâm trong bài
              if (_lesson.vocabulary.isNotEmpty) ...[
                const Text(
                  'Từ vựng trọng tâm trong bài (chạm để xem nghĩa nhanh):',
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _lesson.vocabulary.entries.map((entry) {
                    final isSelected = _selectedVocabWord == entry.key;
                    return ActionChip(
                      label: Text(
                        entry.key,
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : const Color(0xFF1E40AF),
                        ),
                      ),
                      backgroundColor:
                          isSelected ? AppTokens.primary : const Color(0xFFEFF6FF),
                      side: const BorderSide(color: Color(0xFFBFDBFE)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      onPressed: () {
                        setState(() {
                          _selectedVocabWord = entry.key;
                          _selectedVocabMeaning = entry.value;
                        });
                        _usedReadingAssistance = true;
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],

              // Pop-up giải thích từ vựng khi chạm chip
              if (_selectedVocabWord != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lightbulb_rounded, color: Color(0xFFD97706), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '"$_selectedVocabWord": $_selectedVocabMeaning',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF92400E)),
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

              // Trình phát âm thanh bài đọc SGK chuẩn nếu có bản thu
              if (_readingTrack != null) ...[
                AppAudioPlayerWidget(
                  track: _readingTrack!,
                  title: 'Audio bài đọc: ${_lesson.lessonTitle}',
                  subtitle: 'SGK ${_lesson.textbookSource}',
                  compact: true,
                ),
                const SizedBox(height: 12),
              ],

              // Các thẻ đoạn văn bản bài đọc
              ..._lesson.paragraphs.map((p) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _buildParagraphCard(p),
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        ),

        // Nút chuyển sang làm bài tập
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1E2430)
                : Colors.white,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
              ),
            ),
          ),
          child: AppButton(
            label: 'Làm bài tập đọc hiểu (${_questions.length} câu) →',
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

  /// Thẻ hiển thị đoạn văn bản có hỗ trợ tra từ & dịch đoạn trọn vẹn
  Widget _buildParagraphCard(LessonParagraph p) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2430) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2D3748) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              p.label,
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
              ),
            ),
          ),
          const SizedBox(height: 10),
          InteractiveReadingText(
            text: p.text,
            translation: p.translation,
            keyVocabulary: _lesson.vocabulary,
            highlightWords: p.keyWords,
            translateButtonLabel: 'Dịch đoạn (Tiếng Việt)',
            currentLesson: _lesson,
            onAssistanceUsed: (type) {
              _usedReadingAssistance = true;
            },
          ),
        ],
      ),
    );
  }

  // ==========================================
  // BƯỚC 2: LÀM BÀI TẬP ACTIVITY 2 CHUẨN SGK
  // ==========================================
  Widget _buildQuestionsStep() {
    if (_questions.isEmpty ||
        _currentQuestionIndex < 0 ||
        _currentQuestionIndex >= _questions.length) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline_rounded, size: 48, color: Color(0xFF64748B)),
              const SizedBox(height: 16),
              const Text(
                'Chưa có câu hỏi cho bài học này hoặc dữ liệu đang tải.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'Quay lại bài đọc',
                onPressed: () => setState(() => _currentStep = 0),
              ),
            ],
          ),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final question = _questions[_currentQuestionIndex];
    final selectedOption = _selectedAnswers[_currentQuestionIndex];
    final isChecked = _checkedStates[_currentQuestionIndex];
    final isLastQuestion = _currentQuestionIndex == _questions.length - 1;

    return Column(
      children: [
        LinearProgressIndicator(
          value: (_currentQuestionIndex + 1) / _questions.length,
          minHeight: 4,
          backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          valueColor: const AlwaysStoppedAnimation<Color>(AppTokens.primary),
        ),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_lesson.activityName} (${question.pageLabel}):',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: Icon(
                      Icons.menu_book_outlined,
                      size: 16,
                      color: isDark ? const Color(0xFF60A5FA) : AppTokens.primary,
                    ),
                    label: Text(
                      'Đọc lại bài',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFF60A5FA) : AppTokens.primary,
                      ),
                    ),
                    onPressed: _openReadingBottomSheet,
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Thẻ câu hỏi và ngữ cảnh bài đọc
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2430) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      question.word,
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // KHỐI NGỮ CẢNH CÂU VĂN: HỖ TRỢ TRA TỪ VÀ BẤM DỊCH CÂU
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF121620) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.format_quote_rounded,
                                size: 16,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Ngữ cảnh trong bài đọc (Chạm từ để tra hoặc bôi đen dịch):',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          InteractiveReadingText(
                            text: question.contextSentence,
                            translation: question.contextTranslation,
                            keyVocabulary: _lesson.vocabulary,
                            highlightWords: [question.targetWord],
                            translateButtonLabel: 'Dịch câu ngữ cảnh',
                            currentLesson: _lesson,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontStyle: FontStyle.italic,
                              color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                              height: 1.45,
                            ),
                            onAssistanceUsed: (type) {
                              if (!isChecked) {
                                _assistedQuestionsBeforeCheck.add(_currentQuestionIndex);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Danh sách các lựa chọn (người học cũng có thể chạm từ trong lựa chọn để tra cứu)
              ...question.options.asMap().entries.map((entry) {
                final optionIdx = entry.key;
                final optionText = entry.value;
                final isSelected = selectedOption == optionIdx;

                Color itemBg = isDark ? const Color(0xFF1E2430) : Colors.white;
                Color itemBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
                Widget leadingIcon = Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: isSelected ? AppTokens.primary : const Color(0xFF94A3B8),
                  size: 20,
                );

                if (isChecked) {
                  if (optionIdx == question.correctIndex) {
                    itemBg = isDark
                        ? const Color(0xFF14532D).withValues(alpha: 0.4)
                        : const Color(0xFFF0FDF4);
                    itemBorder = const Color(0xFF22C55E);
                    leadingIcon = const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF16A34A), size: 20);
                  } else if (isSelected && optionIdx != question.correctIndex) {
                    itemBg = isDark
                        ? const Color(0xFF7F1D1D).withValues(alpha: 0.4)
                        : const Color(0xFFFEF2F2);
                    itemBorder = AppTokens.errorRed;
                    leadingIcon = const Icon(Icons.cancel_rounded,
                        color: AppTokens.errorRed, size: 20);
                  }
                } else if (isSelected) {
                  itemBg = isDark
                      ? const Color(0xFF1E3A8A).withValues(alpha: 0.4)
                      : const Color(0xFFEFF6FF);
                  itemBorder = AppTokens.primary;
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: (isChecked || _isInteractingWithText)
                        ? null
                        : () {
                            setState(() {
                              _selectedAnswers[_currentQuestionIndex] = optionIdx;
                            });
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: itemBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: itemBorder,
                          width: isSelected ? 1.8 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          leadingIcon,
                          const SizedBox(width: 12),
                          Expanded(
                            child: InteractiveReadingText(
                              text: optionText,
                              keyVocabulary: _lesson.vocabulary,
                              showTranslateButton: false,
                              currentLesson: _lesson,
                              style: TextStyle(
                                fontFamily: 'BeVietnamPro',
                                fontSize: 14,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              onInteractionStart: () {
                                _isInteractingWithText = true;
                                Future.delayed(const Duration(milliseconds: 500), () {
                                  if (mounted) {
                                    setState(() {
                                      _isInteractingWithText = false;
                                    });
                                  }
                                });
                              },
                              onAssistanceUsed: (type) {
                                if (!isChecked) {
                                  _assistedQuestionsBeforeCheck.add(_currentQuestionIndex);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              // Hộp giải thích hiển thị ngay sau khi bấm Kiểm tra
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
                      Text(
                        '• Trích dẫn đối chiếu SGK: "${question.textbookQuote}"',
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155), height: 1.4),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '• Lời giải biên soạn: ${question.explanation}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // Nút hành động đáy màn hình
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2430) : Colors.white,
            border: Border(
              top: BorderSide(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
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

  // ==========================================
  // BƯỚC 3: KẾT QUẢ THẬT & ĐỊNH HƯỚNG ÔN TẬP
  // ==========================================
  Widget _buildResultStep() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
        // Cảnh báo lỗi lưu dữ liệu nếu lưu thất bại (không dùng mock data)
        if (_saveErrorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: AppTokens.errorRed, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Lỗi lưu kết quả bài làm',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: Color(0xFF991B1B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _saveErrorMessage!,
                        style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _saveErrorMessage = null;
                    });
                    _saveCompletedResult();
                  },
                  child: const Text(
                    'Thử lưu lại',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppTokens.errorRed),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Thẻ điểm số thật & thời gian thực tế
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2430) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: score >= 6.0 ? const Color(0xFF86EFAC) : const Color(0xFFFECACA),
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
              EngPassMascot(
                mood: score >= 6.0 ? MascotMood.celebrate : MascotMood.study,
                size: 82,
              ),
              const SizedBox(height: 8),
              Text(
                'Điểm số của bạn: ${score.toStringAsFixed(1)} / 10.0',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: score >= 6.0
                      ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D))
                      : (isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309)),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Bạn đã hoàn thành chính xác $correctCount / ${_questions.length} câu hỏi theo SGK.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 8),

              // Ghi nhận trung thực việc dùng hỗ trợ
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF121620) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 16,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Thời gian học thực tế: ${_formatDuration(_actualDurationSeconds)}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 1.5),
                          child: Icon(
                            _assistedQuestionsBeforeCheck.isNotEmpty
                                ? Icons.translate_rounded
                                : Icons.verified_user_rounded,
                            size: 15,
                            color: _assistedQuestionsBeforeCheck.isNotEmpty
                                ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB))
                                : (isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _assistedQuestionsBeforeCheck.isNotEmpty
                                ? 'Đã dùng tra từ/dịch ở ${_assistedQuestionsBeforeCheck.length}/${_questions.length} câu trước khi trả lời'
                                : (_usedReadingAssistance
                                    ? 'Đã tham khảo từ vựng trong lúc đọc bài trước khi trả lời'
                                    : 'Tự lập hoàn toàn trong quá trình làm bài'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _assistedQuestionsBeforeCheck.isNotEmpty
                                  ? (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF))
                                  : (isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Học thử là cơ hội làm quen với học liệu SGK 12. Việc dùng hỗ trợ tra từ giúp bạn tích lũy từ vựng nhanh hơn!',
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Chi tiết từng câu hỏi & giải thích
        Text(
          'Chi tiết bài làm & Giải thích đáp án:',
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 10),

        ..._questions.asMap().entries.map((entry) {
          final idx = entry.key;
          final q = entry.value;
          final userAns = _selectedAnswers[idx];
          final isCorrect = userAns == q.correctIndex;
          final usedHelp = _assistedQuestionsBeforeCheck.contains(idx);

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2430) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isCorrect ? const Color(0xFF22C55E) : const Color(0xFFFECDD3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      color: isCorrect ? const Color(0xFF16A34A) : AppTokens.errorRed,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        q.word,
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    if (usedHelp)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.5) : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Có tra nghĩa',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Bạn chọn: ${(userAns != null && userAns >= 0 && userAns < q.options.length) ? q.options[userAns] : 'Chưa chọn'}',
                  style: TextStyle(
                    fontSize: 13,
                    color: isCorrect ? const Color(0xFF16A34A) : AppTokens.errorRed,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!isCorrect)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Đáp án đúng: ${q.options[q.correctIndex]}',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF121620) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trích dẫn SGK: "${q.textbookQuote}"',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Giải nghĩa biên soạn: ${q.explanation}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 20),

        // LỜI MỜI TẠO TÀI KHOẢN (CHO KHÁCH) HOẶC THÀNH TÍCH (CHO HỌC VIÊN)
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
                    Icon(Icons.workspace_premium_rounded, color: AppTokens.primary, size: 24),
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
                  style: TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4),
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
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
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
        ] else ...[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF86EFAC)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified_rounded, color: Color(0xFF16A34A), size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Đã lưu bài học vào tài khoản: ${authCtrl.user.displayName}',
                        style: const TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: Color(0xFF166534),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  score >= 6.0
                      ? 'Xuất sắc! Bạn đã vượt qua bài đọc hiểu Unit ${_lesson.unitNumber} (${score.toStringAsFixed(1)} / 10.0 đ). Điểm số và các câu sai đã được lưu trữ an toàn.'
                      : 'Bạn đã hoàn thành bài đọc hiểu Unit ${_lesson.unitNumber}. Hãy ôn lại các câu chưa chính xác trong Sổ câu sai để nắm vững kiến thức.',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B), height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // CÁC NÚT ĐIỀU HƯỚNG ÔN TẬP
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
                label: 'Làm lại bài này',
                variant: AppButtonVariant.secondary,
                height: 48,
                onPressed: () {
                  setState(() {
                    _currentStep = 0;
                    _currentQuestionIndex = 0;
                    _selectedAnswers = List<int?>.filled(_questions.length, null);
                    _checkedStates = List<bool>.filled(_questions.length, false);
                    _assistedQuestionsBeforeCheck.clear();
                    _usedReadingAssistance = false;
                    _isResultSaved = false;
                    _stopwatch.reset();
                    _stopwatch.start();
                    _startedAtEpoch = DateTime.now().millisecondsSinceEpoch;
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton.icon(
            icon: const Icon(Icons.explore_outlined, size: 18, color: AppTokens.primary),
            label: Text(
              authCtrl.user.isGuest
                  ? 'Chọn bài học thử khác (${TrialLessonRepository.instance.getReadyLessons().length} Unit sẵn sàng)'
                  : 'Chọn bài học Unit khác (${TrialLessonRepository.instance.getReadyLessons().length} Unit sẵn sàng)',
              style: const TextStyle(
                fontFamily: 'BeVietnamPro',
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppTokens.primary,
              ),
            ),
            onPressed: _openLessonPicker,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
