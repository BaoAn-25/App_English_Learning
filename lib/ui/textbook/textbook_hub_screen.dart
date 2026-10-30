import 'package:flutter/material.dart';
import 'textbook_screen.dart';
import 'unit_detail_screen.dart';

class TextbookHubScreen extends StatefulWidget {
  const TextbookHubScreen({super.key});

  @override
  State<TextbookHubScreen> createState() => _TextbookHubScreenState();
}

class _TextbookHubScreenState extends State<TextbookHubScreen> {
  int _selectedFilter = 0; // 0: Tất cả, 1: Đang học, 2: Đã tải về

  final List<Map<String, dynamic>> _units = [
    {
      'number': 1,
      'title': 'Life Stories We Admire',
      'vietnamese': 'Những câu chuyện cuộc đời đáng ngưỡng mộ',
      'status': 'completed', // completed | in_progress | not_started
      'sectionsDone': 8,
      'totalSections': 8,
      'isDownloaded': true,
    },
    {
      'number': 2,
      'title': 'A Diversity of Cultures',
      'vietnamese': 'Sự đa dạng của các nền văn hóa',
      'status': 'completed',
      'sectionsDone': 8,
      'totalSections': 8,
      'isDownloaded': true,
    },
    {
      'number': 3,
      'title': 'Green Living',
      'vietnamese': 'Lối sống xanh & Bảo vệ môi trường',
      'status': 'in_progress',
      'sectionsDone': 2,
      'totalSections': 8,
      'isDownloaded': true,
    },
    {
      'number': 4,
      'title': 'Urbanisation',
      'vietnamese': 'Đô thị hóa & Sự phát triển thành phố',
      'status': 'not_started',
      'sectionsDone': 0,
      'totalSections': 8,
      'isDownloaded': false,
    },
    {
      'number': 5,
      'title': 'The World of Work',
      'vietnamese': 'Thế giới việc làm & Nghề nghiệp tương lai',
      'status': 'not_started',
      'sectionsDone': 0,
      'totalSections': 8,
      'isDownloaded': false,
    },
    {
      'number': 6,
      'title': 'Artificial Intelligence',
      'vietnamese': 'Trí tuệ nhân tạo trong đời sống',
      'status': 'not_started',
      'sectionsDone': 0,
      'totalSections': 8,
      'isDownloaded': false,
    },
    {
      'number': 7,
      'title': 'The World of Mass Media',
      'vietnamese': 'Thế giới truyền thông đại chúng',
      'status': 'not_started',
      'sectionsDone': 0,
      'totalSections': 8,
      'isDownloaded': false,
    },
    {
      'number': 8,
      'title': 'Wildlife Conservation',
      'vietnamese': 'Bảo tồn động thực vật hoang dã',
      'status': 'not_started',
      'sectionsDone': 0,
      'totalSections': 8,
      'isDownloaded': false,
    },
    {
      'number': 9,
      'title': 'Career Paths',
      'vietnamese': 'Con đường sự nghiệp',
      'status': 'not_started',
      'sectionsDone': 0,
      'totalSections': 8,
      'isDownloaded': false,
    },
    {
      'number': 10,
      'title': 'Lifelong Learning',
      'vietnamese': 'Học tập suốt đời',
      'status': 'not_started',
      'sectionsDone': 0,
      'totalSections': 8,
      'isDownloaded': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final filteredUnits = _units.where((u) {
      if (_selectedFilter == 1) return u['status'] == 'in_progress';
      if (_selectedFilter == 2) return u['isDownloaded'] == true;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Sách giáo khoa',
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: Color(0xFF0F172A),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Đọc nguyên bản sách PDF 159 trang',
            icon: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF2563EB)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TextbookScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header Thẻ Sách Lớn Xanh (Wireframe Sách ảnh 2)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x202563EB),
                      offset: Offset(0, 4),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Badge Sách 12
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x10000000),
                            offset: Offset(0, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'TIẾNG ANH',
                            style: TextStyle(
                              fontSize: 7.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                          Text(
                            '12',
                            style: TextStyle(
                              fontFamily: 'BeVietnamPro',
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF2563EB),
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Thông tin tiến độ
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Global Success 12',
                            style: TextStyle(
                              fontFamily: 'BeVietnamPro',
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            '2 trên 10 Unit hoàn thành · 22%',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: const LinearProgressIndicator(
                              value: 0.22,
                              minHeight: 6,
                              backgroundColor: Colors.white24,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFC53D)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Tabs bộ lọc
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildFilterTab(0, 'Tất cả (${_units.length})'),
                  const SizedBox(width: 8),
                  _buildFilterTab(1, 'Đang học (1)'),
                  const SizedBox(width: 8),
                  _buildFilterTab(2, 'Đã tải về (3)'),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Danh sách các Unit
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: filteredUnits.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final unit = filteredUnits[index];
                  return _buildUnitCard(context, unit);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTab(int index, String label) {
    final isSelected = _selectedFilter == index;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => _selectedFilter = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildUnitCard(BuildContext context, Map<String, dynamic> unit) {
    final int number = unit['number'] as int;
    final String title = unit['title'] as String;
    final String vietnamese = unit['vietnamese'] as String;
    final String status = unit['status'] as String;
    final int sectionsDone = unit['sectionsDone'] as int;
    final int totalSections = unit['totalSections'] as int;
    // isDownloaded: ${unit['isDownloaded']}

    final bool isCompleted = status == 'completed';
    final bool isInProgress = status == 'in_progress';

    Color numberBg;
    Color numberColor;
    Widget actionWidget;

    if (isCompleted) {
      numberBg = const Color(0xFFDCFCE7);
      numberColor = const Color(0xFF16A34A);
      actionWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Ôn lại',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
        ),
      );
    } else if (isInProgress) {
      numberBg = const Color(0xFF2563EB);
      numberColor = Colors.white;
      actionWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF2563EB),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
              color: Color(0xFF1D4ED8),
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: const Text(
          'Học tiếp',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
        ),
      );
    } else {
      numberBg = const Color(0xFFF1F5F9);
      numberColor = const Color(0xFF64748B);
      actionWidget = const Icon(Icons.download_rounded, size: 20, color: Color(0xFF94A3B8));
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isInProgress ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0),
          width: isInProgress ? 1.6 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            offset: Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UnitDetailScreen(
                  unitNumber: number,
                  unitTitle: title,
                  unitTopic: vietnamese,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Khung số Unit
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: numberBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      '$number',
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: numberColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Tên Unit
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Unit $number · $title',
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                          color: isInProgress ? const Color(0xFF1D4ED8) : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$sectionsDone/$totalSections phần · $vietnamese',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                actionWidget,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
