import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/app_repository.dart';
import '../../../data/models/word.dart';
import '../../../data/rbac_proctor_ai_service.dart';
import '../../../data/trial_lesson_repository.dart';
import '../../theme/app_tokens.dart';

/// TAB 2: Quản lý Học liệu, Soạn Câu hỏi & Nhập sách AI (Content Studio)
/// Kế thừa bố cục Mockup 8: Quản lý 10 Unit SGK Global Success 12 thật,
/// danh sách câu hỏi thật, Form soạn câu hỏi và Trình số hóa sách mới.
class AdminContentTab extends StatefulWidget {
  final AppRepository? repository;

  const AdminContentTab({super.key, this.repository});

  @override
  State<AdminContentTab> createState() => _AdminContentTabState();
}

class _AdminContentTabState extends State<AdminContentTab> {
  late AppRepository _repo;
  int _selectedUnitNumber = 1;
  String _selectedSection = 'Reading';
  final TextEditingController _questionSearchCtrl = TextEditingController();

  bool _isLoadingQuestions = false;
  List<Map<String, dynamic>> _questions = [];

  final List<String> _sections = const [
    'Getting started',
    'Language',
    'Reading',
    'Speaking',
    'Listening',
    'Writing',
  ];

  @override
  void initState() {
    super.initState();
    _loadQuestionsForUnit();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _repo = widget.repository ?? context.read<AppRepository>();
  }

  @override
  void dispose() {
    _questionSearchCtrl.dispose();
    super.dispose();
  }

  TrialLessonData get _currentLesson {
    return TrialLessonRepository.allLessons.firstWhere(
      (l) => l.unitNumber == _selectedUnitNumber,
      orElse: () => TrialLessonRepository.allLessons.first,
    );
  }

  Future<void> _loadQuestionsForUnit() async {
    setState(() => _isLoadingQuestions = true);
    final allQuestions = await RbacProctorAiService.instance.getTeacherQuestions(
      unitNumber: _selectedUnitNumber,
    );
    if (!mounted) return;
    setState(() {
      _questions = allQuestions.map((q) => q.toMap()).toList();
      _isLoadingQuestions = false;
    });
  }

