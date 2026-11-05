import 'dart:convert';
import 'package:flutter/material.dart';
import '../../data/app_repository.dart';
import '../auth/auth_controller.dart';
import '../theme/app_tokens.dart';
import '../theme/components/app_button.dart';
import 'textbook_screen.dart';
import 'widgets/speaking_practice_widget.dart';

/// Màn hình học số hóa tương tác chuyên sâu cho các kỹ năng SGK 12:
/// Speaking, Writing, Communication & Culture / CLIL, Looking Back & Project.
/// Hỗ trợ dàn ý, gợi ý từ vựng, tiêu chí chấm Rubric, bài mẫu tham khảo,
/// bộ đếm từ và lưu bài làm thực tế vào SQLite theo `ownerId`.
class UnitSkillsScreen extends StatefulWidget {
  final int unitNumber;
  final String unitTitle;
  final String sectionTitle;
  final String subtitle;
  final int startPage;

  const UnitSkillsScreen({
    super.key,
    required this.unitNumber,
    required this.unitTitle,
    required this.sectionTitle,
    required this.subtitle,
    required this.startPage,
  });

  @override
  State<UnitSkillsScreen> createState() => _UnitSkillsScreenState();
}

class _UnitSkillsScreenState extends State<UnitSkillsScreen> {
  final TextEditingController _submissionController = TextEditingController();
  final AppRepository _repository = AppRepository();

  bool _isCompleted = false;
  DateTime? _lastSavedAt;
  bool _isLoadingNote = true;
  bool _showModelText = false;
  final Map<String, bool> _rubricChecklist = {};

  @override
  void initState() {
    super.initState();
    _submissionController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadSavedSubmission();
  }

  @override
  void dispose() {
    _submissionController.dispose();
    super.dispose();
  }

  String _cleanKey(String title) {
    return title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
  }

  Future<String> _getEffectiveOwnerId() async {
    final auth = AuthController.instance;
    if (auth.isAuthenticated && !auth.user.isGuest) {
      return auth.user.id;
    }
    return await _repository.getOrCreateGuestSessionId();
  }

  Future<void> _loadSavedSubmission() async {
    try {
      final ownerId = await _getEffectiveOwnerId();
      final key = 'unit_skill_note_${ownerId}_u${widget.unitNumber}_${_cleanKey(widget.sectionTitle)}';
      final progressKey = 'unit_section_progress_${ownerId}_u${widget.unitNumber}_${_cleanKey(widget.sectionTitle)}';
      final savedJson = await _repository.getSetting(key);
      final currentProgress = await _repository.getSetting(progressKey);

      if (savedJson != null && savedJson.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(savedJson);
        final content = data['text'] as String? ?? '';
        final timeStr = data['updatedAt'] as String?;
        final rubricData = data['rubric'] as Map<String, dynamic>?;

        if (mounted) {
          setState(() {
            _submissionController.text = content;
            _isCompleted = currentProgress == 'completed';
            if (timeStr != null) {
              _lastSavedAt = DateTime.tryParse(timeStr);
            }
            if (rubricData != null) {
              rubricData.forEach((k, v) => _rubricChecklist[k] = v == true);
            }
            _isLoadingNote = false;
          });
          return;
        }
      } else if (mounted) {
        setState(() {
          _isCompleted = currentProgress == 'completed';
          _isLoadingNote = false;
        });
        return;
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoadingNote = false);
    }
  }

