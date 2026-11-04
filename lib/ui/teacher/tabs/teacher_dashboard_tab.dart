import 'package:flutter/material.dart';

import '../../../data/app_repository.dart';
import '../../../data/rbac_proctor_ai_service.dart';
import '../../admin/components/admin_kpi_card.dart';

/// Tab 1 (Giáo viên): Tổng quan lớp học, Việc cần làm hôm nay & Trung tâm Thông báo thật
class TeacherDashboardTab extends StatefulWidget {
  final AppRepository repository;
  final void Function(int tabIndex) onNavigateTab;

  const TeacherDashboardTab({
    super.key,
    required this.repository,
    required this.onNavigateTab,
  });

  @override
  State<TeacherDashboardTab> createState() => _TeacherDashboardTabState();
}

class _TeacherDashboardTabState extends State<TeacherDashboardTab> {
  final RbacProctorAiService _service = RbacProctorAiService.instance;

  bool _isLoading = true;
  String _selectedClassId = 'all';

  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _assignments = [];
  List<Map<String, dynamic>> _submissions = [];
  List<Map<String, dynamic>> _pendingMembers = [];
  List<Map<String, dynamic>> _attentionStudents = [];
  List<ExamLiveSessionModel> _explainedSessions = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final allClasses = await _service.getClasses();
      final activeClasses = allClasses.where((c) => c['status'] != 'archived').toList();
      final assignments = await _service.getAssignments(
        classId: _selectedClassId == 'all' ? null : _selectedClassId,
      );
      final submissions = await _service.getSubmissionsForClass(
        classId: _selectedClassId == 'all' ? null : _selectedClassId,
      );

      final pendingList = <Map<String, dynamic>>[];
      final attentionList = <Map<String, dynamic>>[];
      final targetClasses = _selectedClassId == 'all'
          ? activeClasses
          : activeClasses.where((c) => c['id'] == _selectedClassId).toList();

      for (final c in targetClasses) {
        final cid = c['id'].toString();
        final cName = c['name'].toString();
        final members = await _service.getClassMembers(cid, syncRemote: false);
        for (final m in members) {
          final enriched = {...m, 'className': cName};
          if (m['status'] == 'pending') {
            pendingList.add(enriched);
          } else if (m['status'] == 'approved') {
            final avg = (m['avgScore'] as num?)?.toDouble() ?? 0.0;
            final overdue = (m['overdueCount'] as num?)?.toInt() ?? 0;
            if (overdue > 0 || (avg > 0 && avg < 5.0)) {
              attentionList.add(enriched);
            }
          }
        }
      }

      final exams = await _service.getSupervisedExams();
      final explained = <ExamLiveSessionModel>[];
      for (final ex in exams) {
        if (_selectedClassId != 'all' && ex.classId != _selectedClassId) continue;
        final sessions = await _service.getLiveSessionsForExam(ex.id);
        for (final s in sessions) {
          if (s.studentExplanation != null && s.studentExplanation!.trim().isNotEmpty) {
            explained.add(s);
          }
        }
      }

