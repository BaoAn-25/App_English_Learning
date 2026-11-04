import 'dart:async';
import 'package:flutter/material.dart';

import '../../../data/app_repository.dart';
import '../../../data/models/question.dart';
import '../../../data/rbac_proctor_ai_service.dart';
import '../../admin/components/admin_kpi_card.dart';

/// Tab 3 (Giáo viên): Giao bài tập, Cài đặt & Giám sát Phòng thi 10s Live, Ngân hàng câu hỏi
class TeacherAssignmentsExamTab extends StatefulWidget {
  final AppRepository repository;

  const TeacherAssignmentsExamTab({super.key, required this.repository});

  @override
  State<TeacherAssignmentsExamTab> createState() => _TeacherAssignmentsExamTabState();
}

class _TeacherAssignmentsExamTabState extends State<TeacherAssignmentsExamTab>
    with SingleTickerProviderStateMixin {
  final RbacProctorAiService _service = RbacProctorAiService.instance;
  late TabController _subTabController;

  bool _isLoading = true;
  String _assignmentFilter = 'open'; // 'open' | 'closed'
  String _proctorSessionFilter = 'all'; // 'all' | 'in_progress' | 'submitted' | 'violated'
  int _selectedUnitBank = 1;

  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _assignments = [];
  List<SupervisedExamModel> _exams = [];
  SupervisedExamModel? _selectedExam;
  List<ExamLiveSessionModel> _liveSessions = [];
  List<Question> _bankQuestions = [];

  Timer? _proctorRefreshTimer;

  @override
  void initState() {
    super.initState();
    _subTabController = TabController(length: 3, vsync: this);
    _loadAllData();
    // Tự động làm mới số liệu phòng thi mỗi 6 giây khi đang chạy ứng dụng thực tế
    final isTesting = WidgetsBinding.instance.runtimeType.toString().contains('TestWidgetsFlutterBinding');
    if (!isTesting) {
      _proctorRefreshTimer = Timer.periodic(const Duration(seconds: 6), (_) {
        if (mounted && _subTabController.index == 1 && _selectedExam != null) {
          _loadSessionsForSelectedExam(_selectedExam!.id);
        }
      });
    }
  }

  @override
  void dispose() {
    _proctorRefreshTimer?.cancel();
    _subTabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final classes = await _service.getClasses();
      final assignments = await _service.getAssignments();
      final exams = await _service.getSupervisedExams();
      final questions = await _service.getTeacherQuestions(unitNumber: _selectedUnitBank);

      SupervisedExamModel? activeExam = _selectedExam;
      if (activeExam == null && exams.isNotEmpty) {
        activeExam = exams.first;
      } else if (activeExam != null) {
        activeExam = exams.where((e) => e.id == activeExam!.id).firstOrNull ??
            (exams.isNotEmpty ? exams.first : null);
      }

      List<ExamLiveSessionModel> sessions = [];
      if (activeExam != null) {
        sessions = await _service.getLiveSessionsForExam(activeExam.id);
      }

      if (mounted) {
        setState(() {
          _classes = classes.where((c) => c['status'] != 'archived').toList();
          _assignments = assignments;
          _exams = exams;
          _selectedExam = activeExam;
          _liveSessions = sessions;
          _bankQuestions = questions;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSessionsForSelectedExam(String examId) async {
    final sessions = await _service.getLiveSessionsForExam(examId);
    if (mounted) {
      setState(() => _liveSessions = sessions);
    }
  }

  // Modal 1: Giao bài mới (Theo Ảnh 7)
  void _showCreateAssignmentModal() {
    final titleCtrl = TextEditingController(text: 'Unit 1 - Reading và từ vựng');
    String contentType = 'unit';
    int unitNumber = 1;
    final selectedSkills = <String>{'reading', 'vocabulary'};
    String selectedClassId = _classes.isNotEmpty ? _classes.first['id'].toString() : '';
    String selectedClassName = _classes.isNotEmpty ? _classes.first['name'].toString() : '12A1';
    int maxAttempts = 2;
    String showAnswerMode = 'after_submit';

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
                    const Icon(Icons.assignment_add, color: Color(0xFF283593)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Giao bài mới cho lớp',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tên bài giao',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Loại nội dung:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Unit SGK'),
                      selected: contentType == 'unit',
                      onSelected: (_) => setSheetState(() => contentType = 'unit'),
                    ),
                    ChoiceChip(
                      label: const Text('Đề ôn tập'),
                      selected: contentType == 'exam',
                      onSelected: (_) => setSheetState(() => contentType = 'exam'),
                    ),
                    ChoiceChip(
                      label: const Text('Kỹ năng'),
                      selected: contentType == 'skill',
                      onSelected: (_) => setSheetState(() => contentType = 'skill'),
                    ),
                    ChoiceChip(
                      label: const Text('Từ vựng'),
                      selected: contentType == 'vocabulary',
                      onSelected: (_) => setSheetState(() => contentType = 'vocabulary'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: unitNumber,
                        decoration: const InputDecoration(
                          labelText: 'Chọn Unit',
                          border: OutlineInputBorder(),
                        ),
                        items: List.generate(
                          10,
                          (i) => DropdownMenuItem(value: i + 1, child: Text('Unit ${i + 1}')),
                        ),
                        onChanged: (v) {
                          if (v != null) {
                            setSheetState(() {
                              unitNumber = v;
                              titleCtrl.text = 'Unit $v - Bài tập trọng tâm';
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: maxAttempts,
                        decoration: const InputDecoration(
                          labelText: 'Số lần làm',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('1 lần')),
                          DropdownMenuItem(value: 2, child: Text('2 lần')),
                          DropdownMenuItem(value: 3, child: Text('3 lần')),
                          DropdownMenuItem(value: 99, child: Text('Không giới hạn')),
                        ],
                        onChanged: (v) => setSheetState(() => maxAttempts = v ?? 2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Phần giao:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final sk in [
                      {'id': 'reading', 'label': 'Reading'},
                      {'id': 'listening', 'label': 'Listening'},
                      {'id': 'vocabulary', 'label': 'Từ vựng'},
                      {'id': 'grammar', 'label': 'Ngữ pháp'},
                    ])
                      FilterChip(
                        label: Text(sk['label']!),
                        selected: selectedSkills.contains(sk['id']),
                        onSelected: (val) {
                          setSheetState(() {
                            if (val) {
                              selectedSkills.add(sk['id']!);
                            } else if (selectedSkills.length > 1) {
                              selectedSkills.remove(sk['id']!);
                            }
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_classes.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: selectedClassId,
                    decoration: const InputDecoration(
                      labelText: 'Giao cho lớp',
                      border: OutlineInputBorder(),
                    ),
                    items: _classes
                        .map(
                          (c) => DropdownMenuItem(
                            value: c['id'].toString(),
                            child: Text('Lớp ${c['name']} (${c['studentsCount'] ?? 0} HS)'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        final found = _classes.where((c) => c['id'].toString() == v).firstOrNull;
                        setSheetState(() {
                          selectedClassId = v;
                          selectedClassName = found?['name']?.toString() ?? '12A1';
                        });
                      }
                    },
                  ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: showAnswerMode,
                  decoration: const InputDecoration(
                    labelText: 'Hiện đáp án',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'after_submit', child: Text('Sau khi học sinh nộp bài')),
                    DropdownMenuItem(value: 'after_deadline', child: Text('Sau khi hết hạn nộp')),
                  ],
                  onChanged: (v) => setSheetState(() => showAnswerMode = v ?? 'after_submit'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF283593)),
                    onPressed: () async {
                      if (titleCtrl.text.trim().isEmpty) return;
                      Navigator.pop(ctx);
                      await _service.createAssignment(
                        title: titleCtrl.text.trim(),
                        classId: selectedClassId,
                        className: selectedClassName,
                        contentType: contentType,
                        unitNumber: unitNumber,
                        skills: selectedSkills.toList(),
                        dueAt: DateTime.now().add(const Duration(days: 3)),
                        maxAttempts: maxAttempts,
                        showAnswerMode: showAnswerMode,
                      );
                      await _loadAllData();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Đã giao bài "${titleCtrl.text.trim()}" cho lớp $selectedClassName!'),
                            backgroundColor: const Color(0xFF1B5E20),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('Giao bài ngay'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Modal 2: Cài đặt bài thi có giám sát (Theo Ảnh 16)
  void _showCreateSupervisedExamModal() {
    final titleCtrl = TextEditingController(text: 'Thi giữa kỳ - Unit 1–3');
    String selectedClassId = _classes.isNotEmpty ? _classes.first['id'].toString() : '';
    String selectedClassName = _classes.isNotEmpty ? _classes.first['name'].toString() : '12A1';
    int durationMinutes = 45;
    int maxAttempts = 1;
    int graceSeconds = 10; // 5 | 10 | 15 | 20
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
                    const Icon(Icons.shield_outlined, color: Color(0xFF283593)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Cài đặt bài thi có giám sát',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tên bài thi',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                if (_classes.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: selectedClassId,
                    decoration: const InputDecoration(
                      labelText: 'Giao cho lớp',
                      border: OutlineInputBorder(),
                    ),
                    items: _classes
                        .map(
                          (c) => DropdownMenuItem(
                            value: c['id'].toString(),
                            child: Text('Lớp ${c['name']}'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        final found = _classes.where((c) => c['id'].toString() == v).firstOrNull;
                        setSheetState(() {
                          selectedClassId = v;
                          selectedClassName = found?['name']?.toString() ?? '12A1';
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
                        decoration: const InputDecoration(
                          labelText: 'Thời gian làm bài',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 15, child: Text('15 phút')),
                          DropdownMenuItem(value: 30, child: Text('30 phút')),
                          DropdownMenuItem(value: 45, child: Text('45 phút')),
                          DropdownMenuItem(value: 50, child: Text('50 phút')),
                          DropdownMenuItem(value: 60, child: Text('60 phút')),
                        ],
                        onChanged: (v) => setSheetState(() => durationMinutes = v ?? 45),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: maxAttempts,
                        decoration: const InputDecoration(
                          labelText: 'Số lần làm',
                          border: OutlineInputBorder(),
                        ),
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
                  initialValue: unitForExam,
                  decoration: const InputDecoration(
                    labelText: 'Trích xuất đề từ Ngân hàng câu hỏi Unit',
                    border: OutlineInputBorder(),
                  ),
                  items: List.generate(
                    10,
                    (i) => DropdownMenuItem(value: i + 1, child: Text('Unit ${i + 1} (SGK 12)')),
                  ),
                  onChanged: (v) => setSheetState(() => unitForExam = v ?? 1),
                ),
                const SizedBox(height: 14),

                // Khối Chống gian lận chuẩn Ảnh 16
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFC5CAE9)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Chống gian lận',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Khuyên dùng',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
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
                                padding: const EdgeInsets.symmetric(horizontal: 3),
                                child: ChoiceChip(
                                  label: Text('$sec giây'),
                                  selected: graceSeconds == sec,
                                  onSelected: (_) => setSheetState(() => graceSeconds = sec),
                                ),
                              ),
                            ),
                        ],
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Tự nộp và tính điểm khi quá thời gian',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          'Câu chưa làm tính là sai',
                          style: TextStyle(fontSize: 11),
                        ),
                        value: autoSubmitOnTimeout,
                        onChanged: (v) => setSheetState(() => autoSubmitOnTimeout = v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Xáo trộn thứ tự câu và đáp án',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
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
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF283593)),
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
                        description: 'Kỳ thi có giám sát lớp $selectedClassName (Ân hạn rời app: $graceSeconds giây)',
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
                      setState(() => _selectedExam = created);
                      await _loadAllData();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Đã phát hành bài thi giám sát "${created.title}"!'),
                            backgroundColor: const Color(0xFF1B5E20),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.verified_user_outlined),
                    label: const Text('Phát hành bài thi có giám sát'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _subTabController,
            labelColor: const Color(0xFF283593),
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: const Color(0xFF283593),
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: const [
              Tab(text: 'Bài đã giao'),
              Tab(text: 'Giám sát thi 10s'),
              Tab(text: 'Ngân hàng đề'),
            ],
          ),
        ),
        if (_isLoading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: TabBarView(
            controller: _subTabController,
            children: [
              _buildAssignmentsSubView(),
              _buildLiveProctorSubView(),
              _buildQuestionBankSubView(),
            ],
          ),
        ),
      ],
    );
  }

  // Sub-tab 1: Bài đã giao & Kỳ thi
  Widget _buildAssignmentsSubView() {
    final filteredAssigns = _assignments.where((a) {
      if (_assignmentFilter == 'closed') return a['status'] == 'closed';
      return a['status'] != 'closed';
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner Đang thi trực tiếp (Ảnh 7)
            if (_exams.isNotEmpty)
              InkWell(
                onTap: () => _subTabController.animateTo(1),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.fiber_manual_record, color: Colors.redAccent, size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Đang mở thi: ${_exams.first.title}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '${_liveSessions.where((s) => s.isActive).length} đang làm • ${_liveSessions.where((s) => s.violationCount > 0).length} bị ghi nhận rời app',
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.white),
                    ],
                  ),
                ),
              ),

            Row(
              children: [
                ChoiceChip(
                  label: const Text('Đang mở'),
                  selected: _assignmentFilter == 'open',
                  onSelected: (_) => setState(() => _assignmentFilter = 'open'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Đã đóng'),
                  selected: _assignmentFilter == 'closed',
                  onSelected: (_) => setState(() => _assignmentFilter = 'closed'),
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: _showCreateSupervisedExamModal,
                  icon: const Icon(Icons.shield_outlined, size: 16),
                  label: const Text('Tạo thi 10s'),
                ),
                const SizedBox(width: 6),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF283593)),
                  onPressed: _showCreateAssignmentModal,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Giao bài'),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (filteredAssigns.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.assignment_outlined, size: 40, color: Colors.grey),
                    const SizedBox(height: 8),
                    const Text(
                      'Chưa có bài giao nào trong danh sách này.',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Bấm "+ Giao bài" để giao Unit SGK hoặc "+ Tạo thi 10s" để mở phòng thi có giám sát.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredAssigns.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (ctx, idx) {
                  final a = filteredAssigns[idx];
                  final submittedCount = (a['submittedCount'] as num?)?.toInt() ?? 0;
                  final dueStr = (a['dueAt'] ?? '').toString().split('T').first;
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
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    a['title'].toString(),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  Text(
                                    'Lớp ${a['className'] ?? "12"} • Hạn nộp: $dueStr',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                a['status'] == 'closed' ? 'Đã đóng' : 'Đang mở',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[900],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Đã nộp: $submittedCount bài',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            IconButton(
                              tooltip: 'Xóa bài giao',
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                              onPressed: () async {
                                await _service.deleteAssignment(a['id'].toString());
                                await _loadAllData();
                              },
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

  // Sub-tab 2: Giám sát thi 10s Live (Theo Ảnh 16)
  Widget _buildLiveProctorSubView() {
    final inProgressCount = _liveSessions.where((s) => s.isActive).length;
    final submittedCount = _liveSessions
        .where((s) => s.status == 'submitted_on_time' || s.status == 'submitted_late')
        .length;
    final autoSubmittedOrViolatedCount = _liveSessions
        .where((s) =>
            s.status == 'force_submitted_auto' ||
            s.status == 'force_submitted_teacher' ||
            s.status == 'invalidated' ||
            s.violationCount > 0)
        .length;

    final filteredSessions = _liveSessions.where((s) {
      if (_proctorSessionFilter == 'in_progress') return s.isActive;
      if (_proctorSessionFilter == 'submitted') {
        return s.status == 'submitted_on_time' || s.status == 'submitted_late';
      }
      if (_proctorSessionFilter == 'violated') {
        return s.violationCount > 0 ||
            s.status == 'force_submitted_auto' ||
            s.status == 'invalidated';
      }
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _exams.isEmpty
                      ? const Text(
                          'Chưa có đề thi có giám sát nào.',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        )
                      : DropdownButtonFormField<String>(
                          initialValue: _selectedExam?.id,
                          decoration: const InputDecoration(
                            labelText: 'Đề thi đang giám sát',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: _exams
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e.id,
                                  child: Text(e.title, overflow: TextOverflow.ellipsis),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              final ex = _exams.where((e) => e.id == v).firstOrNull;
                              if (ex != null) {
                                setState(() => _selectedExam = ex);
                                _loadSessionsForSelectedExam(ex.id);
                              }
                            }
                          },
                        ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF283593)),
                  onPressed: _showCreateSupervisedExamModal,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Cài đặt đề'),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (_selectedExam != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
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
                          child: Text(
                            _selectedExam!.title,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Đang diễn ra',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Thời lượng: ${_selectedExam!.durationMinutes} phút • Cảnh báo rời app: ${_selectedExam!.graceSeconds} giây',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 3 Thẻ thống kê trực tiếp (Đang làm / Đã nộp / Tự nộp)
              Row(
                children: [
                  Expanded(
                    child: AdminKpiCard(
                      title: 'Đang làm',
                      value: '$inProgressCount',
                      subtitle: 'Thí sinh',
                      icon: Icons.edit_note,
                      iconColor: const Color(0xFF283593),
                      backgroundColor: const Color(0xFFE8EAF6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AdminKpiCard(
                      title: 'Đã nộp',
                      value: '$submittedCount',
                      subtitle: 'Hợp lệ',
                      icon: Icons.check_circle_outline,
                      iconColor: Colors.green[800]!,
                      backgroundColor: const Color(0xFFE8F5E9),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AdminKpiCard(
                      title: 'Tự nộp / Rời app',
                      value: '$autoSubmittedOrViolatedCount',
                      subtitle: 'Quá ${_selectedExam!.graceSeconds}s',
                      icon: Icons.warning_amber_rounded,
                      iconColor: Colors.red[800]!,
                      backgroundColor: const Color(0xFFFFEBEE),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: Text('Tất cả (${_liveSessions.length})'),
                      selected: _proctorSessionFilter == 'all',
                      onSelected: (_) => setState(() => _proctorSessionFilter = 'all'),
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: Text('Đang làm ($inProgressCount)'),
                      selected: _proctorSessionFilter == 'in_progress',
                      onSelected: (_) => setState(() => _proctorSessionFilter = 'in_progress'),
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: Text('Đã nộp ($submittedCount)'),
                      selected: _proctorSessionFilter == 'submitted',
                      onSelected: (_) => setState(() => _proctorSessionFilter = 'submitted'),
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: Text('Bị ghi nhận rời app ($autoSubmittedOrViolatedCount)'),
                      selected: _proctorSessionFilter == 'violated',
                      onSelected: (_) => setState(() => _proctorSessionFilter = 'violated'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              if (filteredSessions.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: const Text(
                    'Chưa có phiên làm bài nào khớp bộ lọc.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredSessions.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (ctx, idx) {
                    final s = filteredSessions[idx];
                    final isAutoSubmitted = s.status == 'force_submitted_auto' ||
                        s.status == 'force_submitted_teacher' ||
                        s.status == 'invalidated';
                    final hasExplanation =
                        s.studentExplanation != null && s.studentExplanation!.trim().isNotEmpty;

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isAutoSubmitted
                            ? Colors.red[50]
                            : (s.violationCount > 0 ? Colors.amber[50] : Colors.white),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isAutoSubmitted
                              ? Colors.red[200]!
                              : (s.violationCount > 0 ? Colors.amber[300]! : Colors.grey[200]!),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: isAutoSubmitted
                                    ? Colors.red[100]
                                    : const Color(0xFFE8EAF6),
                                child: Text(
                                  s.studentName.isNotEmpty ? s.studentName[0].toUpperCase() : 'H',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isAutoSubmitted ? Colors.red[900] : const Color(0xFF283593),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.studentName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    Text(
                                      'Đã làm ${s.answeredCount}/${s.totalQuestions} câu • Rời app: ${s.violationCount} lần • Điểm: ${s.score}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                    ),
                                  ],
                                ),
                              ),
                              if (isAutoSubmitted)
                                FilledButton.tonal(
                                  onPressed: () async {
                                    await _service.performTeacherProctorAction(
                                      exam: _selectedExam!,
                                      session: s,
                                      action: 'reset_violation',
                                    );
                                    await _loadSessionsForSelectedExam(_selectedExam!.id);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Đã mở khóa cho ${s.studentName} làm lại bài thi!'),
                                          backgroundColor: const Color(0xFF1B5E20),
                                        ),
                                      );
                                    }
                                  },
                                  child: const Text('Cho làm lại'),
                                ),
                            ],
                          ),
                          if (hasExplanation) ...[
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.red[200]!),
                              ),
                              child: Text(
                                '💬 Giải trình của học sinh: "${s.studentExplanation}"',
                                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                              ),
                            ),
                          ],
                          if (s.isActive) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () async {
                                    await _service.performTeacherProctorAction(
                                      exam: _selectedExam!,
                                      session: s,
                                      action: 'warn',
                                    );
                                    await _loadSessionsForSelectedExam(_selectedExam!.id);
                                  },
                                  icon: const Icon(Icons.notifications_active_outlined, size: 16),
                                  label: const Text('Nhắc nhở'),
                                ),
                                TextButton.icon(
                                  onPressed: () async {
                                    await _service.performTeacherProctorAction(
                                      exam: _selectedExam!,
                                      session: s,
                                      action: 'force_submit',
                                    );
                                    await _loadSessionsForSelectedExam(_selectedExam!.id);
                                  },
                                  icon: const Icon(Icons.send_and_archive, size: 16, color: Colors.red),
                                  label: const Text('Thu bài', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }

  // Sub-tab 3: Ngân hàng câu hỏi SGK 12 thật
  Widget _buildQuestionBankSubView() {
    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _selectedUnitBank,
                    decoration: const InputDecoration(
                      labelText: 'Chọn Unit SGK 12',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: List.generate(
                      10,
                      (i) => DropdownMenuItem(value: i + 1, child: Text('Unit ${i + 1}')),
                    ),
                    onChanged: (v) async {
                      if (v != null) {
                        setState(() => _selectedUnitBank = v);
                        final qs = await _service.getTeacherQuestions(unitNumber: v);
                        if (mounted) {
                          setState(() => _bankQuestions = qs);
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF283593)),
                  onPressed: () async {
                    setState(() => _isLoading = true);
                    final generated = await _service.generateQuestionsWithAi(
                      unitNumber: _selectedUnitBank,
                      skill: 'grammar',
                      difficulty: 2,
                      count: 3,
                    );
                    await _service.saveTeacherQuestions(generated);
                    final qs = await _service.getTeacherQuestions(unitNumber: _selectedUnitBank);
                    if (mounted) {
                      setState(() {
                        _bankQuestions = qs;
                        _isLoading = false;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Đã bổ sung ${generated.length} câu hỏi vào Unit $_selectedUnitBank!')),
                      );
                    }
                  },
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('Trích xuất / AI'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Hiện có ${_bankQuestions.length} câu hỏi trong Ngân hàng Unit $_selectedUnitBank:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _bankQuestions.take(25).length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (ctx, idx) {
                final q = _bankQuestions[idx];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              q.stem,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                            onPressed: () async {
                              await _service.deleteTeacherQuestion(q.id);
                              final qs = await _service.getTeacherQuestions(unitNumber: _selectedUnitBank);
                              if (mounted) setState(() => _bankQuestions = qs);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ...q.options.asMap().entries.map((entry) {
                        final isCorrect = entry.key == q.correctIndex;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            entry.value,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
                              color: isCorrect ? Colors.green[800] : Colors.black87,
                            ),
                          ),
                        );
                      }),
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
}

