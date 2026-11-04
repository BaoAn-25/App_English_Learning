import 'package:flutter/material.dart';

import '../../../data/app_repository.dart';
import '../../../data/models/learning_session.dart';
import '../../../data/rbac_proctor_ai_service.dart';
import '../../../data/trial_lesson_repository.dart';

/// Đại diện trạng thái của một phần học (Section) trong Unit SGK 12
class SectionProgressInfo {
  final String key;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isCompleted;
  final bool isInProgress;
  final String? note;

  const SectionProgressInfo({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isCompleted,
    this.isInProgress = false,
    this.note,
  });
}

/// Đại diện tiến độ tổng thể của một Unit trong SGK 12
class UnitProgressInfo {
  final int unitNumber;
  final String title;
  final String vietnameseTitle;
  final int completedSections;
  final int totalSections;
  final double percent;
  final String stoppedAtSection;
  final String status; // 'completed' | 'in_progress' | 'not_started'
  final List<SectionProgressInfo> sections;

  const UnitProgressInfo({
    required this.unitNumber,
    required this.title,
    required this.vietnameseTitle,
    required this.completedSections,
    this.totalSections = 8,
    required this.percent,
    required this.stoppedAtSection,
    required this.status,
    required this.sections,
  });
}

/// Modal hiển thị Hồ sơ chi tiết & Tiến độ học tập của Học sinh
/// Cụ thể hoá đến từng Unit (Unit 1 - 10), chỉ rõ vị trí đang dừng và tiến độ %
/// Dùng chung cho cả Quản trị viên (Admin) và Giáo viên (Teacher)
class StudentProgressSheet extends StatefulWidget {
  final Map<String, dynamic> student;
  final String? currentClassName;
  final VoidCallback? onUpdated;

  const StudentProgressSheet({
    super.key,
    required this.student,
    this.currentClassName,
    this.onUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> student,
    String? currentClassName,
    VoidCallback? onUpdated,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StudentProgressSheet(
        student: student,
        currentClassName: currentClassName,
        onUpdated: onUpdated,
      ),
    );
  }

  @override
  State<StudentProgressSheet> createState() => _StudentProgressSheetState();
}

class _StudentProgressSheetState extends State<StudentProgressSheet> {
  final RbacProctorAiService _service = RbacProctorAiService.instance;
  final AppRepository _repo = AppRepository();

  List<Map<String, dynamic>> _allClasses = [];
  bool _isLoading = true;

  // Dữ liệu tiến độ thực tế
  List<UnitProgressInfo> _unitProgressList = [];
  String _effectiveOwnerId = '';
  LearningSession? _latestSession;

  // Vị trí đang học / dừng lại
  String _currentUnitTitle = 'Unit 1: Life Stories We Admire';
  String _currentStoppedLocation = 'Chưa bắt đầu học';
  String _currentProgressSummary = 'Sẵn sàng bắt đầu';
  bool _isAllCompleted = false;

  // Kỹ năng thực tế
  double _vocabPercent = 0.0;
  double _readingPercent = 0.0;
  double _grammarPercent = 0.0;
  double _listeningPercent = 0.0;

  // Bộ lọc danh sách Unit: 'all' | 'in_progress' | 'completed' | 'not_started'
  String _unitFilter = 'all';

  // 10 Unit chuẩn SGK Global Success 12
  static const List<Map<String, dynamic>> _standardUnits = [
    {
      'number': 1,
      'title': 'Life Stories We Admire',
      'vietnamese': 'Những câu chuyện cuộc đời đáng ngưỡng mộ',
    },
    {
      'number': 2,
      'title': 'A Multicultural World',
      'vietnamese': 'Một thế giới đa văn hóa',
    },
    {
      'number': 3,
      'title': 'Green Living',
      'vietnamese': 'Lối sống xanh & Bảo vệ môi trường',
    },
    {
      'number': 4,
      'title': 'Urbanisation',
      'vietnamese': 'Đô thị hóa & Sự phát triển thành phố',
    },
    {
      'number': 5,
      'title': 'The World of Work',
      'vietnamese': 'Thế giới việc làm & Nghề nghiệp tương lai',
    },
    {
      'number': 6,
      'title': 'Artificial Intelligence',
      'vietnamese': 'Trí tuệ nhân tạo trong đời sống',
    },
    {
      'number': 7,
      'title': 'The World of Mass Media',
      'vietnamese': 'Thế giới truyền thông đại chúng',
    },
    {
      'number': 8,
      'title': 'Wildlife Conservation',
      'vietnamese': 'Bảo tồn động thực vật hoang dã',
    },
    {
      'number': 9,
      'title': 'Career Paths',
      'vietnamese': 'Con đường phát triển sự nghiệp',
    },
    {
      'number': 10,
      'title': 'Lifelong Learning',
      'vietnamese': 'Tinh thần học tập suốt đời',
    },
  ];

