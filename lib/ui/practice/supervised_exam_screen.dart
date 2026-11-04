import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/rbac_proctor_ai_service.dart';
import '../auth/auth_controller.dart';
import '../theme/app_tokens.dart';
import '../theme/components/engpass_mascot.dart';

/// Màn hình Danh sách các Kỳ thi & Bài kiểm tra có giám sát (Dành cho Học viên)
class SupervisedExamListScreen extends StatefulWidget {
  const SupervisedExamListScreen({super.key});

  @override
  State<SupervisedExamListScreen> createState() =>
      _SupervisedExamListScreenState();
}

class _SupervisedExamListScreenState extends State<SupervisedExamListScreen> {
  bool _isLoading = true;
  List<SupervisedExamModel> _exams = [];

  @override
  void initState() {
    super.initState();
    _loadExams();
  }

  Future<void> _loadExams() async {
    setState(() => _isLoading = true);
    final list = await RbacProctorAiService.instance.getSupervisedExams();
    if (!mounted) return;
    setState(() {
      _exams = list.where((e) => e.isActive).toList();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppTokens.darkBackground : AppTokens.background;
    final cardColor = isDark ? AppTokens.darkSurface : AppTokens.surface;
    final textMain = isDark ? AppTokens.darkTextMain : AppTokens.textMain;
    final textSub = isDark ? AppTokens.darkTextSub : AppTokens.textSub;
    final borderColor = isDark ? AppTokens.darkBorder : AppTokens.border;
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        title: Text(
          'Phòng Thi Giám Sát & Hạn Nộp',
          style: TextStyle(fontWeight: FontWeight.w800, color: textMain, fontSize: 17),
        ),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: _loadExams,
            icon: Icon(Icons.refresh_rounded, color: textMain),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Thẻ giới thiệu cơ chế chống gian lận 10s
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTokens.primary.withValues(alpha: isDark ? 0.16 : 0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTokens.primary.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      const EngPassMascot(mood: MascotMood.study, size: 48),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quy chế Phòng Thi Chống Gian Lận',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: textMain,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '• Tự động khóa Dịch thuật & Gia sư AI khi vào phòng thi.\n'
                              '• Nếu thoát ứng dụng / mở ChatGPT quá 10 giây hoặc vượt số lần cảnh cáo, hệ thống sẽ tự động thu bài và báo cho Giáo viên.',
                              style: TextStyle(fontSize: 12.5, color: textSub, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (_exams.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Hiện chưa có kỳ thi có giám sát nào đang mở.',
                        style: TextStyle(color: textSub),
                      ),
                    ),
                  ),

                ..._exams.map((exam) {
                  final isLate = exam.isPastDeadline;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: (isLate ? AppTokens.warning : AppTokens.success)
                                    .withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                isLate ? 'Đã quá hạn nộp chuẩn' : 'Đang mở nhận bài',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: isLate ? AppTokens.warning : AppTokens.success,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Icon(Icons.shield_rounded, size: 16, color: AppTokens.primary),
                            const SizedBox(width: 4),
                            Text(
                              'Giám sát ${exam.graceSeconds}s',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTokens.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          exam.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: textMain,
                          ),
                        ),
                        if (exam.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            exam.description,
                            style: TextStyle(fontSize: 13, color: textSub),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 12,
                          runSpacing: 6,
                          children: [
                            _buildMetaTag(
                              Icons.timer_outlined,
                              '${exam.durationMinutes} phút • ${exam.questions.length} câu',
                              textSub,
                            ),
                            _buildMetaTag(
                              Icons.event_available_rounded,
                              'Hạn nộp: ${dateFmt.format(exam.deadlineAt)}',
                              isLate ? AppTokens.danger : textSub,
                            ),
                            _buildMetaTag(
                              Icons.warning_amber_rounded,
                              'Tối đa ${exam.maxViolations} lần cảnh cáo',
                              textSub,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SupervisedExamPlayerScreen(exam: exam),
                                ),
                              );
                              _loadExams();
                            },
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('Vào Phòng Thi Giám Sát'),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
    );
  }

  Widget _buildMetaTag(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
        ),
      ],
    );
  }
}

/// Màn hình Làm Bài Thi Có Giám Sát & Cảm Biến Chống Gian Lận 10 Giây
class SupervisedExamPlayerScreen extends StatefulWidget {
  final SupervisedExamModel exam;