      if (mounted) {
        setState(() {
          _classes = activeClasses;
          _assignments = assignments;
          _submissions = submissions;
          _pendingMembers = pendingList;
          _attentionStudents = attentionList;
          _explainedSessions = explained;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int get _totalStudentsCount {
    final target = _selectedClassId == 'all'
        ? _classes
        : _classes.where((c) => c['id'] == _selectedClassId).toList();
    int sum = 0;
    for (final c in target) {
      sum += (c['studentsCount'] as num?)?.toInt() ?? 0;
    }
    return sum;
  }

  int get _onTimeRatePercent {
    if (_assignments.isEmpty) return 100;
    final totalExpected = _assignments.length * (_totalStudentsCount > 0 ? _totalStudentsCount : 1);
    if (totalExpected <= 0) return 100;
    final rate = ((_submissions.length / totalExpected) * 100).round();
    return rate.clamp(0, 100);
  }

  void _showNotificationsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DefaultTabController(
        length: 3,
        child: Container(
          height: MediaQuery.of(ctx).size.height * 0.82,
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
                  const Icon(Icons.notifications_active_outlined, color: Color(0xFF283593)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Thông báo lớp học & bài nộp',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const TabBar(
                labelColor: Color(0xFF283593),
                unselectedLabelColor: Colors.grey,
                indicatorColor: Color(0xFF283593),
                tabs: [
                  Tab(text: 'Tất cả'),
                  Tab(text: 'Yêu cầu vào lớp'),
                  Tab(text: 'Bài nộp & Thi'),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildNotificationList(filter: 'all', modalContext: ctx),
                    _buildNotificationList(filter: 'requests', modalContext: ctx),
                    _buildNotificationList(filter: 'submissions', modalContext: ctx),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationList({required String filter, required BuildContext modalContext}) {
    final items = <Widget>[];

    if (filter == 'all' || filter == 'requests') {
      for (final req in _pendingMembers) {
        items.add(
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber[200]!),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.amber,
                  child: Icon(Icons.person_add, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${req['studentName']} xin vào lớp ${req['className']}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        'Email: ${req['studentEmail'] ?? "Học sinh"}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF283593),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () async {
                    Navigator.pop(modalContext);
                    await _service.decideClassMember(
                      classId: req['classId'].toString(),
                      memberId: req['id'].toString(),
                      status: 'approved',
                    );
                    await _loadDashboardData();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Đã duyệt ${req['studentName']} vào lớp ${req['className']}!')),
                      );
                    }
                  },
                  child: const Text('Duyệt'),
                ),
              ],
            ),
          ),
        );
      }
    }

    if (filter == 'all' || filter == 'submissions') {
      for (final exSession in _explainedSessions) {
        items.add(
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red[200]!),
            ),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: Colors.redAccent,
                child: Icon(Icons.policy_outlined, color: Colors.white, size: 18),
              ),
              title: Text(
                '${exSession.studentName} gửi giải trình phòng thi 10s',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              subtitle: Text(
                'Nội dung: "${exSession.studentExplanation}"',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: TextButton(
                onPressed: () {
                  Navigator.pop(modalContext);
                  widget.onNavigateTab(2);
                },
                child: const Text('Xem giám sát'),
              ),
            ),
          ),
        );
      }

      for (final sub in _submissions.take(15)) {
        items.add(
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.green,
                  child: Icon(Icons.check, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${sub['studentName']} đã nộp bài',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        'Điểm số: ${sub['score']} / 10 • ${(sub['submittedAt'] ?? '').toString().split('T').first}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    if (items.isEmpty) {
      return const Center(
        child: Text(
          'Chưa có thông báo mới trong mục này.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView(children: items);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bộ lọc Lớp đang dạy
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('Tất cả lớp'),
                    selected: _selectedClassId == 'all',
                    onSelected: (_) {
                      setState(() => _selectedClassId = 'all');
                      _loadDashboardData();
                    },
                  ),
                  const SizedBox(width: 8),
                  ..._classes.map((c) {
                    final cid = c['id'].toString();
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(c['name'].toString()),
                        selected: _selectedClassId == cid,
                        onSelected: (_) {
                          setState(() => _selectedClassId = cid);
                          _loadDashboardData();
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(minHeight: 2),
              ),

            // 4 Thẻ KPI thật
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.55,
              children: [
                AdminKpiCard(
                  title: 'Lớp đang dạy',
                  value: '${_classes.length}',
                  subtitle: _classes.isEmpty
                      ? 'Chưa tạo lớp'
                      : _classes.map((c) => c['name']).take(3).join(' • '),
                  icon: Icons.class_outlined,
                  iconColor: const Color(0xFF283593),
                  backgroundColor: const Color(0xFFE8EAF6),
                  onTap: () => widget.onNavigateTab(1),
                ),
                AdminKpiCard(
                  title: 'Học sinh',
                  value: '$_totalStudentsCount',
                  subtitle: '${_pendingMembers.length} chờ duyệt vào lớp',
                  icon: Icons.groups_outlined,
                  iconColor: Colors.green[800]!,
                  backgroundColor: const Color(0xFFE8F5E9),
                  onTap: () => widget.onNavigateTab(1),
                ),
                AdminKpiCard(
                  title: 'Nộp đúng hạn',
                  value: '$_onTimeRatePercent%',
                  subtitle: '${_submissions.length} lượt bài đã nộp',
                  icon: Icons.assignment_turned_in_outlined,
                  iconColor: Colors.blue[800]!,
                  backgroundColor: const Color(0xFFE3F2FD),
                  onTap: () => widget.onNavigateTab(2),
                ),
                AdminKpiCard(
                  title: 'Cần chú ý',
                  value: '${_attentionStudents.length + _explainedSessions.length}',
                  subtitle: 'Điểm < 5.0 hoặc giải trình thi',
                  icon: Icons.warning_amber_rounded,
                  iconColor: Colors.orange[900]!,
                  backgroundColor: const Color(0xFFFFF8E1),
                  onTap: () => widget.onNavigateTab(3),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Khối Việc cần làm hôm nay
            Container(
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
                      const Icon(Icons.task_alt, color: Color(0xFF283593), size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Việc cần làm hôm nay',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _showNotificationsModal,
                        icon: const Icon(Icons.notifications_none, size: 18),
                        label: const Text('Thông báo'),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  _buildTodoRow(
                    icon: Icons.person_add_alt_1,
                    color: Colors.amber[800]!,
                    title: '${_pendingMembers.length} yêu cầu xin vào lớp chờ duyệt',
                    subtitle: _pendingMembers.isEmpty
                        ? 'Tất cả yêu cầu vào lớp đã được xử lý'
                        : 'Chờ cô/thầy duyệt để học sinh nhận bài giao',
                    onTap: () => widget.onNavigateTab(1),
                  ),
                  const SizedBox(height: 10),
                  _buildTodoRow(
                    icon: Icons.assignment_late_outlined,
                    color: Colors.deepOrange,
                    title: '${_assignments.where((a) => a['status'] != 'closed').length} bài giao đang mở hạn nộp',
                    subtitle: 'Kiểm tra tiến độ nộp bài và nhắc các em chưa nộp',
                    onTap: () => widget.onNavigateTab(2),
                  ),
                  const SizedBox(height: 10),
                  _buildTodoRow(
                    icon: Icons.gpp_maybe_outlined,
                    color: Colors.red[700]!,
                    title: '${_explainedSessions.length} giải trình thi 10s & ${_attentionStudents.length} HS cần chú ý',
                    subtitle: 'Xem xét cho làm lại hoặc giao bài ôn tập bổ trợ',
                    onTap: () => widget.onNavigateTab(2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 4 Nút Thao tác nhanh
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionBtn(
                    icon: Icons.post_add_rounded,
                    label: 'Giao bài',
                    onTap: () => widget.onNavigateTab(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildQuickActionBtn(
                    icon: Icons.add_business_outlined,
                    label: 'Tạo lớp',
                    onTap: () => widget.onNavigateTab(1),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildQuickActionBtn(
                    icon: Icons.timer_outlined,
                    label: 'Tạo thi 10s',
                    onTap: () => widget.onNavigateTab(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildQuickActionBtn(
                    icon: Icons.bar_chart_rounded,
                    label: 'Báo cáo',
                    onTap: () => widget.onNavigateTab(3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Biểu đồ Học sinh hoạt động 7 ngày thật
            _buildSevenDayActivityCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildTodoRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF283593), size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSevenDayActivityCard() {
    final now = DateTime.now();
    final dayCounts = List<int>.filled(7, 0);
    final dayLabels = <String>[];

    for (int i = 6; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final dateStr = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final idx = 6 - i;
      dayLabels.add('${d.day}/${d.month}');
      dayCounts[idx] = _submissions.where((s) {
        final subDate = (s['submittedAt'] ?? '').toString();
        return subDate.startsWith(dateStr);
      }).length;
    }

    final maxVal = dayCounts.reduce((a, b) => a > b ? a : b);
    final safeMax = maxVal > 0 ? maxVal : 1;

    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Học sinh nộp bài 7 ngày qua',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8EAF6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Hôm nay: ${dayCounts.last}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF283593),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final count = dayCounts[i];
                final heightFactor = (count / safeMax).clamp(0.08, 1.0);
                final isToday = i == 6;
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                          color: isToday ? const Color(0xFF283593) : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 75 * heightFactor,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: isToday
                              ? const Color(0xFF283593)
                              : const Color(0xFF283593).withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        dayLabels[i],
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

