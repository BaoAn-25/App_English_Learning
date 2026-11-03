import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_repository.dart';
import '../../data/models/topic.dart';
import '../../data/trial_lesson_repository.dart';
import '../ai/ai_tutor_sheet.dart';
import '../auth/auth_controller.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';
import '../auth/welcome_screen.dart';
import '../onboarding/onboarding_target_screen.dart';
import '../practice/practice_quiz_screen.dart';
import '../practice/practice_screen.dart';
import '../textbook/review_detail_screen.dart';
import '../textbook/textbook_hub_screen.dart';
import '../textbook/unit_detail_screen.dart';
import '../theme/app_tokens.dart';
import '../theme/components/app_button.dart';
import '../theme/components/sync_status_badge.dart';
import '../theme/components/prep_logo.dart';
import '../pronunciation/pronunciation_screen.dart';
import '../interest/interest_topics_screen.dart';
import '../trial/trial_lesson_picker_screen.dart';
import '../trial/trial_lesson_screen.dart';
import 'home_controller.dart';

class RoadmapUnitItem {
  final int number; // 0 for Review
  final int reviewNumber; // 1, 2, 3, 4 if review
  final String title;
  final String bookPages;
  final String readingTitle;
  final String scopeDescription;

  const RoadmapUnitItem({
    required this.number,
    this.reviewNumber = 0,
    required this.title,
    required this.bookPages,
    required this.readingTitle,
    required this.scopeDescription,
  });

