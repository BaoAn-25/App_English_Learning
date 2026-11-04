import 'dart:async';
import 'package:flutter/material.dart';

import '../../../data/app_repository.dart';
import '../../../data/rbac_proctor_ai_service.dart';
import '../components/admin_kpi_card.dart';
import '../components/class_code_dialog.dart';

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Danh sách lớp học:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
            const SizedBox(height: 10),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _classes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (ctx, idx) {
                final c = _classes[idx];
                final needsTeacher = c['status'] == 'needs_teacher';
                return Container(
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                            onPressed: () => _showAssignTeacherModal(c),
                            icon: const Icon(Icons.person_add_alt, size: 14),
                            label: Text(needsTeacher ? 'Gán giáo viên' : 'Đổi giáo viên'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                            onPressed: () => _handleRegenerateClassCode(c),
                            icon: const Icon(Icons.refresh, size: 14),
                            label: const Text('Đổi mã'),
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
            const Text(
              'Các kỳ thi có giám sát trong hệ thống:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
