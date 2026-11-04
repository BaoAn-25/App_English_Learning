import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/models/question.dart';
import '../../data/rbac_proctor_ai_service.dart';
import '../ai/ai_tutor_sheet.dart';
import '../practice/supervised_exam_screen.dart';
import '../theme/app_tokens.dart';
import '../theme/components/engpass_mascot.dart';

/// Cổng Giáo Viên (`TeacherPortalScreen`) — Đầy đủ 4 phân hệ CRUD + Giám sát Phòng thi + Trợ lý AI Giáo viên:
/// 1. CRUD Đề thi & Hạn nộp (Supervised Exams CRUD).
/// 2. Bảng Giám sát Phòng thi Trực tiếp (Live Proctoring: Nhắc nhở, Thu bài ngay, Hủy kết quả, AI Nhận xét).
/// 3. CRUD Ngân hàng Câu hỏi + AI Tự động sinh câu hỏi không cần nhập tay.
/// 4. CRUD Tài liệu & Bài học bổ trợ lớp học.
class TeacherPortalScreen extends StatefulWidget {
  final int initialTabIndex;

  const TeacherPortalScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<TeacherPortalScreen> createState() => _TeacherPortalScreenState();
}

class _TeacherPortalScreenState extends State<TeacherPortalScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final DateFormat _dateFmt = DateFormat('dd/MM/yyyy HH:mm');

  bool _isLoading = true;
  List<SupervisedExamModel> _exams = [];
  SupervisedExamModel? _selectedExamForProctor;
  List<ExamLiveSessionModel> _liveSessions = [];

  List<Question> _questions = [];
  int? _questionUnitFilter;

  List<Map<String, dynamic>> _materials = [];
  bool _isGeneratingAiQuestions = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 3),
    );
    _loadAllTeacherData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllTeacherData() async {
    setState(() => _isLoading = true);
    final exams = await RbacProctorAiService.instance.getSupervisedExams();
    final selectedExam = _selectedExamForProctor ?? (exams.isNotEmpty ? exams.first : null);
    final sessions = selectedExam != null
        ? await RbacProctorAiService.instance.getLiveSessionsForExam(selectedExam.id)
        : <ExamLiveSessionModel>[];
    final questions = await RbacProctorAiService.instance.getTeacherQuestions(
      unitNumber: _questionUnitFilter,
    );
    final materials = await RbacProctorAiService.instance.getStudyMaterials();

    if (!mounted) return;
    setState(() {
      _exams = exams;
      _selectedExamForProctor = selectedExam;
      _liveSessions = sessions;
      _questions = questions;
      _materials = materials;
      _isLoading = false;
    });
  }

  Future<void> _refreshProctorSessions() async {
    if (_selectedExamForProctor == null) return;
    final sessions = await RbacProctorAiService.instance.getLiveSessionsForExam(
      _selectedExamForProctor!.id,
    );
    if (!mounted) return;
    setState(() => _liveSessions = sessions);
  }

  // Hộp thoại Tạo / Sửa Đề thi có giám sát & Hạn nộp
  Future<void> _showExamFormDialog({SupervisedExamModel? existing}) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final descCtrl = TextEditingController(
      text: existing?.description ?? 'Đề kiểm tra có giám sát chống gian lận (tự động thu bài nếu thoát ứng dụng quá 10 giây).',
    );
    final durationCtrl = TextEditingController(
      text: (existing?.durationMinutes ?? 30).toString(),
    );
    final graceCtrl = TextEditingController(
      text: (existing?.graceSeconds ?? 10).toString(),
    );
    final maxViolationsCtrl = TextEditingController(
      text: (existing?.maxViolations ?? 2).toString(),
    );
    String violationAction = existing?.violationAction ?? 'force_submit';
    DateTime deadlineAt = existing?.deadlineAt ?? DateTime.now().add(const Duration(days: 3));

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(existing == null ? 'Tạo Đề Thi Giám Sát Mới' : 'Chỉnh Sửa Đề Thi Giám Sát'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Tiêu đề kỳ thi / bài kiểm tra *',
                        hintText: 'VD: Kiểm tra 45 phút Unit 1 - 3',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Mô tả & Quy định phòng thi'),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: durationCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Thời gian (phút)'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: graceCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Đếm ngược Out App (giây)'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: maxViolationsCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Số lần cảnh cáo tối đa trước khi thu bài',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: violationAction,
                      decoration: const InputDecoration(labelText: 'Xử lý khi vi phạm quá 10 giây'),
                      items: const [
                        DropdownMenuItem(
                          value: 'force_submit',
                          child: Text('Tự động thu bài & chấm số câu đã làm'),
                        ),
                        DropdownMenuItem(
                          value: 'invalidate',
                          child: Text('Hủy kết quả bài thi (0 điểm)'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setDialogState(() => violationAction = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event_available_rounded, color: AppTokens.primary),
                      title: const Text('Hạn chót nộp bài (Deadline)', style: TextStyle(fontSize: 13)),
                      subtitle: Text(
                        _dateFmt.format(deadlineAt),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      trailing: TextButton(
                        onPressed: () async {
                          final pickedDate = await showDatePicker(
                            context: ctx,
                            initialDate: deadlineAt,
                            firstDate: DateTime.now().subtract(const Duration(days: 1)),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (pickedDate != null) {
                            setDialogState(() {
                              deadlineAt = DateTime(
                                pickedDate.year,
                                pickedDate.month,
                                pickedDate.day,
                                23,
                                59,
                              );
                            });
                          }
                        },
                        child: const Text('Đổi hạn nộp'),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  onPressed: () {
                    if (titleCtrl.text.trim().isEmpty) return;
                    Navigator.pop(ctx, true);
                  },
                  child: const Text('Lưu Đề Thi'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == true) {
      await RbacProctorAiService.instance.saveSupervisedExam(
        id: existing?.id,
        title: titleCtrl.text.trim(),
        description: descCtrl.text.trim(),
        durationMinutes: int.tryParse(durationCtrl.text) ?? 30,
        deadlineAt: deadlineAt,
        graceSeconds: int.tryParse(graceCtrl.text) ?? 10,
        maxViolations: int.tryParse(maxViolationsCtrl.text) ?? 2,
        violationAction: violationAction,
        questions: existing?.questions,
      );
      await _loadAllTeacherData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã lưu cấu hình Đề thi có giám sát thành công!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Tạo câu hỏi tự động bằng AI không cần nhập tay
  Future<void> _showAiQuestionGeneratorDialog() async {
    int selectedUnit = _questionUnitFilter ?? 1;
    String selectedSkill = 'grammar';
    int selectedCount = 3;
    final promptCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('⚡ AI Tự Động Sinh Câu Hỏi (Không cần nhập tay)'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: selectedUnit,
                      decoration: const InputDecoration(labelText: 'Chọn Unit SGK 12'),
                      items: List.generate(
                        10,
                        (i) => DropdownMenuItem(value: i + 1, child: Text('Unit ${i + 1}')),
                      ),
                      onChanged: (v) {
                        if (v != null) setDialogState(() => selectedUnit = v);
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: selectedSkill,
                      decoration: const InputDecoration(labelText: 'Kỹ năng kiểm tra'),
                      items: const [
                        DropdownMenuItem(value: 'grammar', child: Text('Ngữ pháp (Grammar)')),
                        DropdownMenuItem(value: 'vocabulary', child: Text('Từ vựng (Vocabulary)')),
                        DropdownMenuItem(value: 'reading', child: Text('Đọc hiểu (Reading)')),
                      ],
                      onChanged: (v) {
                        if (v != null) setDialogState(() => selectedSkill = v);
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      initialValue: selectedCount,
                      decoration: const InputDecoration(labelText: 'Số lượng câu hỏi cần tạo'),
                      items: const [
                        DropdownMenuItem(value: 3, child: Text('3 câu hỏi chuẩn THPT')),
                        DropdownMenuItem(value: 5, child: Text('5 câu hỏi chuẩn THPT')),
                      ],
                      onChanged: (v) {
                        if (v != null) setDialogState(() => selectedCount = v);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: promptCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Chủ đề / Yêu cầu cụ thể (Tùy chọn)',
                        hintText: 'VD: Mệnh đề quan hệ, Câu chẻ, So sánh kép...',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Hủy'),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: const Text('Sinh Câu Hỏi & Lưu'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true) {
      setState(() => _isGeneratingAiQuestions = true);
      final generated = await RbacProctorAiService.instance.generateQuestionsWithAi(
        unitNumber: selectedUnit,
        skill: selectedSkill,
        difficulty: 2,
        count: selectedCount,
        topicPrompt: promptCtrl.text.trim(),
      );
      await RbacProctorAiService.instance.saveTeacherQuestions(generated);
      await _loadAllTeacherData();
      if (!mounted) return;
      setState(() => _isGeneratingAiQuestions = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '⚡ AI đã sinh và lưu ${generated.length} câu hỏi mới vào Ngân hàng đề Unit $selectedUnit!',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Hộp thoại Thêm / Sửa Câu hỏi thủ công (CRUD)
  Future<void> _showQuestionCrudDialog({Question? existing}) async {
    final stemCtrl = TextEditingController(text: existing?.stem ?? '');
    final optACtrl = TextEditingController(
      text: (existing != null && existing.options.isNotEmpty) ? existing.options[0] : 'A. ',
    );
    final optBCtrl = TextEditingController(
      text: (existing != null && existing.options.length > 1) ? existing.options[1] : 'B. ',
    );
    final optCCtrl = TextEditingController(
      text: (existing != null && existing.options.length > 2) ? existing.options[2] : 'C. ',
    );
    final optDCtrl = TextEditingController(
      text: (existing != null && existing.options.length > 3) ? existing.options[3] : 'D. ',
    );
    final explainCtrl = TextEditingController(text: existing?.explanation ?? '');
    int correctIndex = existing?.correctIndex ?? 0;
    int unitNumber = int.tryParse(existing?.topicId?.replaceAll('t', '') ?? '') ?? 1;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(existing == null ? 'Thêm Câu Hỏi Mới' : 'Chỉnh Sửa Câu Hỏi'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: unitNumber.clamp(1, 10),
                      decoration: const InputDecoration(labelText: 'Thuộc Unit SGK 12'),
                      items: List.generate(
                        10,
                        (i) => DropdownMenuItem(value: i + 1, child: Text('Unit ${i + 1}')),
                      ),
                      onChanged: (v) {
                        if (v != null) setDialogState(() => unitNumber = v);
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: stemCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Nội dung câu hỏi (Stem) *'),
                    ),
                    const SizedBox(height: 8),
                    TextField(controller: optACtrl, decoration: const InputDecoration(labelText: 'Phương án A')),
                    TextField(controller: optBCtrl, decoration: const InputDecoration(labelText: 'Phương án B')),
                    TextField(controller: optCCtrl, decoration: const InputDecoration(labelText: 'Phương án C')),
                    TextField(controller: optDCtrl, decoration: const InputDecoration(labelText: 'Phương án D')),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      initialValue: correctIndex.clamp(0, 3),
                      decoration: const InputDecoration(labelText: 'Đáp án đúng'),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('Đáp án A')),
                        DropdownMenuItem(value: 1, child: Text('Đáp án B')),
                        DropdownMenuItem(value: 2, child: Text('Đáp án C')),
                        DropdownMenuItem(value: 3, child: Text('Đáp án D')),
                      ],
                      onChanged: (v) {
                        if (v != null) setDialogState(() => correctIndex = v);
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: explainCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Giải thích đáp án (Tiếng Việt)'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  onPressed: () {
                    if (stemCtrl.text.trim().isEmpty) return;
                    Navigator.pop(ctx, true);
                  },
                  child: const Text('Lưu Câu Hỏi'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == true) {
      await RbacProctorAiService.instance.saveTeacherQuestions([
        {
          'id': existing?.id ?? 'tq_${DateTime.now().millisecondsSinceEpoch}',
          'unitNumber': unitNumber,
          'skill': existing?.type ?? 'grammar',
          'difficulty': existing?.difficulty ?? 2,
          'stem': stemCtrl.text.trim(),
          'options': [
            optACtrl.text.trim(),
            optBCtrl.text.trim(),
            optCCtrl.text.trim(),
            optDCtrl.text.trim(),
          ],
          'correctIndex': correctIndex,
          'explanation': explainCtrl.text.trim(),
        }
      ]);
      await _loadAllTeacherData();
    }
  }

  // Hộp thoại Thêm / Sửa Tài liệu lớp học (Materials CRUD)
  Future<void> _showMaterialCrudDialog({Map<String, dynamic>? existing}) async {
    final titleCtrl = TextEditingController(text: (existing?['title'] ?? '').toString());
    final contentCtrl = TextEditingController(text: (existing?['content'] ?? '').toString());
    int unitNumber = (existing?['unitNumber'] as num?)?.toInt() ?? 1;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(existing == null ? 'Thêm Tài Liệu Học Tập' : 'Chỉnh Sửa Tài Liệu'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: unitNumber.clamp(1, 10),
                      decoration: const InputDecoration(labelText: 'Thuộc Unit SGK 12'),
                      items: List.generate(
                        10,
                        (i) => DropdownMenuItem(value: i + 1, child: Text('Unit ${i + 1}')),
                      ),
                      onChanged: (v) {
                        if (v != null) setDialogState(() => unitNumber = v);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: 'Tiêu đề tài liệu / chuyên đề *'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: contentCtrl,
                      maxLines: 5,
                      decoration: const InputDecoration(labelText: 'Nội dung kiến thức / bài đọc bổ trợ *'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  onPressed: () {
                    if (titleCtrl.text.trim().isEmpty || contentCtrl.text.trim().isEmpty) return;
                    Navigator.pop(ctx, true);
                  },
                  child: const Text('Lưu Tài Liệu'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == true) {
      await RbacProctorAiService.instance.saveStudyMaterial({
        if (existing != null) 'id': existing['id'],
        'unitNumber': unitNumber,
        'category': 'grammar',
        'title': titleCtrl.text.trim(),
        'content': contentCtrl.text.trim(),
      });
      await _loadAllTeacherData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppTokens.darkBackground : AppTokens.background;
    final cardColor = isDark ? AppTokens.darkSurface : AppTokens.surface;
    final textMain = isDark ? AppTokens.darkTextMain : AppTokens.textMain;
    final textSub = isDark ? AppTokens.darkTextSub : AppTokens.textSub;
    final borderColor = isDark ? AppTokens.darkBorder : AppTokens.border;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        title: Row(
          children: [
            const EngPassMascot(mood: MascotMood.cheer, size: 32),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Cổng Giáo Viên & Giám Sát Thi',
                style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: textMain),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Trợ lý AI Giáo viên (Soạn giảng & Chấm bài)',
            icon: const Icon(Icons.auto_awesome_rounded, color: AppTokens.primary),
            onPressed: () => AiTutorSheet.show(context, initialMode: 'teacher_assist'),
          ),
          IconButton(
            tooltip: 'Làm mới dữ liệu',
            icon: Icon(Icons.refresh_rounded, color: textMain),
            onPressed: _loadAllTeacherData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: AppTokens.primary,
          unselectedLabelColor: textSub,
          indicatorColor: AppTokens.primary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.assignment_rounded, size: 18), text: '1. Đề thi & Hạn nộp'),
            Tab(icon: Icon(Icons.radar_rounded, size: 18), text: '2. Giám sát Phòng thi (Live)'),
            Tab(icon: Icon(Icons.quiz_rounded, size: 18), text: '3. Ngân hàng Câu hỏi'),
            Tab(icon: Icon(Icons.menu_book_rounded, size: 18), text: '4. Tài liệu Lớp học'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildExamsCrudTab(cardColor, textMain, textSub, borderColor),
                _buildLiveProctoringTab(cardColor, textMain, textSub, borderColor),
                _buildQuestionsCrudTab(cardColor, textMain, textSub, borderColor),
                _buildMaterialsCrudTab(cardColor, textMain, textSub, borderColor),
              ],
            ),
    );
  }

  // TAB 1: CRUD Đề thi & Hạn nộp
  Widget _buildExamsCrudTab(
    Color cardColor,
    Color textMain,
    Color textSub,
    Color borderColor,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _showExamFormDialog(),
                icon: const Icon(Icons.add_circle_outline_rounded),
                label: const Text('+ Tạo Đề Thi Giám Sát Mới'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ..._exams.map((exam) {
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
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
                    Expanded(
                      child: Text(
                        exam.title,
                        style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: textMain),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Sửa đề thi & gia hạn nộp bài',
                      icon: const Icon(Icons.edit_rounded, size: 20, color: AppTokens.primary),
                      onPressed: () => _showExamFormDialog(existing: exam),
                    ),
                    IconButton(
                      tooltip: 'Xóa đề thi',
                      icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppTokens.danger),
                      onPressed: () async {
                        await RbacProctorAiService.instance.deleteSupervisedExam(exam.id);
                        await _loadAllTeacherData();
                      },
                    ),
                  ],
                ),
                Text(
                  exam.description,
                  style: TextStyle(fontSize: 13, color: textSub),
                ),
                const SizedBox(height: 10),
                Text(
                  '⏰ Hạn nộp: ${_dateFmt.format(exam.deadlineAt)} • ⏱️ ${exam.durationMinutes} phút (${exam.questions.length} câu)\n'
                  '🛡️ Chống gian lận: Đếm ngược ${exam.graceSeconds}s khi Out App • Tối đa ${exam.maxViolations} lần cảnh cáo',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textSub, height: 1.45),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() => _selectedExamForProctor = exam);
                          _refreshProctorSessions();
                          _tabController.animateTo(1);
                        },
                        icon: const Icon(Icons.radar_rounded, size: 18),
                        label: const Text('Giám sát Phòng thi'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SupervisedExamPlayerScreen(exam: exam),
                            ),
                          );
                          await _loadAllTeacherData();
                        },
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: const Text('Thi thử (Test)'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // TAB 2: Bảng Giám sát Phòng thi Trực tiếp (Live Proctoring)
  Widget _buildLiveProctoringTab(
    Color cardColor,
    Color textMain,
    Color textSub,
    Color borderColor,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_exams.isNotEmpty)
          DropdownButtonFormField<String>(
            initialValue: _selectedExamForProctor?.id ?? _exams.first.id,
            decoration: const InputDecoration(
              labelText: 'Chọn Kỳ thi cần Giám sát Trực tiếp',
              border: OutlineInputBorder(),
            ),
            items: _exams
                .map(
                  (e) => DropdownMenuItem(
                    value: e.id,
                    child: Text(e.title, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (examId) {
              final found = _exams.where((e) => e.id == examId).firstOrNull;
              if (found != null) {
                setState(() => _selectedExamForProctor = found);
                _refreshProctorSessions();
              }
            },
          ),
        const SizedBox(height: 12),

        // Nút tạo nhanh 1 phiên học sinh giả lập đang vi phạm để Giáo viên kiểm thử nút Thu bài / Hủy bài ngay lập tức
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _selectedExamForProctor == null
                    ? null
                    : () async {
                        final exam = _selectedExamForProctor!;
                        final s = await RbacProctorAiService.instance.startSupervisedExamSession(
                          exam: exam,
                          userId: 'stu_${DateTime.now().millisecondsSinceEpoch}',
                          studentName: 'Học viên Đang Thi (${DateFormat('HH:mm:ss').format(DateTime.now())})',
                          studentEmail: 'student_exam@engpass.vn',
                        );
                        await RbacProctorAiService.instance.recordProctorHeartbeat(
                          exam: exam,
                          currentSession: s,
                          currentAnswers: {'0': 0, '1': 1},
                          eventType: 'app_backgrounded',
                          detail: 'Phát hiện thoát ứng dụng ra ngoài nghi vấn mở ChatGPT / sao chép tài liệu.',
                        );
                        ExamLockGuard.instance.exitSupervisedExam();
                        await _refreshProctorSessions();
                      },
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('+ Tạo Phiên Thí Sinh Cảnh Báo (Để Test Thu Bài)'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        if (_liveSessions.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                const Icon(Icons.verified_user_outlined, size: 48, color: AppTokens.primary),
                const SizedBox(height: 8),
                Text(
                  'Chưa có thí sinh nào vào phòng thi này.',
                  style: TextStyle(fontWeight: FontWeight.w700, color: textMain),
                ),
                const SizedBox(height: 4),
                Text(
                  'Khi học sinh bắt đầu làm bài hoặc thoát ứng dụng quá 10 giây, cảnh báo và các nút Thu bài / Hủy bài sẽ hiển thị tại đây.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: textSub),
                ),
              ],
            ),
          ),

        ..._liveSessions.map((session) {
          final hasViolation = session.violationCount > 0;
          final statusColor = session.status == 'invalidated' ||
                  session.status == 'force_submitted_auto' ||
                  session.status == 'force_submitted_teacher'
              ? AppTokens.danger
              : (hasViolation ? AppTokens.warning : AppTokens.success);

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: statusColor.withValues(alpha: 0.7), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      hasViolation ? Icons.warning_rounded : Icons.person_pin_circle_rounded,
                      color: statusColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        session.studentName,
                        style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: textMain),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        session.statusLabel,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Tiến độ: ${session.answeredCount}/${session.totalQuestions} câu • Điểm hiện tại: ${session.score.toStringAsFixed(1)}/10 • Số lần rời App: ${session.violationCount} lần',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textSub),
                ),
                if (session.violationLogs.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTokens.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '🚨 Nhật ký phát hiện hành vi khả nghi:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppTokens.danger,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ...session.violationLogs.take(3).map(
                          (log) => Text(
                            '• ${log['detail'] ?? 'Rời khỏi màn hình làm bài'}',
                            style: TextStyle(fontSize: 12, color: textMain),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                // Các nút quyền hạn trực tiếp của Giáo viên
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (session.isActive) ...[
                      OutlinedButton.icon(
                        onPressed: () async {
                          await RbacProctorAiService.instance.performTeacherProctorAction(
                            exam: _selectedExamForProctor!,
                            session: session,
                            action: 'warn',
                          );
                          await _refreshProctorSessions();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Đã gửi cảnh báo nhắc nhở tới ${session.studentName}!'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.campaign_rounded, size: 16),
                        label: const Text('Nhắc nhở'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () async {
                          await RbacProctorAiService.instance.performTeacherProctorAction(
                            exam: _selectedExamForProctor!,
                            session: session,
                            action: 'force_submit',
                          );
                          await _refreshProctorSessions();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Đã THU BÀI ngay lập tức đối với ${session.studentName}!'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.assignment_returned_rounded, size: 16),
                        label: const Text('Thu bài luôn'),
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: AppTokens.danger),
                        onPressed: () async {
                          await RbacProctorAiService.instance.performTeacherProctorAction(
                            exam: _selectedExamForProctor!,
                            session: session,
                            action: 'invalidate',
                          );
                          await _refreshProctorSessions();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Đã HỦY KẾT QUẢ bài thi của ${session.studentName} do vi phạm!'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.block_rounded, size: 16),
                        label: const Text('Hủy kết quả'),
                      ),
                    ] else ...[
                      OutlinedButton.icon(
                        onPressed: () async {
                          await RbacProctorAiService.instance.performTeacherProctorAction(
                            exam: _selectedExamForProctor!,
                            session: session,
                            action: 'reset_violation',
                          );
                          await _refreshProctorSessions();
                        },
                        icon: const Icon(Icons.restore_rounded, size: 16),
                        label: const Text('Cho phép làm lại'),
                      ),
                    ],
                    ActionChip(
                      avatar: const Icon(Icons.auto_awesome_rounded, size: 16, color: AppTokens.primary),
                      label: const Text('AI Nhận xét bài làm'),
                      onPressed: () {
                        AiTutorSheet.show(
                          context,
                          initialMode: 'teacher_assist',
                          contextText:
                              'Học sinh ${session.studentName}, Điểm: ${session.score}/10, Số câu làm: ${session.answeredCount}/${session.totalQuestions}, Số lần rời app: ${session.violationCount}.',
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // TAB 3: CRUD Ngân hàng Câu hỏi + AI Sinh Câu Hỏi Tự Động
  Widget _buildQuestionsCrudTab(
    Color cardColor,
    Color textMain,
    Color textSub,
    Color borderColor,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _isGeneratingAiQuestions ? null : _showAiQuestionGeneratorDialog,
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(
                  _isGeneratingAiQuestions ? 'Đang sinh câu hỏi...' : '⚡ AI Tạo Câu Hỏi Tự Động',
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _showQuestionCrudDialog(),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Thêm tay'),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Lọc theo Unit
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: const Text('Tất cả Unit'),
                  selected: _questionUnitFilter == null,
                  onSelected: (_) {
                    setState(() => _questionUnitFilter = null);
                    _loadAllTeacherData();
                  },
                ),
              ),
              ...List.generate(10, (i) {
                final u = i + 1;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text('Unit $u'),
                    selected: _questionUnitFilter == u,
                    onSelected: (_) {
                      setState(() => _questionUnitFilter = u);
                      _loadAllTeacherData();
                    },
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 12),

        Text(
          'Tổng số câu hỏi đang hiển thị: ${_questions.length} câu',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: textSub),
        ),
        const SizedBox(height: 8),

        ..._questions.take(40).map((q) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTokens.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${q.topicId?.toUpperCase() ?? "SGK"} • ${q.type.toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppTokens.primary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.edit_rounded, size: 18, color: AppTokens.primary),
                      onPressed: () => _showQuestionCrudDialog(existing: q),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTokens.danger),
                      onPressed: () async {
                        await RbacProctorAiService.instance.deleteTeacherQuestion(q.id);
                        await _loadAllTeacherData();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  q.stem,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textMain),
                ),
                const SizedBox(height: 6),
                ...List.generate(q.options.length, (idx) {
                  final isRight = idx == q.correctIndex;
                  return Text(
                    '${isRight ? "✅" : "•"} ${q.options[idx]}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isRight ? FontWeight.w800 : FontWeight.w500,
                      color: isRight ? AppTokens.success : textSub,
                    ),
                  );
                }),
              ],
            ),
          );
        }),
      ],
    );
  }

  // TAB 4: CRUD Tài liệu & Bài học bổ trợ lớp học
  Widget _buildMaterialsCrudTab(
    Color cardColor,
    Color textMain,
    Color textSub,
    Color borderColor,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FilledButton.icon(
          onPressed: () => _showMaterialCrudDialog(),
          icon: const Icon(Icons.post_add_rounded),
          label: const Text('+ Thêm Tài Liệu / Bài Học Bổ Trợ Mới'),
        ),
        const SizedBox(height: 14),
        ..._materials.map((mat) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        (mat['title'] ?? '').toString(),
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textMain),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, size: 19, color: AppTokens.primary),
                      onPressed: () => _showMaterialCrudDialog(existing: mat),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 19, color: AppTokens.danger),
                      onPressed: () async {
                        await RbacProctorAiService.instance.deleteStudyMaterial(
                          mat['id'].toString(),
                        );
                        await _loadAllTeacherData();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  (mat['content'] ?? '').toString(),
                  style: TextStyle(fontSize: 13.5, color: textSub, height: 1.45),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