  bool get isReview => reviewNumber > 0;
}

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
                    'EngPass',
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
                  // 1. Thông báo lỗi tải dữ liệu nếu có
                  if (controller.hasError) ...[
                    _buildErrorBanner(context, controller),
                    const SizedBox(height: 12),
                  ],

                  // 2. Header: GB LỚP 12, Streak, XP thực tế
                  _buildHeaderStats(context, controller, auth),
                  const SizedBox(height: 12),

                  // 3. Banner dành cho Khách (Lưu trên thiết bị)
                  if (!auth.isAuthenticated) ...[
                    _buildGuestBanner(context, controller),
                    const SizedBox(height: 14),
                  ],

                  // 3.5. Khu vực Khám phá Duolingo x Quizlet (Phát âm IPA & Chủ đề sở thích)
                  _buildExploreDuolingoHub(context),
                  const SizedBox(height: 16),

                  // 4. Khối Tiếp tục học / Bài học dở (chỉ hiện khi có phiên học thực tế)
                  if (controller.learningSession != null) ...[
                    _buildContinueLearningCard(context, controller, auth),
                    const SizedBox(height: 16),
                  ],

                  // 5. Lộ trình học tập SGK Tiếng Anh 12 chuẩn mục lục
                  _buildRoadmapTimeline(context, controller, auth),
                  const SizedBox(height: 16),

                  // 6. Card Đếm ngược kỳ thi THPT & Mục tiêu
                  _buildCountdownCard(context, controller, auth),
                  const SizedBox(height: 14),

                  // 7. Checklist Nhiệm vụ hôm nay
                  _buildDailyTasksCard(context, controller, auth),
                  const SizedBox(height: 14),

                  // 8. Phím tắt nhanh
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

  // --- Khu vực Khám phá Duolingo x Quizlet (Phát âm IPA & Chủ đề sở thích) ---
  Widget _buildExploreDuolingoHub(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Góc luyện tập & Khám phá',
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: Color(0xFF0F172A),
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const InterestTopicsScreen()),
                );
              },
              child: const Text(
                'Xem tất cả >',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  color: Color(0xFF2563EB),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            // Card 1: Phát âm IPA 44 âm (Thiết kế sáng đồng bộ EngPass)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PronunciationScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0C0F172A),
                        offset: Offset(0, 4),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.mic_none_rounded, color: Color(0xFF0284C7), size: 22),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Phát âm IPA',
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontWeight: FontWeight.w900,
                          fontSize: 14.5,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        '44 âm & Cặp đối lập',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBAE6FD)),
                        ),
                        child: const Text(
                          '+10 KN',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5, color: Color(0xFF0284C7)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Card 2: Chủ đề sở thích (Bóng đá, Cafe, Du lịch...)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const InterestTopicsScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0C0F172A),
                        offset: Offset(0, 4),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.sports_soccer_rounded, color: Color(0xFFD97706), size: 22),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Theo sở thích',
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontWeight: FontWeight.w900,
                          fontSize: 14.5,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Bóng đá, Cafe, Du lịch...',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: const Text(
                          'Flashcard & Match',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5, color: Color(0xFF2563EB)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- Banner thông báo lỗi tải dữ liệu ---
  Widget _buildErrorBanner(BuildContext context, HomeController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppTokens.errorRed, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              controller.errorMessage ?? 'Không thể tải dữ liệu trang chủ',
              style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
            ),
          ),
          TextButton(
            onPressed: () => controller.refresh(),
            child: const Text(
              'Thử lại',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppTokens.errorRed),
            ),
          ),
        ],
      ),
    );
  }

  // --- 1. Header: GB LỚP 12, Streak, XP thực tế (Không gán tim cố định) ---
  Widget _buildHeaderStats(BuildContext context, HomeController controller, AuthController auth) {
    // Không dùng fallback > 0 để tránh hiển thị nhầm dữ liệu tài khoản cũ khi điểm/streak thực tế là 0
    final streak = controller.streak;
    final xp = controller.totalXp;

    return Row(
      children: [
        // Badge Lớp 12 xanh lá
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFDCFCE7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF86EFAC)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'GB ',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  color: Color(0xFF15803D),
                ),
              ),
              Text(
                'LỚP 12',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  color: Color(0xFF16A34A),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        // Ngọn lửa Streak thực tế
        Row(
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
        const SizedBox(width: 14),
        // Tia sét XP thực tế
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt_rounded, size: 18, color: Color(0xFFEAB308)),
            const SizedBox(width: 2),
            Text(
              '$xp XP',
              style: const TextStyle(
                fontFamily: 'BeVietnamPro',
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: Color(0xFF854D0E),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- 2. Banner nhắc lưu tài khoản (Dành cho Khách) ---
  Widget _buildGuestBanner(BuildContext context, HomeController controller) {
    final xp = controller.totalXp;
    final words = controller.savedWordsCount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.storage_rounded, size: 18, color: AppTokens.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  words > 0 || xp > 0
                      ? 'Lưu trên thiết bị: $xp XP${words > 0 ? ' • $words từ đã lưu' : ''}'
                      : 'Dữ liệu học tập đang được lưu an toàn trên thiết bị',
                  style: const TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Đăng ký tài khoản để đồng bộ kết quả học lên máy chủ đám mây và mở khóa đầy đủ 10 Unit.',
            style: TextStyle(
              fontSize: 11.5,
              color: Color(0xFF475569),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.auto_stories_rounded, size: 14),
                label: const Text('Học thử'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTokens.primary,
                  side: const BorderSide(color: AppTokens.primary),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TrialLessonPickerScreen()),
                  );
                },
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 14),
                label: const Text('Đăng ký'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTokens.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  );
                },
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                child: const Text(
                  'Đăng nhập >',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: AppTokens.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- 4. Lộ trình học tập SGK 12 (Roadmap chuẩn mục lục) ---
  Widget _buildRoadmapTimeline(BuildContext context, HomeController controller, AuthController auth) {
    final isStudent = auth.isAuthenticated && !auth.user.isGuest;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Lộ trình SGK Tiếng Anh 12',
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: Color(0xFF0F172A),
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.menu_book_rounded, size: 16),
              label: const Text('Xem Sách', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TextbookHubScreen()),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        ..._roadmapItems.map((item) {
          if (item.isReview) {
            return _buildReviewRoadmapCard(context, item, isStudent, controller);
          } else {
            return _buildUnitRoadmapCard(context, item, isStudent, controller);
          }
        }),
      ],
    );
  }

  Widget _buildUnitRoadmapCard(
    BuildContext context,
    RoadmapUnitItem item,
    bool isStudent,
    HomeController controller,
  ) {
    final progress = controller.getUnitProgress(item.number);
    final isCompleted = progress.isCompleted;
    final isStarted = progress.isStarted;

    // Màu nền trực quan phản ánh trạng thái thực tế của Unit
    final Color cardBg = isCompleted
        ? const Color(0xFF15803D)
        : (isStarted
            ? const Color(0xFF1E40AF)
            : const Color(0xFF334155));

    final lesson = TrialLessonRepository.instance.getLessonByUnit(item.number);
    final hasTrialReady = lesson != null && lesson.isReady;

    return Column(
      children: [
        // Thẻ Unit chính
        Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: cardBg.withAlpha(60),
                offset: const Offset(0, 4),
                blurRadius: 10,
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
                      unitNumber: item.number,
                      unitTitle: item.title.replaceAll(RegExp(r'^Unit \d+:\s*'), ''),
                      unitTopic: item.readingTitle,
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(isStudent ? 40 : 30),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isStudent
                                ? 'CHƯƠNG TRÌNH SGK 12'
                                : (hasTrialReady ? 'CÓ BÀI HỌC THỬ' : 'SGK 12'),
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        Icon(
                          isCompleted
                              ? Icons.emoji_events_rounded
                              : (isStarted ? Icons.play_circle_outline_rounded : Icons.menu_book_rounded),
                          color: isCompleted
                              ? const Color(0xFFFBBF24)
                              : Colors.white.withAlpha(220),
                          size: 24,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.bookPages} • Bài đọc: ${item.readingTitle}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.white.withAlpha(220),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(40),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 14, color: Colors.white70),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item.scopeDescription,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Nút tròn kết nối lộ trình với trạng thái thật
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Container(
                width: 2,
                height: 14,
                color: const Color(0xFFCBD5E1),
              ),
              InkWell(
                onTap: () {
                  if (!isStudent && hasTrialReady) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TrialLessonScreen(lessonId: lesson.lessonId),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UnitDetailScreen(
                          unitNumber: item.number,
                          unitTitle: item.title.replaceAll(RegExp(r'^Unit \d+:\s*'), ''),
                          unitTopic: item.readingTitle,
                        ),
                      ),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(30),
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? const Color(0xFF22C55E)
                            : (isStarted
                                ? const Color(0xFF2563EB)
                                : const Color(0xFF0F172A)),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (isCompleted
                                    ? const Color(0xFF22C55E)
                                    : (isStarted ? const Color(0xFF2563EB) : const Color(0xFF0F172A)))
                                .withAlpha(80),
                            offset: const Offset(0, 3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Icon(
                        isCompleted
                            ? Icons.check_rounded
                            : (isStarted ? Icons.play_arrow_rounded : (isStudent ? Icons.arrow_forward_rounded : Icons.auto_stories_rounded)),
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isCompleted
                              ? const Color(0xFF86EFAC)
                              : (isStarted ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0)),
                        ),
                      ),
                      child: Text(
                        isCompleted
                            ? 'Ôn lại'
                            : (isStarted
                                ? 'Tiếp tục'
                                : (isStudent ? 'Bắt đầu' : 'Học thử')),
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: isCompleted
                              ? const Color(0xFF15803D)
                              : (isStarted ? const Color(0xFF1D4ED8) : const Color(0xFF1E293B)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isCompleted
                          ? 'Đã hoàn thành ${progress.completedSections}/${progress.totalSections} phần'
                          : (isStarted
                              ? 'Đang học (${progress.completedSections}/${progress.totalSections} phần)'
                              : (isStudent ? '${progress.totalSections} phần SGK' : 'Bài đọc có hướng dẫn')),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Container(
                width: 2,
                height: 14,
                color: const Color(0xFFCBD5E1),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewRoadmapCard(
    BuildContext context,
    RoadmapUnitItem item,
    bool isStudent,
    HomeController controller,
  ) {
    final progress = controller.getReviewProgress(item.reviewNumber);
    final isCompleted = progress.isCompleted;
    final isStarted = progress.isStarted;

    String actionLabel = isCompleted ? 'Ôn lại' : (isStarted ? 'Tiếp tục' : 'Bắt đầu');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3730A3), Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x203730A3),
            offset: Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(50),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCompleted ? Icons.check_circle_rounded : Icons.military_tech_rounded,
              color: isCompleted ? const Color(0xFF86EFAC) : Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBBF24),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'ĐIỂM MỐC ÔN TẬP SGK (${item.bookPages})',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF78350F),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.title,
                  style: const TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.scopeDescription,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.white.withAlpha(220),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF4338CA),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              // Quyền truy cập Review: Học viên hoặc Review 1 (mở cho trải nghiệm)
              if (isStudent || item.reviewNumber == 1) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReviewDetailScreen(reviewNumber: item.reviewNumber),
                  ),
                );
              } else {
                _showLockedDialog(context);
              }
            },
            child: Text(
              actionLabel,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  void _showLockedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.school_rounded, color: AppTokens.primary, size: 24),
            SizedBox(width: 8),
            Text('Nội dung dành cho Học viên', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text(
          'Bạn đang trải nghiệm ở chế độ Khách (được làm các bài đọc hiểu học thử trong 10 Unit).\n\nHãy đăng ký tài khoản Học viên hoàn toàn miễn phí để mở khóa toàn bộ các phần bài học, bài tập ôn tập Review và đồng bộ kết quả học tập!',
          style: TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF334155)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Để sau'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTokens.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RegisterScreen()),
              );
            },
            child: const Text('Đăng ký ngay', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static const List<RoadmapUnitItem> _roadmapItems = [
    RoadmapUnitItem(
      number: 1,
      title: 'Unit 1: Life Stories We Admire',
      bookPages: 'Trang in 8–19',
      readingTitle: 'Steve Jobs: Life and Achievements',
      scopeDescription: '9 phần SGK • Bài đọc tương tác Activity 2 (5 câu hỏi)',
    ),
    RoadmapUnitItem(
      number: 2,
      title: 'Unit 2: A Multicultural World',
      bookPages: 'Trang in 20–31',
      readingTitle: 'The Effects of Globalisation on Cultural Diversity',
      scopeDescription: '9 phần SGK • Bài đọc tương tác Activity 2 (5 câu hỏi)',
    ),
    RoadmapUnitItem(
      number: 3,
      title: 'Unit 3: Green Living',
      bookPages: 'Trang in 32–43',
      readingTitle: 'Go Green with Plastics!',
      scopeDescription: '9 phần SGK • Bài đọc tương tác Activity 2 (5 câu hỏi)',
    ),
    RoadmapUnitItem(
      number: 0,
      reviewNumber: 1,
      title: 'Review 1 (Units 1 - 3)',
      bookPages: 'Trang in 44–47',
      readingTitle: 'Ôn tập Language & 4 Skills Units 1 - 3',
      scopeDescription: '15 câu hỏi trắc nghiệm & bài tập viết luận SGK',
    ),
    RoadmapUnitItem(
      number: 4,
      title: 'Unit 4: Urbanisation',
      bookPages: 'Trang in 48–59',
      readingTitle: 'Ha Noi: Then and Now',
      scopeDescription: '9 phần SGK • Bài đọc tương tác Activity 2 (5 câu hỏi)',
    ),
    RoadmapUnitItem(
      number: 5,
      title: 'Unit 5: The World of Work',
      bookPages: 'Trang in 60–71',
      readingTitle: 'Job Advertisements',
      scopeDescription: '9 phần SGK • Bài đọc tương tác Activity 2 (5 câu hỏi)',
    ),
    RoadmapUnitItem(
      number: 0,
      reviewNumber: 2,
      title: 'Review 2 (Units 4 - 5)',
      bookPages: 'Trang in 72–75',
      readingTitle: 'Ôn tập Language & 4 Skills Units 4 - 5',
      scopeDescription: '15 câu hỏi trắc nghiệm & bài tập viết luận SGK',
    ),
    RoadmapUnitItem(
      number: 6,
      title: 'Unit 6: Artificial Intelligence',
      bookPages: 'Trang in 76–87',
      readingTitle: 'AI Applications in Education',
      scopeDescription: '9 phần SGK • Bài đọc tương tác Activity 2 (5 câu hỏi)',
    ),
    RoadmapUnitItem(
      number: 7,
      title: 'Unit 7: The World of Mass Media',
      bookPages: 'Trang in 88–99',
      readingTitle: 'Digital Media vs. Traditional Media',
      scopeDescription: '9 phần SGK • Bài đọc tương tác Activity 2 (5 câu hỏi)',
    ),
    RoadmapUnitItem(
      number: 8,
      title: 'Unit 8: Wildlife Conservation',
      bookPages: 'Trang in 100–111',
      readingTitle: 'Wildlife Conservation News',
      scopeDescription: '9 phần SGK • Bài đọc tương tác Activity 2 (5 câu hỏi)',
    ),
    RoadmapUnitItem(
      number: 0,
      reviewNumber: 3,
      title: 'Review 3 (Units 6 - 8)',
      bookPages: 'Trang in 112–115',
      readingTitle: 'Ôn tập Language & 4 Skills Units 6 - 8',
      scopeDescription: '15 câu hỏi trắc nghiệm & bài tập viết luận SGK',
    ),
    RoadmapUnitItem(
      number: 9,
      title: 'Unit 9: Career Paths',
      bookPages: 'Trang in 116–127',
      readingTitle: 'Career Experts',
      scopeDescription: '9 phần SGK • Bài đọc tương tác Activity 2 (5 câu hỏi)',
    ),
    RoadmapUnitItem(
      number: 10,
      title: 'Unit 10: Lifelong Learning',
      bookPages: 'Trang in 128–139',
      readingTitle: 'Head Teacher',
      scopeDescription: '9 phần SGK • Bài đọc tương tác Activity 2 (5 câu hỏi)',
    ),
    RoadmapUnitItem(
      number: 0,
      reviewNumber: 4,
      title: 'Review 4 (Units 9 - 10)',
      bookPages: 'Trang in 140–143',
      readingTitle: 'Ôn tập tổng kết toàn bộ SGK Tiếng Anh 12',
      scopeDescription: 'Tổng hợp ngữ pháp trọng tâm & bài tập viết luận SGK',
    ),
  ];

  // --- 3. Card Đếm ngược kỳ thi THPT (tự thu gọn nếu chưa đặt ngày thi) ---
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

    // Nếu chưa đặt ngày thi: thu gọn thẻ đếm ngược, giữ đường dẫn chỉnh mục tiêu ở vị trí phụ
    if (rawExamDate.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.calendar_month_rounded, color: AppTokens.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Kỳ thi THPT: Chưa đặt ngày thi',
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    auth.user.hasConfirmedTargetScore
                        ? 'Mục tiêu: ${auth.user.targetScore == 10.0 ? '10' : '${auth.user.targetScore!.toStringAsFixed(0)}+'} đ • Kế hoạch: ${auth.user.dailyMinutes}p/ngày'
                        : 'Mục tiêu: Chưa chọn • Kế hoạch: ${auth.user.dailyMinutes}p/ngày',
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OnboardingTargetScreen(
                      initialTargetScore: auth.user.hasConfirmedTargetScore ? auth.user.targetScore : null,
                      autoLoadSavedSettings: false,
                    ),
                  ),
                );
              },
              child: const Text(
                'Thiết lập >',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  color: AppTokens.primary,
                ),
              ),
            ),
          ],
        ),
      );
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
                  auth.user.hasConfirmedTargetScore
                      ? 'Mục tiêu ${auth.user.targetScore == 10.0 ? '10' : '${auth.user.targetScore!.toStringAsFixed(0)}+'}'
                      : 'Chưa chọn mục tiêu',
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
                    MaterialPageRoute(
                      builder: (_) => OnboardingTargetScreen(
                        initialTargetScore: auth.user.hasConfirmedTargetScore ? auth.user.targetScore : null,
                        autoLoadSavedSettings: false,
                      ),
                    ),
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

  // --- 4. Card Bài học thử / Tiếp tục học (ưu tiên trải nghiệm học thử của khách) ---
  Widget _buildContinueLearningCard(
    BuildContext context,
    HomeController controller,
    AuthController auth,
  ) {
    final session = controller.learningSession;

    // A. DÀNH CHO KHÁCH CHƯA ĐĂNG NHẬP
    if (!auth.isAuthenticated) {
      final isTrialSession = session != null &&
          (session.lessonType == 'trial' || session.lessonId.startsWith('trial_'));

      // 1. Khách đang làm dở bài thử (in_progress)
      if (isTrialSession && session.isInProgress) {
        final lesson = TrialLessonRepository.instance.getLessonById(session.lessonId) ??
            TrialLessonRepository.instance.getDefaultLesson();

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF93C5FD), width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0E2563EB),
                offset: Offset(0, 4),
                blurRadius: 10,
              ),
            ],
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'TIẾP TỤC BÀI HỌC THỬ (UNIT ${lesson.unitNumber})',
                      style: const TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        color: AppTokens.primary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Câu ${session.currentQuestionIndex + 1}/${session.totalQuestions}',
                    style: const TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: AppTokens.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                lesson.lessonTitle,
                style: const TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${lesson.textbookSource} • ${lesson.activityName}',
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),
              AppButton(
                label: 'Tiếp tục làm câu ${session.currentQuestionIndex + 1}',
                isFullWidth: true,
                variant: AppButtonVariant.primary,
                height: 46,
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TrialLessonScreen(
                        lessonId: lesson.lessonId,
                        initialStep: 1,
                        initialQuestionIndex: session.currentQuestionIndex,
                        initialAnswers: session.selectedAnswers,
                      ),
                    ),
                  );
                  if (context.mounted) {
                    controller.refresh();
                  }
                },
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  icon: const Icon(Icons.swap_horiz_rounded, size: 16, color: AppTokens.primary),
                  label: const Text(
                    'Đổi sang bài học thử khác',
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color: AppTokens.primary,
                    ),
                  ),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TrialLessonPickerScreen(currentLessonId: lesson.lessonId),
                      ),
                    );
                    if (context.mounted) {
                      controller.refresh();
                    }
                  },
                ),
              ),
            ],
          ),
        );
      }

      // 2. Khách đã hoàn thành bài thử (completed)
      if (isTrialSession && session.isCompleted) {
        final lesson = TrialLessonRepository.instance.getLessonById(session.lessonId) ??
            TrialLessonRepository.instance.getDefaultLesson();
        final score = session.score != null
            ? (session.score! / session.totalQuestions * 10.0)
            : 0.0;
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                offset: Offset(0, 4),
                blurRadius: 10,
              ),
            ],
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 16),
                        SizedBox(width: 4),
                        Text(
                          'ĐÃ HOÀN THÀNH BÀI THỬ',
                          style: TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${score.toStringAsFixed(1)} / 10.0 đ',
                    style: const TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: Color(0xFF15803D),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Unit ${lesson.unitNumber}: ${lesson.lessonTitle}',
                style: const TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Đúng ${session.score}/${session.totalQuestions} câu theo SGK. Tạo tài khoản để mở khóa toàn bộ 10 Unit.',
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Xem lại kết quả',
                      variant: AppButtonVariant.primary,
                      height: 44,
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TrialLessonScreen(
                              lessonId: lesson.lessonId,
                              initialStep: 2,
                              initialAnswers: session.selectedAnswers,
                            ),
                          ),
                        );
                        if (context.mounted) {
                          controller.refresh();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppButton(
                      label: 'Ôn lại bài',
                      variant: AppButtonVariant.outlined,
                      height: 44,
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TrialLessonScreen(
                              lessonId: lesson.lessonId,
                              initialStep: 0,
                            ),
                          ),
                        );
                        if (context.mounted) {
                          controller.refresh();
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  icon: const Icon(Icons.explore_outlined, size: 16, color: AppTokens.primary),
                  label: const Text(
                    'Xem danh sách 10 Unit (Học thử hoặc đăng ký)',
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color: AppTokens.primary,
                    ),
                  ),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TrialLessonPickerScreen(currentLessonId: lesson.lessonId),
                      ),
                    );
                    if (context.mounted) {
                      controller.refresh();
                    }
                  },
                ),
              ),
            ],
          ),
        );
      }

      // 3. Khách chưa bắt đầu bài thử (mặc định đề xuất Unit 1 nhưng cho chọn bài khác)
      final defaultLesson = TrialLessonRepository.instance.getDefaultLesson();
      return Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E40AF), Color(0xFF2563EB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x252563EB),
              offset: Offset(0, 6),
              blurRadius: 14,
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(50),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.stars_rounded, color: Color(0xFFFFC53D), size: 16),
                      SizedBox(width: 4),
                      Text(
                        'BÀI HỌC THỬ ĐẦU TIÊN',
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                const Text(
                  'SGK Tiếng Anh 12',
                  style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Unit ${defaultLesson.unitNumber}: ${defaultLesson.lessonTitle}',
              style: const TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Đọc hiểu tương tác có hỗ trợ tra từ, dịch đoạn và làm bài tập đọc hiểu Activity 2 chuẩn SGK Global Success 12.',
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.white70,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1D4ED8),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => TrialLessonScreen(lessonId: defaultLesson.lessonId)),
                );
                if (context.mounted) {
                  controller.refresh();
                }
              },
              child: const Text(
                'Học thử ngay',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: InkWell(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TrialLessonPickerScreen(),
                    ),
                  );
                  if (context.mounted) {
                    controller.refresh();
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.explore_outlined, size: 16, color: Color(0xFFFFC53D)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Chọn bài học thử khác (${TrialLessonRepository.instance.getReadyLessons().length} Unit sẵn sàng) >',
                          style: const TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            color: Color(0xFFFFC53D),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // B. DÀNH CHO HỌC VIÊN ĐÃ ĐĂNG NHẬP
    if (session == null) {
      final defaultLesson = TrialLessonRepository.instance.getDefaultLesson();
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF93C5FD), width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0E2563EB),
              offset: Offset(0, 4),
              blurRadius: 10,
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.school_rounded, color: AppTokens.primary, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'LỘ TRÌNH HỌC VIÊN SGK 12',
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          color: AppTokens.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                const Text(
                  '10 Unit chuẩn SGK',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Unit ${defaultLesson.unitNumber}: ${defaultLesson.unitTitle}',
              style: const TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${defaultLesson.lessonTitle} · Đầy đủ bài đọc tương tác, từ vựng và ngữ pháp trọng tâm.',
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.35),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Học bài đọc hiểu',
                    icon: Icons.menu_book_rounded,
                    variant: AppButtonVariant.primary,
                    height: 44,
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TrialLessonScreen(lessonId: defaultLesson.lessonId),
                        ),
                      );
                      if (context.mounted) controller.refresh();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppButton(
                    label: 'Chi tiết Unit',
                    icon: Icons.arrow_forward_rounded,
                    variant: AppButtonVariant.outlined,
                    height: 44,
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UnitDetailScreen(
                            unitNumber: defaultLesson.unitNumber,
                            unitTitle: defaultLesson.unitTitle,
                          ),
                        ),
                      );
                      if (context.mounted) controller.refresh();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Center(
              child: TextButton.icon(
                icon: const Icon(Icons.explore_outlined, size: 16, color: AppTokens.primary),
                label: const Text(
                  'Chọn bài học từ toàn bộ 10 Unit SGK >',
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: AppTokens.primary,
                  ),
                ),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TextbookHubScreen(),
                    ),
                  );
                  if (context.mounted) controller.refresh();
                },
              ),
            ),
          ],
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
  Widget _buildDailyTasksCard(
    BuildContext context,
    HomeController controller,
    AuthController auth,
  ) {
    final dueWords = controller.dueWordsCount;
    final dueWrongs = controller.dueWrongQuestionsCount;
    final hasDailyActivity = controller.todayQuestionsDone > 0;
    final session = controller.learningSession;

    // Nếu là khách và chưa có dữ liệu từ vựng / câu sai cần ôn
    if (!auth.isAuthenticated && dueWords == 0 && dueWrongs == 0 && !hasDailyActivity) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.assignment_outlined, color: Color(0xFF64748B), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nhiệm vụ hôm nay',
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    session != null && session.isCompleted
                        ? 'Bạn đã hoàn thành bài học thử hôm nay! Hãy tạo tài khoản để làm thêm nhiệm vụ mới.'
                        : 'Hoàn thành bài học thử đầu tiên để bắt đầu ghi nhận từ vựng và câu sai cần ôn.',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

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
                MaterialPageRoute(builder: (_) => const TextbookHubScreen()),
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
              AiTutorSheet.show(
                context,
                unitNumber: 1,
                unitTitle: 'Life Stories We Admire',
                sectionTitle: 'Hỏi đáp bài học',
              );
            },
          ),
        ),
      ],
    );
  }
}