  const SupervisedExamPlayerScreen({
    super.key,
    required this.exam,
  });

  @override
  State<SupervisedExamPlayerScreen> createState() =>
      _SupervisedExamPlayerScreenState();
}

class _SupervisedExamPlayerScreenState extends State<SupervisedExamPlayerScreen>
    with WidgetsBindingObserver {
  ExamLiveSessionModel? _session;
  final Map<String, int> _answers = {};
  int _currentIndex = 0;

  // Đồng hồ làm bài chính
  Timer? _examTimer;
  late int _remainingExamSeconds;

  // Đồng hồ đếm ngược 10 giây chống gian lận khi rời ứng dụng
  Timer? _graceCountdownTimer;
  bool _isAntiCheatWarningOverlayVisible = false;
  int _graceSecondsLeft = 10;
  DateTime? _leftAppAt;

  bool _isFinished = false;
  String _finalResultMessage = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _remainingExamSeconds = widget.exam.durationMinutes * 60;
    _graceSecondsLeft = widget.exam.graceSeconds;
    _initSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _examTimer?.cancel();
    _graceCountdownTimer?.cancel();
    ExamLockGuard.instance.exitSupervisedExam();
    super.dispose();
  }

  Future<void> _initSession() async {
    final user = AuthController.instance.user;
    final started = await RbacProctorAiService.instance.startSupervisedExamSession(
      exam: widget.exam,
      userId: user.id,
      studentName: user.displayName,
      studentEmail: user.email,
    );
    if (!mounted) return;
    setState(() {
      _session = started;
    });

    _examTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isFinished) {
        timer.cancel();
        return;
      }
      if (_remainingExamSeconds <= 1) {
        timer.cancel();
        _submitExamNow(isAutoTimeout: true);
      } else {
        setState(() => _remainingExamSeconds -= 1);
      }
    });
  }

  /// Phát hiện sự kiện Học sinh thoát ứng dụng / mở cửa sổ đa nhiệm / chuyển sang ChatGPT
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isFinished || _session == null) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _leftAppAt ??= DateTime.now();
      _triggerAntiCheatCountdown(
        detail: 'Phát hiện thoát ứng dụng / chuyển cửa sổ (${state.name})',
      );
    } else if (state == AppLifecycleState.resumed) {
      if (_leftAppAt != null) {
        final awaySec = DateTime.now().difference(_leftAppAt!).inSeconds;
        _leftAppAt = null;
        if (awaySec >= widget.exam.graceSeconds) {
          _handleGracePeriodExceeded(awaySec);
        }
      }
    }
  }

  /// Kích hoạt bộ đếm ngược 10 giây yêu cầu quay lại làm bài ngay lập tức
  Future<void> _triggerAntiCheatCountdown({required String detail}) async {
    if (_isFinished || _session == null) return;

    _graceCountdownTimer?.cancel();
    setState(() {
      _isAntiCheatWarningOverlayVisible = true;
      _graceSecondsLeft = widget.exam.graceSeconds;
    });

    // Ghi nhận ngay sự kiện vi phạm lên hệ thống giám sát của Giáo viên
    final updated = await RbacProctorAiService.instance.recordProctorHeartbeat(
      exam: widget.exam,
      currentSession: _session!,
      currentAnswers: _answers,
      eventType: 'app_backgrounded',
      detail: detail,
    );

    if (!mounted) return;
    setState(() => _session = updated);

    if (!updated.isActive) {
      _finalizeTerminatedSession(updated);
      return;
    }

    _graceCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isFinished) {
        timer.cancel();
        return;
      }
      if (_graceSecondsLeft <= 1) {
        timer.cancel();
        _handleGracePeriodExceeded(widget.exam.graceSeconds);
      } else {
        setState(() => _graceSecondsLeft -= 1);
      }
    });
  }

  void _confirmReturnedToExam() {
    _graceCountdownTimer?.cancel();
    setState(() {
      _isAntiCheatWarningOverlayVisible = false;
    });
  }

  Future<void> _handleGracePeriodExceeded(int awaySeconds) async {
    if (_isFinished || _session == null) return;
    _graceCountdownTimer?.cancel();

    final terminated = await RbacProctorAiService.instance.recordProctorHeartbeat(
      exam: widget.exam,
      currentSession: _session!,
      currentAnswers: _answers,
      eventType: 'timeout_10s_exceeded',
      outOfAppSeconds: awaySeconds,
      detail: 'Quá ${widget.exam.graceSeconds} giây không xác nhận quay lại phòng thi.',
    );

    if (!mounted) return;
    _finalizeTerminatedSession(terminated);
  }

  void _finalizeTerminatedSession(ExamLiveSessionModel terminated) {
    _examTimer?.cancel();
    _graceCountdownTimer?.cancel();
    ExamLockGuard.instance.exitSupervisedExam();

    setState(() {
      _session = terminated;
      _isAntiCheatWarningOverlayVisible = false;
      _isFinished = true;
      _finalResultMessage = terminated.teacherWarningMessage ??
          'Bài thi đã bị tự động thu hồi do vi phạm quy chế phòng thi.';
    });
  }

  Future<void> _submitExamNow({bool isAutoTimeout = false}) async {
    if (_isFinished || _session == null) return;
    _examTimer?.cancel();
    _graceCountdownTimer?.cancel();

    final submitted = await RbacProctorAiService.instance.submitSupervisedExam(
      exam: widget.exam,
      currentSession: _session!,
      answers: _answers,
    );

    if (!mounted) return;
    setState(() {
      _session = submitted;
      _isFinished = true;
      _finalResultMessage = isAutoTimeout
          ? 'Đã hết thời gian làm bài. Hệ thống đã tự động thu bài của bạn!'
          : (submitted.status == 'submitted_late'
              ? 'Đã nộp bài thành công (Ghi nhận nộp trễ hạn so với hạn chót của Giáo viên).'
              : 'Chúc mừng! Bạn đã nộp bài đúng hạn và tuân thủ quy chế phòng thi.');
    });
  }

  String _formatClock(int totalSec) {
    final m = (totalSec ~/ 60).toString().padLeft(2, '0');
    final s = (totalSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppTokens.darkBackground : AppTokens.background;
    final cardColor = isDark ? AppTokens.darkSurface : AppTokens.surface;
    final textMain = isDark ? AppTokens.darkTextMain : AppTokens.textMain;
    final textSub = isDark ? AppTokens.darkTextSub : AppTokens.textSub;
    final borderColor = isDark ? AppTokens.darkBorder : AppTokens.border;

    if (_isFinished && _session != null) {
      return _buildFinishedResultView(cardColor, bgColor, textMain, textSub, borderColor);
    }

    final questions = widget.exam.questions;
    if (questions.isEmpty) {
      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(title: Text(widget.exam.title)),
        body: const Center(child: Text('Đề thi chưa có câu hỏi.')),
      );
    }

    final currentQ = questions[_currentIndex];
    final qId = (currentQ['id'] ?? '$_currentIndex').toString();
    final options = (currentQ['options'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final chosenIndex = _answers[qId];

    // Chặn bôi đen copy văn bản trong phòng thi
    return SelectionContainer.disabled(
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: cardColor,
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.exam.title,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textMain),
              ),
              Row(
                children: [
                  const Icon(Icons.shield_rounded, size: 13, color: AppTokens.success),
                  const SizedBox(width: 4),
                  Text(
                    'Đang giám sát • Cảnh cáo: ${_session?.violationCount ?? 0}/${widget.exam.maxViolations}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: (_session?.violationCount ?? 0) > 0
                          ? AppTokens.danger
                          : AppTokens.success,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            // Nút mô phỏng thoát ứng dụng để kiểm thử trực tiếp đồng hồ 10 giây
            TextButton.icon(
              onPressed: () => _triggerAntiCheatCountdown(
                detail: 'Phát hiện chuyển cửa sổ ra ngoài ứng dụng (Kiểm thử Anti-Cheat 10s)',
              ),
              icon: const Icon(Icons.warning_amber_rounded, size: 16, color: AppTokens.warning),
              label: const Text(
                'Test Out App',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTokens.warning),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTokens.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _formatClock(_remainingExamSeconds),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppTokens.primary,
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Cảnh báo nóng từ Giáo viên (nếu có)
                if (_session?.teacherWarningMessage != null &&
                    _session!.teacherWarningMessage!.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTokens.danger.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTokens.danger),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.campaign_rounded, color: AppTokens.danger),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _session!.teacherWarningMessage!,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: textMain,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Thanh tiến độ câu hỏi
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Câu ${_currentIndex + 1} / ${questions.length}',
                      style: TextStyle(fontWeight: FontWeight.w800, color: textMain, fontSize: 15),
                    ),
                    Text(
                      'Đã làm: ${_answers.length}/${questions.length} câu',
                      style: TextStyle(fontWeight: FontWeight.w600, color: textSub, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: (_currentIndex + 1) / questions.length,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(999),
                  color: AppTokens.primary,
                ),
                const SizedBox(height: 16),

                // Nội dung câu hỏi
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: borderColor),
                  ),
                  child: Text(
                    (currentQ['stem'] ?? '').toString(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textMain,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Các phương án A, B, C, D
                ...List.generate(options.length, (optIdx) {
                  final isSelected = chosenIndex == optIdx;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        setState(() {
                          _answers[qId] = optIdx;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTokens.primary.withValues(alpha: 0.16)
                              : cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? AppTokens.primary : borderColor,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_off_rounded,
                              color: isSelected ? AppTokens.primary : textSub,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                options[optIdx],
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  color: textMain,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 18),
                Row(
                  children: [
                    if (_currentIndex > 0)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => setState(() => _currentIndex -= 1),
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('Câu trước'),
                        ),
                      ),
                    if (_currentIndex > 0) const SizedBox(width: 10),
                    Expanded(
                      child: _currentIndex < questions.length - 1
                          ? FilledButton.icon(
                              onPressed: () => setState(() => _currentIndex += 1),
                              icon: const Icon(Icons.arrow_forward_rounded),
                              label: const Text('Câu tiếp theo'),
                            )
                          : FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTokens.success,
                              ),
                              onPressed: () => _submitExamNow(),
                              icon: const Icon(Icons.check_circle_rounded),
                              label: const Text('Nộp Bài Thi Ngay'),
                            ),
                    ),
                  ],
                ),
              ],
            ),

            // Màn chắn Cảnh báo Đỏ Đếm Ngược 10 Giây Chống Gian Lận
            if (_isAntiCheatWarningOverlayVisible)
              Container(
                color: Colors.black.withValues(alpha: 0.88),
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppTokens.danger, width: 3),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.gpp_bad_rounded, size: 64, color: AppTokens.danger),
                      const SizedBox(height: 12),
                      const Text(
                        'CẢNH BÁO VI PHẠM QUY CHẾ PHÒNG THI!',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: AppTokens.danger,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Hệ thống phát hiện bạn vừa rời khỏi màn hình làm bài (Lần cảnh cáo: ${_session?.violationCount ?? 1}/${widget.exam.maxViolations}).\n'
                        'Cảnh báo đã được gửi trực tiếp tới Giáo viên giám sát!',
                        style: TextStyle(fontSize: 13.5, color: textMain, height: 1.45),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppTokens.danger.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Tự động thu bài / hủy kết quả sau:',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$_graceSecondsLeft giây',
                              style: const TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                color: AppTokens.danger,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTokens.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: _confirmReturnedToExam,
                          icon: const Icon(Icons.login_rounded),
                          label: const Text(
                            'TÔI ĐÃ QUAY LẠI TIẾP TỤC LÀM BÀI',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinishedResultView(
    Color cardColor,
    Color bgColor,
    Color textMain,
    Color textSub,
    Color borderColor,
  ) {
    final session = _session!;
    final isViolationTerminated = session.status == 'force_submitted_auto' ||
        session.status == 'force_submitted_teacher' ||
        session.status == 'invalidated';

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        title: Text(
          'Kết Quả Phòng Thi Giám Sát',
          style: TextStyle(fontWeight: FontWeight.w800, color: textMain),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isViolationTerminated ? AppTokens.danger : AppTokens.success,
                width: 2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                EngPassMascot(
                  mood: isViolationTerminated ? MascotMood.study : MascotMood.celebrate,
                  size: 72,
                ),
                const SizedBox(height: 14),
                Text(
                  session.statusLabel,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: isViolationTerminated ? AppTokens.danger : AppTokens.success,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '${session.score.toStringAsFixed(1)} / 10.0 điểm',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: textMain,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _finalResultMessage,
                  style: TextStyle(fontSize: 13.5, color: textSub, height: 1.45),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                Text(
                  'Số câu đã trả lời: ${session.answeredCount}/${session.totalQuestions} • Số lần cảnh báo rời app: ${session.violationCount}',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: textSub),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Quay về Danh sách Phòng thi'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
