import 'package:flutter/material.dart';
import '../../data/textbook_repository.dart';
import '../../data/trial_policy.dart';
import '../auth/auth_controller.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';
import '../theme/app_tokens.dart';
import 'reading_study_screen.dart';
import 'textbook_screen.dart';

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
  // Danh sách các phần bài học chuẩn theo cấu trúc SGK 12
  final List<Map<String, dynamic>> _sections = [
    {
      'id': 1,
      'title': 'Getting Started',
      'subtitle': 'Khởi động & Làm quen chủ đề',
      'pageOffset': 0, // Bắt đầu unit
      'status': 'not_started',
      'icon': Icons.flag_rounded,
    },
    {
      'id': 2,
      'title': 'Language',
      'subtitle': 'Từ vựng & Ngữ pháp trọng tâm',
      'pageOffset': 1,
      'status': 'not_started',
      'icon': Icons.menu_book_rounded,
    },
    {
      'id': 3,
      'title': 'Pronunciation',
      'subtitle': 'Ngữ điệu và phát âm chuẩn',
      'pageOffset': 1,
      'status': 'not_started',
      'icon': Icons.record_voice_over_rounded,
    },
    {
      'id': 4,
      'title': 'Reading',
      'subtitle': 'Bài đọc · Tra từ điển · Luyện tập đọc hiểu',
      'pageOffset': 3,
      'status': 'not_started',
      'icon': Icons.auto_stories_rounded,
    },
    {
      'id': 5,
      'title': 'Speaking',
      'subtitle': 'Luyện nói theo tình huống SGK',
      'pageOffset': 5,
      'status': 'not_started',
      'icon': Icons.chat_bubble_outline_rounded,
    },
    {
      'id': 6,
      'title': 'Listening & Writing',
      'subtitle': 'Luyện nghe & kỹ năng viết SGK',
      'pageOffset': 6,
      'status': 'not_started',
      'icon': Icons.edit_note_rounded,
    },
    {
      'id': 7,
      'title': 'Looking Back & Project',
      'subtitle': 'Ôn tập toàn diện Unit & Dự án',
      'pageOffset': 10,
      'status': 'not_started',
      'icon': Icons.assignment_outlined,
    },
  ];

  int _getUnitStartPage() {
    // Ước lượng hoặc tính theo mục lục 10 Unit chuẩn SGK
    // Unit 1: 8..19, Unit 2: 20..31, Unit 3: 32..43, Unit 4: 48..59, Unit 5: 60..71...
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

  void _handleSectionTap(Map<String, dynamic> sec) {
    final title = sec['title'] as String;
    final bool isTrial = TrialPolicy.isTrialContent(
      unitNumber: widget.unitNumber,
      sectionTitle: title,
    );

    // Nếu là nội dung trong phạm vi học thử (Unit 1 Reading)
    if (isTrial) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReadingStudyScreen(
            unitNumber: widget.unitNumber,
            unitTitle: widget.unitTitle,
            articleTitle: widget.unitNumber == 1
                ? TrialPolicy.trialArticleTitle
                : widget.unitTopic,
          ),
        ),
      );
      return;
    }

    final isGuest = AuthController.instance.user.isGuest;
    final int targetPage = _getUnitStartPage() + (sec['pageOffset'] as int);

    if (isGuest) {
      // Khách bấm vào nội dung ngoài phạm vi thử: giải thích lợi ích tài khoản
      showDialog(
        context: context,
        builder: (dCtx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.lock_outline_rounded, color: AppTokens.primary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Nội dung dành cho Học viên',
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Phần "$title" thuộc phạm vi chương trình chính thức. ${TrialPolicy.accountBenefitsExplanation}',
                style: const TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 13.5,
                  height: 1.45,
                  color: AppTokens.textMain,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Bạn vẫn có thể xem trước trang sách nguyên bản dưới đây hoặc đăng ký tài khoản miễn phí để học tương tác.',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 12.5,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dCtx);
                _openTextbookPage(targetPage);
              },
              child: const Text('Xem trang SGK gốc'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dCtx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              child: const Text('Đăng nhập'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dCtx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                );
              },
              child: const Text('Tạo tài khoản'),
            ),
          ],
        ),
      );
    } else {
      // Học viên đã đăng nhập
      if (title == 'Reading') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReadingStudyScreen(
              unitNumber: widget.unitNumber,
              unitTitle: widget.unitTitle,
              articleTitle: widget.unitTopic,
            ),
          ),
        );
      } else {
        _openTextbookPage(targetPage);
      }
    }
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
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Nội dung sách giáo khoa Global Success 12 đã được tích hợp sẵn ngoại tuyến trong ứng dụng.'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(
              Icons.check_circle_outline_rounded,
              size: 18,
              color: Color(0xFF16A34A),
            ),
            label: const Text(
              'Có sẵn ngoại tuyến',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF16A34A),
              ),
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
    final bool isTrial = TrialPolicy.isTrialContent(
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