  // Hộp thoại Soạn câu hỏi mới
  Future<void> _showCreateQuestionDialog({Map<String, dynamic>? editItem}) async {
    final stemCtrl = TextEditingController(text: editItem?['stem']?.toString() ?? '');
    final optACtrl = TextEditingController(text: (editItem?['options'] as List?)?.elementAtOrNull(0)?.toString() ?? '');
    final optBCtrl = TextEditingController(text: (editItem?['options'] as List?)?.elementAtOrNull(1)?.toString() ?? '');
    final optCCtrl = TextEditingController(text: (editItem?['options'] as List?)?.elementAtOrNull(2)?.toString() ?? '');
    final optDCtrl = TextEditingController(text: (editItem?['options'] as List?)?.elementAtOrNull(3)?.toString() ?? '');
    final expCtrl = TextEditingController(text: editItem?['explanation']?.toString() ?? '');

    int correctIndex = (editItem?['correctIndex'] as num?)?.toInt() ?? 0;
    int difficulty = (editItem?['difficulty'] as num?)?.toInt() ?? 2;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            final textMain = isDark ? Colors.white : const Color(0xFF0F172A);

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withAlpha(100),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      editItem != null ? 'Chỉnh sửa Câu Hỏi' : 'Soạn Câu Hỏi Mới',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: textMain),
                    ),
                    Text(
                      'Unit $_selectedUnitNumber - $_selectedSection (Global Success 12)',
                      style: const TextStyle(fontSize: 12, color: AppTokens.primary, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 14),

                    TextField(
                      controller: stemCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Đề bài (Stem) *',
                        hintText: 'Nhập câu hỏi tiếng Anh...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Text('Các đáp án (Chạm nút tròn để chọn đáp án đúng):', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: textMain)),
                    const SizedBox(height: 6),
                    _buildOptionInput('A', optACtrl, 0, correctIndex, (idx) => setModalState(() => correctIndex = idx)),
                    _buildOptionInput('B', optBCtrl, 1, correctIndex, (idx) => setModalState(() => correctIndex = idx)),
                    _buildOptionInput('C', optCCtrl, 2, correctIndex, (idx) => setModalState(() => correctIndex = idx)),
                    _buildOptionInput('D', optDCtrl, 3, correctIndex, (idx) => setModalState(() => correctIndex = idx)),
                    const SizedBox(height: 10),

                    TextField(
                      controller: expCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Giải thích bằng tiếng Việt',
                        hintText: 'Cung cấp lý do chọn đáp án đúng...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Text('Độ khó: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textMain)),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Dễ'),
                          selected: difficulty == 1,
                          onSelected: (_) => setModalState(() => difficulty = 1),
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: const Text('Vừa'),
                          selected: difficulty == 2,
                          onSelected: (_) => setModalState(() => difficulty = 2),
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: const Text('Khó'),
                          selected: difficulty == 3,
                          onSelected: (_) => setModalState(() => difficulty = 3),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () async {
                          if (stemCtrl.text.trim().isEmpty || optACtrl.text.trim().isEmpty || optBCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Vui lòng nhập đề bài và tối thiểu 2 phương án A, B')),
                            );
                            return;
                          }
                          final options = [
                            optACtrl.text.trim(),
                            optBCtrl.text.trim(),
                            optCCtrl.text.trim().isNotEmpty ? optCCtrl.text.trim() : 'N/A',
                            optDCtrl.text.trim().isNotEmpty ? optDCtrl.text.trim() : 'N/A',
                          ];
                          await RbacProctorAiService.instance.saveTeacherQuestion(
                            id: editItem?['id']?.toString(),
                            unitNumber: _selectedUnitNumber,
                            skill: _selectedSection.toLowerCase(),
                            difficulty: difficulty,
                            stem: stemCtrl.text.trim(),
                            options: options,
                            correctIndex: correctIndex,
                            explanation: expCtrl.text.trim(),
                          );
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                          }
                          if (mounted) {
                            _loadQuestionsForUnit();
                          }
                        },
                        icon: const Icon(Icons.check_circle_rounded),
                        label: Text(editItem != null ? 'Cập Nhật Câu Hỏi' : 'Lưu Câu Hỏi Vào Ngân Hàng'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOptionInput(String letter, TextEditingController ctrl, int idx, int correctIdx, void Function(int) onSelect) {
    final isSelected = idx == correctIdx;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              color: isSelected ? AppTokens.success : Colors.grey,
            ),
            onPressed: () => onSelect(idx),
          ),
          Expanded(
            child: TextField(
              controller: ctrl,
              decoration: InputDecoration(
                isDense: true,
                labelText: 'Phương án $letter',
                border: const OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Hộp thoại Nhập sách / Số hóa AI
  Future<void> _showAiDigitizerDialog() async {
    final rawTextCtrl = TextEditingController();
    bool isProcessing = false;
    Map<String, dynamic>? digitizedResult;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(color: Colors.grey.withAlpha(100), borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Row(
                      children: [
                        Icon(Icons.document_scanner_rounded, color: AppTokens.primary, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'AI Số Hóa Sách Giáo Khoa Mới',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Dán văn bản bài đọc từ sách mới, AI sẽ tự động bóc tách thành Cấu trúc bài đọc, Từ vựng IPA và Bộ câu hỏi trắc nghiệm.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: rawTextCtrl,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Dán văn bản SGK cần số hóa...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (isProcessing)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () async {
                            if (rawTextCtrl.text.trim().isEmpty) return;
                            setSheetState(() => isProcessing = true);
                            final res = await RbacProctorAiService.instance.digitizeCurriculumWithAi(
                              unitNumber: _selectedUnitNumber,
                              title: 'Unit $_selectedUnitNumber: ${_currentLesson.unitTitle}',
                              rawText: rawTextCtrl.text.trim(),
                            );
                            setSheetState(() {
                              isProcessing = false;
                              digitizedResult = res;
                            });
                          },
                          icon: const Icon(Icons.auto_awesome_rounded),
                          label: const Text('Bắt Đầu Số Hóa Tự Động Bằng AI'),
                        ),
                      ),
                    if (digitizedResult != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTokens.success.withAlpha(20),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTokens.success.withAlpha(60)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('🎉 Đã số hóa thành công:', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTokens.success)),
                            const SizedBox(height: 4),
                            Text('• Từ vựng bóc tách: ${(digitizedResult!['vocabulary'] as List).length} từ kèm IPA'),
                            Text('• Câu hỏi trắc nghiệm: ${(digitizedResult!['questions'] as List).length} câu kèm giải nghĩa'),
                            const SizedBox(height: 8),
                            FilledButton.tonal(
                              onPressed: () async {
                                final vocabs = digitizedResult!['vocabulary'] as List? ?? [];
                                final batchWords = <Word>[];
                                for (int i = 0; i < vocabs.length; i++) {
                                  final v = Map<String, dynamic>.from(vocabs[i] as Map);
                                  final eng = (v['english'] ?? '').toString().trim();
                                  if (eng.isEmpty) continue;
                                  batchWords.add(Word(
                                    id: 'w_u${_selectedUnitNumber}_${DateTime.now().millisecondsSinceEpoch}_$i',
                                    topicId: 't$_selectedUnitNumber',
                                    grade: 12,
                                    english: eng,
                                    ipa: (v['ipa'] ?? '/$eng/').toString(),
                                    meaningVi: (v['meaningVi'] ?? '').toString(),
                                    example: (v['example'] ?? '').toString(),
                                  ));
                                }
                                if (batchWords.isNotEmpty) {
                                  await _repo.insertWords(batchWords);
                                }
                                if (ctx.mounted) Navigator.pop(ctx);
                                _loadQuestionsForUnit();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Đã lưu nội dung số hóa: ${batchWords.length} từ vựng và câu hỏi vào Unit $_selectedUnitNumber!')),
                                  );
                                }
                              },
                              child: const Text('Áp dụng vào Unit này'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF162032) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final textMain = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSub = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final lesson = _currentLesson;
    final totalWords = lesson.paragraphs.fold<int>(0, (sum, p) => sum + p.text.split(' ').length);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sách giáo khoa lớp 12', style: TextStyle(fontSize: 12, color: textSub, fontWeight: FontWeight.w600)),
                Text('Quản Lý Học Liệu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textMain)),
              ],
            ),
            Row(
              children: [
                IconButton(
                  tooltip: 'Số hóa sách AI',
                  onPressed: _showAiDigitizerDialog,
                  icon: const Icon(Icons.document_scanner_rounded, color: AppTokens.primary),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _showCreateQuestionDialog(),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Soạn câu hỏi', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Bộ chọn 10 Unit chuẩn SGK Global Success 12
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 10,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (ctx, idx) {
              final uNum = idx + 1;
              final isSel = uNum == _selectedUnitNumber;
              return ChoiceChip(
                label: Text('Unit $uNum'),
                selected: isSel,
                onSelected: (_) {
                  setState(() => _selectedUnitNumber = uNum);
                  _loadQuestionsForUnit();
                },
              );
            },
          ),
        ),
        const SizedBox(height: 8),

        // Bộ chọn Phân môn (Reading, Language, Speaking...)
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _sections.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (ctx, idx) {
              final sec = _sections[idx];
              final isSel = sec == _selectedSection;
              return FilterChip(
                label: Text(sec, style: const TextStyle(fontSize: 11.5)),
                selected: isSel,
                onSelected: (_) => setState(() => _selectedSection = sec),
              );
            },
          ),
        ),
        const SizedBox(height: 14),

        // Thẻ thông tin Bài đọc & Từ vựng của Unit hiện tại
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Unit $_selectedUnitNumber: ${lesson.unitTitle}',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: textMain),
              ),
              const SizedBox(height: 4),
              Text(
                'Bài: ${lesson.lessonTitle} • ${lesson.textbookSource}',
                style: TextStyle(fontSize: 12, color: textSub),
              ),
              const Divider(height: 20),

              // Module Bài đọc
              Row(
                children: [
                  const Icon(Icons.menu_book_rounded, color: AppTokens.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bài đọc (Reading Passage)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: textMain)),
                        Text('${lesson.paragraphs.length} đoạn văn • $totalWords từ chuẩn SGK', style: TextStyle(fontSize: 11.5, color: textSub)),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () {
                      _showParagraphsViewer(lesson);
                    },
                    child: const Text('Xem & Sửa', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Module Từ vựng
              Row(
                children: [
                  const Icon(Icons.spellcheck_rounded, color: Color(0xFF059669), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Từ vựng trọng tâm', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: textMain)),
                        Text('${lesson.vocabulary.length} từ vựng kèm phiên âm IPA', style: TextStyle(fontSize: 11.5, color: textSub)),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () {
                      _showVocabularyViewer(lesson);
                    },
                    child: const Text('Xem & Sửa', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Danh sách Câu hỏi (từ SQLite và Backend)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Ngân hàng Câu hỏi (${_questions.length} câu)',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: textMain),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              onPressed: _loadQuestionsForUnit,
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (_isLoadingQuestions)
          const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
        else if (_questions.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                const Icon(Icons.quiz_outlined, size: 36, color: Colors.grey),
                const SizedBox(height: 8),
                Text('Chưa có câu hỏi riêng cho Unit $_selectedUnitNumber', style: TextStyle(color: textSub, fontSize: 13)),
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  onPressed: () => _showCreateQuestionDialog(),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Soạn câu hỏi đầu tiên'),
                ),
              ],
            ),
          )
        else
          ..._questions.map((q) {
            final options = (q['options'] as List?) ?? [];
            final correctIdx = (q['correctIndex'] as num?)?.toInt() ?? 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTokens.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          (q['skill'] ?? 'Trắc nghiệm').toString().toUpperCase(),
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppTokens.primary),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Độ khó: ${q['difficulty'] ?? 2}',
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF059669)),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () => _showCreateQuestionDialog(editItem: q),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTokens.danger),
                        onPressed: () async {
                          final sm = ScaffoldMessenger.of(context);
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (dCtx) => AlertDialog(
                              title: const Text('Xác nhận xóa câu hỏi'),
                              content: const Text('Bạn có chắc chắn muốn xóa câu hỏi này khỏi ngân hàng câu hỏi không?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Hủy')),
                                FilledButton(
                                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                  onPressed: () => Navigator.pop(dCtx, true),
                                  child: const Text('Xóa'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await RbacProctorAiService.instance.deleteTeacherQuestion(q['id'].toString());
                            _loadQuestionsForUnit();
                            if (mounted) {
                              sm.showSnackBar(
                                const SnackBar(content: Text('Đã xóa câu hỏi khỏi ngân hàng đề!')),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    (q['stem'] ?? '').toString(),
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: textMain),
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(options.length, (i) {
                    final isAns = i == correctIdx;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(
                            isAns ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                            size: 14,
                            color: isAns ? AppTokens.success : Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${String.fromCharCode(65 + i)}. ${options[i]}',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: isAns ? FontWeight.w800 : FontWeight.w500,
                                color: isAns ? AppTokens.success : textMain,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  if ((q['explanation'] ?? '').toString().isNotEmpty) ...[
                    const Divider(height: 14),
                    Text(
                      '💡 Lời giải: ${q['explanation']}',
                      style: TextStyle(fontSize: 12, color: textSub, fontStyle: FontStyle.italic),
                    ),
                  ],
                ],
              ),
            );
          }),
        const SizedBox(height: 24),
      ],
    );
  }

  // ===========================================================================
  // QUẢN LÝ BÀI ĐỌC (XEM, THÊM, SỬA, XÓA ĐOẠN VĂN & LƯU VÀO DATABASE)
  // ===========================================================================
  Future<void> _showParagraphsViewer(TrialLessonData lesson) async {
    final customRaw = await _repo.getSetting('custom_reading_unit_$_selectedUnitNumber');
    List<Map<String, dynamic>> paragraphsList = [];
    if (customRaw != null && customRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(customRaw) as List;
        paragraphsList = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {}
    }
    if (paragraphsList.isEmpty) {
      paragraphsList = lesson.paragraphs.map((p) => {
        'label': p.label,
        'text': p.text,
        'translation': p.translation,
      }).toList();
    }

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            void showEditParagraphDialog({int? index}) {
              final isEdit = index != null;
              final pItem = isEdit ? paragraphsList[index] : null;
              final labelCtrl = TextEditingController(text: pItem?['label']?.toString() ?? 'Đoạn ${paragraphsList.length + 1}');
              final textCtrl = TextEditingController(text: pItem?['text']?.toString() ?? '');
              final transCtrl = TextEditingController(text: pItem?['translation']?.toString() ?? '');

              showDialog(
                context: ctx,
                builder: (dCtx) => AlertDialog(
                  title: Text(isEdit ? 'Chỉnh sửa đoạn văn' : 'Thêm đoạn văn mới'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: labelCtrl,
                          decoration: const InputDecoration(labelText: 'Tên đoạn (VD: Đoạn 1, Paragraph A)', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: textCtrl,
                          maxLines: 5,
                          decoration: const InputDecoration(labelText: 'Nội dung tiếng Anh chuẩn SGK', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: transCtrl,
                          maxLines: 4,
                          decoration: const InputDecoration(labelText: 'Bản dịch tiếng Việt', border: OutlineInputBorder()),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Hủy')),
                    FilledButton(
                      onPressed: () async {
                        if (textCtrl.text.trim().isEmpty) return;
                        setSheetState(() {
                          final item = {
                            'label': labelCtrl.text.trim(),
                            'text': textCtrl.text.trim(),
                            'translation': transCtrl.text.trim(),
                          };
                          if (isEdit) {
                            paragraphsList[index] = item;
                          } else {
                            paragraphsList.add(item);
                          }
                        });
                        final sm = ScaffoldMessenger.of(context);
                        await _repo.setSetting('custom_reading_unit_$_selectedUnitNumber', jsonEncode(paragraphsList));
                        if (dCtx.mounted) Navigator.pop(dCtx);
                        if (mounted) {
                          sm.showSnackBar(
                            SnackBar(content: Text('Đã cập nhật ${labelCtrl.text.trim()}!')),
                          );
                        }
                      },
                      child: Text(isEdit ? 'Cập nhật' : 'Thêm đoạn'),
                    ),
                  ],
                ),
              );
            }

            return Container(
              height: MediaQuery.of(ctx).size.height * 0.88,
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
                      const Icon(Icons.menu_book_rounded, color: AppTokens.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bài đọc Unit $_selectedUnitNumber: ${lesson.unitTitle}',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${paragraphsList.length} đoạn văn • Quản trị toàn quyền Thêm, Sửa, Xóa',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
                          onPressed: () => showEditParagraphDialog(),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Thêm đoạn văn mới'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: paragraphsList.isEmpty
                        ? const Center(child: Text('Chưa có đoạn văn nào trong bài đọc này.'))
                        : ListView.separated(
                            itemCount: paragraphsList.length,
                            separatorBuilder: (_, _) => const Divider(height: 20),
                            itemBuilder: (ctx, idx) {
                              final p = paragraphsList[idx];
                              return Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.grey[200]!),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            (p['label'] ?? 'Đoạn ${idx + 1}').toString(),
                                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A), fontSize: 13.5),
                                          ),
                                          Row(
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                                                onPressed: () => showEditParagraphDialog(index: idx),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                                onPressed: () async {
                                                  setSheetState(() => paragraphsList.removeAt(idx));
                                                  await _repo.setSetting('custom_reading_unit_$_selectedUnitNumber', jsonEncode(paragraphsList));
                                                },
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text((p['text'] ?? '').toString(), style: const TextStyle(fontSize: 13, height: 1.45)),
                                      if ((p['translation'] ?? '').toString().isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text('Dịch: ${p['translation']}', style: const TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // QUẢN LÝ TỪ VỰNG TRỌNG TÂM (XEM, THÊM, SỬA, XÓA TRỰC TIẾP TRONG DATABASE SQLITE)
  // ===========================================================================
  Future<void> _showVocabularyViewer(TrialLessonData lesson) async {
    final topicId = 't$_selectedUnitNumber';
    List<Word> words = await _repo.getWordsByTopicId(topicId);

    // Nếu database chưa có từ vựng cho unit này, khởi tạo từ lesson default
    if (words.isEmpty && lesson.vocabulary.isNotEmpty) {
      final initialWords = <Word>[];
      int i = 0;
      for (final e in lesson.vocabulary.entries) {
        initialWords.add(Word(
          id: 'w_u${_selectedUnitNumber}_${DateTime.now().millisecondsSinceEpoch}_$i',
          topicId: topicId,
          grade: 12,
          english: e.key,
          ipa: '/${e.key}/',
          meaningVi: e.value,
          example: 'Steve Jobs was an innovator.',
        ));
        i++;
      }
      await _repo.insertWords(initialWords);
      words = await _repo.getWordsByTopicId(topicId);
    }

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            void showWordEditDialog({Word? editWord}) {
              final sm = ScaffoldMessenger.of(ctx);
              final isEdit = editWord != null;
              final engCtrl = TextEditingController(text: editWord?.english ?? '');
              final ipaCtrl = TextEditingController(text: editWord?.ipa ?? '');
              final meaningCtrl = TextEditingController(text: editWord?.meaningVi ?? '');
              final exCtrl = TextEditingController(text: editWord?.example ?? '');

              showDialog(
                context: ctx,
                builder: (dCtx) => AlertDialog(
                  title: Text(isEdit ? 'Chỉnh sửa từ vựng' : 'Thêm từ vựng mới vào Unit $_selectedUnitNumber'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: engCtrl,
                          decoration: const InputDecoration(labelText: 'Từ tiếng Anh (English)', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: ipaCtrl,
                          decoration: const InputDecoration(labelText: 'Phiên âm IPA (VD: /ˈæksəbl/)', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: meaningCtrl,
                          decoration: const InputDecoration(labelText: 'Nghĩa tiếng Việt', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: exCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(labelText: 'Câu ví dụ tiếng Anh', border: OutlineInputBorder()),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Hủy')),
                    FilledButton(
                      onPressed: () async {
                        final eng = engCtrl.text.trim();
                        final meaning = meaningCtrl.text.trim();
                        if (eng.isEmpty || meaning.isEmpty) return;

                        if (isEdit) {
                          final updated = editWord.copyWith(
                            english: eng,
                            ipa: ipaCtrl.text.trim().isEmpty ? '/$eng/' : ipaCtrl.text.trim(),
                            meaningVi: meaning,
                            example: exCtrl.text.trim(),
                          );
                          await _repo.updateWord(updated);
                        } else {
                          final newWord = Word(
                            id: 'w_u${_selectedUnitNumber}_${DateTime.now().millisecondsSinceEpoch}',
                            topicId: topicId,
                            grade: 12,
                            english: eng,
                            ipa: ipaCtrl.text.trim().isEmpty ? '/$eng/' : ipaCtrl.text.trim(),
                            meaningVi: meaning,
                            example: exCtrl.text.trim(),
                          );
                          await _repo.insertWord(newWord);
                        }

                        final updatedList = await _repo.getWordsByTopicId(topicId);
                        setSheetState(() => words = updatedList);
                        if (dCtx.mounted) Navigator.pop(dCtx);

                        if (mounted) {
                          sm.showSnackBar(
                            SnackBar(content: Text(isEdit ? 'Đã cập nhật từ "$eng"!' : 'Đã thêm từ mới "$eng" vào Unit $_selectedUnitNumber!')),
                          );
                        }
                      },
                      child: Text(isEdit ? 'Cập nhật' : 'Thêm từ'),
                    ),
                  ],
                ),
              );
            }

            return Container(
              height: MediaQuery.of(ctx).size.height * 0.88,
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
                      const Icon(Icons.spellcheck_rounded, color: Color(0xFF059669)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Từ vựng Unit $_selectedUnitNumber: ${lesson.unitTitle}',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${words.length} từ vựng trong cơ sở dữ liệu thật • Thêm, Sửa, Xóa trực tiếp',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)),
                          onPressed: () => showWordEditDialog(),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Thêm từ vựng mới'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: words.isEmpty
                        ? const Center(child: Text('Chưa có từ vựng nào trong Unit này.'))
                        : ListView.separated(
                            itemCount: words.length,
                            separatorBuilder: (_, _) => const Divider(height: 12),
                            itemBuilder: (ctx, idx) {
                              final w = words[idx];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: const Color(0xFF059669).withValues(alpha: 0.12),
                                  child: Text('${idx + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                                ),
                                title: Row(
                                  children: [
                                    Text(w.english, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                    const SizedBox(width: 6),
                                    Text(w.ipa, style: const TextStyle(color: Colors.grey, fontSize: 12.5)),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(w.meaningVi, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                                    if (w.example.isNotEmpty)
                                      Text('VD: ${w.example}', style: TextStyle(fontSize: 11.5, color: Colors.grey[600], fontStyle: FontStyle.italic)),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                                      onPressed: () => showWordEditDialog(editWord: w),
                                      tooltip: 'Sửa từ',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: ctx,
                                          builder: (dCtx) => AlertDialog(
                                            title: const Text('Xác nhận xóa từ vựng'),
                                            content: Text('Bạn có chắc muốn xóa từ "${w.english}" khỏi Unit $_selectedUnitNumber?'),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Hủy')),
                                              FilledButton(
                                                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                                onPressed: () => Navigator.pop(dCtx, true),
                                                child: const Text('Xóa'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          await _repo.deleteWord(w.id);
                                          final updatedList = await _repo.getWordsByTopicId(topicId);
                                          setSheetState(() => words = updatedList);
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Đã xóa từ "${w.english}"!')),
                                            );
                                          }
                                        }
                                      },
                                      tooltip: 'Xóa từ',
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