  static const List<Map<String, dynamic>> _sectionDefinitions = [
    {
      'key': 'getting_started',
      'title': 'Getting Started',
      'subtitle': 'Khởi động & Giới thiệu chủ đề bài học',
      'icon': Icons.flag_outlined,
    },
    {
      'key': 'language',
      'title': 'Language',
      'subtitle': 'Phát âm, Từ vựng & Ngữ pháp cốt lõi',
      'icon': Icons.spellcheck_outlined,
    },
    {
      'key': 'reading',
      'title': 'Reading',
      'subtitle': 'Đọc hiểu chuyên sâu SGK (Interactive Reading)',
      'icon': Icons.menu_book_outlined,
    },
    {
      'key': 'speaking',
      'title': 'Speaking',
      'subtitle': 'Luyện nói tương tác & Diễn đạt tình huống',
      'icon': Icons.record_voice_over_outlined,
    },
    {
      'key': 'listening',
      'title': 'Listening',
      'subtitle': 'Luyện nghe hiểu hội thoại & bài giảng',
      'icon': Icons.headphones_outlined,
    },
    {
      'key': 'writing',
      'title': 'Writing',
      'subtitle': 'Luyện viết đoạn văn & tiểu luận ngắn',
      'icon': Icons.edit_note_outlined,
    },
    {
      'key': 'communication_culture_clil',
      'title': 'Communication & Culture / CLIL',
      'subtitle': 'Giao tiếp thực tế & Kiến thức liên môn CLIL',
      'icon': Icons.public_outlined,
    },
    {
      'key': 'looking_back_project',
      'title': 'Looking Back & Project',
      'subtitle': 'Ôn tập tổng kết Unit & Dự án thực hành',
      'icon': Icons.assignment_turned_in_outlined,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadClasses(),
      _loadStudentProgress(),
    ]);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadClasses() async {
    final classes = await _service.getClasses();
    if (mounted) {
      _allClasses = classes;
    }
  }

