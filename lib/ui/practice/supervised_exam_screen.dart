import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/rbac_proctor_ai_service.dart';
import '../auth/auth_controller.dart';
import '../auth/login_screen.dart';
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
  List<Map<String, dynamic>> _assignments = [];
  Map<String, ExamLiveSessionModel> _myExamSessions = {};
  final TextEditingController _joinCodeController = TextEditingController();

  bool get _isGuest =>
      !AuthController.instance.isAuthenticated ||
      AuthController.instance.user.isGuest;

  @override
  void initState() {
    super.initState();
    _loadExams();
  }

  @override
  void dispose() {
    _joinCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadExams() async {
    setState(() => _isLoading = true);
    final list = await RbacProctorAiService.instance.getSupervisedExams();
    final assigns = await RbacProctorAiService.instance.getAssignments();
    final user = AuthController.instance.user;
    final Map<String, ExamLiveSessionModel> mySessions = {};

    for (final exam in list) {
      final sessions = await RbacProctorAiService.instance.getLiveSessionsForExam(exam.id);
      final my = sessions.where((s) => s.userId == user.id).firstOrNull;
      if (my != null) {
        mySessions[exam.id] = my;
      }
    }

    if (!mounted) return;
    setState(() {
      _exams = list.where((e) => e.isActive).toList();
      _assignments = assigns.where((a) => a['status'] != 'closed').toList();
      _myExamSessions = mySessions;
      _isLoading = false;
    });
  }

  void _showGuestWarningDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.lock_person_rounded, color: AppTokens.primary, size: 26),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Yêu Cầu Tài Khoản Học Sinh',
                style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tính năng Phòng Thi Giám Sát và Lớp Học yêu cầu tài khoản học sinh chính thức để:',
              style: TextStyle(fontSize: 13.5, height: 1.4),
            ),
            SizedBox(height: 8),
            Text('• Tham gia danh sách lớp do Giáo viên tạo.', style: TextStyle(fontSize: 13, height: 1.4)),
            Text('• Ghi nhận điểm số học bạ và kết quả làm bài.', style: TextStyle(fontSize: 13, height: 1.4)),
            Text('• Giám sát tính trung thực trong quá trình thi cử.', style: TextStyle(fontSize: 13, height: 1.4)),
            SizedBox(height: 10),
            Text(
              'Tài khoản Khách vãng lai chỉ dùng để học thử bài giảng và không thể lưu điểm thi.',
              style: TextStyle(fontSize: 12.5, color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Để sau'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            icon: const Icon(Icons.login_rounded, size: 18),
            label: const Text('Đăng nhập ngay'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleJoinClassByCode() async {
    if (_isGuest) {
      _showGuestWarningDialog();
      return;
    }
    final code = _joinCodeController.text.trim();
    if (code.isEmpty) return;
    final res = await RbacProctorAiService.instance.joinClassByCode(code);
    if (!mounted) return;
    final ok = res['ok'] == true;
    if (ok) {
      _joinCodeController.clear();
      await _loadExams();
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text((res['message'] ?? '').toString()),
        backgroundColor: ok ? AppTokens.success : AppTokens.danger,
      ),
    );
  }

  void _showExamRulesSheet(SupervisedExamModel exam) {
    if (_isGuest) {
      _showGuestWarningDialog();
      return;
    }

    final mySession = _myExamSessions[exam.id];
    if (mySession != null && !mySession.isActive) {
      _showFinishedExamDetailSheet(exam, mySession);
      return;
    }

    bool agreed = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.policy_outlined, color: AppTokens.primary),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Quy chế thi có giám sát',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                exam.title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  Chip(label: Text('${exam.questions.length} câu')),
                  Chip(label: Text('${exam.durationMinutes} phút')),
                  Chip(label: Text('Làm ${exam.maxAttempts} lần')),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Trong lúc thi:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              _buildRuleItem(
                Icons.app_blocking_outlined,
                Colors.indigo,
                'Không thoát ứng dụng và không chuyển sang ứng dụng khác.',
              ),
              _buildRuleItem(
                Icons.timer_outlined,
                Colors.amber[800]!,
                'Nếu rời ứng dụng, bạn có ${exam.graceSeconds} giây để quay lại làm bài.',
              ),
              _buildRuleItem(
                Icons.warning_amber_rounded,
                Colors.red,
                'Quá ${exam.graceSeconds} giây, bài thi tự nộp và tính điểm ngay. Câu chưa làm tính là sai.',
              ),
              _buildRuleItem(
                Icons.visibility_outlined,
                Colors.blueGrey,
                'Mọi lần rời ứng dụng đều được ghi nhận và gửi trực tiếp cho Giáo viên.',
              ),
              const SizedBox(height: 10),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: agreed,
                onChanged: (v) => setSheetState(() => agreed = v ?? false),
                title: const Text(
                  'Tôi đã đọc và đồng ý với quy chế thi có giám sát',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: agreed
                      ? () async {
                          Navigator.pop(ctx);
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SupervisedExamPlayerScreen(exam: exam),
                            ),
                          );
                          _loadExams();
                        }
                      : null,
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('Bắt đầu thi'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRuleItem(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13, height: 1.35)),
          ),
        ],
      ),
    );
  }

  /// Xem lại kết quả bài thi đã hoàn thành hoặc bị thu bài (Chặn thi lại)
  void _showFinishedExamDetailSheet(SupervisedExamModel exam, ExamLiveSessionModel session) {
    final isViolation = session.status == 'force_submitted_auto' ||
        session.status == 'force_submitted_teacher' ||
        session.status == 'invalidated';
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(22),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isViolation ? Icons.gpp_bad_rounded : Icons.verified_rounded,
                  color: isViolation ? AppTokens.danger : AppTokens.success,
                  size: 26,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isViolation ? 'Kết quả: Vi phạm quy chế thi' : 'Kết quả bài thi đã nộp',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: isViolation ? AppTokens.danger : AppTokens.textMain,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              exam.title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),

            // Điểm số nổi bật
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: (isViolation ? AppTokens.danger : AppTokens.primary).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isViolation ? AppTokens.danger : AppTokens.primary,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '${session.score.toStringAsFixed(1)} / 10.0',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: isViolation ? AppTokens.danger : AppTokens.primary,
                      ),
                    ),
                    Text(
                      session.statusLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isViolation ? AppTokens.danger : AppTokens.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Thống kê bài thi
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Số câu đã làm:', style: TextStyle(fontSize: 13, color: Colors.black87)),
                      Text('${session.answeredCount} / ${session.totalQuestions} câu', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Divider(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Số lần cảnh cáo rời app:', style: TextStyle(fontSize: 13, color: Colors.black87)),
                      Text('${session.violationCount} lần', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: session.violationCount > 0 ? AppTokens.danger : Colors.black87)),
                    ],
                  ),
                  if (session.submittedAt != null) ...[
                    const Divider(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Thời điểm nộp bài:', style: TextStyle(fontSize: 13, color: Colors.black87)),
                        Text(dateFmt.format(session.submittedAt!), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            if (session.teacherWarningMessage != null && session.teacherWarningMessage!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTokens.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTokens.danger.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 18, color: AppTokens.danger),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        session.teacherWarningMessage!,
                        style: const TextStyle(fontSize: 12.5, color: AppTokens.danger, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),
            // Thông báo quy chế chặn làm lại
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber[300]!),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_clock_rounded, size: 18, color: Colors.amber),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Quy chế thi có giám sát: Mỗi học sinh chỉ được làm bài 1 lần duy nhất để bảo đảm tính công bằng. Bạn không thể làm lại bài thi này.',
                      style: TextStyle(fontSize: 12, color: Colors.brown, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Đã hiểu và đóng'),
              ),
            ),
          ],
        ),
      ),
    );
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
          'Lớp Học & Phòng Thi Giám Sát',
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
                if (_isGuest)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Bạn đang ở chế độ Khách vãng lai',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Để được vào lớp của giáo viên và lưu điểm thi giám sát, vui lòng đăng nhập.',
                                style: TextStyle(fontSize: 12, color: textSub),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                          ),
                          child: const Text('Đăng nhập', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),

                // Khối Tham gia lớp học bằng Mã lớp thật
                Container(
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
                          const Icon(Icons.groups_rounded, color: AppTokens.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Tham gia lớp học bằng mã giáo viên cấp',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: textMain,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _joinCodeController,
                              textCapitalization: TextCapitalization.characters,
                              decoration: const InputDecoration(
                                hintText: 'Nhập mã lớp (VD: 12A1-7432)',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          FilledButton(
                            onPressed: _handleJoinClassByCode,
                            child: const Text('Vào lớp'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Danh sách bài tập lớp học giáo viên giao (nếu có)
                if (_assignments.isNotEmpty) ...[
                  Text(
                    'Bài tập Giáo viên giao (${_assignments.length})',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textMain),
                  ),
                  const SizedBox(height: 8),
                  ..._assignments.map((a) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.assignment_outlined, color: AppTokens.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a['title'].toString(),
                                  style: TextStyle(fontWeight: FontWeight.bold, color: textMain),
                                ),
                                Text(
                                  'Lớp ${a['className'] ?? "12"} • Unit ${a['unitNumber'] ?? 1}',
                                  style: TextStyle(fontSize: 12, color: textSub),
                                ),
                              ],
                            ),
                          ),
                          FilledButton.tonal(
                            onPressed: () async {
                              await RbacProctorAiService.instance.submitAssignment(
                                assignmentId: a['id'].toString(),
                                classId: (a['classId'] ?? '').toString(),
                                score: 8.5,
                              );
                              await _loadExams();
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Đã hoàn thành và nộp bài "${a['title']}"!'),
                                  backgroundColor: AppTokens.success,
                                ),
                              );
                            },
                            child: const Text('Nộp bài'),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                ],

                // Thẻ giới thiệu cơ chế chống gian lận
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
                              '• Nếu thoát ứng dụng / mở app khác quá thời gian quy định hoặc vượt số lần cảnh cáo, hệ thống sẽ tự động thu bài và báo cho Giáo viên.',
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
                  final mySession = _myExamSessions[exam.id];
                  final hasCompleted = mySession != null && !mySession.isActive;
                  final isViolation = hasCompleted &&
                      (mySession.status == 'force_submitted_auto' ||
                          mySession.status == 'force_submitted_teacher' ||
                          mySession.status == 'invalidated');

                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: hasCompleted
                            ? (isViolation ? AppTokens.danger.withValues(alpha: 0.5) : AppTokens.success.withValues(alpha: 0.5))
                            : borderColor,
                        width: hasCompleted ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: (hasCompleted
                                        ? (isViolation ? AppTokens.danger : AppTokens.success)
                                        : (isLate ? AppTokens.warning : AppTokens.success))
                                    .withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                hasCompleted
                                    ? (isViolation ? 'Đã thu bài do vi phạm' : 'Đã nộp bài hoàn tất')
                                    : (isLate ? 'Đã quá hạn nộp chuẩn' : 'Đang mở nhận bài'),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: hasCompleted
                                      ? (isViolation ? AppTokens.danger : AppTokens.success)
                                      : (isLate ? AppTokens.warning : AppTokens.success),
                                ),
                              ),
                            ),
                            const Spacer(),
                            const Icon(Icons.shield_rounded, size: 16, color: AppTokens.primary),
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
                        if (hasCompleted) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: (isViolation ? AppTokens.danger : AppTokens.success).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isViolation ? Icons.gpp_bad_rounded : Icons.check_circle_rounded,
                                  size: 16,
                                  color: isViolation ? AppTokens.danger : AppTokens.success,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Điểm số: ${mySession.score.toStringAsFixed(1)} / 10.0 • ${mySession.statusLabel}',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: isViolation ? AppTokens.danger : AppTokens.success,
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
                          child: hasCompleted
                              ? FilledButton.tonalIcon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: (isViolation ? AppTokens.danger : AppTokens.success).withValues(alpha: 0.12),
                                    foregroundColor: isViolation ? AppTokens.danger : AppTokens.success,
                                  ),
                                  onPressed: () => _showFinishedExamDetailSheet(exam, mySession),
                                  icon: const Icon(Icons.assignment_turned_in_rounded),
                                  label: const Text('Xem Kết Quả & Chi Tiết Bài Làm'),
                                )
                              : FilledButton.icon(
                                  onPressed: () => _showExamRulesSheet(exam),
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

  // Đồng hồ đếm ngược graceSeconds chống gian lận khi rời ứng dụng
  Timer? _graceCountdownTimer;
  bool _isAntiCheatWarningOverlayVisible = false;
  int _graceSecondsLeft = 10;
  DateTime? _leftAppAt;
  bool _isAppCurrentlyBackgrounded = false;

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
      _answers.addAll(started.currentAnswers);
    });

    if (!started.isActive) {
      setState(() {
        _isFinished = true;
        _finalResultMessage = started.teacherWarningMessage ??
            (started.status.startsWith('submitted')
                ? 'Bạn đã hoàn thành bài thi này.'
                : 'Bài thi đã bị khóa kết thúc do vi phạm quy chế.');
      });
      return;
    }

    final elapsedSec = DateTime.now().difference(started.startedAt).inSeconds;
    final totalSec = widget.exam.durationMinutes * 60;
    _remainingExamSeconds = (totalSec - elapsedSec).clamp(0, totalSec);
    if (_remainingExamSeconds <= 0) {
      _submitExamNow(isAutoTimeout: true);
      return;
    }

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
      if (!_isAppCurrentlyBackgrounded) {
        _isAppCurrentlyBackgrounded = true;
        _leftAppAt = DateTime.now();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_isAppCurrentlyBackgrounded) {
        _isAppCurrentlyBackgrounded = false;
        final left = _leftAppAt;
        _leftAppAt = null;
        if (left != null) {
          final awaySec = DateTime.now().difference(left).inSeconds;
          if (awaySec >= widget.exam.graceSeconds) {
            _handleGracePeriodExceeded(awaySec);
          } else {
            _handleReturnedWithinGrace(awaySec);
          }
        }
      }
    }
  }

  /// Xử lý khi học sinh quay lại phòng thi trong thời gian cho phép
  Future<void> _handleReturnedWithinGrace(int awaySec) async {
    if (_isFinished || _session == null) return;

    final updated = await RbacProctorAiService.instance.recordProctorHeartbeat(
      exam: widget.exam,
      currentSession: _session!,
      currentAnswers: _answers,
      eventType: 'app_backgrounded',
      outOfAppSeconds: awaySec,
      detail: 'Rời ứng dụng $awaySec giây rồi quay lại phòng thi.',
    );

    if (!mounted) return;
    setState(() => _session = updated);

    if (!updated.isActive) {
      _finalizeTerminatedSession(updated);
      return;
    }

    _showReturnWarningDialog(awaySec, updated.violationCount);
  }

  /// Hiển thị cảnh báo trực quan khi học sinh vừa out app quay lại
  void _showReturnWarningDialog(int awaySec, int violations) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTokens.danger, size: 28),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'CẢNH BÁO RỜI PHÒNG THI',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTokens.danger),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hệ thống phát hiện bạn vừa rời khỏi màn hình làm bài ${awaySec > 0 ? awaySec : 1} giây.',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTokens.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTokens.danger.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• Số lần cảnh cáo: $violations / ${widget.exam.maxViolations} lần',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTokens.danger),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• Thời gian tối đa cho phép mỗi lần: ${widget.exam.graceSeconds} giây',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '• Mọi lần rời app đều được lưu lại và gửi tới Giáo viên giám sát.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              violations >= widget.exam.maxViolations
                  ? '⚠️ Bạn đã chạm ngưỡng cảnh cáo! Rời app thêm 1 lần nữa bài thi sẽ bị thu hồi ngay lập tức!'
                  : 'Vui lòng tập trung làm bài và không tiếp tục chuyển đổi ứng dụng.',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: violations >= widget.exam.maxViolations ? AppTokens.danger : AppTokens.primary,
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tôi đã hiểu, tiếp tục làm bài'),
          ),
        ],
      ),
    );
  }

  /// Nút thử nghiệm đếm ngược trực tiếp trên màn hình
  void _triggerManualTestCountdown() {
    if (_isFinished || _session == null) return;
    _graceCountdownTimer?.cancel();
    setState(() {
      _isAntiCheatWarningOverlayVisible = true;
      _graceSecondsLeft = widget.exam.graceSeconds;
    });

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
    final elapsedSec = widget.exam.graceSeconds - _graceSecondsLeft;
    _handleReturnedWithinGrace(elapsedSec > 0 ? elapsedSec : 1);
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
          titleSpacing: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.exam.title,
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: textMain),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Row(
                children: [
                  const Icon(Icons.shield_rounded, size: 12, color: AppTokens.success),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      'Giám sát ${widget.exam.graceSeconds}s • Cảnh cáo: ${_session?.violationCount ?? 0}/${widget.exam.maxViolations}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: (_session?.violationCount ?? 0) > 0
                            ? AppTokens.danger
                            : AppTokens.success,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            // Nút mô phỏng thoát ứng dụng gọn gàng, không tràn màn hình
            IconButton(
              tooltip: 'Thử nghiệm rời ứng dụng (Test Out App)',
              padding: const EdgeInsets.symmetric(horizontal: 4),
              constraints: const BoxConstraints(),
              icon: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTokens.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTokens.warning.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 13, color: AppTokens.warning),
                    SizedBox(width: 2),
                    Text(
                      'Test Out',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppTokens.warning),
                    ),
                  ],
                ),
              ),
              onPressed: _triggerManualTestCountdown,
            ),
            Container(
              margin: const EdgeInsets.only(right: 12, left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: AppTokens.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _formatClock(_remainingExamSeconds),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppTokens.primary,
                  fontSize: 13,
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

                // Nội dung câu hỏi + Nút Báo lỗi câu hỏi thật
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (currentQ['stem'] ?? '').toString(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textMain,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            foregroundColor: textSub,
                          ),
                          onPressed: () => _showReportQuestionDialog(currentQ, _currentIndex + 1),
                          icon: const Icon(Icons.flag_outlined, size: 15),
                          label: const Text('Báo lỗi câu hỏi', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
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

  void _showReportQuestionDialog(Map<String, dynamic> question, int questionNum) {
    final reasonCtrl = TextEditingController();
    String issueType = 'Sai đáp án';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Báo lỗi Câu $questionNum'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: issueType,
                decoration: const InputDecoration(
                  labelText: 'Loại lỗi',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Sai đáp án', child: Text('Sai đáp án')),
                  DropdownMenuItem(value: 'Sai chính tả', child: Text('Sai chính tả / Đề thiếu chữ')),
                  DropdownMenuItem(value: 'Giải thích chưa rõ', child: Text('Giải thích chưa rõ')),
                ],
                onChanged: (v) => setDialogState(() => issueType = v ?? 'Sai đáp án'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Mô tả chi tiết lỗi bạn phát hiện',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () async {
                if (reasonCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                await RbacProctorAiService.instance.submitBugReport(
                  targetCode: '${widget.exam.title} • Câu $questionNum',
                  unitNumber: (question['unitNumber'] as num?)?.toInt() ?? 1,
                  skill: (question['skill'] ?? 'grammar').toString(),
                  issueType: issueType,
                  reason: reasonCtrl.text.trim(),
                  questionId: (question['id'] ?? '').toString(),
                );
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã gửi báo lỗi câu hỏi tới Giáo viên & Admin!'),
                    backgroundColor: AppTokens.success,
                  ),
                );
              },
              child: const Text('Gửi báo lỗi'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSubmitExplanationDialog(ExamLiveSessionModel session) {
    String selectedReason = 'Mất mạng hoặc Wi-Fi bị rớt';
    final explainCtrl = TextEditingController();

    // Nếu đã có giải trình trước đó
    if (session.studentExplanation != null && session.studentExplanation!.isNotEmpty) {
      final raw = session.studentExplanation!;
      if (raw.startsWith('[') && raw.contains('] ')) {
        final closing = raw.indexOf('] ');
        selectedReason = raw.substring(1, closing);
        explainCtrl.text = raw.substring(closing + 2);
      } else {
        explainCtrl.text = raw;
      }
    }

    final reasonOptions = const [
      'Mất mạng hoặc Wi-Fi bị rớt',
      'Có cuộc gọi đến',
      'Sự cố ứng dụng / máy tắt nguồn',
      'Việc gia đình khẩn cấp',
      'Khác...',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.assignment_late_outlined, color: Color(0xFF283593)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Gửi giải trình sự cố thi',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.timer_off_outlined, color: Colors.red[800], size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${widget.exam.title} • Quá hạn rời app ${widget.exam.graceSeconds}s',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red[900]),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Lý do sự cố', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: selectedReason,
                  isExpanded: true,
                  decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                  items: reasonOptions.map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (val) {
                    if (val != null) setSheetState(() => selectedReason = val);
                  },
                ),
                const SizedBox(height: 12),
                const Text('Cô cần biết thêm điều gì?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: explainCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Ví dụ: Wi-Fi nhà em bị rớt lúc thi, em mở lại app ngay.',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: Color(0xFF283593)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'App sẽ tự động đính kèm nhật ký rời app và thời gian của bạn cho cô xem.',
                          style: TextStyle(fontSize: 11, color: Colors.blue[900]),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Giải trình không đảm bảo được thi lại. Giáo viên sẽ xem xét nhật ký và trả lời. Hãy nói đúng sự thật.',
                  style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF283593)),
                    onPressed: () async {
                      final detail = explainCtrl.text.trim();
                      final fullExplanation = '[$selectedReason] ${detail.isNotEmpty ? detail : "Học sinh báo cáo sự cố $selectedReason"}';
                      final sm = ScaffoldMessenger.of(context);
                      Navigator.pop(ctx);
                      final updated = await RbacProctorAiService.instance.submitExamExplanation(
                        examId: widget.exam.id,
                        sessionId: session.id,
                        explanation: fullExplanation,
                      );
                      if (updated != null && mounted) {
                        setState(() => _session = updated);
                      }
                      if (mounted) {
                        sm.showSnackBar(
                          const SnackBar(
                            content: Text('Đã gửi giải trình kèm nhật ký tới giáo viên!'),
                            backgroundColor: AppTokens.success,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const Text('Gửi giải trình cho giáo viên'),
                  ),
                ),
              ],
            ),
          ),
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
        child: SingleChildScrollView(
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
                  isViolationTerminated ? 'Bài thi đã được nộp tự động' : session.statusLabel,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: isViolationTerminated ? AppTokens.danger : AppTokens.success,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '${session.score.toStringAsFixed(2)} / 10.0 điểm',
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
                  'Đã trả lời: ${session.answeredCount}/${session.totalQuestions} • Chưa làm: ${session.totalQuestions - session.answeredCount} • Rời app: ${session.violationCount} lần',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: textSub),
                  textAlign: TextAlign.center,
                ),
                if (session.studentExplanation != null &&
                    session.studentExplanation!.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTokens.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Đã gửi giải trình: "${session.studentExplanation}"',
                      style: TextStyle(fontSize: 12.5, color: textMain, fontStyle: FontStyle.italic),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                if (isViolationTerminated) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showSubmitExplanationDialog(session),
                      icon: const Icon(Icons.chat_bubble_outline_rounded),
                      label: const Text('Gửi giải trình cho giáo viên'),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
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