  Future<void> _saveDraft() async {
    final text = _submissionController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập bài làm hoặc câu trả lời trước khi lưu.')),
      );
      return;
    }

    try {
      final ownerId = await _getEffectiveOwnerId();
      final now = DateTime.now();
      final key = 'unit_skill_note_${ownerId}_u${widget.unitNumber}_${_cleanKey(widget.sectionTitle)}';
      await _repository.setSetting(
        key,
        jsonEncode({
          'text': text,
          'unitNumber': widget.unitNumber,
          'sectionTitle': widget.sectionTitle,
          'ownerId': ownerId,
          'updatedAt': now.toIso8601String(),
          'rubric': _rubricChecklist,
        }),
      );

      // Nếu chưa completed thì cập nhật tiến độ in_progress
      final progressKey = 'unit_section_progress_${ownerId}_u${widget.unitNumber}_${_cleanKey(widget.sectionTitle)}';
      final current = await _repository.getSetting(progressKey);
      if (current != 'completed') {
        await _repository.setSetting(progressKey, 'in_progress');
      }

      if (!mounted) return;
      setState(() {
        _lastSavedAt = now;
      });

      final timeFormatted = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã lưu bản nháp vào tài khoản lúc $timeFormatted.'),
          backgroundColor: AppTokens.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể lưu bản nháp: $e'), backgroundColor: AppTokens.errorRed),
      );
    }
  }

  Future<void> _completeSection() async {
    final text = _submissionController.text.trim();
    final isWriting = widget.sectionTitle.contains('Writing');
    final wordCount = _countWords(text);

    if (isWriting && wordCount < 30) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bài viết cần tối thiểu 30 từ trước khi xác nhận hoàn thành.'),
          backgroundColor: AppTokens.accentYellow,
        ),
      );
      return;
    }

    if (text.isEmpty && !_rubricChecklist.values.any((v) => v)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng hoàn thành nội dung luyện tập hoặc tự đánh giá trước khi nộp.'),
          backgroundColor: AppTokens.accentYellow,
        ),
      );
      return;
    }

    try {
      final ownerId = await _getEffectiveOwnerId();
      final now = DateTime.now();
      final key = 'unit_skill_note_${ownerId}_u${widget.unitNumber}_${_cleanKey(widget.sectionTitle)}';
      await _repository.setSetting(
        key,
        jsonEncode({
          'text': text,
          'unitNumber': widget.unitNumber,
          'sectionTitle': widget.sectionTitle,
          'ownerId': ownerId,
          'updatedAt': now.toIso8601String(),
          'rubric': _rubricChecklist,
        }),
      );

      final progressKey = 'unit_section_progress_${ownerId}_u${widget.unitNumber}_${_cleanKey(widget.sectionTitle)}';
      await _repository.setSetting(progressKey, 'completed');

      if (!mounted) return;
      setState(() {
        _isCompleted = true;
        _lastSavedAt = now;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Chúc mừng! Bạn đã hoàn thành phần ${widget.sectionTitle}.'),
          backgroundColor: AppTokens.successGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể hoàn thành phần học: $e'), backgroundColor: AppTokens.errorRed),
      );
    }
  }

  Future<void> _markSectionCompleted() async {
    try {
      final ownerId = await _getEffectiveOwnerId();
      final progressKey = 'unit_section_progress_${ownerId}_u${widget.unitNumber}_${_cleanKey(widget.sectionTitle)}';
      await _repository.setSetting(progressKey, 'completed');
      if (mounted) {
        setState(() => _isCompleted = true);
      }
    } catch (_) {}
  }

  Future<void> _openTextbookOriginal() async {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const TextbookScreen(),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể tải trang in SGK. Vui lòng thử lại.')),
      );
    }
  }

  int _countWords(String text) {
    if (text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).length;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final skill = _getStructuredSkillData();
    final isWriting = widget.sectionTitle.contains('Writing');
    final wordCount = _countWords(_submissionController.text);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121620) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E2430) : Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: isDark ? Colors.white : const Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context, _isCompleted),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Unit ${widget.unitNumber}: ${widget.sectionTitle}',
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            Text(
              'SGK trang in ${widget.startPage} • Học tương tác',
              style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Đối chiếu trang sách in gốc',
            icon: const Icon(Icons.menu_book_outlined, color: AppTokens.primary),
            onPressed: _openTextbookOriginal,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoadingNote
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Thẻ Mục tiêu kỹ năng
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E2430) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(skill.icon, color: AppTokens.primary, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                skill.goalTitle,
                                style: TextStyle(
                                  fontFamily: 'BeVietnamPro',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                skill.goalDescription,
                                style: TextStyle(fontSize: 12.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569), height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Đề bài và Yêu cầu chuẩn SGK
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF78350F).withAlpha(120) : const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isDark ? const Color(0xFFD97706) : const Color(0xFFFDE68A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.assignment_outlined, size: 18, color: Color(0xFFD97706)),
                            const SizedBox(width: 8),
                            Text(
                              'Đề bài SGK (Task Requirement)',
                              style: const TextStyle(
                                fontFamily: 'BeVietnamPro',
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF92400E),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          skill.taskPrompt,
                          style: TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                            height: 1.4,
                          ),
                        ),
                        if (skill.taskGuidance != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            skill.taskGuidance!,
                            style: const TextStyle(fontSize: 12.5, color: Color(0xFF78350F), height: 1.4),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Khối Thu Âm & Chấm Điểm Luyện Nói AI Tương Tác
                  if (widget.sectionTitle.contains('Speaking')) ...[
                    SpeakingPracticeWidget(
                      title: 'Luyện Nói AI Tương Tác (Speech AI Practice)',
                      description: 'Nói theo các câu mẫu hội thoại SGK 12 bên dưới. AI sẽ tự động chấm điểm phát âm, phát hiện từ sai và gợi ý sửa.',
                      prompts: _getSpeakingPromptsForUnit(widget.unitNumber),
                      onPracticeCompleted: (score, data) {
                        if (!_isCompleted) {
                          _markSectionCompleted();
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Dàn ý gợi ý & Mẫu câu Useful Expressions
                  if (skill.outline != null || skill.usefulLanguage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (skill.outline != null) ...[
                            const Row(
                              children: [
                                Icon(Icons.format_list_numbered_rounded, size: 18, color: AppTokens.primary),
                                SizedBox(width: 8),
                                Text(
                                  'Dàn ý cấu trúc chuẩn (Outline)',
                                  style: TextStyle(
                                    fontFamily: 'BeVietnamPro',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              skill.outline!,
                              style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155), height: 1.5),
                            ),
                            if (skill.usefulLanguage != null) const Divider(height: 20, color: Color(0xFFE2E8F0)),
                          ],
                          if (skill.usefulLanguage != null) ...[
                            const Row(
                              children: [
                                Icon(Icons.lightbulb_outline_rounded, size: 18, color: Color(0xFFD97706)),
                                SizedBox(width: 8),
                                Text(
                                  'Mẫu câu hữu ích (Useful Expressions)',
                                  style: TextStyle(
                                    fontFamily: 'BeVietnamPro',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              skill.usefulLanguage!,
                              style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155), height: 1.5),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Bài mẫu tham khảo biên soạn (Có nhãn rõ ràng)
                  if (skill.modelText != null) ...[
                    Card(
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          initiallyExpanded: _showModelText,
                          onExpansionChanged: (val) => setState(() => _showModelText = val),
                          leading: const Icon(Icons.menu_book_rounded, color: AppTokens.primary, size: 20),
                          title: const Text(
                            'Bài mẫu tham khảo (Model Text)',
                            style: TextStyle(
                              fontFamily: 'BeVietnamPro',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          subtitle: const Text(
                            'Bản tham khảo do ứng dụng biên soạn (Không phải đáp án chính thức)',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                              child: Text(
                                skill.modelText!,
                                style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Khu vực Soạn thảo bài làm & Bộ đếm từ
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.edit_note_rounded, size: 20, color: AppTokens.primary),
                            const SizedBox(width: 8),
                            Text(
                              isWriting ? 'Bài viết của bạn (Your Writing)' : 'Ghi chép bài làm & Luyện tập',
                              style: const TextStyle(
                                fontFamily: 'BeVietnamPro',
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const Spacer(),
                            if (isWriting)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: (wordCount >= 150 && wordCount <= 180)
                                      ? const Color(0xFFE6F7F0)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '$wordCount / 150-180 từ',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: (wordCount >= 150 && wordCount <= 180)
                                        ? AppTokens.successGreen
                                        : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _submissionController,
                          maxLines: 10,
                          minLines: 5,
                          style: const TextStyle(fontSize: 13.5, height: 1.5, color: Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            hintText: isWriting
                                ? 'Soạn bài viết luận (150-180 từ) theo yêu cầu đề bài trên...'
                                : 'Ghi lại các ý chính, câu trả lời hoặc kịch bản luyện nói của bạn...',
                            hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppTokens.primary, width: 1.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Bảng Rubric tự đánh giá
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.checklist_rounded, size: 18, color: AppTokens.primary),
                            SizedBox(width: 8),
                            Text(
                              'Tiêu chí tự đánh giá (Self-check Rubric)',
                              style: TextStyle(
                                fontFamily: 'BeVietnamPro',
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...skill.rubricCriteria.map((crit) {
                          final isChecked = _rubricChecklist[crit] ?? false;
                          return CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(
                              crit,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: isChecked ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                fontWeight: isChecked ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                            value: isChecked,
                            activeColor: AppTokens.primary,
                            onChanged: (val) {
                              setState(() {
                                _rubricChecklist[crit] = val == true;
                              });
                            },
                          );
                        }),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (_isCompleted) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6F7F0),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTokens.successGreen.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: AppTokens.successGreen, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Phần học này đã được xác nhận hoàn thành.',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Nút Lưu bản nháp & Hoàn thành bài làm
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: 'Lưu bản nháp',
                          icon: Icons.save_as_outlined,
                          variant: AppButtonVariant.secondary,
                          isFullWidth: true,
                          onPressed: _saveDraft,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppButton(
                          label: _isCompleted ? 'Cập nhật hoàn thành' : 'Hoàn thành bài',
                          icon: Icons.check_circle_outline_rounded,
                          variant: AppButtonVariant.primary,
                          isFullWidth: true,
                          onPressed: _completeSection,
                        ),
                      ),
                    ],
                  ),

                  if (_lastSavedAt != null) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Đã lưu lúc ${_lastSavedAt!.hour.toString().padLeft(2, '0')}:${_lastSavedAt!.minute.toString().padLeft(2, '0')} ngày ${_lastSavedAt!.day}/${_lastSavedAt!.month}/${_lastSavedAt!.year}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  _SkillStructuredData _getStructuredSkillData() {
    final title = widget.sectionTitle;
    final u = widget.unitNumber;

    if (title.contains('Speaking')) {
      return _getSpeakingData(u);
    } else if (title.contains('Writing')) {
      return _getWritingData(u);
    } else if (title.contains('CLIL') || title.contains('Culture')) {
      return _getClilData(u);
    } else {
      return _getLookingBackData(u);
    }
  }

  _SkillStructuredData _getWritingData(int u) {
    switch (u) {
      case 1:
        return _SkillStructuredData(
          icon: Icons.edit_note_rounded,
          goalTitle: 'Viết tiểu sử một danh nhân (A Biography)',
          goalDescription: 'Viết bài luận 150-180 từ kể về cuộc đời, sự nghiệp và cống hiến của Walt Disney.',
          taskPrompt: 'Write a biography (150-180 words) of Walt Disney, using the timeline and notes provided on page 15 of your textbook.',
          taskGuidance: 'Sử dụng thì quá khứ đơn (Past Simple) làm thì chủ đạo, kết hợp quá khứ tiếp diễn khi mô tả hoàn cảnh bối cảnh.',
          outline: '1. Mở bài (Introduction): Giới thiệu tên, năm sinh - mất và lý do nhân vật được ngưỡng mộ.\n'
              '2. Thân bài 1 (Early Life & Career): Tuổi thơ, những thất bại ban đầu và quyết định chuyển đến Hollywood.\n'
              '3. Thân bài 2 (Major Achievements): Sự ra đời của Chuột Mickey, phim Bạch Tuyết và công viên Disneyland.\n'
              '4. Kết bài (Legacy): Kỷ lục 26 giải Oscar và nguồn cảm hứng bất tận để lại cho nhân loại.',
          usefulLanguage: '• "Walt Disney was born in 1901 in Chicago..."\n'
              '• "He showed a great talent for drawing and animation from an early age."\n'
              '• "His determination helped him overcome bankruptcy and create..."\n'
              '• "He holds the record for winning the most Oscars in history."',
          modelText: 'Walt Disney was one of the most influential figures in the global entertainment industry. Born in 1901 in Chicago, he displayed a remarkable talent for drawing and painting during his childhood. After his early animation business in Kansas went bankrupt, he moved to Hollywood in 1923 to start afresh with his brother Roy.\n\nIn 1928, Disney created Mickey Mouse, which quickly became an international sensation. He continued to break new ground by releasing Snow White and the Seven Dwarfs in 1937, the first full-length animated movie in history. Later, in 1955, he opened Disneyland in California, creating a magical wonderland for millions of families worldwide.\n\nDuring his illustrious career, Walt Disney won an extraordinary total of 26 Oscars, a record that remains unbeaten today. He passed away in 1966, but his boundless creativity, perseverance, and dedication continue to inspire generations of artists and storytellers around the world.',
          rubricCriteria: [
            'Đáp ứng đúng dung lượng yêu cầu (150-180 từ).',
            'Đầy đủ 4 phần: Mở bài, Thời niên thiếu, Thành tựu nổi bật, Kết luận di sản.',
            'Sử dụng chuẩn xác thì Quá khứ đơn (Past Simple) và liên từ thời gian.',
            'Từ vựng phong phú, không mắc lỗi chính tả cơ bản.',
          ],
        );
      case 2:
        return _SkillStructuredData(
          icon: Icons.edit_note_rounded,
          goalTitle: 'Viết bài văn nghị luận về lễ hội quốc tế (Opinion Essay)',
          goalDescription: 'Nêu quan điểm (150-180 từ) về tác động của các lễ hội quốc tế (Halloween, Giáng sinh...) đối với giới trẻ Việt Nam.',
          taskPrompt: 'Write an opinion essay (150-180 words) discussing whether celebrating world festivals has positive or negative impacts on young Vietnamese people.',
          outline: '1. Introduction: Giới thiệu xu hướng giới trẻ đón nhận các lễ hội quốc tế; nêu rõ quan điểm cá nhân.\n'
              '2. Body Paragraph 1: Các lợi ích tích cực (mở mang kiến thức văn hóa, gắn kết bạn bè, thư giãn).\n'
              '3. Body Paragraph 2: Thách thức tiềm ẩn (tiêu tốn chi phí, nguy cơ xao nhãng lễ hội truyền thống).\n'
              '4. Conclusion: Khẳng định sự cần thiết của việc đón nhận cởi mở đi đôi với bảo tồn bản sắc.',
          usefulLanguage: '• "Nowadays, an increasing number of young people celebrate world festivals..."\n'
              '• "In my opinion, this cultural trend brings far more benefits than drawbacks."\n'
              '• "First and foremost, it allows students to gain a deeper insight into global diversity."\n'
              '• "However, it is crucial that we never neglect our own cultural heritage."',
          modelText: 'Nowadays, celebrating international festivals such as Halloween and Christmas has become increasingly popular among young Vietnamese people. In my opinion, this cultural trend brings several significant benefits, provided that it is approached in a balanced and responsible manner.\n\nFirst and foremost, participating in global festivals offers students a wonderful opportunity to learn about other cultures and traditions firsthand. It broadens their horizons and fosters cultural empathy in an interconnected world. Moreover, these celebrations provide a joyful atmosphere for friends and families to gather, engage in creative activities, and relieve academic stress after long hours of study.\n\nNevertheless, young people must be mindful not to overspend money or allow commercialised foreign celebrations to overshadow meaningful local traditions like the Mid-Autumn Festival or Tet. In conclusion, embracing world festivals enriches our lives, as long as we continue to cherish and preserve our unique Vietnamese cultural identity.',
          rubricCriteria: [
            'Đạt dung lượng 150-180 từ.',
            'Có câu chủ đề (Thesis statement) nêu rõ quan điểm.',
            'Sử dụng các từ nối lập luận (First and foremost, Moreover, Nevertheless, In conclusion).',
            'Ngữ pháp câu phức và từ vựng về chủ đề văn hóa chuẩn xác.',
          ],
        );
      case 3:
        return _SkillStructuredData(
          icon: Icons.edit_note_rounded,
          goalTitle: 'Viết bài báo về lối sống xanh trong trường học (Article on Green Living)',
          goalDescription: 'Viết bài báo 150-180 từ gợi ý các giải pháp thiết thực để biến trường học thành một môi trường xanh, không rác thải nhựa.',
          taskPrompt: 'Write an article (150-180 words) for your school newsletter suggesting practical ways students can adopt a greener lifestyle at school.',
          taskGuidance: 'Sử dụng các từ chỉ nguyên nhân - kết quả (as a result, consequently) và các động từ khuyết thiếu (should, ought to, must).',
          outline: '1. Tiêu đề hấp dẫn (Catchy Title) & Giới thiệu thực trạng rác thải tại trường học.\n'
              '2. Biện pháp 1: Giảm thiểu rác thải nhựa (dùng bình nước cá nhân, hộp cơm tái sử dụng).\n'
              '3. Biện pháp 2: Tiết kiệm năng lượng & Tham gia phong trào xanh (tắt thiết bị điện, trồng cây xanh).\n'
              '4. Kết luận: Lời kêu gọi hành động chung tay bảo vệ môi trường học đường.',
          usefulLanguage: '• "Small actions can make a huge difference to our environment..."\n'
              '• "First, students should replace single-use plastic bottles with reusable ones."\n'
              '• "In addition, turning off unnecessary lights and air conditioners helps save electricity."\n'
              '• "Let us take action today to build a cleaner and greener school for tomorrow."',
          modelText: 'Small everyday habits can make a dramatic difference in making our school a greener place. As high school students, we have the responsibility to protect our surroundings and reduce our environmental footprint.\n\nFirst and foremost, students should eliminate single-use plastic items from their daily routine. Bringing a personal reusable water bottle and cloth lunch containers significantly reduces the amount of plastic rubbish accumulating in our school bins. Furthermore, plastic takes hundreds of years to decompose, so minimizing plastic waste is an urgent priority.\n\nSecondly, saving energy inside classrooms must become a shared habit. Everyone should remember to switch off lights, fans, and projectors when leaving the room. Organising weekly cleanup campaigns and planting more potted flowers on balconies will also enhance air quality and create a pleasant study atmosphere.\n\nIn conclusion, building an eco-friendly school does not require grand gestures, but persistent individual commitment. Let us act together today to preserve our green future.',
          rubricCriteria: [
            'Đủ dung lượng yêu cầu (150-180 từ).',
            'Cấu trúc bài báo rõ ràng (Tiêu đề, Giới thiệu, 2 giải pháp, Lời kêu gọi).',
            'Vận dụng tốt từ vựng Unit 3 (carbon footprint, single-use, eco-friendly, decompose).',
            'Ngữ pháp mạch lạc và liên kết câu chặt chẽ.',
          ],
        );
      case 4:
        return _SkillStructuredData(
          icon: Icons.edit_note_rounded,
          goalTitle: 'Viết bài văn phân tích thách thức của đô thị hóa (Problem-Solution Essay)',
          goalDescription: 'Viết bài văn 150-180 từ thảo luận các vấn đề phát sinh từ quá trình đô thị hóa nhanh và đề xuất giải pháp phù hợp.',
          taskPrompt: 'Write an essay (150-180 words) discussing the problems caused by rapid urbanisation in big cities and suggesting potential solutions.',
          taskGuidance: 'Trình bày rõ ràng mối liên hệ giữa các vấn đề (tắc nghẽn giao thông, thiếu nhà ở) và các giải pháp tương ứng (giao thông công cộng, quy hoạch đô thị thông minh).',
          outline: '1. Introduction: Giới thiệu làn sóng đô thị hóa nhanh chóng tại các đô thị lớn.\n'
              '2. Body 1 (Problems): Tắc đường nghiêm trọng, ô nhiễm không khí và áp lực nhà ở quá tải.\n'
              '3. Body 2 (Solutions): Phát triển hệ thống tàu điện/xe buýt điện và giãn dân ra các đô thị vệ tinh.\n'
              '4. Conclusion: Khẳng định sự cần thiết của quy hoạch bền vững để nâng cao chất lượng cuộc sống.',
          usefulLanguage: '• "Rapid urbanisation has transformed rural areas into booming metropolises..."\n'
              '• "However, this phenomenon has led to severe traffic congestion and air pollution."\n'
              '• "To tackle these challenges, local authorities ought to invest heavily in mass transit systems."\n'
              '• "In summary, sustainable urban development is key to ensuring a high quality of life."',
          modelText: 'Rapid urbanisation has turned many rural regions into booming metropolises across the country. While this transformation offers abundant employment opportunities and modern services, it also brings severe challenges that demand immediate attention.\n\nOne of the most pressing issues is catastrophic traffic congestion and air pollution. During rush hours, hundreds of thousands of vehicles flood narrow streets, releasing toxic fumes that threaten public health. Additionally, rapid population influx causes acute housing shortages and strains public healthcare and educational facilities.\n\nTo address these difficulties effectively, city authorities must take proactive measures. First, investing in green public transit, such as electric buses and urban railways, will encourage commuters to leave their motorbikes at home. Moreover, designing satellite towns with complete infrastructure can help decentralize the population and ease the burden on city centres.\n\nIn summary, while urbanisation is an inevitable trend, implementing smart and sustainable urban planning is vital to ensuring a prosperous future for all citizens.',
          rubricCriteria: [
            'Đạt dung lượng yêu cầu 150-180 từ.',
            'Bố cục bài viết gồm Mở bài, Thực trạng vấn đề, Giải pháp khả thi, Kết luận.',
            'Dùng chính xác từ vựng chủ đề Đô thị hóa (metropolis, traffic congestion, satellite town, sustainable).',
            'Chính tả và cấu trúc câu phức chuẩn xác.',
          ],
        );
      case 5:
        return _SkillStructuredData(
          icon: Icons.edit_note_rounded,
          goalTitle: 'Viết thư ứng tuyển công việc thực tập hoặc làm thêm (Job Application Letter)',
          goalDescription: 'Viết một bức thư ứng tuyển 150-180 từ nộp đơn xin việc làm thêm hoặc vị trí tình nguyện viên hè phù hợp với học sinh lớp 12.',
          taskPrompt: 'Write a formal letter of application (150-180 words) for a summer internship or part-time position advertised in a local community organisation.',
          taskGuidance: 'Sử dụng văn phong trang trọng (formal register), lời chào và kết thư chuẩn quy tắc (Dear Sir/Madam, Yours faithfully).',
          outline: '1. Lời chào & Lý do viết thư (Nêu rõ vị trí ứng tuyển và nơi biết thông tin).\n'
              '2. Trình độ học vấn & Phẩm chất phù hợp (Kỹ năng giao tiếp, trách nhiệm, thành tích học tập).\n'
              '3. Kinh nghiệm liên quan & Giá trị có thể đóng góp cho tổ chức.\n'
              '4. Kết thư, đề cập hồ sơ đính kèm và mong muốn được phỏng vấn trực tiếp.',
          usefulLanguage: '• "I am writing to express my enthusiastic interest in the position of..."\n'
              '• "As an energetic and responsible grade 12 student, I possess strong communication skills."\n'
              '• "I have previously participated in various extracurricular activities and school clubs."\n'
              '• "I would welcome the chance to attend an interview at your earliest convenience."',
          modelText: 'Dear Hiring Manager,\n\nI am writing to express my enthusiastic interest in the part-time Assistant Coordinator position advertised on your organisation website yesterday. As a dedicated grade 12 student at Le Hong Phong High School, I believe my skills and enthusiasm make me a suitable candidate for this role.\n\nDuring my high school years, I have actively participated in our Youth Union club, where I successfully coordinated several charity fundraisers and volunteer campaigns. These experiences have helped me cultivate excellent teamwork, problem-solving, and bilingual communication skills. Furthermore, I am reliable, punctual, and capable of working under pressure during busy events.\n\nI am confident that my positive attitude and dedication will enable me to make a meaningful contribution to your team this summer. I have attached my curriculum vitae for your consideration, and I would be delighted to attend an interview at your convenience.\n\nThank you very much for your time and consideration.\n\nYours faithfully,\nNguyen Minh Anh',
          rubricCriteria: [
            'Đúng cấu trúc thư xin việc trang trọng (Formal letter format).',
            'Dung lượng 150-180 từ.',
            'Thể hiện rõ kỹ năng, kinh nghiệm và thái độ cầu tiến.',
            'Ngữ pháp trang trọng, không dùng từ viết tắt.',
          ],
        );
      case 6:
        return _SkillStructuredData(
          icon: Icons.edit_note_rounded,
          goalTitle: 'Viết bài luận về tác động của Trí tuệ nhân tạo (AI Opinion Essay)',
          goalDescription: 'Viết bài nghị luận 150-180 từ trình bày quan điểm về những lợi ích và nguy cơ của AI đối với việc học tập của học sinh.',
          taskPrompt: 'Write an opinion essay (150-180 words) expressing your view on whether artificial intelligence (AI) brings more benefits or risks to high school students.',
          taskGuidance: 'Sử dụng các trạng từ liên kết đối lập (On the one hand, On the other hand, Nonetheless) để bài viết có tính khách quan và sắc sảo.',
          outline: '1. Giới thiệu sự bùng nổ của AI trong giáo dục và nêu quan điểm cá nhân.\n'
              '2. Lợi ích: Hỗ trợ học tập cá nhân hóa, tra cứu tài liệu nhanh chóng, giải đáp thắc mắc 24/7.\n'
              '3. Nguy cơ: Sự phụ thuộc quá mức, giảm sút tư duy phản biện và gian lận học thuật.\n'
              '4. Kết luận: AI là công cụ hỗ trợ đắc lực nếu học sinh sử dụng có đạo đức và tỉnh táo.',
          usefulLanguage: '• "Artificial intelligence has rapidly transformed the educational landscape..."\n'
              '• "Undoubtedly, AI-powered tools provide personalized tutoring and instant feedback."\n'
              '• "However, excessive reliance on AI may undermine students critical thinking abilities."\n'
              '• "To conclude, learners must use AI responsibly as a supportive assistant rather than a replacement."',
          modelText: 'The revolutionary rise of artificial intelligence has fundamentally transformed the way students approach education today. In my view, while AI tools offer remarkable advantages for academic study, learners must remain vigilant about their potential risks.\n\nOn the one hand, AI-driven applications serve as brilliant personal tutors that are available round the clock. They can instantly simplify complex scientific concepts, check grammatical accuracy, and generate customized practice exercises tailored to each student’s learning pace. Consequently, students can grasp difficult materials much faster and enhance their independent learning capacity.\n\nOn the other hand, excessive reliance on AI can severely impair students’ critical thinking and creative problem-solving skills. If students routinely copy machine-generated answers without evaluating their truthfulness, they fail to cultivate authentic analytical abilities. Moreover, academic dishonesty might increase significantly.\n\nIn conclusion, artificial intelligence is an extraordinarily powerful instrument when used responsibly. High school students should harness AI to supplement their intellectual curiosity rather than substitute their own effort.',
          rubricCriteria: [
            'Đủ dung lượng quy định (150-180 từ).',
            'Cấu trúc bài văn nghị luận chặt chẽ (2 mặt lợi ích và rủi ro, kết luận cân bằng).',
            'Sử dụng đúng thuật ngữ AI (algorithm, personalized tutor, critical thinking, reliance).',
            'Ngữ pháp và văn phong lập luận học thuật sắc sảo.',
          ],
        );
      case 7:
        return _SkillStructuredData(
          icon: Icons.edit_note_rounded,
          goalTitle: 'Viết bài báo về tác động của Mạng xã hội đối với thanh thiếu niên',
          goalDescription: 'Viết bài báo 150-180 từ phân tích ảnh hưởng của mạng xã hội đối với thói quen học tập và lối sống của học sinh THPT.',
          taskPrompt: 'Write an article (150-180 words) for a teenage magazine discussing the impacts of social media on high school students\' daily lives.',
          outline: '1. Giới thiệu mức độ phổ biến của mạng xã hội trong giới trẻ.\n'
              '2. Tác động tích cực: Kết nối bạn bè, cập nhật tin tức tức thời, tham gia các nhóm học tập.\n'
              '3. Tác động tiêu cực: Mất tập trung, hội chứng sợ bỏ lỡ (FOMO), nguy cơ tiếp nhận tin giả.\n'
              '4. Kết luận: Lời khuyên thiết lập ranh giới số thông minh (digital detox, phân bổ thời gian).',
          usefulLanguage: '• "Social media platforms have become an inseparable part of modern teenage life."\n'
              '• "They provide incredible platforms for sharing creative ideas and forming study groups."\n'
              '• "Nevertheless, spending endless hours scrolling through feeds leads to severe sleep deprivation."\n'
              '• "In conclusion, digital balance is crucial for maintaining mental well-being."',
          modelText: 'Social media platforms have become an inseparable part of modern youth culture, profoundly shaping how teenagers communicate, learn, and entertain themselves. While these virtual networks offer considerable conveniences, their negative repercussions should not be overlooked.\n\nOn the positive side, platforms like Facebook, Instagram, and TikTok allow teenagers to stay connected with peers across geographical borders. They serve as valuable resources for collaborating on school assignments, sharing informative educational videos, and raising awareness about societal causes.\n\nNevertheless, unregulated screen time poses severe risks to adolescent well-being. Excessive scrolling frequently leads to sleep deprivation, poor academic concentration, and psychological distress caused by unrealistic social comparisons. Furthermore, the rapid dissemination of fake news and sensational headlines can easily mislead impressionable young minds.\n\nIn summary, social media is a double-edged sword. Teenagers must cultivate digital literacy and practice self-discipline to reap the benefits of digital connectivity without falling into its addictive traps.',
          rubricCriteria: [
            'Đủ dung lượng (150-180 từ).',
            'Thể hiện góc nhìn cân bằng giữa lợi ích và tác hại.',
            'Từ vựng đa dạng về truyền thông (digital literacy, fake news, double-edged sword).',
            'Liên kết mạch lạc, chuẩn văn phong báo chí giới trẻ.',
          ],
        );
      case 8:
        return _SkillStructuredData(
          icon: Icons.edit_note_rounded,
          goalTitle: 'Viết bài báo cáo về bảo tồn động vật hoang dã nguy cấp (Conservation Report)',
          goalDescription: 'Viết báo cáo 150-180 từ về một loài động vật có nguy cơ tuyệt chủng tại Việt Nam và các biện pháp bảo vệ chúng.',
          taskPrompt: 'Write a report (150-180 words) describing the status of an endangered species in Viet Nam and recommending conservation measures.',
          outline: '1. Giới thiệu loài động vật (Voọc Cát Bà hoặc Sao la, môi trường sống, số lượng còn lại).\n'
              '2. Nguyên nhân đe dọa: Phá rừng mất sinh cảnh, săn trộm trái phép, biến đổi khí hậu.\n'
              '3. Biện pháp bảo tồn: Thiết lập khu bảo tồn nghiêm ngặt, thực thi luật pháp và giáo dục cộng đồng.\n'
              '4. Kết luận: Tầm quan trọng của việc bảo vệ đa dạng sinh học cho các thế hệ tương lai.',
          usefulLanguage: '• "Viet Nam is recognized as one of the world\'s biodiversity hotspots..."\n'
              '• "However, iconic species such as the Cat Ba Langur are hovering on the brink of extinction."\n'
              '• "The primary threats include rampant habitat loss and illegal wildlife poaching."\n'
              '• "Decisive conservation initiatives are vital to ensure their continued survival."',
          modelText: 'Viet Nam is celebrated as one of the world’s most biodiverse nations, yet many of its endemic treasures are hovering on the brink of extinction. Among these critically endangered animals, the Cat Ba Langur is one of the rarest primates on Earth.\n\nCurrently, fewer than eighty individuals remain in the wild, confined to the limestone cliffs of Cat Ba Island. The survival of this majestic species is gravely threatened by habitat fragmentation caused by tourism development, along with past illegal poaching for traditional medicine. The loss of suitable feeding grounds has made their recovery exceptionally difficult.\n\nTo prevent the extinction of the Cat Ba Langur, urgent conservation interventions are indispensable. First, law enforcement must be intensified to eradicate all illegal hunting and trespassing within national park boundaries. Additionally, eco-tourism projects should be carefully regulated to prevent further disturbance to their natural habitats.\n\nIn conclusion, safeguarding our endangered fauna is our moral obligation. Preserving the Cat Ba Langur means preserving our rich ecological heritage.',
          rubricCriteria: [
            'Đúng hình thức bài báo cáo sinh thái học (150-180 từ).',
            'Cung cấp số liệu và thực trạng cụ thể.',
            'Từ vựng phong phú về sinh thái (biodiversity hotspot, brink of extinction, poaching, habitat fragmentation).',
            'Mạch lạc, trang trọng và giàu sức thuyết phục.',
          ],
        );
      case 9:
        return _SkillStructuredData(
          icon: Icons.edit_note_rounded,
          goalTitle: 'Viết thư xin lời khuyên định hướng nghề nghiệp (Letter Asking for Career Advice)',
          goalDescription: 'Viết bức thư 150-180 từ gửi chuyên gia tư vấn hỏi xin lời khuyên về việc nên học đại học hay học nghề sau lớp 12.',
          taskPrompt: 'Write a letter (150-180 words) to a career adviser asking for guidance on whether to pursue higher education or vocational training.',
          outline: '1. Lời chào & Lý do viết thư (Băn khoăn lựa chọn hướng đi sau khi tốt nghiệp THPT).\n'
              '2. Điểm mạnh và sở thích cá nhân (Thích kỹ thuật thực hành, muốn sớm độc lập tài chính).\n'
              '3. Câu hỏi thắc mắc cụ thể về cơ hội việc làm của bằng nghề so với bằng cử nhân.\n'
              '4. Lời cảm ơn và mong muốn nhận được lời khuyên.',
          usefulLanguage: '• "I am currently in my final year of high school and facing a crucial career dilemma."\n'
              '• "I have a strong passion for automotive mechanics and practical problem-solving."\n'
              '• "While my parents encourage me to attend university, I am drawn to vocational colleges."\n'
              '• "I would be deeply grateful if you could share your professional insights on this matter."',
          modelText: 'Dear Mr Kien,\n\nI am currently a twelfth-grade student at Nguyen Khuyen High School, and I am writing to seek your valuable professional guidance regarding my future career trajectory.\n\nWith our graduation exams approaching rapidly, I find myself torn between pursuing a four-year university degree and enrolling in a vocational training institution. Personally, I have a deep fascination with automotive engineering and hands-on technology. I thoroughly enjoy fixing machines and would prefer practical training that enables me to enter the workforce promptly and achieve financial independence.\n\nHowever, my family strongly wishes that I obtain a traditional bachelor’s degree, believing it guarantees greater prestige and managerial prospects. Could you please advise me on the long-term career growth and employment prospects of certified technicians compared to university graduates in today’s evolving job market? Any recommendations regarding top vocational programmes in Ho Chi Minh City would be immensely helpful.\n\nThank you very much for taking the time to read my letter. I look forward to hearing from you.\n\nYours sincerely,\nTran Hoang Nam',
          rubricCriteria: [
            'Cấu trúc thư trang trọng, lịch sự và rõ ràng.',
            'Dung lượng đúng chuẩn (150-180 từ).',
            'Trình bày rõ sở thích, điểm mạnh và thắc mắc định hướng nghề nghiệp.',
            'Từ vựng chủ đề Nghề nghiệp (vocational training, bachelor\'s degree, hands-on, prospects).',
          ],
        );
      case 10:
        return _SkillStructuredData(
          icon: Icons.edit_note_rounded,
          goalTitle: 'Viết bài luận về Tầm quan trọng của Học tập suốt đời (Lifelong Learning Essay)',
          goalDescription: 'Viết bài luận 150-180 từ giải thích tại sao học tập suốt đời là kỹ năng sinh tồn thiết yếu trong kỷ nguyên số.',
          taskPrompt: 'Write an essay (150-180 words) discussing why lifelong learning is vital for personal and professional success in the 21st century.',
          outline: '1. Định nghĩa học tập suốt đời & Khẳng định việc học không kết thúc sau khi rời ghế nhà trường.\n'
              '2. Lý do 1: Sự chuyển dịch công nghệ và thay đổi nhanh chóng của thị trường việc làm (cần liên tục nâng cấp kỹ năng).\n'
              '3. Lý do 2: Phát triển trí não, duy trì sự thích nghi và mở rộng cơ hội cá nhân.\n'
              '4. Kết luận: Cam kết rèn luyện tinh thần tự học bền bỉ.',
          usefulLanguage: '• "In an era of relentless technological disruption, learning is no longer confined to classrooms."\n'
              '• "Continuous upskilling enables professionals to stay competitive in a transforming market."\n'
              '• "Moreover, cultivating intellectual curiosity keeps our minds agile and fulfilled."\n'
              '• "Ultimately, embracing lifelong learning is the surest pathway to lasting fulfillment."',
          modelText: 'In an era characterized by relentless technological transformation, education is no longer a phase confined to our school years. Instead, cultivating a mindset of lifelong learning has become an indispensable requirement for personal fulfillment and professional survival.\n\nFirst and foremost, the modern employment landscape is evolving at an unprecedented velocity. Jobs that exist today may be automated by sophisticated technologies within a decade. Therefore, professionals who proactively upskill and embrace emerging digital tools will maintain a competitive advantage, whereas those who remain complacent risk falling behind.\n\nFurthermore, engaging in lifelong learning enriches our daily lives beyond monetary gains. Whether we choose to acquire a new foreign language, master coding, or explore philosophical literature, acquiring novel knowledge keeps our minds sharp, resilient, and adaptable to life\'s uncertainties.\n\nIn conclusion, education is an enduring journey rather than a fixed destination. By nurturing an insatiable curiosity and an openness to change, young people can confidently navigate the challenges of the twenty-first century.',
          rubricCriteria: [
            'Đủ dung lượng 150-180 từ.',
            'Lập luận sắc bén, giàu tính triết lý và thực tiễn.',
            'Sử dụng chuẩn xác từ vựng nâng cao (technological transformation, upskill, resilient, enduring journey).',
            'Văn phong học thuật chỉn chu, truyền cảm hứng.',
          ],
        );
      default:
        return _SkillStructuredData(
          icon: Icons.edit_note_rounded,
          goalTitle: 'Viết bài luận học thuật Unit $u theo chuẩn SGK Global Success 12',
          goalDescription: 'Thực hiện bài viết học thuật 150-180 từ theo đúng chủ đề và cấu trúc định hướng của Unit $u.',
          taskPrompt: 'Write a structured essay or report (150-180 words) based on the Writing instructions on page ${widget.startPage} of your textbook.',
          outline: '1. Mở bài (Introduction): Nêu bối cảnh và mục đích bài viết.\n'
              '2. Thân bài (Body): 2 đoạn luận điểm kèm dẫn chứng minh họa cụ thể.\n'
              '3. Kết bài (Conclusion): Tóm lược và đưa ra thông điệp hành động.',
          usefulLanguage: '• "It is widely acknowledged that..."\n'
              '• "One of the most compelling arguments is..."\n'
              '• "Furthermore, evidence suggests that..."\n'
              '• "In summary, addressing this issue requires collective efforts."',
          modelText: 'In our rapidly evolving world, the topics explored in Unit $u play a crucial role in shaping our perspective and future career readiness. Developing effective communication and analytical skills is essential for modern high school students.\n\nThrough structured research and practice, learners are encouraged to synthesize key concepts, apply specialized vocabulary, and build coherent arguments supported by credible evidence. This comprehensive approach ensures that academic writing remains both informative and impactful.\n\nUltimately, mastering these foundational writing techniques prepares students to excel in national examinations while fostering a lifelong passion for learning and personal growth.',
          rubricCriteria: [
            'Đủ dung lượng quy định (150-180 từ).',
            'Mạch lạc, có từ nối chuyển ý rõ ràng.',
            'Đúng cấu trúc bài học thuật SGK 12.',
          ],
        );
    }
  }

  _SkillStructuredData _getSpeakingData(int u) {
    switch (u) {
      case 1:
        return _SkillStructuredData(
          icon: Icons.chat_bubble_outline_rounded,
          goalTitle: 'Thuyết trình về các anh hùng dân tộc Việt Nam (National Heroes)',
          goalDescription: 'Luyện nói trong 2-3 phút giới thiệu về cuộc đời và sự cống hiến của Đại tướng Võ Nguyên Giáp hoặc Anh hùng Võ Thị Sáu.',
          taskPrompt: 'Work in pairs. Talk about the life and achievements of a Vietnamese national hero (General Vo Nguyen Giap or Vo Thi Sau), using the cards on page 14.',
          outline: '1. Giới thiệu nhân vật (Tên, năm sinh - mất, quê quán, danh hiệu).\n'
              '2. Cống hiến trong cuộc kháng chiến giành độc lập dân tộc.\n'
              '3. Phẩm chất cao đẹp và bài học truyền cảm hứng cho thế hệ trẻ hôm nay.',
          usefulLanguage: '• "Today, I would like to tell you about General Vo Nguyen Giap..."\n'
              '• "He was born in 1911 in Quang Binh Province and was a brilliant military strategist."\n'
              '• "He led the Vietnamese army to historic victories, including Dien Bien Phu in 1954."\n'
              '• "His courage and devotion have won the admiration of people worldwide."',
          rubricCriteria: [
            'Nói lưu loát, tự tin, phát âm rõ ràng.',
            'Đầy đủ thông tin về năm tháng, sự kiện lịch sử quan trọng.',
            'Sử dụng các cụm từ thể hiện lòng ngưỡng mộ (admire, dedicate, inspire).',
          ],
        );
      case 2:
        return _SkillStructuredData(
          icon: Icons.chat_bubble_outline_rounded,
          goalTitle: 'Thảo luận về các phong tục lễ hội đa văn hóa (Cultural Festivals)',
          goalDescription: 'Luyện nói về các lễ hội độc đáo trên thế giới và chia sẻ trải nghiệm tham gia lễ hội.',
          taskPrompt: 'Work in pairs. Talk about a festival in Viet Nam or around the world that you have experienced or would like to visit.',
          outline: '1. Tên lễ hội, thời gian và địa điểm diễn ra.\n'
              '2. Các hoạt động đặc sắc (ẩm thực, trang phục, nghi lễ, âm nhạc).\n'
              '3. Cảm xúc cá nhân và ý nghĩa giao lưu văn hóa.',
          usefulLanguage: '• "Today, I would like to introduce the Mid-Autumn Festival..."\n'
              '• "People celebrate this special occasion by making colorful lanterns..."\n'
              '• "What impresses me most is the sense of family reunion and gratitude."',
          rubricCriteria: [
            'Nói lưu loát, tự nhiên và đúng chủ đề.',
            'Vận dụng tốt từ vựng lễ hội (lantern, delicacy, celebration, reunion).',
          ],
        );
      case 3:
        return _SkillStructuredData(
          icon: Icons.chat_bubble_outline_rounded,
          goalTitle: 'Thuyết trình ý tưởng Sống xanh trong trường học (Green Living Presentation)',
          goalDescription: 'Trình bày 3 giải pháp cụ thể giúp giảm thiểu rác thải nhựa và tiết kiệm năng lượng.',
          taskPrompt: 'Work in groups. Present 3 practical ideas to reduce carbon footprints and single-use plastic waste in your school.',
          outline: '1. Thực trạng rác thải tại trường hiện nay.\n'
              '2. Ba giải pháp hành động cụ thể cho học sinh.\n'
              '3. Lợi ích lâu dài và lời kêu gọi hành động.',
          usefulLanguage: '• "Our group proposes three practical solutions to make our school greener..."\n'
              '• "First, we should launch a Refill Bottle campaign..."\n'
              '• "By doing so, we can cut down tons of single-use plastic every semester."',
          rubricCriteria: [
            'Lập luận rõ ràng, thuyết phục.',
            'Sử dụng các mẫu câu đề xuất (propose, recommend, suggest).',
          ],
        );
      case 4:
        return _SkillStructuredData(
          icon: Icons.chat_bubble_outline_rounded,
          goalTitle: 'Tranh luận về Cuộc sống ở Đô thị lớn so với Nông thôn (Urban vs. Rural Living)',
          goalDescription: 'Thảo luận các ưu điểm và bất lợi khi sinh sống tại thành phố lớn so với vùng quê.',
          taskPrompt: 'Work in pairs. Discuss the advantages and disadvantages of moving from the countryside to a mega-city.',
          usefulLanguage: '• "Living in a metropolis offers superior education and job prospects..."\n'
              '• "On the other hand, the high cost of living and traffic congestion can be overwhelming..."\n'
              '• "Personally, I would choose..."',
          rubricCriteria: [
            'Thể hiện quan điểm đa chiều có ví dụ minh họa.',
            'Ngữ điệu tự nhiên, phản xạ đối đáp tốt.',
          ],
        );
      case 5:
        return _SkillStructuredData(
          icon: Icons.chat_bubble_outline_rounded,
          goalTitle: 'Mô phỏng Phỏng vấn tuyển dụng việc làm thêm (Job Interview Role-Play)',
          goalDescription: 'Đóng vai người phỏng vấn và ứng viên cho một vị trí làm thêm hè hoặc thực tập sinh.',
          taskPrompt: 'Work in pairs. Role-play a job interview between an interviewer and an applicant for a part-time position.',
          usefulLanguage: '• "Could you tell me a little about your strengths and previous experience?"\n'
              '• "I consider myself a dependable, proactive, and quick learner..."\n'
              '• "Why do you think you are the right fit for our organisation?"',
          rubricCriteria: [
            'Sử dụng ngôn ngữ phỏng vấn trang trọng, tự tin.',
            'Trả lời lưu loát, nêu bật thế mạnh bản thân.',
          ],
        );
      case 6:
        return _SkillStructuredData(
          icon: Icons.chat_bubble_outline_rounded,
          goalTitle: 'Tranh luận về Tương lai của Trí tuệ nhân tạo (Debate on the Future of AI)',
          goalDescription: 'Thảo luận liệu robot AI có thay thế giáo viên hay nhân viên văn phòng trong tương lai hay không.',
          taskPrompt: 'Work in pairs. Debate whether AI and humanoid robots will eventually replace human workers in the education sector.',
          usefulLanguage: '• "AI algorithms can process massive amounts of data in seconds..."\n'
              '• "However, empathy, emotional support, and human moral judgment cannot be coded..."\n'
              '• "Therefore, AI will complement rather than completely replace humans."',
          rubricCriteria: [
            'Lập luận sắc bén, logic.',
            'Sử dụng các liên từ tranh luận (However, Conversely, Therefore).',
          ],
        );
      case 7:
        return _SkillStructuredData(
          icon: Icons.chat_bubble_outline_rounded,
          goalTitle: 'Trao đổi về Thói quen sử dụng Mạng xã hội và Nhận diện tin giả (Social Media & Fake News)',
          goalDescription: 'Chia sẻ kinh nghiệm sử dụng mạng xã hội thông minh và cách xác thực nguồn tin tức.',
          taskPrompt: 'Work with a partner. Discuss how social media affects your daily routine and share tips on spotting fake news online.',
          usefulLanguage: '• "I spend roughly two hours a day browsing educational channels..."\n'
              '• "Whenever I read shocking headlines, I always check the original source..."\n'
              '• "Critical digital literacy is essential to protect ourselves from misinformation."',
          rubricCriteria: [
            'Trao đổi cởi mở, tự nhiên.',
            'Đưa ra các mẹo thực tế, hữu ích.',
          ],
        );
      case 8:
        return _SkillStructuredData(
          icon: Icons.chat_bubble_outline_rounded,
          goalTitle: 'Kêu gọi Bảo vệ Động vật hoang dã nguy cấp (Wildlife Conservation Talk)',
          goalDescription: 'Thuyết trình ngắn 2 phút kêu gọi bảo vệ các loài linh trưởng và động vật quý hiếm tại Việt Nam.',
          taskPrompt: 'Give a 2-minute presentation proposing actions students can take to protect endangered animals in your region.',
          usefulLanguage: '• "Today, I urge everyone to say no to illegal wildlife products..."\n'
              '• "Habitat degradation is pushing many rare primates toward the brink of extinction..."\n'
              '• "Together, our awareness can save these magnificent creatures."',
          rubricCriteria: [
            'Bài nói truyền cảm hứng, phát âm chuẩn xác.',
            'Thông điệp rõ ràng, có tính kêu gọi hành động.',
          ],
        );
      case 9:
        return _SkillStructuredData(
          icon: Icons.chat_bubble_outline_rounded,
          goalTitle: 'Thảo luận Định hướng nghề nghiệp sau lớp 12 (Choosing a Career Path)',
          goalDescription: 'Thảo luận các tiêu chí quan trọng khi chọn trường đại học hoặc trung tâm đào tạo nghề.',
          taskPrompt: 'Discuss with your partner the key factors you will consider when choosing between university and vocational careers.',
          usefulLanguage: '• "Passion and personal aptitude should always come first..."\n'
              '• "Vocational courses offer hands-on training and fast workforce entry..."\n'
              '• "Whichever path you choose, continuous effort is the key to success."',
          rubricCriteria: [
            'Phân tích thấu đáo các yếu tố chọn nghề.',
            'Lắng nghe và phản hồi ý kiến của bạn cùng học.',
          ],
        );
      case 10:
        return _SkillStructuredData(
          icon: Icons.chat_bubble_outline_rounded,
          goalTitle: 'Chia sẻ về Tinh thần Tự học và Học tập suốt đời (Lifelong Learning Experience)',
          goalDescription: 'Chia sẻ về một kỹ năng mới bạn tự học được qua mạng và kế hoạch tự học trong tương lai.',
          taskPrompt: 'Talk about a skill, hobby, or foreign language you have learned independently and how you plan to keep learning in the future.',
          usefulLanguage: '• "Last summer, I taught myself basic Python programming using free online courses..."\n'
              '• "Self-discipline and curiosity kept me motivated whenever I hit a roadblock..."\n'
              '• "I believe lifelong learning is the best investment we can ever make."',
          rubricCriteria: [
            'Chia sẻ câu chuyện cá nhân chân thực, sinh động.',
            'Ngữ pháp thì hiện tại hoàn thành và quá khứ đơn chuẩn xác.',
          ],
        );
      default:
        return _SkillStructuredData(
          icon: Icons.chat_bubble_outline_rounded,
          goalTitle: 'Luyện nói và trao đổi ý kiến theo chủ đề Unit $u',
          goalDescription: 'Thực hành đàm thoại theo cặp hoặc thuyết trình ngắn theo tình huống SGK.',
          taskPrompt: 'Work with a partner to discuss the questions and prompts presented in the Speaking section on page ${widget.startPage}.',
          usefulLanguage: '• "From my point of view, ..."\n'
              '• "I completely agree because..."\n'
              '• "Could you clarify what you mean by...?"\n'
              '• "To conclude, I would argue that..."',
          rubricCriteria: [
            'Phát âm rõ ràng, có ngữ điệu câu tự nhiên.',
            'Trình bày ý kiến có luận điểm và ví dụ chứng minh.',
            'Tương tác tốt với bạn cùng học.',
          ],
        );
    }
  }

  _SkillStructuredData _getClilData(int u) {
    return _SkillStructuredData(
      icon: Icons.public_rounded,
      goalTitle: 'Tiếng Anh giao tiếp & Văn hóa liên môn (Everyday English & CLIL)',
      goalDescription: 'Học cách diễn đạt tự nhiên trong đời sống và mở rộng tri thức văn hóa, xã hội thế giới.',
      taskPrompt: 'Read the culture text and complete the discussion questions on page ${widget.startPage} of your textbook.',
      usefulLanguage: '• "In comparison with our tradition, this culture focuses on..."\n'
          '• "This historical event demonstrates that..."\n'
          '• "We can adopt similar approaches in our community by..."',
      rubricCriteria: [
        'Hiểu và vận dụng đúng mẫu câu giao tiếp Everyday English.',
        'Đối chiếu và phân tích được nét tương đồng/khác biệt văn hóa.',
      ],
    );
  }

  _SkillStructuredData _getLookingBackData(int u) {
    return _SkillStructuredData(
      icon: Icons.assignment_outlined,
      goalTitle: 'Tổng kết Unit & Dự án thực tế (Looking Back & Project)',
      goalDescription: 'Ôn tập toàn diện Phát âm, Từ vựng, Ngữ pháp và lập kế hoạch thực hiện Dự án nhóm.',
      taskPrompt: 'Complete the self-assessment checklist and outline your project presentation based on pages ${widget.startPage}-${widget.startPage + 1}.',
      usefulLanguage: '• "Our project aims to raise awareness about..."\n'
          '• "The target audience of our campaign is..."\n'
          '• "The expected outcome of this project will be..."',
      rubricCriteria: [
        'Nắm vững toàn bộ kiến thức trọng tâm của Unit.',
        'Kế hoạch dự án có tính khả thi và sáng tạo.',
      ],
    );
  }

  List<SpeakingPracticePrompt> _getSpeakingPromptsForUnit(int u) {
    switch (u) {
      case 1:
        return const [
          SpeakingPracticePrompt(
            text: 'General Vo Nguyen Giap was born in 1911 in Quang Binh Province.',
            ipa: "/'dʒenərəl 'vɔ: 'ŋwi:ən 'zæp wəz bɔ:n in 1911 in 'kwɑ:ŋ 'bi:n prɒvins/",
            translation: 'Đại tướng Võ Nguyên Giáp sinh năm 1911 tại tỉnh Quảng Bình.',
            contextTip: 'Chú ý nối âm giữa "born in" và nhấn đúng tên riêng.',
          ),
          SpeakingPracticePrompt(
            text: 'He led the Vietnamese army to historic victories, including Dien Bien Phu in 1954.',
            ipa: "/hi: led ðə vjetnə'mi:z 'ɑ:mi tʊ hi'stɒrik 'viktəriz in'klu:diŋ 'ðjen 'bjen 'fu:/",
            translation: 'Ông đã lãnh đạo quân đội Việt Nam giành những chiến thắng lịch sử, bao gồm Điện Biên Phủ năm 1954.',
            contextTip: 'Nhấn mạnh từ "historic victories" và từ chỉ năm "1954".',
          ),
          SpeakingPracticePrompt(
            text: 'His courage and devotion have won the admiration of people worldwide.',
            ipa: "/hiz 'kʌridʒ ænd di'vəʊʃn hæv wʌn ðə ædmə'reiʃn əv 'pi:pl 'wɜ:ldwaid/",
            translation: 'Lòng dũng cảm và sự cống hiến của ông đã giành được sự ngưỡng mộ của mọi người trên thế giới.',
            contextTip: 'Chú ý phát âm rõ trọng âm từ "courage" và "admiration".',
          ),
        ];
      case 2:
        return const [
          SpeakingPracticePrompt(
            text: 'The Mid-Autumn Festival is celebrated in many Asian countries.',
            ipa: "/ðə mid 'ɔ:təm 'festvl iz 'selibreitid in 'meni 'eiʃn 'kʌntriz/",
            translation: 'Lễ hội Trung thu được tổ chức ở nhiều quốc gia châu Á.',
            contextTip: 'Phát âm rõ âm đuôi /ed/ trong "celebrated".',
          ),
          SpeakingPracticePrompt(
            text: 'People enjoy eating mooncakes and watching lion dances during the festival.',
            ipa: "/'pi:pl in'dʒɔi 'i:tiŋ 'mu:nkeiks ænd 'wɒtʃiŋ 'laiən 'dɑ:nsiz 'djʊəriŋ ðə 'festvl/",
            translation: 'Mọi người thích ăn bánh trung thu và xem múa lân trong dịp lễ hội.',
            contextTip: 'Chú ý âm đuôi /s/ trong "mooncakes" và "dances".',
          ),
        ];
      case 3:
        return const [
          SpeakingPracticePrompt(
            text: 'We should reduce our carbon footprint by using public transport.',
            ipa: "/wi: ʃʊd ri'dju:s ɑ: 'kɑ:bən 'fʊtprint bai 'ju:ziŋ 'pʌblik 'trænspɔ:t/",
            translation: 'Chúng ta nên giảm lượng khí thải carbon bằng cách sử dụng phương tiện công cộng.',
            contextTip: 'Nhấn rõ hai từ trọng tâm "reduce" và "carbon footprint".',
          ),
          SpeakingPracticePrompt(
            text: 'Recycling single-use plastic bottles helps protect the environment.',
            ipa: "/ri:'saikliŋ 'siŋgl ju:s 'plæstik 'bɒtlz helps prə'tekt ðə in'vaiərənmənt/",
            translation: 'Tái chế chai nhựa dùng một lần giúp bảo vệ môi trường.',
            contextTip: 'Chú ý phát âm đúng âm /ŋ/ trong "recycling".',
          ),
        ];
      default:
        return [
          SpeakingPracticePrompt(
            text: 'Developing skills and knowledge is essential for Unit $u Global Success 12.',
            ipa: "/di'veləpiŋ skilz ænd 'nɒlidʒ iz i'senʃl fɔ: 'ju:nit $u 'gləʊbl sək'ses/",
            translation: 'Rèn luyện kỹ năng và kiến thức là yếu tố then chốt cho Unit $u SGK Global Success 12.',
            contextTip: 'Luyện tập phát âm trôi chảy với tốc độ vừa phải.',
          ),
        ];
    }
  }
}

class _SkillStructuredData {
  final IconData icon;
  final String goalTitle;
  final String goalDescription;
  final String taskPrompt;
  final String? taskGuidance;
  final String? outline;
  final String? usefulLanguage;
  final String? modelText;
  final List<String> rubricCriteria;

  _SkillStructuredData({
    required this.icon,
    required this.goalTitle,
    required this.goalDescription,
    required this.taskPrompt,
    this.taskGuidance,
    this.outline,
    this.usefulLanguage,
    this.modelText,
    this.rubricCriteria = const [],
  });
}