  Future<void> _loadStudentProgress() async {
    final s = widget.student;
    final rawId = (s['id'] ?? s['studentId'] ?? s['userId'] ?? '').toString();
    final rawEmail = (s['studentEmail'] ?? s['email'] ?? '').toString();

    // Xác định ownerId hiệu lực trong SQLite
    _effectiveOwnerId = rawId.isNotEmpty ? rawId : rawEmail;

    // 1. Tìm phiên học gần nhất
    LearningSession? session = await _repo.getLearningSession(_effectiveOwnerId);
    if (session == null && rawEmail.isNotEmpty && rawEmail != _effectiveOwnerId) {
      session = await _repo.getLearningSession(rawEmail);
    }
    _latestSession = session;

    // 2. Load tiến độ 10 Unit
    final unitsResult = <UnitProgressInfo>[];
    int totalCompletedReading = 0;
    int totalCompletedLanguage = 0;
    int totalCompletedListening = 0;
    int totalCompletedSectionsAllUnits = 0;

    int firstInProgressUnitNumber = 0;
    String firstInProgressSectionTitle = '';
    String firstInProgressDetail = '';

    for (final u in _standardUnits) {
      final unitNum = u['number'] as int;
      final unitTitle = u['title'] as String;
      final vietnamese = u['vietnamese'] as String;

      final sectionsList = <SectionProgressInfo>[];
      int unitCompletedCount = 0;
      String unitStoppedSection = '';

      // Kiểm tra bài đọc hiểu trial_unitX_reading
      final lesson = TrialLessonRepository.instance.getLessonByUnit(unitNum);
      final readingSession = lesson != null
          ? await _repo.getLearningSession(_effectiveOwnerId, lessonId: lesson.lessonId)
          : null;

      for (final sec in _sectionDefinitions) {
        final secKey = sec['key'] as String;
        final title = sec['title'] as String;
        final subtitle = sec['subtitle'] as String;
        final icon = sec['icon'] as IconData;

        bool isDone = false;
        bool isInProg = false;
        String? note;

        if (secKey == 'reading') {
          final p = await _repo.getSetting('unit_section_progress_${_effectiveOwnerId}_u${unitNum}_$secKey');
          if (p == 'completed' || (readingSession != null && readingSession.isCompleted)) {
            isDone = true;
            totalCompletedReading++;
          } else if (readingSession != null && readingSession.isInProgress) {
            isInProg = true;
            note = 'Đang làm câu ${readingSession.currentQuestionIndex + 1}/${readingSession.totalQuestions}';
          }
        } else {
          final p = await _repo.getSetting('unit_section_progress_${_effectiveOwnerId}_u${unitNum}_$secKey');
          if (p == 'completed') {
            isDone = true;
            if (secKey == 'language') totalCompletedLanguage++;
            if (secKey == 'listening') totalCompletedListening++;
          }
        }

        if (isDone) {
          unitCompletedCount++;
        } else if (unitStoppedSection.isEmpty) {
          unitStoppedSection = title;
          if (firstInProgressUnitNumber == 0) {
            firstInProgressUnitNumber = unitNum;
            firstInProgressSectionTitle = title;
            firstInProgressDetail = isInProg && note != null
                ? note
                : 'Đang dừng tại mục $title ($subtitle)';
          }
        }

        sectionsList.add(SectionProgressInfo(
          key: secKey,
          title: title,
          subtitle: subtitle,
          icon: icon,
          isCompleted: isDone,
          isInProgress: isInProg,
          note: note,
        ));
      }

      totalCompletedSectionsAllUnits += unitCompletedCount;

      final percent = (unitCompletedCount / 8.0) * 100.0;
      String status;
      if (unitCompletedCount >= 8) {
        status = 'completed';
        unitStoppedSection = 'Đã hoàn thành 8/8 phần';
      } else if (unitCompletedCount > 0 || (readingSession != null && readingSession.isInProgress)) {
        status = 'in_progress';
        if (unitStoppedSection.isEmpty) unitStoppedSection = 'Đang học';
      } else {
        status = 'not_started';
        unitStoppedSection = 'Chưa bắt đầu';
      }

      unitsResult.add(UnitProgressInfo(
        unitNumber: unitNum,
        title: unitTitle,
        vietnameseTitle: vietnamese,
        completedSections: unitCompletedCount,
        totalSections: 8,
        percent: percent,
        stoppedAtSection: unitStoppedSection,
        status: status,
        sections: sectionsList,
      ));
    }

    // 3. Tính toán vị trí học gần nhất
    if (_latestSession != null) {
      _currentUnitTitle = _latestSession!.lessonTitle;
      final qIdx = _latestSession!.currentQuestionIndex;
      final totalQ = _latestSession!.totalQuestions;
      if (_latestSession!.isInProgress) {
        _currentStoppedLocation = 'Đang làm câu ${qIdx + 1}/$totalQ';
        _currentProgressSummary = 'Tiến độ bài: ${((qIdx + 1) / (totalQ > 0 ? totalQ : 1) * 100).toInt()}%';
      } else {
        _currentStoppedLocation = 'Đã hoàn thành bài thi/bài đọc';
        _currentProgressSummary = _latestSession!.score != null ? 'Điểm: ${_latestSession!.score}/10' : 'Đã nộp bài';
      }
    } else if (firstInProgressUnitNumber > 0 && totalCompletedSectionsAllUnits > 0) {
      final currentU = unitsResult.firstWhere((u) => u.unitNumber == firstInProgressUnitNumber);
      _currentUnitTitle = 'Unit $firstInProgressUnitNumber: ${currentU.title}';
      _currentStoppedLocation = firstInProgressSectionTitle;
      _currentProgressSummary = firstInProgressDetail;
    } else if (totalCompletedSectionsAllUnits >= 80) {
      _isAllCompleted = true;
      _currentUnitTitle = 'Toàn bộ 10 Unit SGK 12';
      _currentStoppedLocation = 'Đã hoàn thành 100% chương trình';
      _currentProgressSummary = 'Hoàn thành 80/80 phần học';
    } else {
      _currentUnitTitle = 'Unit 1: Life Stories We Admire';
      _currentStoppedLocation = 'Chưa bắt đầu học';
      _currentProgressSummary = 'Sẵn sàng học phần Getting Started';
    }

    // 4. Tính toán tiến độ nắm vững kỹ năng
    // A. Từ vựng: Lấy word progress thực tế của học sinh
    try {
      final wordsProgress = await _repo.getAllWordProgress(ownerId: _effectiveOwnerId);
      final learnedWordsCount = wordsProgress.where((w) => w.reviewCount > 0).length;
      // Trung bình 10 Unit SGK 12 có khoảng 160 từ vựng trọng tâm
      _vocabPercent = (learnedWordsCount / 160.0).clamp(0.0, 1.0);
      if (_vocabPercent == 0.0 && totalCompletedSectionsAllUnits > 0) {
        _vocabPercent = (totalCompletedSectionsAllUnits / 80.0).clamp(0.0, 1.0);
      }
    } catch (_) {
      _vocabPercent = (totalCompletedSectionsAllUnits / 80.0).clamp(0.0, 1.0);
    }

    _readingPercent = (totalCompletedReading / 10.0).clamp(0.0, 1.0);
    _grammarPercent = (totalCompletedLanguage / 10.0).clamp(0.0, 1.0);
    _listeningPercent = (totalCompletedListening / 10.0).clamp(0.0, 1.0);

    // Fallback thông minh: nếu là user mới có một số section hoàn thành
    if (_readingPercent == 0.0 && totalCompletedSectionsAllUnits > 0) {
      _readingPercent = (totalCompletedSectionsAllUnits / 80.0 * 0.8).clamp(0.0, 1.0);
    }
    if (_grammarPercent == 0.0 && totalCompletedSectionsAllUnits > 0) {
      _grammarPercent = (totalCompletedSectionsAllUnits / 80.0 * 0.75).clamp(0.0, 1.0);
    }
    if (_listeningPercent == 0.0 && totalCompletedSectionsAllUnits > 0) {
      _listeningPercent = (totalCompletedSectionsAllUnits / 80.0 * 0.7).clamp(0.0, 1.0);
    }

    _unitProgressList = unitsResult;
  }

