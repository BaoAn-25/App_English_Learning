import '../textbook/book_practice_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_repository.dart';
import '../../data/models/question.dart';
import '../../data/rbac_proctor_ai_service.dart';
import 'mock_exam_screen.dart';
import 'practice_history_screen.dart';
import 'practice_quiz_screen.dart';
import 'services/exam_builder_service.dart';
import 'supervised_exam_screen.dart';
import 'widgets/adaptive_learning_section.dart';
import 'wrong_book_screen.dart';

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  final GlobalKey<AdaptiveLearningSectionState> _adaptiveKey =
      GlobalKey<AdaptiveLearningSectionState>();

  List<SupervisedExamModel> _supervisedExams = [];

  @override
  void initState() {
    super.initState();
    _loadSupervisedExams();
  }

  Future<void> _loadSupervisedExams() async {
    try {
      final exams = await RbacProctorAiService.instance.getSupervisedExams();
      if (mounted) {
        setState(() => _supervisedExams = exams.where((e) => e.isActive).toList());
      }
    } catch (_) {}
  }

  static const Map<String, _TypeInfo> _questionTypeDetails = {
    'grammar': _TypeInfo(
      title: 'Ngữ pháp',
      subtitle: 'Thì động từ, câu điều kiện, mệnh đề...',
      icon: Icons.spellcheck_rounded,
    ),
    'arrange': _TypeInfo(
      title: 'Sắp xếp câu',
      subtitle: 'Sắp xếp đoạn văn, email, hội thoại logic',
      icon: Icons.sort_rounded,
    ),
    'vocab': _TypeInfo(
      title: 'Từ vựng',
      subtitle: 'Từ vựng theo chủ đề lớp 12, collocations',
      icon: Icons.auto_stories_rounded,
    ),
    'synonym_antonym': _TypeInfo(
      title: 'Đồng nghĩa - Trái nghĩa',
      subtitle: 'Tìm từ đồng nghĩa, trái nghĩa trong ngữ cảnh',
      icon: Icons.compare_arrows_rounded,
    ),
    'communication': _TypeInfo(
      title: 'Giao tiếp',
      subtitle: 'Tình huống giao tiếp và đối thoại thực tế',
      icon: Icons.forum_outlined,
    ),
    'signs': _TypeInfo(
      title: 'Biển báo',
      subtitle: 'Biển báo giao thông, thông báo nơi công cộng',
      icon: Icons.signpost_outlined,
    ),
    'cloze': _TypeInfo(
      title: 'Điền từ',
      subtitle: 'Bài đọc điền khuyết từ ngữ pháp & từ vựng',
      icon: Icons.edit_note_rounded,
    ),
    'reading': _TypeInfo(
      title: 'Đọc hiểu',
      subtitle: 'Đọc hiểu đoạn văn và trả lời câu hỏi',
      icon: Icons.article_outlined,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Luyện Theo Dạng Bài')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // Khu vực Luyện tập thích ứng thông minh
          AdaptiveLearningSection(key: _adaptiveKey),
          const SizedBox(height: 20),

          // Tiêu đề nhóm 1: Tiện ích & Thi thử
          Text(
            'Luyện thi & Tiện ích',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),

          // Card Phòng thi Giám sát Live 10s (Chống gian lận)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(
                color: Color(0xFFF97316),
                width: 1.5,
              ),
            ),
            color: const Color(0xFFFFF7ED),
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEA580C),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  title: Row(
                    children: [
                      const Text(
                        'Phòng thi Giám sát 10s',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15.5,
                          color: Color(0xFF9A3412),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    _supervisedExams.isNotEmpty
                        ? '${_supervisedExams.length} bài thi đang mở do Thầy/Cô & Admin giao'
                        : 'Làm đề thi chính thức có giám sát chống gian lận 10s',
                    style: const TextStyle(
                      color: Color(0xFFC2410C),
                      fontSize: 12,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFEA580C)),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SupervisedExamListScreen()),
                    );
                    _loadSupervisedExams();
                  },
                ),
                if (_supervisedExams.isNotEmpty) ...[
                  const Divider(height: 1, color: Color(0xFFFED7AA)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Đề thi giáo viên giao đang mở:',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF9A3412),
                          ),
                        ),
                        const SizedBox(height: 6),
                        for (final exam in _supervisedExams.take(3))
                          InkWell(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const SupervisedExamListScreen()),
                              );
                              _loadSupervisedExams();
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.assignment_outlined, size: 16, color: Color(0xFFEA580C)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      exam.title,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Vào thi',
                                      style: TextStyle(
                                        color: Color(0xFF166534),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Card Thi thử THPT
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: colorScheme.primary.withValues(alpha: 0.4),
                width: 1.2,
              ),
            ),
            color: colorScheme.primaryContainer.withValues(alpha: 0.25),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              title: Text(
                'Thi thử THPT',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                'Làm đề thi bấm giờ mô phỏng đề thi THPT',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MockExamScreen()),
                );
                if (mounted) {
                  _adaptiveKey.currentState?.reload();
                }
              },
            ),
          ),
          const SizedBox(height: 10),

          // Card Sổ câu sai
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.7),
              ),
            ),
            color: colorScheme.surface,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.bookmark_border_rounded,
                  color: Colors.amber.shade900,
                  size: 24,
                ),
              ),
              title: Text(
                'Sổ câu sai',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                'Xem lại & ôn tập các câu từng trả lời sai',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WrongBookScreen()),
                );
                if (mounted) {
                  _adaptiveKey.currentState?.reload();
                }
              },
            ),
          ),
          const SizedBox(height: 24),

          const SizedBox(height: 10),

          // Card Ôn tập theo Sách
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.7),
              ),
            ),
            color: colorScheme.surface,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.teal.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.menu_book_rounded,
                  color: Colors.teal.shade900,
                  size: 24,
                ),
              ),
              title: Text(
                'Ôn tập theo SGK 12',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                'Luyện từ vựng bám sát 10 Unit Global Success 12',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BookPracticeScreen()),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Tiêu đề nhóm 2: 8 Dạng câu hỏi tốt nghiệp
          Text(
            '8 Dạng câu hỏi ôn thi tốt nghiệp',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),

          // Danh sách 8 dạng bài
          ..._questionTypeDetails.entries.map((entry) {
            final type = entry.key;
            final info = entry.value;

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
              color: colorScheme.surface,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(info.icon, color: colorScheme.primary, size: 22),
                ),
                title: Text(
                  info.title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  info.subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          QuestionListScreen(type: type, title: info.title),
                    ),
                  );
                  if (mounted) {
                    _adaptiveKey.currentState?.reload();
                  }
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _TypeInfo {
  final String title;
  final String subtitle;
  final IconData icon;

  const _TypeInfo({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

class QuestionListScreen extends StatefulWidget {
  final String type;
  final String title;

  const QuestionListScreen({
    super.key,
    required this.type,
    required this.title,
  });

  @override
  State<QuestionListScreen> createState() => _QuestionListScreenState();
}

class _QuestionListScreenState extends State<QuestionListScreen> {
  late Future<List<Question>> questionsFuture;

  @override
  void initState() {
    super.initState();
    questionsFuture = context.read<AppRepository>().getQuestionsByType(
      widget.type,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: FutureBuilder<List<Question>>(
        future: questionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Lỗi tải câu hỏi: ${snapshot.error}'));
          }

          final questions = snapshot.data ?? [];

          if (questions.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 64,
                    color: colorScheme.outline,
                  ),
                  const SizedBox(height: 12),
                  const Text('Chưa có câu hỏi cho dạng bài này.'),
                ],
              ),
            );
          }

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(
                        alpha: 0.6,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.quiz_rounded,
                      size: 42,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Có ${questions.length} câu hỏi trong ngân hàng đề',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Mỗi lượt làm gồm 10 câu ngẫu nhiên',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        final quizQuestions = ExamBuilderService()
                            .buildPracticeSet(questions, count: 10);

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PracticeQuizScreen(
                              title: widget.title,
                              questions: quizQuestions,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Bắt đầu luyện tập'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PracticeHistoryScreen(
                              type: widget.type,
                              title: widget.title,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.history_rounded),
                      label: const Text('Xem lịch sử luyện tập'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
