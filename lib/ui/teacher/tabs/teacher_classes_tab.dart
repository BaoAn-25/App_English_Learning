import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/app_repository.dart';
import '../../../data/rbac_proctor_ai_service.dart';
import '../../admin/components/class_code_dialog.dart';
import '../../common/dialogs/student_progress_sheet.dart';
import '../../settings/notification_service.dart';

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
      // Tự động đồng bộ ngầm toàn bộ lớp lên Cloud Render để học sinh ở bất kỳ máy nào cũng vào được
      _service.syncAllClassesToCloud().catchError((_) => <String, dynamic>{});
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

  /// Lên lịch nhắc hẹn học bài gửi tới toàn bộ học sinh trong lớp học
  void _showScheduleClassReminderModal(Map<String, dynamic> classItem) {
    final classId = classItem['id'].toString();
    final className = classItem['name']?.toString() ?? 'Lớp học';

    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = const TimeOfDay(hour: 20, minute: 0);

    final titleCtrl = TextEditingController(text: 'Nhắc học tập tiếng Anh');
    final messageCtrl = TextEditingController(
      text: 'Thầy/Cô nhắc cả lớp $className: Tối nay nhớ vào hoàn thành bài tập trắc nghiệm và ôn luyện từ vựng nhé!',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final scheduledDateTime = DateTime(
            selectedDate.year,
            selectedDate.month,
            selectedDate.day,
            selectedTime.hour,
            selectedTime.minute,
          );

          void applyPreset(String title, String message) {
            setSheetState(() {
              titleCtrl.text = title;
              messageCtrl.text = message;
            });
          }

          return Container(
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
                      const Icon(Icons.notifications_active_rounded, color: Color(0xFFE65100), size: 26),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Lên lịch nhắc hẹn cho $className',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Đến đúng giờ hẹn, điện thoại của tất cả học viên trong lớp sẽ tự động nảy chuông và thông báo nhắc học.',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 14),

                  // Khối Chọn Ngày & Giờ
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            final d = await showDatePicker(
                              context: ctx,
                              initialDate: selectedDate,
                              firstDate: DateTime.now().subtract(const Duration(days: 1)),
                              lastDate: DateTime.now().add(const Duration(days: 90)),
                            );
                            if (d != null) setSheetState(() => selectedDate = d);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F7FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFC5CAE9)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_outlined, size: 18, color: Color(0xFF283593)),
                                const SizedBox(width: 8),
                                Text(
                                  '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            final t = await showTimePicker(
                              context: ctx,
                              initialTime: selectedTime,
                            );
                            if (t != null) setSheetState(() => selectedTime = t);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3E0),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFFCC80)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time_rounded, size: 18, color: Color(0xFFE65100)),
                                const SizedBox(width: 8),
                                Text(
                                  '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Mẫu nhắc nhở nhanh
                  const Text('Chọn mẫu nhắc nhanh:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.menu_book_rounded, size: 16),
                          label: const Text('Ôn từ vựng Unit', style: TextStyle(fontSize: 12)),
                          onPressed: () => applyPreset(
                            'Nhắc ôn từ vựng $className',
                            'Thầy/Cô nhắc cả lớp hôm nay nhớ vào làm flashcard và ôn từ vựng Unit SGK 12 nhé!',
                          ),
                        ),
                        const SizedBox(width: 6),
                        ActionChip(
                          avatar: const Icon(Icons.assignment_turned_in_rounded, size: 16),
                          label: const Text('Hoàn thành bài tập', style: TextStyle(fontSize: 12)),
                          onPressed: () => applyPreset(
                            'Nhắc làm bài tập $className',
                            'Thầy/Cô nhắc cả lớp vào hoàn thành bài tập giao trong lớp trước khi hết hạn!',
                          ),
                        ),
                        const SizedBox(width: 6),
                        ActionChip(
                          avatar: const Icon(Icons.shield_rounded, size: 16),
                          label: const Text('Vào phòng thi', style: TextStyle(fontSize: 12)),
                          onPressed: () => applyPreset(
                            'Nhắc thi kiểm tra $className',
                            'Đến giờ kiểm tra giám sát rồi! Cả lớp vào mục Phòng Thi Giám Sát để làm bài nghiêm túc nhé.',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tiêu đề thông báo',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: messageCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Nội dung dặn dò của Thầy/Cô',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Nút Phát thông báo hẹn giờ
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE65100)),
                      onPressed: () async {
                        if (titleCtrl.text.trim().isEmpty) return;
                        Navigator.pop(ctx);

                        await _service.createClassReminder(
                          classId: classId,
                          className: className,
                          title: titleCtrl.text.trim(),
                          message: messageCtrl.text.trim(),
                          scheduledAt: scheduledDateTime,
                        );

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Đã tạo lịch nhắc hẹn cho $className lúc ${scheduledDateTime.hour}:${scheduledDateTime.minute.toString().padLeft(2, '0')} ngày ${scheduledDateTime.day}/${scheduledDateTime.month}!'),
                              backgroundColor: const Color(0xFF1B5E20),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.alarm_on_rounded),
                      label: const Text('Phát Lịch Nhắc Hẹn Cho Cả Lớp', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Nút test nảy notification tức thì trên máy này
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final notifId = DateTime.now().millisecondsSinceEpoch % 100000 + 4000;
                        await NotificationService().showInstantNotification(
                          id: notifId,
                          title: '🔔 $className: ${titleCtrl.text.trim()}',
                          body: messageCtrl.text.trim(),
                        );
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã phát thông báo thử nghiệm thành công lên thanh thông báo máy của bạn!'),
                            backgroundColor: Colors.blueAccent,
                          ),
                        );
                      },
                      icon: const Icon(Icons.play_arrow_outlined, size: 18),
                      label: const Text('Thử nghiệm thông báo ngay trên máy này'),
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
                        tooltip: 'Lên lịch nhắc hẹn cả lớp',
                        icon: const Icon(Icons.alarm_add_rounded, color: Color(0xFFE65100)),
                        onPressed: () => _showScheduleClassReminderModal(currentClass),
                      ),
                      IconButton(
                        tooltip: 'Thêm học sinh vào lớp',
                        icon: const Icon(Icons.person_add_alt_1, color: Color(0xFF283593)),
                        onPressed: () => _showAddStudentDialog(
                          classId: classId,
                          onAdded: reloadInsideModal,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Giải tán lớp học',
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        onPressed: () => _confirmDeleteClass(
                          currentClass,
                          onSuccess: () => Navigator.pop(ctx),
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
                await _loadClasses();
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

  void _showStudentProfileSheet(Map<String, dynamic> student, String className) {
    StudentProgressSheet.show(
      context,
      student: student,
      currentClassName: className,
      onUpdated: _loadClasses,
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
                                tooltip: 'Lên lịch nhắc hẹn cho cả lớp',
                                icon: const Icon(Icons.alarm_add_rounded, size: 20, color: Color(0xFFE65100)),
                                onPressed: () => _showScheduleClassReminderModal(c),
                              ),
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
                              IconButton(
                                tooltip: 'Giải tán / Xóa lớp',
                                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                onPressed: () => _confirmDeleteClass(c),
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
