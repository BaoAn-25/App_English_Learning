import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_repository.dart';
import '../../data/models/topic.dart';
import '../auth/auth_controller.dart';
import '../auth/register_screen.dart';
import '../auth/welcome_screen.dart';
import '../onboarding/onboarding_target_screen.dart';
import '../practice/practice_quiz_screen.dart';
import '../practice/practice_screen.dart';
import '../textbook/unit_detail_screen.dart';
import '../theme/components/app_button.dart';
import '../theme/components/sync_status_badge.dart';
import '../theme/components/prep_logo.dart';
import 'home_controller.dart';

class HomeScreen extends StatefulWidget {
  final AppRepository? repository;
  final VoidCallback? onContinueLearning;
  final ValueChanged<Topic>? onSelectTopic;

  const HomeScreen({
    super.key,
    this.repository,
    this.onContinueLearning,
    this.onSelectTopic,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    AppRepository repo;
    try {
      repo = widget.repository ?? Provider.of<AppRepository>(context, listen: false);
    } catch (_) {
      repo = AppRepository();
    }

    final auth = AuthController.instance;

    return ChangeNotifierProvider<HomeController>(
      create: (_) => HomeController(repo: repo),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          title: Row(
            children: [
              const PrepLogo(size: 34, showText: false),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'English 12',
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    'Luyện Thi THPT',
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            // Nút Khám phá Onboarding / Chào mừng
            IconButton(
              tooltip: 'Xem luồng Khách & Onboarding',
              icon: const Icon(Icons.explore_outlined, color: Color(0xFF2563EB)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                );
              },
            ),
            Consumer<HomeController>(
              builder: (context, controller, child) {
                return Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: SyncStatusBadge(
                    state: controller.syncState,
                    compact: true,
                    onRetry: () => controller.refresh(),
                  ),
                );
              },
            ),
          ],
        ),
        body: Consumer<HomeController>(
          builder: (context, controller, child) {
            if (controller.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            return RefreshIndicator(
              onRefresh: () => controller.refresh(),
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                children: [
                  // 1. Header: Lời chào, Streak & XP badge
                  _buildHeaderStats(context, controller, auth),
                  const SizedBox(height: 14),

                  // 2. Banner nhắc lưu tài khoản (nếu chưa đăng nhập)
                  if (!auth.isAuthenticated) ...[
                    _buildGuestBanner(context, controller.streak),
                    const SizedBox(height: 14),
                  ],

                  // 3. Card Đếm ngược kỳ thi THPT & Mục tiêu
                  _buildCountdownCard(context, controller, auth),
                  const SizedBox(height: 14),

                  // 4. Card Tiếp tục học
                  _buildContinueLearningCard(context, controller),
                  const SizedBox(height: 18),

                  // 5. Checklist Nhiệm vụ hôm nay
                  _buildDailyTasksCard(context, controller),
                  const SizedBox(height: 18),

                  // 6. Phím tắt nhanh
                  _buildQuickActionButtons(context),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // --- 1. Lời chào & Chỉ số Streak, XP ---
  Widget _buildHeaderStats(BuildContext context, HomeController controller, AuthController auth) {
    final streak = controller.streak > 0 ? controller.streak : auth.user.streakDays;
    final xp = controller.totalXp > 0 ? controller.totalXp : auth.user.xp;
    final name = auth.isAuthenticated ? auth.user.displayName : 'Chào bạn';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$name,',
                style: const TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const Text(
                'Hôm nay học gì?',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
        // Badge Streak Ngọn lửa Duolingo
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFFEDD5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFED7AA)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔥', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 4),
              Text(
                '$streak',
                style: const TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: Color(0xFFC2410C),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Badge XP
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt_rounded, color: Color(0xFF2563EB), size: 18),
              const SizedBox(width: 2),
              Text(
                '$xp',
                style: const TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: Color(0xFF1D4ED8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- 2. Banner nhắc nhở tạo tài khoản ---
  Widget _buildGuestBanner(BuildContext context, int streak) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  streak > 0
                      ? 'Duy trì chuỗi $streak ngày học!'
                      : 'Bắt đầu hành trình học tập!',
                  style: const TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: Color(0xFF1E40AF),
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Tạo tài khoản để không mất tiến độ.',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF3B82F6)),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RegisterScreen()),
              );
            },
            child: const Text(
              'Tạo tài khoản',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // --- 3. Card Đếm ngược kỳ thi THPT ---
  Widget _buildCountdownCard(BuildContext context, HomeController controller, AuthController auth) {
    // Tính số ngày đếm ngược từ examDate thực tế nếu có
    final rawExamDate = controller.examDate.isNotEmpty ? controller.examDate : auth.user.examDate;
    int? daysRemaining;
    bool isExpired = false;

    if (rawExamDate.isNotEmpty) {
      final parsedDate = DateTime.tryParse(rawExamDate);
      if (parsedDate != null) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final target = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
        final diff = target.difference(today).inDays;
        if (diff < 0) {
          isExpired = true;
        } else {
          daysRemaining = diff;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E40AF), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x202563EB),
            offset: Offset(0, 6),
            blurRadius: 14,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Đếm ngược kỳ thi THPT',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Mục tiêu ${auth.user.targetScore.toStringAsFixed(0)}+',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                daysRemaining != null
                    ? '$daysRemaining'
                    : (isExpired ? 'Đã qua' : 'Chưa đặt'),
                style: const TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontWeight: FontWeight.w900,
                  fontSize: 34,
                  color: Colors.white,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                daysRemaining != null
                    ? 'ngày nữa'
                    : (isExpired ? 'ngày thi' : 'ngày thi'),
                style: const TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Kế hoạch: ${auth.user.dailyMinutes} phút mỗi ngày',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const OnboardingTargetScreen()),
                  );
                },
                child: const Text(
                  'Điều chỉnh lộ trình >',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFFC53D),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- 4. Card Tiếp tục học (dựa trên LearningSession thật, không mở mặc định Reading Unit 3) ---
  Widget _buildContinueLearningCard(BuildContext context, HomeController controller) {
    final session = controller.learningSession;

    if (session == null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PracticeScreen()),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.school_outlined, color: Color(0xFF64748B), size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bắt đầu học',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Chưa có bài học dở',
                          style: TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Chọn một dạng bài luyện tập để bắt đầu',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF94A3B8), size: 16),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final isInProgress = !session.isCompleted;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isInProgress ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            offset: Offset(0, 3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () async {
            final repo = Provider.of<AppRepository>(context, listen: false);
            if (isInProgress) {
              final questions = await repo.getQuestionsByIds(session.questionIds);
              if (context.mounted && questions.isNotEmpty) {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PracticeQuizScreen(
                      title: session.lessonTitle,
                      questions: questions,
                      lessonId: session.lessonId,
                      initialIndex: session.currentQuestionIndex,
                      initialAnswers: session.selectedAnswers,
                      nextLessonTitle: session.nextLessonTitle,
                    ),
                  ),
                );
                if (context.mounted) {
                  controller.refresh();
                }
                return;
              }
            }

            if (context.mounted) {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PracticeScreen()),
              );
              if (context.mounted) {
                controller.refresh();
              }
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isInProgress ? const Color(0xFFEFF6FF) : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Icon(
                      isInProgress ? Icons.play_arrow_rounded : Icons.check_circle_outline_rounded,
                      color: isInProgress ? const Color(0xFF2563EB) : const Color(0xFF16A34A),
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isInProgress ? 'Tiếp tục bài đang làm dở' : 'Bài đã hoàn thành gần đây',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isInProgress ? const Color(0xFF2563EB) : const Color(0xFF16A34A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        session.lessonTitle,
                        style: const TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isInProgress
                            ? 'Câu ${session.currentQuestionIndex + 1}/${session.totalQuestions} • Chạm để làm tiếp'
                            : 'Đúng ${session.score}/${session.totalQuestions} câu • Gợi ý: ${session.nextLessonTitle ?? 'Luyện tập thêm'}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF94A3B8), size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- 5. Checklist Nhiệm vụ hôm nay dựa trên dữ liệu thật ---
  Widget _buildDailyTasksCard(BuildContext context, HomeController controller) {
    final dueWords = controller.dueWordsCount;
    final dueWrongs = controller.dueWrongQuestionsCount;
    final hasDailyActivity = controller.todayQuestionsDone > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            offset: Offset(0, 3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Nhiệm vụ hôm nay',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Color(0xFF0F172A),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Mục tiêu: ${controller.todayQuestionsDone}/${controller.dailyGoal} câu',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Task 1: Ôn từ vựng
          _buildTaskItem(
            title: dueWords > 0
                ? 'Ôn $dueWords từ vựng đến hạn'
                : 'Chưa có từ vựng nào đến hạn ôn',
            time: dueWords > 0 ? 'Cần ôn' : 'Trống',
            isDone: false,
            onChanged: (_) {},
          ),
          const Divider(height: 16),

          // Task 2: Câu sai
          _buildTaskItem(
            title: dueWrongs > 0
                ? 'Ôn $dueWrongs câu sai trong sổ tay'
                : 'Sổ câu sai trống',
            time: dueWrongs > 0 ? 'Cần ôn' : 'Trống',
            isDone: false,
            onChanged: (_) {},
          ),
          const Divider(height: 16),

          // Task 3: Luyện tập ngày
          _buildTaskItem(
            title: hasDailyActivity
                ? 'Đã luyện ${controller.todayQuestionsDone} câu hôm nay'
                : 'Luyện tập đạt mục tiêu ngày (${controller.dailyGoal} câu)',
            time: controller.isDailyGoalCompleted
                ? 'Hoàn thành'
                : (hasDailyActivity ? 'Đang học' : 'Chưa bắt đầu'),
            isDone: controller.isDailyGoalCompleted && hasDailyActivity,
            onChanged: (_) {},
          ),
        ],
      ),
    );
  }

  Widget _buildTaskItem({
    required String title,
    required String time,
    required bool isDone,
    required ValueChanged<bool?> onChanged,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          Checkbox(
            value: isDone,
            activeColor: const Color(0xFF16A34A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            onChanged: onChanged,
          ),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontWeight: isDone ? FontWeight.w500 : FontWeight.w600,
                fontSize: 14,
                color: isDone ? const Color(0xFF94A3B8) : const Color(0xFF1E293B),
                decoration: isDone ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isDone ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              time,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDone ? const Color(0xFF16A34A) : const Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 6. Phím tắt nhanh ---
  Widget _buildQuickActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AppButton(
            label: 'Sách giáo khoa 12',
            icon: Icons.menu_book_rounded,
            variant: AppButtonVariant.outlined,
            height: 48,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UnitDetailScreen()),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AppButton(
            label: 'Hỏi gia sư AI',
            icon: Icons.auto_awesome_rounded,
            variant: AppButtonVariant.outlined,
            height: 48,
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Gia sư AI English 12 sẵn sàng giải đáp thắc mắc bài tập của bạn!'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
