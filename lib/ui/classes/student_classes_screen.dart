import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/rbac_proctor_ai_service.dart';
import '../practice/supervised_exam_screen.dart';
import '../theme/app_tokens.dart';
import '../theme/components/app_button.dart';
import '../theme/components/app_card.dart';

/// Màn hình Quản lý Lớp học dành cho Học sinh:
/// - Nhập mã tham gia lớp học từ Giáo viên
/// - Xem danh sách lớp đã tham gia và trạng thái phê duyệt
/// - Xem bài tập và kỳ thi được giao theo từng lớp
class StudentClassesScreen extends StatefulWidget {
  const StudentClassesScreen({super.key});

  @override
  State<StudentClassesScreen> createState() => _StudentClassesScreenState();
}

class _StudentClassesScreenState extends State<StudentClassesScreen> {
  final RbacProctorAiService _service = RbacProctorAiService.instance;
  final TextEditingController _codeCtrl = TextEditingController();

  bool _isLoading = true;
  bool _isJoining = false;
  String? _joinError;
  String? _joinSuccess;
  List<Map<String, dynamic>> _myClasses = [];

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadClasses() async {
    setState(() => _isLoading = true);
    try {
      final list = await _service.getMyJoinedClasses();
      if (mounted) {
        setState(() {
          _myClasses = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleJoinClass() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() {
        _joinError = 'Vui lòng nhập mã lớp học từ giáo viên.';
        _joinSuccess = null;
      });
      return;
    }

    setState(() {
      _isJoining = true;
      _joinError = null;
      _joinSuccess = null;
    });

    final res = await _service.joinClassByCode(code);

    if (!mounted) return;

    if (res['ok'] == true) {
      _codeCtrl.clear();
      setState(() {
        _isJoining = false;
        _joinSuccess = res['message']?.toString() ?? 'Tham gia lớp thành công!';
        _joinError = null;
      });
      await _loadClasses();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_joinSuccess!),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      setState(() {
        _isJoining = false;
        _joinError = res['message']?.toString() ?? 'Mã lớp không hợp lệ hoặc lớp đã đóng.';
        _joinSuccess = null;
      });
    }
  }

  void _showClassDetail(Map<String, dynamic> c) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cid = (c['id'] ?? '').toString();
    final cName = (c['name'] ?? 'Lớp học').toString();
    final teacherName = (c['teacherName'] ?? c['teacher_name'] ?? 'Giáo viên phụ trách').toString();
    final schoolName = (c['schoolName'] ?? c['school_name'] ?? 'THPT').toString();
    final code = (c['code'] ?? c['join_code'] ?? '').toString();
    final status = (c['membershipStatus'] ?? 'approved').toString();
    final isApproved = status == 'approved' || status == 'active';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E2430) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          builder: (_, scrollCtrl) {
            return FutureBuilder<List<Map<String, dynamic>>>(
              future: _service.getAssignments(classId: cid),
              builder: (context, snapshot) {
                final assignments = snapshot.data ?? [];
                final loadingAssignments = snapshot.connectionState == ConnectionState.waiting;

                return ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.school_rounded, color: Color(0xFF2563EB), size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cName,
                                style: TextStyle(
                                  fontFamily: 'BeVietnamPro',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$teacherName • $schoolName',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Trạng thái thành viên
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isApproved
                            ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7))
                            : (isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isApproved
                              ? (isDark ? const Color(0xFF059669) : const Color(0xFF86EFAC))
                              : (isDark ? const Color(0xFFD97706) : const Color(0xFFFDE68A)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isApproved ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                            color: isApproved ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isApproved
                                  ? 'Bạn là thành viên chính thức của lớp học này.'
                                  : 'Yêu cầu đang chờ giáo viên phê duyệt vào lớp.',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isApproved
                                    ? (isDark ? const Color(0xFF86EFAC) : const Color(0xFF166534))
                                    : (isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Thông tin mã lớp
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Mã lớp: $code',
                            style: TextStyle(
                              fontFamily: 'BeVietnamPro',
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: code));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Đã sao chép mã lớp vào bộ nhớ tạm'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            label: const Text('Sao chép'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Danh sách bài tập
                    Text(
                      'Bài tập & Đề thi của lớp',
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (loadingAssignments)
                      const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
                    else if (assignments.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.assignment_turned_in_outlined,
                                size: 36, color: isDark ? Colors.white38 : Colors.black38),
                            const SizedBox(height: 8),
                            Text(
                              'Chưa có bài tập nào được giao cho lớp này.',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...assignments.map((a) {
                        final title = (a['title'] ?? 'Bài tập').toString();
                        final deadline = (a['deadline'] ?? 'Không giới hạn').toString();
                        final isExam = a['type'] == 'exam' || a['isExam'] == true;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isExam
                                  ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                                  : const Color(0xFF2563EB).withValues(alpha: 0.15),
                              child: Icon(
                                isExam ? Icons.timer_outlined : Icons.assignment_outlined,
                                color: isExam ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                                size: 20,
                              ),
                            ),
                            title: Text(
                              title,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            subtitle: Text('Hạn chót: $deadline', style: const TextStyle(fontSize: 12)),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SupervisedExamListScreen(),
                                  ),
                                );
                              },
                              child: const Text('Làm bài', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        );
                      }),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121620) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Lớp học của tôi',
          style: TextStyle(fontFamily: 'BeVietnamPro', fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadClasses,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadClasses,
        child: ListView(
          padding: const EdgeInsets.all(AppTokens.space16),
          children: [
            // Thẻ nhập mã tham gia lớp học
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.group_add_rounded, color: Color(0xFF2563EB), size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tham gia lớp học mới',
                              style: TextStyle(
                                fontFamily: 'BeVietnamPro',
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Nhập mã lớp do giáo viên cung cấp (ví dụ: 12A1-1234)',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _codeCtrl,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\-]')),
                          ],
                          decoration: InputDecoration(
                            hintText: 'Nhập mã lớp học…',
                            prefixIcon: const Icon(Icons.key_rounded, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 48,
                        child: AppButton(
                          label: _isJoining ? 'Đang vào...' : 'Vào lớp',
                          variant: AppButtonVariant.primary,
                          isLoading: _isJoining,
                          onPressed: _isJoining ? null : _handleJoinClass,
                        ),
                      ),
                    ],
                  ),

                  if (_joinError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _joinError!,
                      style: const TextStyle(color: Colors.red, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ],

                  if (_joinSuccess != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _joinSuccess!,
                      style: const TextStyle(color: Color(0xFF16A34A), fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Tiêu đề danh sách lớp học
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Lớp học đã tham gia (${_myClasses.length})',
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
            else if (_myClasses.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2430) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.school_outlined,
                      size: 52,
                      color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Bạn chưa tham gia lớp học nào',
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Hãy hỏi thầy/cô giáo dạy tiếng Anh của bạn để lấy mã lớp và nhập vào ô phía trên để vào lớp.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._myClasses.map((c) {
                final cName = (c['name'] ?? 'Lớp học').toString();
                final teacherName = (c['teacherName'] ?? c['teacher_name'] ?? 'Giáo viên').toString();
                final schoolName = (c['schoolName'] ?? c['school_name'] ?? 'THPT').toString();
                final code = (c['code'] ?? c['join_code'] ?? '').toString();
                final studentsCount = (c['studentsCount'] ?? 0 as num).toInt();
                final status = (c['membershipStatus'] ?? 'approved').toString();
                final isApproved = status == 'approved' || status == 'active';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _showClassDetail(c),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(
                                  child: Icon(Icons.groups_rounded, color: Color(0xFF2563EB), size: 24),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      cName,
                                      style: TextStyle(
                                        fontFamily: 'BeVietnamPro',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$teacherName • $schoolName',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isApproved
                                      ? const Color(0xFF16A34A).withValues(alpha: 0.15)
                                      : const Color(0xFFD97706).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  isApproved ? 'Đang học' : 'Chờ duyệt',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: isApproved ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Mã lớp: $code',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                              Row(
                                children: [
                                  Icon(Icons.person_outline_rounded,
                                      size: 15, color: isDark ? Colors.white60 : Colors.black54),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$studentsCount học sinh',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: isDark ? Colors.white60 : Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
