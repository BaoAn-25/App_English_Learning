import 'dart:async';
import 'package:flutter/material.dart';

import '../../../data/app_repository.dart';
import '../../../data/rbac_proctor_ai_service.dart';
import '../components/admin_kpi_card.dart';
import '../components/class_code_dialog.dart';
import '../../common/dialogs/student_progress_sheet.dart';

/// Tab 4: Quản lý Lớp học, Giám sát Phòng thi 10s Live & Thông báo Hệ thống
class AdminProctorTab extends StatefulWidget {
  final AppRepository repository;

  const AdminProctorTab({super.key, required this.repository});

  @override
  State<AdminProctorTab> createState() => _AdminProctorTabState();
}

class _AdminProctorTabState extends State<AdminProctorTab> with SingleTickerProviderStateMixin {
  final RbacProctorAiService _service = RbacProctorAiService.instance;
  late TabController _subTabController;

  List<Map<String, dynamic>> _classes = [];
  List<SupervisedExamModel> _exams = [];
  List<Map<String, dynamic>> _announcements = [];
  bool _isLoading = true;

  Timer? _liveRefreshTimer;

  @override
  void initState() {
    super.initState();
    _subTabController = TabController(length: 3, vsync: this);
    _loadData();
    // Tự động làm mới số liệu giám sát phòng thi mỗi 10 giây (Live Proctoring)
    final isTesting = WidgetsBinding.instance.runtimeType.toString().contains('TestWidgetsFlutterBinding');
    if (!isTesting) {
      _liveRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        if (mounted && _subTabController.index == 1) {
          _refreshLiveProctor();
        }
      });
    }
  }

  @override
  void dispose() {
    _liveRefreshTimer?.cancel();
    _subTabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final classes = await _service.getClasses();
      final exams = await _service.getSupervisedExams();
      final announcements = await _service.getAnnouncements();

      if (mounted) {
        setState(() {
          _classes = classes;
          _exams = exams;
          _announcements = announcements;
          _isLoading = false;
        });
      }
      // Tự động đồng bộ ngầm các lớp lên Cloud Render
      _service.syncAllClassesToCloud().catchError((_) => <String, dynamic>{});
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshLiveProctor() async {
    final exams = await _service.getSupervisedExams();
    if (mounted) {
      setState(() => _exams = exams);
    }
  }

  void _confirmDeleteClass(Map<String, dynamic> c, {VoidCallback? onSuccess}) {
    final className = (c['name'] ?? 'Lớp học').toString();
    final classId = c['id'].toString();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
            const SizedBox(width: 8),
            Expanded(child: Text('Giải tán $className?')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hành động này sẽ xóa vĩnh viễn lớp "$className" (Mã: ${c['code']}) khỏi hệ thống.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '• Học sinh sẽ bị gỡ khỏi danh sách lớp.\n• Mã tham gia lớp lập tức bị vô hiệu hóa.\n• Dữ liệu gắn với lớp này sẽ được làm sạch.',
              style: TextStyle(fontSize: 12.5, color: Colors.black87, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy bỏ'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red[700]),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await _service.deleteClass(classId);
              if (success) {
                await _loadData();
                onSuccess?.call();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Đã giải tán lớp "$className" thành công!'),
                      backgroundColor: Colors.red[800],
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.delete_forever, size: 18),
            label: const Text('Xác nhận giải tán'),
          ),
        ],
      ),
    );
  }

  void _showAddClassModal() {
    final nameCtrl = TextEditingController();
    final schoolCtrl = TextEditingController(text: 'THPT Nguyễn Trãi');
    final teacherCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          top: 20,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
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
                const Icon(Icons.class_outlined, color: Color(0xFF1E3A8A)),
                const SizedBox(width: 8),
                const Text('Thêm lớp học mới', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Tên lớp (VD: 12A3)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: schoolCtrl,
              decoration: const InputDecoration(labelText: 'Trường học', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: teacherCtrl,
              decoration: const InputDecoration(labelText: 'Giáo viên phụ trách (Tùy chọn)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) return;
                  Navigator.pop(ctx);
                  await _service.createClass(
                    name: nameCtrl.text.trim(),
                    schoolName: schoolCtrl.text.trim(),
                    teacherName: teacherCtrl.text.trim().isEmpty ? 'Chưa có GV' : teacherCtrl.text.trim(),
                  );
                  _loadData();
                },
                child: const Text('Lưu lớp học'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAssignTeacherModal(Map<String, dynamic> cls) {
    final teacherCtrl = TextEditingController(text: cls['teacherName'] == 'Chưa có GV' ? '' : (cls['teacherName'] ?? '').toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Gán giáo viên cho lớp ${cls['name']}'),
        content: TextField(
          controller: teacherCtrl,
          decoration: const InputDecoration(labelText: 'Tên giáo viên phụ trách', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _service.updateClass(
                classId: cls['id'].toString(),
                teacherName: teacherCtrl.text.trim().isEmpty ? 'Chưa có GV' : teacherCtrl.text.trim(),
                status: teacherCtrl.text.trim().isEmpty ? 'needs_teacher' : 'active',
              );
              _loadData();
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRegenerateClassCode(Map<String, dynamic> cls) async {
    final classId = cls['id'].toString();
    final className = (cls['name'] ?? 'Lớp học').toString();
    final oldCode = (cls['code'] ?? '').toString();

    // Sinh mã lớp mới từ cơ sở dữ liệu thật
    final newCode = await _service.regenerateClassCode(classId);
    await _loadData();

    if (!mounted) return;

    // Hiển thị cửa sổ nhỏ thông báo đổi mã trực quan với các con số/ký tự nổi bật
    await ClassCodeDialog.show(
      context,
      className: className,
      oldCode: oldCode,
      initialNewCode: newCode,
      onRegenerateAnother: () async {
        final anotherCode = await _service.regenerateClassCode(classId);
        await _loadData();
        return anotherCode;
      },
    );
  }

  void _showCreateSupervisedExamModal() {
    final titleCtrl = TextEditingController(text: 'Kỳ thi Giám sát Khối 12: Đề Ôn tập Trọng điểm');
    String selectedClassId = _classes.isNotEmpty ? _classes.first['id'].toString() : '';
    String selectedClassName = _classes.isNotEmpty ? _classes.first['name'].toString() : 'Toàn trường';
    int durationMinutes = 45;
    int maxAttempts = 1;
    int graceSeconds = 10;
    bool autoSubmitOnTimeout = true;
    bool shuffleQuestions = true;
    int unitForExam = 1;

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
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
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
                    const Icon(Icons.shield_outlined, color: Color(0xFF1E3A8A)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Admin: Tạo bài thi có giám sát ${graceSeconds}s',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tên bài thi kiểm tra',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                if (_classes.isNotEmpty)
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: selectedClassId,
                    decoration: const InputDecoration(
                      labelText: 'Giao cho lớp học',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(value: 'ALL', child: Text('Tất cả các lớp (Toàn trường)')),
                      ..._classes.map(
                        (c) => DropdownMenuItem(
                          value: c['id'].toString(),
                          child: Text('Lớp ${c['name']} (Mã: ${c['code']})'),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        final found = _classes.where((c) => c['id'].toString() == v).firstOrNull;
                        setSheetState(() {
                          selectedClassId = v;
                          selectedClassName = v == 'ALL' ? 'Toàn trường' : (found?['name']?.toString() ?? '12A1');
                        });
                      }
                    },
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: durationMinutes,
                        decoration: const InputDecoration(labelText: 'Thời gian làm bài', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 15, child: Text('15 phút')),
                          DropdownMenuItem(value: 30, child: Text('30 phút')),
                          DropdownMenuItem(value: 45, child: Text('45 phút')),
                          DropdownMenuItem(value: 60, child: Text('60 phút')),
                        ],
                        onChanged: (v) => setSheetState(() => durationMinutes = v ?? 45),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: maxAttempts,
                        decoration: const InputDecoration(labelText: 'Số lần làm', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('1 lần')),
                          DropdownMenuItem(value: 2, child: Text('2 lần')),
                        ],
                        onChanged: (v) => setSheetState(() => maxAttempts = v ?? 1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  initialValue: unitForExam,
                  decoration: const InputDecoration(
                    labelText: 'Trích xuất đề từ Ngân hàng SGK 12',
                    border: OutlineInputBorder(),
                  ),
                  items: List.generate(
                    10,
                    (i) => DropdownMenuItem(value: i + 1, child: Text('Unit ${i + 1} (SGK Global Success 12)')),
                  ),
                  onChanged: (v) => setSheetState(() => unitForExam = v ?? 1),
                ),
                const SizedBox(height: 14),

                // Khối Chống gian lận
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quy chế giám sát chống gian lận (${graceSeconds}s Live Proctoring)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E3A8A)),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Thời gian cho phép quay lại khi rời ứng dụng:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          for (final sec in [5, 10, 15, 20])
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                child: ChoiceChip(
                                  label: Text('$sec s'),
                                  selected: graceSeconds == sec,
                                  onSelected: (_) => setSheetState(() => graceSeconds = sec),
                                ),
                              ),
                            ),
                        ],
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Tự nộp và tính điểm khi quá $graceSeconds giây', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: Text('Tự thu bài và ghi nhận log vi phạm sau $graceSeconds giây rời app', style: const TextStyle(fontSize: 11)),
                        value: autoSubmitOnTimeout,
                        onChanged: (v) => setSheetState(() => autoSubmitOnTimeout = v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Xáo trộn thứ tự câu và đáp án', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        value: shuffleQuestions,
                        onChanged: (v) => setSheetState(() => shuffleQuestions = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
                    onPressed: () async {
                      if (titleCtrl.text.trim().isEmpty) return;
                      Navigator.pop(ctx);
                      final qs = await _service.generateQuestionsWithAi(
                        unitNumber: unitForExam,
                        skill: 'grammar',
                        difficulty: 2,
                        count: 10,
                        topicPrompt: titleCtrl.text.trim(),
                      );
                      final created = await _service.saveSupervisedExam(
                        title: titleCtrl.text.trim(),
                        description: 'Kỳ thi do Admin phát hành: $selectedClassName (Ân hạn rời app: $graceSeconds giây)',
                        classId: selectedClassId,
                        className: selectedClassName,
                        durationMinutes: durationMinutes,
                        deadlineAt: DateTime.now().add(const Duration(days: 7)),
                        graceSeconds: graceSeconds,
                        maxViolations: 2,
                        maxAttempts: maxAttempts,
                        shuffleQuestions: shuffleQuestions,
                        violationAction: autoSubmitOnTimeout ? 'force_submit' : 'invalidate',
                        questions: qs,
                      );
                      await _loadData();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Admin đã phát hành bài thi giám sát "${created.title}"!'),
                            backgroundColor: const Color(0xFF1B5E20),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.verified_user_outlined),
                    label: Text('Phát hành đề thi giám sát ${graceSeconds}s'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showClassMembersModal(Map<String, dynamic> cls) async {
    final classId = cls['id'].toString();
    final className = (cls['name'] ?? 'Lớp học').toString();
    List<Map<String, dynamic>> members = await _service.getClassMembers(classId);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final approvedList = members.where((m) => m['status'] != 'pending').toList();
          final pendingList = members.where((m) => m['status'] == 'pending').toList();

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.85,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.groups_rounded, color: Color(0xFF1E3A8A)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Lớp $className', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('Giáo viên: ${cls['teacherName'] ?? "Chưa có GV"} • Mã: ${cls['code']}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 14),

                // Nút thêm học sinh vào lớp
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
                    onPressed: () => _showAddStudentToClassDialog(classId, () async {
                      final updated = await _service.getClassMembers(classId);
                      setSheetState(() => members = updated);
                      _loadData();
                    }),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                    label: const Text('Thêm học sinh vào lớp này'),
                  ),
                ),
                const SizedBox(height: 14),

                if (pendingList.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber[200]!),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.hourglass_top_rounded, size: 16, color: Colors.amber),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Có ${pendingList.length} yêu cầu vào lớp cần duyệt', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: pendingList.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (ctx, idx) {
                      final p = pendingList[idx];
                      return ListTile(
                        dense: true,
                        tileColor: Colors.amber[50]?.withValues(alpha: 0.5),
                        title: Text(p['studentName']?.toString() ?? 'Học sinh', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(p['studentEmail']?.toString() ?? ''),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check_circle, color: Colors.green),
                              onPressed: () async {
                                await _service.decideClassMember(classId: classId, memberId: p['id'].toString(), status: 'approved');
                                final updated = await _service.getClassMembers(classId);
                                setSheetState(() => members = updated);
                                _loadData();
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.cancel, color: Colors.red),
                              onPressed: () async {
                                await _service.decideClassMember(classId: classId, memberId: p['id'].toString(), status: 'rejected');
                                final updated = await _service.getClassMembers(classId);
                                setSheetState(() => members = updated);
                                _loadData();
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const Divider(height: 20),
                ],

                Text('Danh sách học sinh chính thức (${approvedList.length}):', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),

                Expanded(
                  child: approvedList.isEmpty
                      ? Center(
                          child: Text('Lớp này chưa có học sinh nào.\nBấm nút phía trên để thêm học sinh!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[500])),
                        )
                      : ListView.separated(
                          itemCount: approvedList.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (ctx, idx) {
                            final m = approvedList[idx];
                            final name = (m['studentName'] ?? 'Học sinh').toString();
                            final email = (m['studentEmail'] ?? '').toString();
                            final streak = (m['streakDays'] as num?)?.toInt() ?? 0;
                            final avg = (m['avgScore'] as num?)?.toDouble() ?? 0.0;

                            return ListTile(
                              tileColor: Colors.grey[50],
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[200]!)),
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                                child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'H', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                              ),
                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: Text('$email • Streak: $streak ngày • Điểm: ${avg.toStringAsFixed(1)}', style: const TextStyle(fontSize: 11)),
                              trailing: IconButton(
                                tooltip: 'Xem tiến độ học tập',
                                icon: const Icon(Icons.insights_rounded, color: Color(0xFF1E3A8A), size: 20),
                                onPressed: () {
                                  StudentProgressSheet.show(ctx, student: m, currentClassName: className, onUpdated: () async {
                                    final updated = await _service.getClassMembers(classId);
                                    setSheetState(() => members = updated);
                                  });
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAddStudentToClassDialog(String classId, VoidCallback onAdded) async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();

    // Lấy danh sách học sinh toàn hệ thống để Admin chọn nhanh nếu muốn
    final allUsers = await _service.getAdminUsers();
    final studentUsers = allUsers.where((u) => u['role'] == 'student').toList();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Thêm học sinh vào lớp'),
          content: SizedBox(
            width: MediaQuery.of(ctx).size.width.clamp(280.0, 380.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (studentUsers.isNotEmpty) ...[
                    const Text('Chọn nhanh học sinh đã đăng ký:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Danh sách học sinh',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                      selectedItemBuilder: (context) {
                        return studentUsers.map((u) {
                          final name = (u['display_name'] ?? u['displayName'] ?? u['email'] ?? '').toString();
                          final email = (u['email'] ?? '').toString();
                          return Text(
                            '$name ($email)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          );
                        }).toList();
                      },
                      items: studentUsers
                          .map(
                            (u) {
                              final name = (u['display_name'] ?? u['displayName'] ?? u['email'] ?? '').toString();
                              final email = (u['email'] ?? '').toString();
                              return DropdownMenuItem(
                                value: email,
                                child: Text(
                                  '$name ($email)',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              );
                            },
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          final found = studentUsers.where((u) => u['email'] == v).firstOrNull;
                          if (found != null) {
                            setDlgState(() {
                              nameCtrl.text = (found['display_name'] ?? found['displayName'] ?? '').toString();
                              emailCtrl.text = v;
                            });
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    const Row(children: [Expanded(child: Divider()), Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('hoặc nhập mới', style: TextStyle(fontSize: 11, color: Colors.grey))), Expanded(child: Divider())]),
                    const SizedBox(height: 10),
                  ],
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Họ và tên học sinh', border: OutlineInputBorder(), isDense: true),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email học sinh', border: OutlineInputBorder(), isDense: true),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                await _service.addStudentToClass(
                  classId: classId,
                  studentName: nameCtrl.text.trim(),
                  studentEmail: emailCtrl.text.trim(),
                );
                onAdded();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Đã thêm học sinh "${nameCtrl.text.trim()}" vào lớp thành công!'), backgroundColor: Colors.green[800]),
                  );
                }
              },
              child: const Text('Thêm vào lớp'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSendAnnouncementModal() {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    String target = 'all';
    String type = 'maintenance';
    String? titleError;
    String? contentError;
    bool isSubmitting = false;

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
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
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
                    const Icon(Icons.campaign_outlined, color: Color(0xFF1E3A8A)),
                    const SizedBox(width: 8),
                    const Text('Soạn thông báo hệ thống', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: target,
                  decoration: const InputDecoration(labelText: 'Gửi tới', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Tất cả người dùng')),
                    DropdownMenuItem(value: 'student', child: Text('Chỉ Học sinh')),
                    DropdownMenuItem(value: 'teacher', child: Text('Chỉ Giáo viên')),
                  ],
                  onChanged: (v) => setSheetState(() => target = v ?? 'all'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Loại thông báo', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'maintenance', child: Text('Bảo trì hệ thống')),
                    DropdownMenuItem(value: 'exam', child: Text('Lịch thi & Giám sát')),
                    DropdownMenuItem(value: 'update', child: Text('Sách mới & Cập nhật')),
                  ],
                  onChanged: (v) => setSheetState(() => type = v ?? 'maintenance'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    labelText: 'Tiêu đề thông báo *',
                    hintText: 'Nhập tiêu đề thông báo...',
                    errorText: titleError,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) {
                    if (titleError != null) setSheetState(() => titleError = null);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Nội dung chi tiết *',
                    hintText: 'Nhập nội dung thông báo gửi đến người dùng...',
                    errorText: contentError,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) {
                    if (contentError != null) setSheetState(() => contentError = null);
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final title = titleCtrl.text.trim();
                            final content = contentCtrl.text.trim();
                            bool hasError = false;
                            if (title.isEmpty) {
                              titleError = 'Vui lòng nhập tiêu đề thông báo';
                              hasError = true;
                            }
                            if (content.isEmpty) {
                              contentError = 'Vui lòng nhập nội dung chi tiết';
                              hasError = true;
                            }
                            if (hasError) {
                              setSheetState(() {});
                              return;
                            }

                            setSheetState(() => isSubmitting = true);
                            try {
                              await _service.createAnnouncement(
                                title: title,
                                content: content,
                                audience: target,
                                category: type,
                              );
                              if (ctx.mounted) Navigator.pop(ctx);
                              await _loadData();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(Icons.check_circle_rounded, color: Colors.white),
                                        const SizedBox(width: 8),
                                        Expanded(child: Text('Đã phát thông báo "$title" thành công!')),
                                      ],
                                    ),
                                    backgroundColor: const Color(0xFF1B5E20),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } catch (e) {
                              setSheetState(() => isSubmitting = false);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Lỗi khi phát thông báo: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                    child: isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.send_rounded, size: 20),
                              SizedBox(width: 8),
                              Text('Phát thông báo ngay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showProctorDetailModal(SupervisedExamModel exam) async {
    final sessions = await _service.getLiveSessionsForExam(exam.id);

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          height: MediaQuery.of(ctx).size.height * 0.85,
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.shield, color: Colors.red),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exam.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Quy định: Ra ngoài quá ${exam.graceSeconds}s cảnh báo, quá ${exam.maxViolations} lần tự nộp',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: AdminKpiCard(
                      title: 'Đang làm',
                      value: '${sessions.where((s) => s.status == "in_progress").length}',
                      subtitle: 'Thí sinh trực tuyến',
                      icon: Icons.edit_note,
                      iconColor: Colors.blue,
                      backgroundColor: Colors.blue[50]!,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AdminKpiCard(
                      title: 'Cảnh báo 10s',
                      value: '${sessions.where((s) => s.violationCount > 0).length}',
                      subtitle: 'Vi phạm out app',
                      icon: Icons.warning_amber,
                      iconColor: Colors.amber[800]!,
                      backgroundColor: Colors.amber[50]!,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AdminKpiCard(
                      title: 'Đã nộp/Hủy',
                      value: '${sessions.where((s) => s.status != "in_progress").length}',
                      subtitle: 'Hoàn tất',
                      icon: Icons.assignment_turned_in,
                      iconColor: Colors.green,
                      backgroundColor: Colors.green[50]!,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Danh sách thí sinh trong phòng thi:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: sessions.isEmpty
                    ? Center(
                        child: Text('Chưa có thí sinh nào vào phòng thi này.', style: TextStyle(color: Colors.grey[600])),
                      )
                    : ListView.separated(
                        itemCount: sessions.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (ctx, idx) {
                          final s = sessions[idx];
                          final hasViolations = s.violationCount > 0;
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: hasViolations ? Colors.orange[50] : Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: hasViolations ? Colors.orange[300]! : Colors.grey[200]!,
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: hasViolations ? Colors.orange[100] : Colors.blue[100],
                                  child: Icon(
                                    hasViolations ? Icons.warning_amber_rounded : Icons.person,
                                    size: 18,
                                    color: hasViolations ? Colors.orange[900] : Colors.blue[900],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.studentName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      Text(
                                        'Vi phạm out app: ${s.violationCount}/${exam.maxViolations} lần | Trạng thái: ${s.status}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: hasViolations ? Colors.red[800] : Colors.grey[600],
                                          fontWeight: hasViolations ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (s.status == 'in_progress') ...[
                                  IconButton(
                                    tooltip: 'Nhắc nhở nóng',
                                    icon: const Icon(Icons.notifications_active, color: Colors.amber, size: 20),
                                    onPressed: () async {
                                      await _service.performTeacherProctorAction(
                                        exam: exam,
                                        session: s,
                                        action: 'warn',
                                      );
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Đã gửi thông báo cảnh cáo tới ${s.studentName}')),
                                        );
                                      }
                                    },
                                  ),
                                  IconButton(
                                    tooltip: 'Cưỡng chế nộp bài ngay',
                                    icon: const Icon(Icons.send_and_archive, color: Colors.red, size: 20),
                                    onPressed: () async {
                                      await _service.performTeacherProctorAction(
                                        exam: exam,
                                        session: s,
                                        action: 'force_submit',
                                      );
                                      if (ctx.mounted) Navigator.pop(ctx);
                                      _loadData();
                                    },
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab điều hướng phụ chuẩn M3: Lớp học | Giám sát 10s | Thông báo
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _subTabController,
            labelColor: const Color(0xFF1E3A8A),
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: const Color(0xFF1E3A8A),
            indicatorWeight: 3,
            tabs: [
              Tab(
                icon: const Icon(Icons.class_outlined, size: 18),
                text: 'Lớp học (${_classes.length})',
              ),
              Tab(
                icon: const Icon(Icons.shield_outlined, size: 18),
                text: 'Giám sát 10s (${_exams.length})',
              ),
              Tab(
                icon: const Icon(Icons.campaign_outlined, size: 18),
                text: 'Thông báo (${_announcements.length})',
              ),
            ],
          ),
        ),
        if (_isLoading) const LinearProgressIndicator(minHeight: 2),

        Expanded(
          child: TabBarView(
            controller: _subTabController,
            children: [
              _buildClassesSubView(),
              _buildProctorSubView(),
              _buildAnnouncementsSubView(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildClassesSubView() {
    final needsTeacherCount = _classes.where((c) => c['status'] == 'needs_teacher').length;
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: AdminKpiCard(
                    title: 'Tổng số lớp',
                    value: '${_classes.length}',
                    subtitle: 'Đang hoạt động',
                    icon: Icons.meeting_room_outlined,
                    iconColor: Colors.blue,
                    backgroundColor: Colors.blue[50]!,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AdminKpiCard(
                    title: 'Cần chú ý',
                    value: '$needsTeacherCount',
                    subtitle: needsTeacherCount > 0 ? '$needsTeacherCount lớp chưa có GV' : 'Đã phân công đủ',
                    icon: Icons.warning_amber_rounded,
                    iconColor: needsTeacherCount > 0 ? Colors.orange[800]! : Colors.green,
                    backgroundColor: needsTeacherCount > 0 ? Colors.orange[50]! : Colors.green[50]!,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 430;
                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Danh sách lớp học:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: _showCreateSupervisedExamModal,
                              icon: const Icon(Icons.shield_outlined, size: 16),
                              label: const Text('Tạo thi 10s', style: TextStyle(fontSize: 12.5)),
                              style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _showAddClassModal,
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Thêm lớp', style: TextStyle(fontSize: 12.5)),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF1E3A8A),
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Danh sách lớp học:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: _showCreateSupervisedExamModal,
                          icon: const Icon(Icons.shield_outlined, size: 16),
                          label: const Text('Tạo thi 10s'),
                          style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: _showAddClassModal,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Thêm lớp'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A8A),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _classes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (ctx, idx) {
                final c = _classes[idx];
                final needsTeacher = c['status'] == 'needs_teacher';
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _showClassMembersModal(c),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: needsTeacher ? Colors.orange[300]! : Colors.grey[200]!,
                        ),
                      ),
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E3A8A).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.groups_outlined, color: Color(0xFF1E3A8A)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${c['name']} - ${c['schoolName'] ?? c['school'] ?? "THPT"}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                Text(
                                  '${c['teacherName'] ?? "Giáo viên"} • ${c['studentsCount'] ?? c['studentCount'] ?? 0} học sinh • Mã: ${c['code']}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: needsTeacher ? Colors.orange[100] : Colors.green[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              needsTeacher ? 'Chưa có GV' : 'Hoạt động',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: needsTeacher ? Colors.orange[900] : Colors.green[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            onPressed: () => _showClassMembersModal(c),
                            icon: const Icon(Icons.group_outlined, size: 14),
                            label: const Text('Học sinh', style: TextStyle(fontSize: 12)),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            onPressed: () => _showAssignTeacherModal(c),
                            icon: const Icon(Icons.person_add_alt, size: 14),
                            label: Text(needsTeacher ? 'Gán GV' : 'Đổi GV', style: const TextStyle(fontSize: 12)),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            onPressed: () => _handleRegenerateClassCode(c),
                            icon: const Icon(Icons.refresh, size: 14),
                            label: const Text('Đổi mã', style: TextStyle(fontSize: 12)),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            tooltip: 'Giải tán lớp',
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                            onPressed: () => _confirmDeleteClass(c),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
          ],
        ),
      ),
    );
  }

  Widget _buildProctorSubView() {
    return RefreshIndicator(
      onRefresh: _refreshLiveProctor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.wifi_tethering, color: Color(0xFF1D4ED8)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Đang bật Giám sát Trực tiếp (Live 10s Anti-Cheat). Tự động cập nhật mỗi 10 giây.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Kỳ thi giám sát hệ thống:',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                FilledButton.icon(
                  onPressed: _showCreateSupervisedExamModal,
                  icon: const Icon(Icons.shield_outlined, size: 15),
                  label: const Text('Tạo thi 10s', style: TextStyle(fontSize: 12.5)),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_exams.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text('Chưa có đề thi có giám sát nào được tạo.', style: TextStyle(color: Colors.grey[600])),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _exams.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (ctx, idx) {
                  final ex = _exams[idx];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.quiz_outlined, color: Colors.blue),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ex.title,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  Text(
                                    '${ex.durationMinutes} phút • ${ex.questions.length} câu hỏi • Hạn nộp: ${ex.deadlineAt.hour}:${ex.deadlineAt.minute}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: ex.isActive ? Colors.green[100] : Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                ex.isActive ? 'Đang mở' : 'Đã đóng',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: ex.isActive ? Colors.green[900] : Colors.grey[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF1E3A8A),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () => _showProctorDetailModal(ex),
                              icon: const Icon(Icons.remove_red_eye_outlined, size: 16),
                              label: const Text('Xem giám sát 10s Live'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnouncementsSubView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Thông báo hệ thống:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              FilledButton.icon(
                onPressed: _showSendAnnouncementModal,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Soạn mới'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _announcements.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (ctx, idx) {
              final a = _announcements[idx];
              final targetVal = (a['target'] ?? a['audience'] ?? 'all').toString();
              final targetLabel = targetVal == 'all'
                  ? 'Tất cả'
                  : (targetVal == 'student' ? 'Học sinh' : (targetVal == 'teacher' ? 'Giáo viên' : targetVal));
              final dateRaw = (a['sentAt'] ?? a['sent_at'] ?? a['createdAt'] ?? DateTime.now().toIso8601String()).toString();
              final sentDate = dateRaw.contains('T') ? dateRaw.split('T').first : (dateRaw.length >= 10 ? dateRaw.substring(0, 10) : dateRaw);

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.notifications_active_outlined, color: Color(0xFF1E3A8A), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            (a['title'] ?? '').toString(),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            targetLabel,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      (a['content'] ?? '').toString(),
                      style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Gửi lúc: $sentDate',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
