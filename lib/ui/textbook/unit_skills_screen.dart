import 'dart:convert';
import 'package:flutter/material.dart';
import '../../data/app_repository.dart';
import '../auth/auth_controller.dart';
import '../theme/app_tokens.dart';
import '../theme/components/app_button.dart';
import 'textbook_screen.dart';

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
    final skill = _getStructuredSkillData();
    final isWriting = widget.sectionTitle.contains('Writing');
    final wordCount = _countWords(_submissionController.text);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context, _isCompleted),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Unit ${widget.unitNumber}: ${widget.sectionTitle}',
              style: const TextStyle(
                fontFamily: 'BeVietnamPro',
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: Color(0xFF0F172A),
              ),
            ),
            Text(
              'SGK trang in ${widget.startPage} • Học tương tác',
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
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
                                style: const TextStyle(
                                  fontFamily: 'BeVietnamPro',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                skill.goalDescription,
                                style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.4),
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
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFDE68A)),
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
                          style: const TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
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
