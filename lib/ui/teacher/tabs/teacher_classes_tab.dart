import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/app_repository.dart';
import '../../../data/rbac_proctor_ai_service.dart';
import '../../admin/components/class_code_dialog.dart';

/// Tab 2 (Giáo viên): Quản lý Lớp học, Tạo lớp mới, Duyệt học sinh & Hồ sơ học sinh chi tiết
class TeacherClassesTab extends StatefulWidget {
  final AppRepository repository;
  final void Function(int tabIndex) onNavigateTab;

  const TeacherClassesTab({
    super.key,
    required this.repository,
    required this.onNavigateTab,
  });

  @override
  State<TeacherClassesTab> createState() => _TeacherClassesTabState();
}

class _TeacherClassesTabState extends State<TeacherClassesTab> {
  final RbacProctorAiService _service = RbacProctorAiService.instance;

  bool _isLoading = true;
  bool _showArchived = false;
  List<Map<String, dynamic>> _classes = [];

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    setState(() => _isLoading = true);
    try {
      final list = await _service.getClasses();
      if (mounted) {
        setState(() {
          _classes = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _activeClasses =>
      _classes.where((c) => c['status'] != 'archived').toList();

  List<Map<String, dynamic>> get _archivedClasses =>
      _classes.where((c) => c['status'] == 'archived').toList();

  void _showCreateClassModal() {
    final nameCtrl = TextEditingController();
    final schoolCtrl = TextEditingController(text: 'THPT');
    String schoolYear = '2026-2027';
    String bookSet = 'Sách giáo khoa lớp 12 (Global Success)';
    String generatedCode = RbacProctorAiService.generateClassJoinCode('12A1');
    bool requireApproval = true;
    bool showLeaderboard = true;

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
                    const Icon(Icons.add_business_outlined, color: Color(0xFF283593)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Tạo lớp mới',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: nameCtrl,
                  onChanged: (v) {
                    if (v.trim().isNotEmpty) {
                      setSheetState(() {
                        generatedCode = RbacProctorAiService.generateClassJoinCode(v.trim());
                      });
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: 'Tên lớp',
                    hintText: 'Ví dụ: 12A1',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: schoolYear,
                        decoration: const InputDecoration(
                          labelText: 'Năm học',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: '2025-2026', child: Text('2025-2026')),
                          DropdownMenuItem(value: '2026-2027', child: Text('2026-2027')),
                          DropdownMenuItem(value: '2027-2028', child: Text('2027-2028')),
                        ],
                        onChanged: (v) => setSheetState(() => schoolYear = v ?? '2026-2027'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: schoolCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Trường',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: bookSet,
                  decoration: const InputDecoration(
                    labelText: 'Sách của lớp',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Sách giáo khoa lớp 12 (Global Success)',
                      child: Text('Sách giáo khoa lớp 12 (Global Success)'),
                    ),
                    DropdownMenuItem(
                      value: 'Tài liệu Ôn thi THPT Quốc gia 12',
                      child: Text('Tài liệu Ôn thi THPT Quốc gia 12'),
                    ),
                  ],
                  onChanged: (v) => setSheetState(() => bookSet = v ?? bookSet),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFC5CAE9)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Mã lớp (Tự sinh)',
                              style: TextStyle(fontSize: 11, color: Colors.black54),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              generatedCode,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                color: Color(0xFF283593),
                              ),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          setSheetState(() {
                            generatedCode = RbacProctorAiService.generateClassJoinCode(
                              nameCtrl.text.trim().isEmpty ? '12A1' : nameCtrl.text.trim(),
                            );
                          });
                        },
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Tạo mã khác'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Duyệt học sinh trước khi vào lớp', style: TextStyle(fontSize: 14)),
                  value: requireApproval,
                  onChanged: (v) => setSheetState(() => requireApproval = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Cho học sinh xem bảng xếp hạng lớp', style: TextStyle(fontSize: 14)),
                  value: showLeaderboard,
                  onChanged: (v) => setSheetState(() => showLeaderboard = v),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF283593)),
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty) return;
                      Navigator.pop(ctx);
                      await _service.createClass(
                        name: nameCtrl.text.trim(),
                        schoolName: schoolCtrl.text.trim(),
                        schoolYear: schoolYear,
                        bookSet: bookSet,
                        joinCode: generatedCode,
                        requireApproval: requireApproval,
                        showLeaderboard: showLeaderboard,
                      );
                      await _loadClasses();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Đã tạo lớp ${nameCtrl.text.trim()} (Mã: $generatedCode)!'),
                            backgroundColor: const Color(0xFF1B5E20),
                          ),
                        );
                      }
                    },
                    child: const Text('Tạo lớp'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openClassDetailModal(Map<String, dynamic> classItem) async {
    final classId = classItem['id'].toString();
    var currentClass = Map<String, dynamic>.from(classItem);
    var members = await _service.getClassMembers(classId);
    var assignments = await _service.getAssignments(classId: classId);
    var submissions = await _service.getSubmissionsForClass(classId: classId);

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final pendingList = members.where((m) => m['status'] == 'pending').toList();
          final approvedList = members.where((m) => m['status'] == 'approved').toList();

          Future<void> reloadInsideModal() async {
            final allClasses = await _service.getClasses();
            final updatedCls = allClasses.where((c) => c['id'] == classId).firstOrNull;
            final newMembers = await _service.getClassMembers(classId);
            final newAssigns = await _service.getAssignments(classId: classId);
            final newSubs = await _service.getSubmissionsForClass(classId: classId);
            setModalState(() {
              if (updatedCls != null) currentClass = updatedCls;
              members = newMembers;
              assignments = newAssigns;
              submissions = newSubs;
            });
            _loadClasses();
          }

          return DefaultTabController(
            length: 3,
            child: Container(
              height: MediaQuery.of(ctx).size.height * 0.88,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Lớp
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                      Expanded(
                        child: Text(
                          'Lớp ${currentClass['name']} (${currentClass['schoolYear'] ?? "2026-2027"})',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Thêm học sinh vào lớp',
                        icon: const Icon(Icons.person_add_alt_1, color: Color(0xFF283593)),
                        onPressed: () => _showAddStudentDialog(
                          classId: classId,
                          onAdded: reloadInsideModal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Khung Mã lớp + Sao chép + Đổi mã mới + Công tắc cho phép vào lớp
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F7FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFC5CAE9)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Mã lớp', style: TextStyle(fontSize: 11, color: Colors.black54)),
                                  Text(
                                    currentClass['code'].toString(),
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF283593),
                                      letterSpacing: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: currentClass['code'].toString()));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Đã sao chép mã lớp: ${currentClass['code']}')),
                                );
                              },
                              icon: const Icon(Icons.copy, size: 16),
                              label: const Text('Sao chép'),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        Row(
                          children: [
                            const Expanded(
                              child: Text('Đang cho phép vào lớp bằng mã', style: TextStyle(fontSize: 13)),
                            ),
                            TextButton.icon(
                              onPressed: () async {
                                final oldCode = currentClass['code']?.toString() ?? '';
                                final newCode = await _service.regenerateClassCode(classId);
                                await reloadInsideModal();
                                if (mounted) {
                                  await ClassCodeDialog.show(
                                    context,
                                    className: currentClass['name']?.toString() ?? 'Lớp học',
                                    oldCode: oldCode,
                                    initialNewCode: newCode,
                                    onRegenerateAnother: () async {
                                      final another = await _service.regenerateClassCode(classId);
                                      await reloadInsideModal();
                                      return another;
                                    },
                                  );
                                }
                              },
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Mã mới'),
                            ),
                            Switch(
                              value: currentClass['allowJoin'] != false,
                              onChanged: (v) async {
                                await _service.updateClass(classId: classId, allowJoin: v);
                                await reloadInsideModal();
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  TabBar(
                    labelColor: const Color(0xFF283593),
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: const Color(0xFF283593),
                    tabs: [
                      Tab(text: 'Học sinh (${approvedList.length})'),
                      Tab(text: 'Bài giao (${assignments.length})'),
                      const Tab(text: 'Điểm'),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Expanded(
                    child: TabBarView(
                      children: [
                        // Sub-tab 1: Danh sách Học sinh & Duyệt yêu cầu vào lớp
                        ListView(
                          children: [
                            if (pendingList.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.amber[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.amber[300]!),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.info_outline, color: Colors.amber[900], size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '${pendingList.length} yêu cầu vào lớp đang chờ duyệt',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.amber[900],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ...pendingList.map(
                                      (p) => Padding(
                                        padding: const EdgeInsets.only(bottom: 6),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '${p['studentName']} (${p['studentEmail']})',
                                                style: const TextStyle(fontSize: 13),
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () async {
                                                await _service.decideClassMember(
                                                  classId: classId,
                                                  memberId: p['id'].toString(),
                                                  status: 'rejected',
                                                );
                                                await reloadInsideModal();
                                              },
                                              child: const Text('Từ chối', style: TextStyle(color: Colors.red)),
                                            ),
                                            FilledButton(
                                              style: FilledButton.styleFrom(
                                                backgroundColor: Colors.amber[800],
                                                visualDensity: VisualDensity.compact,
                                              ),
                                              onPressed: () async {
                                                await _service.decideClassMember(
                                                  classId: classId,
                                                  memberId: p['id'].toString(),
                                                  status: 'approved',
                                                );
                                                await reloadInsideModal();
                                              },
                                              child: const Text('Duyệt'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (approvedList.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  children: [
                                    const Text(
                                      'Chưa có học sinh chính thức trong lớp này.',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                    const SizedBox(height: 8),
                                    OutlinedButton.icon(
                                      onPressed: () => _showAddStudentDialog(
                                        classId: classId,
                                        onAdded: reloadInsideModal,
                                      ),
                                      icon: const Icon(Icons.person_add),
                                      label: const Text('Thêm học sinh vào lớp'),
                                    ),
                                  ],
                                ),
                              )
                            else
                              ...approvedList.map((st) {
                                final avg = (st['avgScore'] as num?)?.toDouble() ?? 0.0;
                                final streak = (st['streakDays'] as num?)?.toInt() ?? 0;
                                final needsAttention = avg > 0 && avg < 5.5;
                                return Card(
                                  elevation: 0,
                                  margin: const EdgeInsets.only(bottom: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: Colors.grey[200]!),
                                  ),
                                  child: ListTile(
                                    onTap: () => _showStudentProfileSheet(st, currentClass['name'].toString()),
                                    leading: CircleAvatar(
                                      backgroundColor: needsAttention ? Colors.red[50] : Colors.indigo[50],
                                      child: Text(
                                        (st['studentName'] ?? 'HS')
                                            .toString()
                                            .trim()
                                            .split(' ')
                                            .map((w) => w.isNotEmpty ? w[0] : '')
                                            .take(2)
                                            .join()
                                            .toUpperCase(),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: needsAttention ? Colors.red[800] : const Color(0xFF283593),
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      st['studentName'].toString(),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    subtitle: Text(
                                      'Streak $streak ngày • Điểm TB: ${avg.toStringAsFixed(1)}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                    ),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: needsAttention ? Colors.red[50] : Colors.green[50],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        needsAttention ? 'Cần chú ý' : 'Tốt',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: needsAttention ? Colors.red[800] : Colors.green[800],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                          ],
                        ),

                        // Sub-tab 2: Bài giao của lớp
                        assignments.isEmpty
                            ? const Center(
                                child: Text('Chưa có bài giao nào cho lớp này.', style: TextStyle(color: Colors.grey)),
                              )
                            : ListView.builder(
                                itemCount: assignments.length,
                                itemBuilder: (_, idx) {
                                  final a = assignments[idx];
                                  return Card(
                                    elevation: 0,
                                    margin: const EdgeInsets.only(bottom: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(color: Colors.grey[200]!),
                                    ),
                                    child: ListTile(
                                      title: Text(
                                        a['title'].toString(),
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Text(
                                        'Unit ${a['unitNumber']} • Đã nộp: ${a['submittedCount'] ?? 0}/${approvedList.length}',
                                      ),
                                      trailing: Chip(
                                        label: Text(a['status'] == 'closed' ? 'Đã đóng' : 'Đang mở'),
                                      ),
                                    ),
                                  );
                                },
                              ),

                        // Sub-tab 3: Bảng điểm bài nộp của lớp
                        submissions.isEmpty
                            ? const Center(
                                child: Text('Chưa có dữ liệu điểm bài nộp của lớp.', style: TextStyle(color: Colors.grey)),
                              )
                            : ListView.builder(
                                itemCount: submissions.length,
                                itemBuilder: (_, idx) {
                                  final s = submissions[idx];
                                  return ListTile(
                                    leading: const Icon(Icons.fact_check_outlined, color: Color(0xFF283593)),
                                    title: Text(s['studentName'].toString()),
                                    subtitle: Text((s['submittedAt'] ?? '').toString().split('T').first),
                                    trailing: Text(
                                      '${s['score']} đ',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: Color(0xFF283593),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF283593)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        widget.onNavigateTab(2);
                      },
                      icon: const Icon(Icons.assignment_add),
                      label: Text('Giao bài cho lớp ${currentClass['name']}'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddStudentDialog({
    required String classId,
    required Future<void> Function() onAdded,
  }) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm học sinh vào lớp'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Họ và tên học sinh',
                hintText: 'VD: Nguyễn Minh An',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Email học sinh',
                hintText: 'minhan@gmail.com',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              await _service.addStudentToClass(
                classId: classId,
                studentName: nameCtrl.text.trim(),
                studentEmail: emailCtrl.text.trim(),
              );
              await onAdded();
            },
            child: const Text('Thêm vào lớp'),
          ),
        ],
      ),
    );
  }

  void _showStudentProfileSheet(Map<String, dynamic> student, String className) {
    final name = (student['studentName'] ?? 'Học sinh').toString();
    final streak = (student['streakDays'] as num?)?.toInt() ?? 0;
    final avgScore = (student['avgScore'] as num?)?.toDouble() ?? 0.0;
    final overdue = (student['overdueCount'] as num?)?.toInt() ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
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
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFE8EAF6),
                  child: Text(
                    name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'H',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF283593),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(
                        'Lớp $className • ${student['studentEmail'] ?? ""}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Streak học tập', style: TextStyle(fontSize: 11, color: Colors.black54)),
                        const SizedBox(height: 4),
                        Text(
                          '$streak ngày',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange[900]),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Điểm trung bình', style: TextStyle(fontSize: 11, color: Colors.black54)),
                        const SizedBox(height: 4),
                        Text(
                          avgScore.toStringAsFixed(1),
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue[900]),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Quá hạn', style: TextStyle(fontSize: 11, color: Colors.black54)),
                        const SizedBox(height: 4),
                        Text(
                          '$overdue bài',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red[900]),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF283593)),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _service.createAnnouncement(
                        title: 'Nhắc nhở học tập từ giáo viên lớp $className',
                        content: 'Chào $name, em nhớ hoàn thành bài tập đúng hạn nhé!',
                        audience: name,
                        category: 'Nhắc học',
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Đã gửi thông báo nhắc học tới $name!')),
                        );
                      }
                    },
                    icon: const Icon(Icons.notifications_active_outlined, size: 18),
                    label: const Text('Nhắc học'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      widget.onNavigateTab(2);
                    },
                    icon: const Icon(Icons.assignment_add, size: 18),
                    label: const Text('Giao bài ôn'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadClasses,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lớp học của tôi',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Quản lý mã lớp, duyệt học sinh và theo dõi tiến độ sách',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF283593)),
                  onPressed: _showCreateClassModal,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Tạo lớp mới'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(minHeight: 2),
              ),

            if (_activeClasses.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.class_outlined, size: 44, color: Colors.grey),
                    const SizedBox(height: 10),
                    const Text(
                      'Bạn chưa tạo lớp học nào.',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Bấm "Tạo lớp mới" để sinh mã lớp cho học sinh tham gia.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF283593)),
                      onPressed: _showCreateClassModal,
                      icon: const Icon(Icons.add),
                      label: const Text('Tạo lớp đầu tiên'),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _activeClasses.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (ctx, idx) {
                  final c = _activeClasses[idx];
                  final studentsCount = (c['studentsCount'] as num?)?.toInt() ?? 0;
                  final pendingCount = (c['pendingCount'] as num?)?.toInt() ?? 0;
                  final openAssigns = (c['openAssignmentsCount'] as num?)?.toInt() ?? 0;
                  final progress = ((c['progressPercent'] as num?)?.toInt() ?? 0).clamp(0, 100);

                  return InkWell(
                    onTap: () => _openClassDetailModal(c),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c['name'].toString(),
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      'Năm học ${c['schoolYear'] ?? "2026-2027"} • $studentsCount học sinh',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8EAF6),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  c['code'].toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Color(0xFF283593),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Tiến độ sách', style: TextStyle(fontSize: 12, color: Colors.black54)),
                              Text('$progress%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          LinearProgressIndicator(
                            value: progress / 100.0,
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(4),
                            backgroundColor: Colors.grey[200],
                            color: const Color(0xFF283593),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '$openAssigns bài đang mở',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue[800]),
                                ),
                              ),
                              if (pendingCount > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.amber[100],
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '$pendingCount chờ duyệt',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber[900]),
                                  ),
                                ),
                              ],
                              const Spacer(),
                              IconButton(
                                tooltip: 'Sao chép mã lớp',
                                icon: const Icon(Icons.copy, size: 18),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: c['code'].toString()));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Đã sao chép mã lớp ${c['code']}')),
                                  );
                                },
                              ),
                              IconButton(
                                tooltip: 'Lưu trữ lớp',
                                icon: const Icon(Icons.archive_outlined, size: 18, color: Colors.grey),
                                onPressed: () async {
                                  await _service.updateClass(
                                    classId: c['id'].toString(),
                                    status: 'archived',
                                  );
                                  await _loadClasses();
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

            if (_archivedClasses.isNotEmpty) ...[
              const SizedBox(height: 16),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey[200]!),
                ),
                leading: const Icon(Icons.inventory_2_outlined, color: Colors.grey),
                title: Text('Lớp đã lưu trữ (${_archivedClasses.length})'),
                trailing: Icon(_showArchived ? Icons.expand_less : Icons.expand_more),
                onTap: () => setState(() => _showArchived = !_showArchived),
              ),
              if (_showArchived)
                ..._archivedClasses.map(
                  (ac) => ListTile(
                    title: Text('${ac['name']} (${ac['schoolYear']})'),
                    subtitle: Text('Mã: ${ac['code']}'),
                    trailing: TextButton(
                      onPressed: () async {
                        await _service.updateClass(
                          classId: ac['id'].toString(),
                          status: 'active',
                        );
                        await _loadClasses();
                      },
                      child: const Text('Khôi phục'),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
