import 'package:flutter/material.dart';
import '../../data/app_repository.dart';
import '../../data/textbook_repository.dart';
import '../../data/trial_lesson_repository.dart';
import '../../data/trial_policy.dart';
import '../auth/auth_controller.dart';
import '../listening/unit_listening_screen.dart';
import '../theme/app_tokens.dart';
import '../trial/trial_lesson_screen.dart';
import 'textbook_screen.dart';
import 'unit_getting_started_screen.dart';
import 'unit_language_screen.dart';
import 'unit_skills_screen.dart';

class UnitDetailScreen extends StatefulWidget {
  final int unitNumber;
  final String unitTitle;
  final String unitTopic;

  const UnitDetailScreen({
    super.key,
    this.unitNumber = 1,
    this.unitTitle = 'Life Stories We Admire',
    this.unitTopic = 'Steve Jobs: Life and Achievements',
  });

  @override
  State<UnitDetailScreen> createState() => _UnitDetailScreenState();
}

class _UnitDetailScreenState extends State<UnitDetailScreen> {
  final AppRepository _repository = AppRepository();

  // Danh sách các phần bài học chuẩn theo mục lục SGK 12 Global Success
  final List<Map<String, dynamic>> _sections = [
    {
      'id': 1,
      'title': 'Getting Started',
      'subtitle': 'Khởi động & Làm quen chủ đề bài học',
      'pageOffset': 0,
      'status': 'not_started',
      'icon': Icons.flag_rounded,
    },
    {
      'id': 2,
      'title': 'Language',
      'subtitle': 'Ngữ âm, Từ vựng & Ngữ pháp trọng tâm',
      'pageOffset': 1,
      'status': 'not_started',
      'icon': Icons.menu_book_rounded,
    },
    {
      'id': 3,
      'title': 'Reading',
      'subtitle': 'Bài đọc hiểu tương tác & Tra từ ngữ cảnh',
      'pageOffset': 3,
      'status': 'not_started',
      'icon': Icons.auto_stories_rounded,
    },
    {
      'id': 4,
      'title': 'Speaking',
      'subtitle': 'Luyện nói & Thuyết trình theo tình huống SGK',
      'pageOffset': 5,
      'status': 'not_started',
      'icon': Icons.chat_bubble_outline_rounded,
    },
    {
      'id': 5,
      'title': 'Listening',
      'subtitle': 'Luyện nghe & bài tập tương tác chuẩn SGK',
      'pageOffset': 6,
      'status': 'not_started',
      'icon': Icons.headphones_rounded,
    },
    {
      'id': 6,
      'title': 'Writing',
      'subtitle': 'Luyện viết học thuật & bài luận chuẩn SGK',
      'pageOffset': 7,
      'status': 'not_started',
      'icon': Icons.edit_note_rounded,
    },
    {
      'id': 7,
      'title': 'Communication & Culture / CLIL',
      'subtitle': 'Tiếng Anh đời sống & Mở rộng văn hóa liên môn',
      'pageOffset': 8,
      'status': 'not_started',
      'icon': Icons.public_rounded,
    },
    {
      'id': 8,
      'title': 'Looking Back & Project',
      'subtitle': 'Tổng kết toàn diện Unit & Dự án thực tế',
      'pageOffset': 10,
      'status': 'not_started',
      'icon': Icons.assignment_outlined,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadSectionStatuses();
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

  Future<void> _loadSectionStatuses() async {
    try {
      final ownerId = await _getEffectiveOwnerId();
      for (final sec in _sections) {
        final title = sec['title'] as String;
        final key = _cleanKey(title);

        if (title == 'Reading') {
          final lesson = TrialLessonRepository.instance.getLessonByUnit(widget.unitNumber) ??
              TrialLessonRepository.instance.getDefaultLesson();
          final session = await _repository.getLearningSession(ownerId, lessonId: lesson.lessonId);
          if (session != null && session.isCompleted) {
            sec['status'] = 'completed';
          } else if (session != null && session.isInProgress) {
            sec['status'] = 'in_progress';
          } else {
            sec['status'] = 'not_started';
          }
        } else {
          final progress = await _repository.getSetting('unit_section_progress_${ownerId}_u${widget.unitNumber}_$key');
          if (progress == 'completed') {
            sec['status'] = 'completed';
          } else {
            final note = await _repository.getSetting('unit_skill_note_${ownerId}_u${widget.unitNumber}_$key');
            if (note != null && note.isNotEmpty) {
              sec['status'] = 'in_progress';
            } else {
              sec['status'] = 'not_started';
            }
          }
        }
      }
      if (mounted) {
        setState(() {});
      }
    } catch (_) {}
  }

  int _getUnitStartPage() {
    switch (widget.unitNumber) {
      case 1:
        return 8;
      case 2:
        return 20;
      case 3:
        return 32;
      case 4:
        return 48;
      case 5:
        return 60;
      case 6:
        return 76;
      case 7:
        return 88;
      case 8:
        return 100;
      case 9:
        return 116;
      case 10:
        return 128;
      default:
        return 8;
    }
  }

  Future<void> _openTextbookPage(int targetPage) async {
    try {
      final repo = TextbookRepository();
      final book = await repo.load();
      if (!mounted) return;
      final start = _getUnitStartPage();
      final end = start + 11;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TextbookReader(
            book: book,
            initialPage: targetPage,
            start: start,
            end: end,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể tải dữ liệu trang sách. Vui lòng thử lại.')),
      );
    }
  }

  Future<void> _handleSectionTap(Map<String, dynamic> sec) async {
    final title = sec['title'] as String;
    final int targetPage = _getUnitStartPage() + (sec['pageOffset'] as int);
    final key = _cleanKey(title);

    if (title == 'Getting Started') {
      final res = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => UnitGettingStartedScreen(
            unitNumber: widget.unitNumber,
            unitTitle: widget.unitTitle,
            startPage: targetPage,
          ),
        ),
      );
      if (res == true) {
        final ownerId = await _getEffectiveOwnerId();
        await _repository.setSetting('unit_section_progress_${ownerId}_u${widget.unitNumber}_$key', 'completed');
      }
      await _loadSectionStatuses();
      return;
    }

    if (title == 'Language') {
      final res = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => UnitLanguageScreen(
            unitNumber: widget.unitNumber,
            unitTitle: widget.unitTitle,
            startPage: targetPage,
          ),
        ),
      );
      if (res == true) {
        final ownerId = await _getEffectiveOwnerId();
        await _repository.setSetting('unit_section_progress_${ownerId}_u${widget.unitNumber}_$key', 'completed');
      }
      await _loadSectionStatuses();
      return;
    }

    if (title == 'Reading') {
      final lesson = TrialLessonRepository.instance.getLessonByUnit(widget.unitNumber) ??
          TrialLessonRepository.instance.getDefaultLesson();
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TrialLessonScreen(lessonId: lesson.lessonId),
        ),
      );
      await _loadSectionStatuses();
      return;
    }

    if (title == 'Listening') {
      final res = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => UnitListeningScreen(
            lessonKey: 'unit-${widget.unitNumber.toString().padLeft(2, '0')}',
            initialTitle: widget.unitTitle,
            printedPage: targetPage,
          ),
        ),
      );
      if (res == true) {
        final ownerId = await _getEffectiveOwnerId();
        await _repository.setSetting('unit_section_progress_${ownerId}_u${widget.unitNumber}_$key', 'completed');
      }
      await _loadSectionStatuses();
      return;
    }

    // Speaking, Writing, Communication & Culture / CLIL, Looking Back & Project
    final res = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => UnitSkillsScreen(
          unitNumber: widget.unitNumber,
          unitTitle: widget.unitTitle,
          sectionTitle: title,
          subtitle: sec['subtitle'] as String,
          startPage: targetPage,
        ),
      ),
    );
    if (res == true) {
      final ownerId = await _getEffectiveOwnerId();
      await _repository.setSetting('unit_section_progress_${ownerId}_u${widget.unitNumber}_$key', 'completed');
    }
    await _loadSectionStatuses();
  }

  @override
  Widget build(BuildContext context) {
    final completedCount = _sections.where((s) => s['status'] == 'completed').length;
    final totalCount = _sections.length;
    final progressRatio = completedCount / totalCount;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tiếng Anh 12',
              style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500),
            ),
            Text(
              'Unit ${widget.unitNumber} · ${widget.unitTitle}',
              style: const TextStyle(
                fontFamily: 'BeVietnamPro',
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _openTextbookPage(_getUnitStartPage()),
            icon: const Icon(Icons.menu_book_rounded, size: 16, color: AppTokens.primary),
            label: const Text(
              'Xem sách gốc',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTokens.primary),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Thanh tiến độ Unit
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tiến độ Unit',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: Color(0xFF334155),
                        ),
                      ),
                      Text(
                        '$completedCount/$totalCount phần',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                          color: AppTokens.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progressRatio,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTokens.primary),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Danh sách các Section
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _sections.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final sec = _sections[index];
                  return _buildSectionCard(
                    section: sec,
                    onTap: () => _handleSectionTap(sec),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required Map<String, dynamic> section,
    required VoidCallback onTap,
  }) {
    final status = section['status'] as String;
    final bool isCompleted = status == 'completed';
    final bool isInProgress = status == 'in_progress';
    final authCtrl = AuthController.instance;
    final bool isGuest = !authCtrl.isAuthenticated || authCtrl.user.isGuest;
    final bool isTrial = isGuest &&
        TrialPolicy.isTrialContent(
          unitNumber: widget.unitNumber,
          sectionTitle: section['title'] as String,
        );

    Color iconBg;
    Color iconColor;
    Widget trailing;

    if (isCompleted) {
      iconBg = const Color(0xFFDCFCE7);
      iconColor = AppTokens.successGreen;
      trailing = const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, color: AppTokens.successGreen, size: 20),
          SizedBox(width: 4),
          Text(
            'Hoàn thành',
            style: TextStyle(color: AppTokens.successGreen, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      );
    } else if (isInProgress) {
      iconBg = const Color(0xFFEFF6FF);
      iconColor = AppTokens.primary;
      trailing = Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppTokens.primary,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color(0xFF1D4ED8),
              offset: Offset(0, 2.5),
            ),
          ],
        ),
        child: const Text(
          'Học tiếp',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    } else if (isTrial) {
      iconBg = const Color(0xFFFEF3C7);
      iconColor = const Color(0xFFD97706);
      trailing = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: const Text(
          'Học thử',
          style: TextStyle(
            color: Color(0xFFB45309),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    } else {
      iconBg = const Color(0xFFF1F5F9);
      iconColor = const Color(0xFF64748B);
      trailing = const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8));
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isInProgress ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
          width: isInProgress ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isInProgress
                ? AppTokens.primary.withValues(alpha: 0.08)
                : const Color(0x04000000),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Icon tròn
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(section['icon'] as IconData, color: iconColor, size: 22),
                  ),
                ),
                const SizedBox(width: 14),

                // Tiêu đề & phụ đề
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section['title'] as String,
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: isInProgress ? const Color(0xFF1D4ED8) : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        section['subtitle'] as String,
                        style: const TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),

                trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
