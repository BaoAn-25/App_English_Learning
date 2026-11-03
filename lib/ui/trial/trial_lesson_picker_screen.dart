import 'package:flutter/material.dart';
import '../../data/app_repository.dart';
import '../../data/textbook_repository.dart';
import '../../data/trial_lesson_repository.dart';
import '../auth/auth_controller.dart';
import '../textbook/textbook_screen.dart';
import '../theme/app_tokens.dart';
import 'trial_lesson_screen.dart';

/// Màn hình danh sách chọn bài học thử dành cho người học
class TrialLessonPickerScreen extends StatefulWidget {
  final String? currentLessonId;

  const TrialLessonPickerScreen({super.key, this.currentLessonId});

  @override
  State<TrialLessonPickerScreen> createState() => _TrialLessonPickerScreenState();
}

class _TrialLessonPickerScreenState extends State<TrialLessonPickerScreen> {
  String? _completedLessonId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGuestTrialStatus();
  }

  Future<void> _loadGuestTrialStatus() async {
    final authCtrl = AuthController.instance;
    final repo = AppRepository();
    final ownerId = authCtrl.user.id.isNotEmpty
        ? authCtrl.user.id
        : await repo.getOrCreateGuestSessionId();

    final completedId = await repo.getCompletedTrialLessonId(ownerId);
    if (mounted) {
      setState(() {
        _completedLessonId = completedId;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleLessonSelect(TrialLessonData lesson) async {
    // 1. Nếu bài chưa sẵn sàng
    if (!lesson.isReady) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.edit_note_rounded, color: AppTokens.primary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Học liệu đang được số hóa',
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            '${lesson.unreadyReason}\n\nBạn có thể xem trước trang sách nguyên bản qua tính năng Đọc sách SGK.',
            style: const TextStyle(fontSize: 13.5, height: 1.45, color: Color(0xFF334155)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đóng'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTokens.primary,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  final tbRepo = TextbookRepository();
                  final book = await tbRepo.load();
                  if (!mounted) return;
                  final collection = book.collections.firstWhere(
                    (c) =>
                        c.id == 'gs12_u0${lesson.unitNumber}' ||
                        c.id == 'gs12_u${lesson.unitNumber}',
                    orElse: () => book.collections.first,
                  );
                  final readingSection = collection.sections.firstWhere(
                    (s) => (s['title'] as String).contains('Reading'),
                    orElse: () => {'page': collection.start},
                  );
                  final targetPage = readingSection['page'] as int;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TextbookReader(
                        book: book,
                        initialPage: targetPage,
                        start: collection.start,
                        end: collection.end,
                      ),
                    ),
                  );
                } catch (_) {}
              },
              child: const Text('Xem trang sách'),
            ),
          ],
        ),
      );
      return;
    }

    // 2. Mở bài học được chọn
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => TrialLessonScreen(lessonId: lesson.lessonId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lessons = TrialLessonRepository.allLessons;

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
            const Text(
              'Chọn bài học thử',
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            Text(
              'SGK Tiếng Anh 12 Global Success · ${TrialLessonRepository.instance.getReadyLessons().length} Unit sẵn sàng',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              children: [
                // Banner thông tin chính sách
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.explore_rounded, color: AppTokens.primary, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Tự do chọn bài học thử bạn yêu thích',
                              style: TextStyle(
                                fontFamily: 'BeVietnamPro',
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                                color: Color(0xFF1E40AF),
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Bạn có thể học thử bất kỳ Unit nào trong các bài đã sẵn sàng. Mỗi bài đều có bài đọc kèm tra từ, dịch đoạn và bộ câu hỏi đối chiếu SGK thực tế.',
                              style: TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.35),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Danh sách 10 Unit
                ...lessons.map((lesson) {
                  final isCurrent = widget.currentLessonId == lesson.lessonId;
                  final isCompleted = _completedLessonId == lesson.lessonId;

                  Color cardBg = Colors.white;
                  Color borderColor = const Color(0xFFE2E8F0);

                  if (isCurrent) {
                    cardBg = const Color(0xFFF0FDF4);
                    borderColor = const Color(0xFF86EFAC);
                  } else if (!lesson.isReady) {
                    cardBg = const Color(0xFFF8FAFC);
                    borderColor = const Color(0xFFE2E8F0);
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor, width: isCurrent ? 1.8 : 1.0),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x06000000),
                          offset: Offset(0, 2),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _handleLessonSelect(lesson),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: lesson.isReady
                                        ? const Color(0xFFEFF6FF)
                                        : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Unit ${lesson.unitNumber}',
                                    style: TextStyle(
                                      fontFamily: 'BeVietnamPro',
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11.5,
                                      color: lesson.isReady
                                          ? AppTokens.primary
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    lesson.unitTitle,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (lesson.isReady)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Sẵn sàng',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF15803D),
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Đang biên soạn',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              lesson.lessonTitle,
                              style: TextStyle(
                                fontFamily: 'BeVietnamPro',
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: lesson.isReady
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              lesson.isReady
                                  ? '${lesson.textbookSource} • ${lesson.questions.length} câu hỏi • ${lesson.estimatedDuration}'
                                  : lesson.unreadyReason,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                            if (isCurrent) ...[
                              const SizedBox(height: 8),
                              const Row(
                                children: [
                                  Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 16),
                                  SizedBox(width: 4),
                                  Text(
                                    'Bài học đang chọn hiện tại',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF15803D),
                                    ),
                                  ),
                                ],
                              ),
                            ] else if (isCompleted) ...[
                              const SizedBox(height: 8),
                              const Row(
                                children: [
                                  Icon(Icons.task_alt_rounded, color: Color(0xFF2563EB), size: 16),
                                  SizedBox(width: 4),
                                  Text(
                                    'Đã hoàn thành (Có thể xem lại kết quả)',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1D4ED8),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 20),
              ],
            ),
    );
  }
}
