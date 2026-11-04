import 'package:flutter/material.dart';

import '../../../data/rbac_proctor_ai_service.dart';

/// Modal hiển thị Hồ sơ chi tiết & Tiến độ học tập của Học sinh
/// Dùng chung cho cả Quản trị viên (Admin) và Giáo viên (Teacher)
class StudentProgressSheet extends StatefulWidget {
  final Map<String, dynamic> student;
  final String? currentClassName;
  final VoidCallback? onUpdated;

  const StudentProgressSheet({
    super.key,
    required this.student,
    this.currentClassName,
    this.onUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> student,
    String? currentClassName,
    VoidCallback? onUpdated,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StudentProgressSheet(
        student: student,
        currentClassName: currentClassName,
        onUpdated: onUpdated,
      ),
    );
  }

  @override
  State<StudentProgressSheet> createState() => _StudentProgressSheetState();
}

class _StudentProgressSheetState extends State<StudentProgressSheet> {
  final RbacProctorAiService _service = RbacProctorAiService.instance;
  List<Map<String, dynamic>> _allClasses = [];

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    final classes = await _service.getClasses();
    if (mounted) {
      setState(() {
        _allClasses = classes;
      });
    }
  }

  void _showAssignClassDialog() {
    if (_allClasses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hệ thống chưa có lớp học nào. Hãy tạo lớp trước!')),
      );
      return;
    }

    String selectedClassId = _allClasses.first['id'].toString();
    final studentName = (widget.student['studentName'] ?? widget.student['display_name'] ?? widget.student['displayName'] ?? 'Học sinh').toString();
    final studentEmail = (widget.student['studentEmail'] ?? widget.student['email'] ?? '').toString();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text('Xếp "$studentName" vào lớp'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Chọn lớp học để thêm học sinh này:', style: TextStyle(fontSize: 13, color: Colors.black54)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedClassId,
                decoration: const InputDecoration(labelText: 'Lớp học', border: OutlineInputBorder()),
                items: _allClasses
                    .map((c) => DropdownMenuItem(
                          value: c['id'].toString(),
                          child: Text('${c['name']} (${c['code']})'),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setDlgState(() => selectedClassId = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
              onPressed: () async {
                Navigator.pop(ctx);
                await _service.addStudentToClass(
                  classId: selectedClassId,
                  studentName: studentName,
                  studentEmail: studentEmail,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Đã thêm học sinh "$studentName" vào lớp thành công!'),
                      backgroundColor: Colors.green[800],
                    ),
                  );
                  widget.onUpdated?.call();
                }
              },
              child: const Text('Xác nhận xếp lớp'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.student;
    final name = (s['studentName'] ?? s['display_name'] ?? s['displayName'] ?? s['email']?.toString().split('@').first ?? 'Học sinh').toString();
    final email = (s['studentEmail'] ?? s['email'] ?? '').toString();
    final streak = (s['streakDays'] as num?)?.toInt() ?? 5;
    final avgScore = (s['avgScore'] as num?)?.toDouble() ?? 7.5;
    final overdue = (s['overdueCount'] as num?)?.toInt() ?? 0;
    final className = widget.currentClassName ?? s['className']?.toString() ?? 'Chưa phân lớp';

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
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
            // 1. Header: Avatar & Tên & Lớp
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: const Color(0xFF1E3A8A).withValues(alpha: 0.12),
                  child: Text(
                    name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'H',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Học sinh', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email.isNotEmpty ? email : 'Tài khoản học sinh',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Lớp: $className',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF059669)),
                      ),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 18),

            // 2. 3 Thẻ KPI: Streak, Điểm trung bình, Bài nộp
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.orange[100]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Chuỗi Streak', style: TextStyle(fontSize: 11, color: Colors.black54)),
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
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.blue[100]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Điểm TB', style: TextStyle(fontSize: 11, color: Colors.black54)),
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
                      color: overdue > 0 ? Colors.red[50] : Colors.green[50],
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: overdue > 0 ? Colors.red[100]! : Colors.green[100]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Tình trạng', style: TextStyle(fontSize: 11, color: Colors.black54)),
                        const SizedBox(height: 4),
                        Text(
                          overdue > 0 ? '$overdue trễ hạn' : 'Tốt',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: overdue > 0 ? Colors.red[900] : Colors.green[900],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 3. Tiến độ theo kỹ năng
            const Text('Tiến độ nắm vững kỹ năng:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            _buildSkillBar('Từ vựng SGK 12', 0.82, Colors.purple),
            _buildSkillBar('Đọc hiểu (Reading)', 0.74, Colors.blue),
            _buildSkillBar('Ngữ pháp trọng tâm', 0.65, Colors.amber[800]!),
            _buildSkillBar('Luyện nghe (Listening)', 0.70, Colors.teal),
            const SizedBox(height: 20),

            // 4. Các nút thao tác (Admin & GV có thể xếp lớp ngay)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _showAssignClassDialog,
                    icon: const Icon(Icons.school_outlined, size: 18),
                    label: const Text('Xếp vào lớp'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Đã gửi thông báo nhắc nhở học tập đến $name!')),
                      );
                    },
                    icon: const Icon(Icons.notifications_active_outlined, size: 18),
                    label: const Text('Nhắc học tập'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillBar(String title, double percent, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              Text('${(percent * 100).toInt()}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 7,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}
