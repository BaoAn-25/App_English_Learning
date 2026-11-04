import 'package:flutter/material.dart';

import '../../../data/app_repository.dart';
import '../../../data/rbac_proctor_ai_service.dart';
import '../../admin/components/admin_kpi_card.dart';

/// Tab 4 (Giáo viên): Báo cáo Lớp học, Phân bố điểm, Ma trận Kỹ năng & Báo lỗi câu hỏi thật
class TeacherReportsTab extends StatefulWidget {
  final AppRepository repository;

  const TeacherReportsTab({super.key, required this.repository});

  @override
  State<TeacherReportsTab> createState() => _TeacherReportsTabState();
}

class _TeacherReportsTabState extends State<TeacherReportsTab> {
  final RbacProctorAiService _service = RbacProctorAiService.instance;

  bool _isLoading = true;
  String _selectedClassId = 'all';
  int _selectedDays = 30;

  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _submissions = [];
  List<Map<String, dynamic>> _assignments = [];
  List<Map<String, dynamic>> _bugReports = [];

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    setState(() => _isLoading = true);
    try {
      final classes = await _service.getClasses();
      final activeClasses = classes.where((c) => c['status'] != 'archived').toList();
      final subs = await _service.getSubmissionsForClass(
        classId: _selectedClassId == 'all' ? null : _selectedClassId,
      );
      final assigns = await _service.getAssignments(
        classId: _selectedClassId == 'all' ? null : _selectedClassId,
      );
      final reports = await _service.getBugReports();

      final cutoff = DateTime.now().subtract(Duration(days: _selectedDays));
      final filteredSubs = subs.where((s) {
        final dt = DateTime.tryParse((s['submittedAt'] ?? '').toString());
        if (dt == null) return true;
        return dt.isAfter(cutoff);
      }).toList();

      if (mounted) {
        setState(() {
          _classes = activeClasses;
          _submissions = filteredSubs;
          _assignments = assigns;
          _bugReports = reports;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double get _averageScore {
    if (_submissions.isEmpty) return 0.0;
    double sum = 0.0;
    for (final s in _submissions) {
      sum += (s['score'] as num?)?.toDouble() ?? 0.0;
    }
    return sum / _submissions.length;
  }

  int get _completionPercent {
    if (_assignments.isEmpty) return 0;
    int totalStudents = 0;
    final targetClasses = _selectedClassId == 'all'
        ? _classes
        : _classes.where((c) => c['id'] == _selectedClassId).toList();
    for (final c in targetClasses) {
      totalStudents += (c['studentsCount'] as num?)?.toInt() ?? 0;
    }
    final expected = _assignments.length * (totalStudents > 0 ? totalStudents : 1);
    if (expected <= 0) return 0;
    return ((_submissions.length / expected) * 100).round().clamp(0, 100);
  }

  List<int> get _scoreDistribution {
    // 5 khoảng điểm: [0-2, 2-4, 4-6, 6-8, 8-10]
    final buckets = [0, 0, 0, 0, 0];
    for (final s in _submissions) {
      final sc = (s['score'] as num?)?.toDouble() ?? 0.0;
      if (sc < 2.0) {
        buckets[0]++;
      } else if (sc < 4.0) {
        buckets[1]++;
      } else if (sc < 6.0) {
        buckets[2]++;
      } else if (sc < 8.0) {
        buckets[3]++;
      } else {
        buckets[4]++;
      }
    }
    return buckets;
  }

  @override
  Widget build(BuildContext context) {
    final dist = _scoreDistribution;
    final maxBucket = dist.reduce((a, b) => a > b ? a : b);
    final safeMax = maxBucket > 0 ? maxBucket : 1;
    final bucketLabels = ['0–2', '2–4', '4–6', '6–8', '8–10'];

    return RefreshIndicator(
      onRefresh: _loadReportData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Báo cáo lớp học',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Bộ lọc Lớp & Thời gian (Ảnh 7)
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedClassId,
                    decoration: const InputDecoration(
                      labelText: 'Lớp',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(value: 'all', child: Text('Tất cả lớp')),
                      ..._classes.map(
                        (c) => DropdownMenuItem(
                          value: c['id'].toString(),
                          child: Text('Lớp ${c['name']}'),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _selectedClassId = v);
                        _loadReportData();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _selectedDays,
                    decoration: const InputDecoration(
                      labelText: 'Thời gian',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 7, child: Text('7 ngày qua')),
                      DropdownMenuItem(value: 30, child: Text('30 ngày qua')),
                      DropdownMenuItem(value: 180, child: Text('Học kỳ')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _selectedDays = v);
                        _loadReportData();
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(minHeight: 2),
              ),

            // 2 Thẻ KPI Điểm TB & Hoàn thành
            Row(
              children: [
                Expanded(
                  child: AdminKpiCard(
                    title: 'Điểm TB',
                    value: _averageScore.toStringAsFixed(1),
                    subtitle: '${_submissions.length} bài nộp thực tế',
                    icon: Icons.insights,
                    iconColor: Colors.green[800]!,
                    backgroundColor: const Color(0xFFE8F5E9),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AdminKpiCard(
                    title: 'Hoàn thành',
                    value: '$_completionPercent%',
                    subtitle: 'Mục tiêu 80%',
                    icon: Icons.pie_chart_outline,
                    iconColor: Colors.amber[900]!,
                    backgroundColor: const Color(0xFFFFF8E1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Biểu đồ Phân bố điểm (Ảnh 7)
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Phân bố điểm',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8EAF6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_submissions.length} bài nộp',
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
                    height: 130,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(5, (i) {
                        final count = dist[i];
                        final factor = (count / safeMax).clamp(0.08, 1.0);
                        final isPeak = count == maxBucket && count > 0;
                        return Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                '$count',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isPeak ? FontWeight.bold : FontWeight.normal,
                                  color: isPeak ? const Color(0xFF283593) : Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                height: 85 * factor,
                                margin: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  color: isPeak
                                      ? const Color(0xFF283593)
                                      : const Color(0xFF283593).withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                bucketLabels[i],
                                style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Ma trận Kỹ năng theo lớp (Ảnh 7)
            _buildSkillMatrixCard(),
            const SizedBox(height: 18),

            // Khối Phản hồi / Báo lỗi câu hỏi từ học sinh
            _buildBugReportsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillMatrixCard() {
    final skills = [
      {'key': 'listening', 'label': 'Nghe hiểu'},
      {'key': 'reading', 'label': 'Đọc hiểu'},
      {'key': 'grammar', 'label': 'Ngữ pháp'},
      {'key': 'vocabulary', 'label': 'Từ vựng'},
    ];

    final baseAvgPercent = (_averageScore * 10).round().clamp(0, 100);

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
          const Text(
            'Kỹ năng theo lớp',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (_classes.isEmpty)
            const Text(
              'Chưa có lớp học để thống kê kỹ năng.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            )
          else
            Table(
              columnWidths: const {
                0: FlexColumnWidth(1.5),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text('Kỹ năng', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    ..._classes.take(3).map(
                      (c) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          c['name'].toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                for (final sk in skills)
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(sk['label']!, style: const TextStyle(fontSize: 13)),
                      ),
                      ..._classes.take(3).map((c) {
                        final cid = c['id'].toString();
                        final classSubs = _submissions.where((s) => s['classId'] == cid).toList();
                        int pct = baseAvgPercent;
                        if (classSubs.isNotEmpty) {
                          double sum = 0;
                          for (final cs in classSubs) {
                            sum += (cs['score'] as num?)?.toDouble() ?? 0.0;
                          }
                          pct = ((sum / classSubs.length) * 10).round().clamp(0, 100);
                        }
                        final bg = pct >= 70
                            ? Colors.green[50]
                            : (pct >= 50 ? Colors.amber[50] : Colors.red[50]);
                        final fg = pct >= 70
                            ? Colors.green[900]
                            : (pct >= 50 ? Colors.amber[900] : Colors.red[900]);
                        return Container(
                          margin: const EdgeInsets.all(4),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$pct%',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: fg,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildBugReportsSection() {
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
                'Báo lỗi câu hỏi từ học sinh',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              Text(
                '${_bugReports.where((r) => r['status'] == 'open' || r['status'] == 'new').length} chờ xử lý',
                style: TextStyle(fontSize: 12, color: Colors.red[700], fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_bugReports.isEmpty)
            const Text(
              'Chưa có báo lỗi câu hỏi nào từ học sinh.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            )
          else
            ..._bugReports.take(5).map((r) {
              final title = (r['targetCode'] ?? r['title'] ?? 'Câu hỏi').toString();
              final reason = (r['reason'] ?? r['details'] ?? '').toString();
              final isDone = r['status'] == 'fixed' || r['status'] == 'resolved';
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  isDone ? Icons.check_circle : Icons.flag_outlined,
                  color: isDone ? Colors.green : Colors.redAccent,
                ),
                title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text(reason, style: const TextStyle(fontSize: 12)),
                trailing: isDone
                    ? const Text('Đã sửa', style: TextStyle(color: Colors.green, fontSize: 12))
                    : TextButton(
                        onPressed: () async {
                          await _service.updateBugReportStatus(
                            reportId: r['id'].toString(),
                            status: 'fixed',
                          );
                          await _loadReportData();
                        },
                        child: const Text('Xác nhận sửa'),
                      ),
              );
            }),
        ],
      ),
    );
  }
}