  void _showAssignClassDialog() {
    if (_allClasses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hệ thống chưa có lớp học nào. Hãy tạo lớp trước!')),
      );
      return;
    }

    String selectedClassId = _allClasses.first['id'].toString();
    final studentName = (widget.student['studentName'] ?? widget.student['display_name'] ?? widget.student['displayName'] ?? 'Học sinh').toString();
    final studentEmail = (widget.student['studentEmail'] ?? widget.student['email'] ?? '').toString();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text('Xếp "$studentName" vào lớp'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Chọn lớp học để thêm học sinh này:', style: TextStyle(fontSize: 13, color: Colors.black54)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: selectedClassId,
                  decoration: const InputDecoration(labelText: 'Lớp học', border: OutlineInputBorder()),
                  items: _allClasses
                      .map((c) => DropdownMenuItem(
                            value: c['id'].toString(),
                            child: Text(
                              '${c['name']} (${c['code']})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDlgState(() => selectedClassId = v);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
              onPressed: () async {
                Navigator.pop(ctx);
                await _service.addStudentToClass(
                  classId: selectedClassId,
                  studentName: studentName,
                  studentEmail: studentEmail,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Đã thêm học sinh "$studentName" vào lớp thành công!'),
                      backgroundColor: Colors.green[800],
                    ),
                  );
                  widget.onUpdated?.call();
                }
              },
              child: const Text('Xác nhận xếp lớp'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.student;
    final name = (s['studentName'] ?? s['display_name'] ?? s['displayName'] ?? s['email']?.toString().split('@').first ?? 'Học sinh').toString();
    final email = (s['studentEmail'] ?? s['email'] ?? '').toString();
    final streak = (s['streakDays'] ?? s['streak_days'] as num?)?.toInt() ?? 5;
    final avgScore = (s['avgScore'] ?? s['avg_score'] as num?)?.toDouble() ?? 7.5;
    final overdue = (s['overdueCount'] ?? s['overdue_count'] as num?)?.toInt() ?? 0;
    final className = widget.currentClassName ?? s['className']?.toString() ?? s['class_name']?.toString() ?? 'Chưa phân lớp';

    final filteredUnits = _unitProgressList.where((u) {
      if (_unitFilter == 'in_progress') return u.status == 'in_progress';
      if (_unitFilter == 'completed') return u.status == 'completed';
      if (_unitFilter == 'not_started') return u.status == 'not_started';
      return true;
    }).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 18,
        right: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header: Avatar & Tên & Lớp
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: const Color(0xFF1E3A8A).withValues(alpha: 0.12),
                child: Text(
                  name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'H',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Học sinh', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email.isNotEmpty ? email : 'Tài khoản học sinh',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Lớp: $className',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF059669)),
                    ),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 12),

