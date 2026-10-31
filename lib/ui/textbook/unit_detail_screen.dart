import 'package:flutter/material.dart';
import 'reading_study_screen.dart';

class UnitDetailScreen extends StatefulWidget {
  final int unitNumber;
  final String unitTitle;
  final String unitTopic;

  const UnitDetailScreen({
    super.key,
    this.unitNumber = 3,
    this.unitTitle = 'Green Living',
    this.unitTopic = 'Green Habits for a Better Future',
  });

  @override
  State<UnitDetailScreen> createState() => _UnitDetailScreenState();
}

class _UnitDetailScreenState extends State<UnitDetailScreen> {
  // Danh sách các phần bài học chuẩn theo cấu trúc SGK 12
  // Khởi tạo trạng thái thực tế: chưa học phần nào
  final List<Map<String, dynamic>> _sections = [
    {
      'id': 1,
      'title': 'Getting Started',
      'subtitle': 'Khởi động & Làm quen chủ đề',
      'status': 'not_started', // completed | in_progress | locked | not_started
      'icon': Icons.flag_rounded,
    },
    {
      'id': 2,
      'title': 'Language',
      'subtitle': 'Từ vựng & Ngữ pháp trọng tâm',
      'status': 'not_started',
      'icon': Icons.menu_book_rounded,
    },
    {
      'id': 3,
      'title': 'Pronunciation',
      'subtitle': 'Ngữ điệu và phát âm chuẩn',
      'status': 'not_started',
      'icon': Icons.record_voice_over_rounded,
    },
    {
      'id': 4,
      'title': 'Reading',
      'subtitle': 'Bài đọc · Tra từ điển · Luyện tập đọc hiểu',
      'status': 'not_started',
      'icon': Icons.auto_stories_rounded,
    },
    {
      'id': 5,
      'title': 'Speaking',
      'subtitle': 'Luyện nói theo tình huống (Chưa sẵn sàng)',
      'status': 'not_started',
      'icon': Icons.chat_bubble_outline_rounded,
    },
    {
      'id': 6,
      'title': 'Writing',
      'subtitle': 'Luyện viết có gia sư AI sửa lỗi (Chưa sẵn sàng)',
      'status': 'not_started',
      'icon': Icons.edit_note_rounded,
    },
    {
      'id': 7,
      'title': 'Looking Back & Project',
      'subtitle': 'Ôn tập toàn diện Unit & Dự án (Chưa sẵn sàng)',
      'status': 'not_started',
      'icon': Icons.assignment_outlined,
    },
  ];

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
                          color: Color(0xFF2563EB),
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
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
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
                  final bool isReading = sec['title'] == 'Reading';

                  return _buildSectionCard(
                    section: sec,
                    onTap: () {
                      if (isReading) {
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Phần ${sec['title']} chưa sẵn sàng nội dung ở bước này.'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
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

    Color iconBg;
    Color iconColor;
    Widget trailing;

    if (isCompleted) {
      iconBg = const Color(0xFFDCFCE7);
      iconColor = const Color(0xFF16A34A);
      trailing = const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
          SizedBox(width: 4),
          Text(
            'Hoàn thành',
            style: TextStyle(color: Color(0xFF16A34A), fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      );
    } else if (isInProgress) {
      iconBg = const Color(0xFFEFF6FF);
      iconColor = const Color(0xFF2563EB);
      trailing = Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF2563EB),
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
                ? const Color(0xFF2563EB).withValues(alpha: 0.08)
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