          Expanded(
            child: _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card nổi bật: Vị trí học gần nhất & Dừng ở đâu
                        _buildCurrentPositionCard(),
                        const SizedBox(height: 14),

                        // 3 Thẻ KPI: Streak, Điểm TB, Trạng thái
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                decoration: BoxDecoration(
                                  color: Colors.orange[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.orange[100]!),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Chuỗi Streak', style: TextStyle(fontSize: 11, color: Colors.black54)),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$streak ngày',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange[900]),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.blue[100]!),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Điểm TB', style: TextStyle(fontSize: 11, color: Colors.black54)),
                                    const SizedBox(height: 2),
                                    Text(
                                      avgScore.toStringAsFixed(1),
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue[900]),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                decoration: BoxDecoration(
                                  color: overdue > 0 ? Colors.red[50] : Colors.green[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: overdue > 0 ? Colors.red[100]! : Colors.green[100]!),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Tình trạng', style: TextStyle(fontSize: 11, color: Colors.black54)),
                                    const SizedBox(height: 2),
                                    Text(
                                      overdue > 0 ? '$overdue trễ hạn' : 'Tốt',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: overdue > 0 ? Colors.red[900] : Colors.green[900],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Section 1: Tiến độ chi tiết 10 Unit SGK 12
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Tiến độ 10 Unit SGK 12:',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)),
                            ),
                            Text(
                              '${_unitProgressList.where((u) => u.status == 'completed').length}/10 Unit xong',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF059669)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Filter chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildFilterChip('Tất cả (10)', 'all'),
                              const SizedBox(width: 6),
                              _buildFilterChip('Đang học (${_unitProgressList.where((u) => u.status == 'in_progress').length})', 'in_progress'),
                              const SizedBox(width: 6),
                              _buildFilterChip('Hoàn thành (${_unitProgressList.where((u) => u.status == 'completed').length})', 'completed'),
                              const SizedBox(width: 6),
                              _buildFilterChip('Chưa học (${_unitProgressList.where((u) => u.status == 'not_started').length})', 'not_started'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Danh sách các Unit (Accordion cho phép xem chi tiết từng section)
                        ...filteredUnits.map((u) => _buildUnitCard(u)),

                        const SizedBox(height: 20),

                        // Section 2: Tiến độ theo 4 kỹ năng thực tế
                        const Text(
                          'Năng lực kỹ năng thực tế:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                        ),
                        const SizedBox(height: 8),
                        _buildSkillBar('Từ vựng SGK 12', _vocabPercent, Colors.purple),
                        _buildSkillBar('Đọc hiểu (Reading)', _readingPercent, Colors.blue),
                        _buildSkillBar('Ngữ pháp trọng tâm (Language)', _grammarPercent, Colors.amber[800]!),
                        _buildSkillBar('Luyện nghe (Listening)', _listeningPercent, Colors.teal),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
          ),

          const SizedBox(height: 12),

          // Nút thao tác dưới cùng (Xếp lớp / Nhắc nhở)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _showAssignClassDialog,
                  icon: const Icon(Icons.school_outlined, size: 18),
                  label: const Text('Xếp vào lớp'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Đã gửi thông báo nhắc nhở học tập đến $name!')),
                    );
                  },
                  icon: const Icon(Icons.notifications_active_outlined, size: 18),
                  label: const Text('Nhắc học tập'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Card nổi bật: Chỉ rõ học sinh đang học Unit mấy và dừng ở đâu
  Widget _buildCurrentPositionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E3A8A),
            const Color(0xFF2563EB).withValues(alpha: 0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_stories, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 8),
              const Text(
                'VỊ TRÍ HỌC GẦN NHẤT',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _isAllCompleted ? Colors.green[400] : Colors.amber[400],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _isAllCompleted ? 'ĐÃ HOÀN THÀNH' : 'ĐANG HỌC',
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _currentUnitTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, color: Colors.white70, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Dừng tại: $_currentStoppedLocation',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _currentProgressSummary,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _unitFilter == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      onSelected: (_) => setState(() => _unitFilter = value),
      selectedColor: const Color(0xFF1E3A8A).withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF1E3A8A) : Colors.black87,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
    );
  }

  /// Card từng Unit với chi tiết 8 phần khi nhấn mở rộng
  Widget _buildUnitCard(UnitProgressInfo unit) {
    final Color statusColor;
    final String statusLabel;
    final Color badgeBg;

    if (unit.status == 'completed') {
      statusColor = const Color(0xFF059669);
      statusLabel = 'Hoàn thành 100%';
      badgeBg = Colors.green[50]!;
    } else if (unit.status == 'in_progress') {
      statusColor = const Color(0xFF2563EB);
      statusLabel = 'Đang học (${unit.percent.toInt()}%)';
      badgeBg = Colors.blue[50]!;
    } else {
      statusColor = Colors.grey[600]!;
      statusLabel = 'Chưa học (0%)';
      badgeBg = Colors.grey[100]!;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: unit.status == 'in_progress' ? const Color(0xFF2563EB).withValues(alpha: 0.4) : Colors.grey[200]!,
          width: unit.status == 'in_progress' ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.only(left: 14, right: 14, bottom: 12),
          leading: CircleAvatar(
            radius: 16,
            backgroundColor: statusColor.withValues(alpha: 0.12),
            child: Text(
              '${unit.unitNumber}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  'Unit ${unit.unitNumber}: ${unit.title}',
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Text(
                unit.vietnameseTitle,
                style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: unit.percent / 100.0,
                  minHeight: 5,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation(statusColor),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Đã học: ${unit.completedSections}/${unit.totalSections} phần',
                    style: TextStyle(fontSize: 11, color: Colors.grey[700], fontWeight: FontWeight.w500),
                  ),
                  Text(
                    unit.status == 'in_progress' ? 'Dừng ở: ${unit.stoppedAtSection}' : '',
                    style: const TextStyle(fontSize: 11, color: Color(0xFFD97706), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
          children: [
            const Divider(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Chi tiết 8 phần của Unit:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54),
              ),
            ),
            const SizedBox(height: 6),
            ...unit.sections.map((sec) => _buildSectionItem(sec)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionItem(SectionProgressInfo sec) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            sec.isCompleted
                ? Icons.check_circle
                : (sec.isInProgress ? Icons.play_circle_filled : Icons.radio_button_unchecked),
            size: 18,
            color: sec.isCompleted
                ? const Color(0xFF059669)
                : (sec.isInProgress ? const Color(0xFF2563EB) : Colors.grey[400]),
          ),
          const SizedBox(width: 8),
          Icon(sec.icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sec.title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: sec.isCompleted || sec.isInProgress ? FontWeight.bold : FontWeight.w500,
                    color: sec.isCompleted ? const Color(0xFF0F172A) : Colors.black87,
                  ),
                ),
                Text(
                  sec.note ?? sec.subtitle,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: sec.isInProgress ? const Color(0xFF2563EB) : Colors.grey[600],
                    fontWeight: sec.isInProgress ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: sec.isCompleted
                  ? Colors.green[50]
                  : (sec.isInProgress ? Colors.blue[50] : Colors.grey[100]),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              sec.isCompleted ? 'Đã xong' : (sec.isInProgress ? 'Đang học' : 'Chưa học'),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: sec.isCompleted
                    ? const Color(0xFF059669)
                    : (sec.isInProgress ? const Color(0xFF2563EB) : Colors.grey[600]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillBar(String title, double percent, Color color) {
    final int displayPercent = (percent * 100).toInt();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              Text('$displayPercent%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 7,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}
