import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/interest_repository.dart';
import '../../data/models/interest_topic.dart';
import '../../navigation/main_shell.dart';
import '../auth/auth_controller.dart';
import '../interest/interest_topic_detail_screen.dart';
import '../theme/components/app_button.dart';
import '../theme/components/engpass_mascot.dart';
import '../trial/trial_lesson_screen.dart';

class PlanReadyScreen extends StatefulWidget {
  final double? targetScore;
  final int dailyMinutes;
  final bool reminderEnabled;
  final String reminderTime;
  final List<String> favoriteTopics;

  const PlanReadyScreen({
    super.key,
    this.targetScore,
    required this.dailyMinutes,
    required this.reminderEnabled,
    this.reminderTime = '20:00',
    this.favoriteTopics = const [],
  });

  @override
  State<PlanReadyScreen> createState() => _PlanReadyScreenState();
}

class _PlanReadyScreenState extends State<PlanReadyScreen> {
  InterestTopic? _matchedTopic;
  bool _isLoadingTopic = true;

  @override
  void initState() {
    super.initState();
    _loadMatchedTopic();
  }

  Future<void> _loadMatchedTopic() async {
    try {
      final userTopics = widget.favoriteTopics.isNotEmpty
          ? widget.favoriteTopics
          : AuthController.instance.user.favoriteTopics;

      final allTopics = await InterestRepository().getInterestTopics();
      if (!mounted) return;

      InterestTopic? matched;
      if (userTopics.isNotEmpty && allTopics.isNotEmpty) {
        final firstChoice = userTopics.first.toLowerCase().trim();
        for (final topic in allTopics) {
          final tTitle = topic.title.toLowerCase();
          final tVi = topic.titleVi.toLowerCase();
          final tCat = topic.categoryName.toLowerCase();
          if (tVi.contains(firstChoice) ||
              tTitle.contains(firstChoice) ||
              tCat.contains(firstChoice) ||
              (firstChoice == 'bóng đá' && topic.id == 'it_football') ||
              (firstChoice == 'game' && topic.id == 'it_esports') ||
              (firstChoice == 'công nghệ' && topic.id == 'it_tech_coding') ||
              (firstChoice == 'khoa học' && topic.id == 'it_tech_coding') ||
              (firstChoice == 'âm nhạc' && topic.id == 'it_music') ||
              (firstChoice == 'phim ảnh' && topic.id == 'it_movies') ||
              (firstChoice == 'du lịch' && topic.id == 'it_airport') ||
              (firstChoice == 'nấu ăn' && topic.id == 'it_dining') ||
              (firstChoice == 'thể thao' && topic.id == 'it_football')) {
            matched = topic;
            break;
          }
        }
      }

      // Fallback topic nếu không match hoặc allTopics rỗng
      matched ??= allTopics.isNotEmpty
          ? allTopics.first
          : const InterestTopic(
              id: 'it_cafe',
              categoryId: 'cat_food',
              categoryName: 'Ẩm thực & Đời sống',
              title: 'Coffee Shop & Milk Tea',
              titleVi: 'Quán Cafe & Trà sữa',
              iconName: 'local_cafe_rounded',
              description: 'Cách gọi đồ uống, chọn độ ngọt, tráng miệng và thanh toán sành điệu',
              order: 4,
            );

      setState(() {
        _matchedTopic = matched;
        _isLoadingTopic = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _matchedTopic = const InterestTopic(
            id: 'it_cafe',
            categoryId: 'cat_food',
            categoryName: 'Ẩm thực & Đời sống',
            title: 'Coffee Shop & Milk Tea',
            titleVi: 'Quán Cafe & Trà sữa',
            iconName: 'local_cafe_rounded',
            description: 'Cách gọi đồ uống, chọn độ ngọt, tráng miệng và thanh toán sành điệu',
            order: 4,
          );
          _isLoadingTopic = false;
        });
      }
    }
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_completed_onboarding', true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 4),
                // Linh vật ăn mừng hoàn thành thiết lập lộ trình + Huy hiệu Checkmark
                Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.bottomRight,
                    children: [
                      const EngPassMascot(
                        mood: MascotMood.celebrate,
                        size: 76,
                      ),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF22C55E), width: 2),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.check_rounded,
                            color: Color(0xFF16A34A),
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

              Text(
                'Lộ trình của bạn đã sẵn sàng!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'EngPass đã cá nhân hóa nội dung học theo sở thích và mục tiêu của bạn.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 12.5,
                  color: isDark ? Colors.white70 : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 16),

              // Thẻ tóm tắt 3 thông số
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x252563EB),
                      offset: Offset(0, 4),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryItem(
                      badge: widget.targetScore != null
                          ? (widget.targetScore == 10.0 ? '10' : '${widget.targetScore!.toStringAsFixed(0)}+')
                          : '8.0+',
                      label: 'Điểm mục tiêu',
                    ),
                    Container(width: 1, height: 28, color: Colors.white24),
                    _buildSummaryItem(
                      badge: "${widget.dailyMinutes}'",
                      label: 'Mỗi ngày',
                    ),
                    Container(width: 1, height: 28, color: Colors.white24),
                    _buildSummaryItem(
                      badge: widget.reminderEnabled ? widget.reminderTime : 'Tắt',
                      label: 'Nhắc học',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Danh sách giai đoạn & Thẻ sở thích
              Expanded(
                child: ListView(
                  children: [
                    // Banner Chủ đề sở thích cá nhân hóa
                    if (_matchedTopic != null)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? const Color(0xFF3B82F6) : const Color(0xFF93C5FD),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withAlpha(25),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Text('🎯', style: TextStyle(fontSize: 22)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2563EB),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'SỞ THÍCH CỦA BẠN',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _matchedTopic!.titleVi,
                                    style: TextStyle(
                                      fontFamily: 'BeVietnamPro',
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _matchedTopic!.description,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                                      height: 1.3,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 14),

                    Text(
                      'Lộ trình 3 giai đoạn đồng hành',
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 10),

                    _buildPhaseCard(
                      step: '1',
                      title: 'Khởi động theo sở thích & IPA',
                      desc: 'Học từ vựng trực quan, luyện phát âm cặp âm đối lập không nhàm chán.',
                      color: const Color(0xFF2563EB),
                      isDark: isDark,
                    ),
                    const SizedBox(height: 8),
                    _buildPhaseCard(
                      step: '2',
                      title: 'Nền tảng SGK Global Success 12',
                      desc: '10 Unit trọng tâm với bài đọc và từ vựng chuẩn bám sát thi THPT.',
                      color: const Color(0xFFF59E0B),
                      isDark: isDark,
                    ),
                    const SizedBox(height: 8),
                    _buildPhaseCard(
                      step: '3',
                      title: 'Luyện đề chuẩn 40 câu 50 phút',
                      desc: 'Thi thử phân tích điểm yếu tức thì, hỗ trợ giải thích đối chiếu chi tiết.',
                      color: const Color(0xFF10B981),
                      isDark: isDark,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Nút chính: Bắt đầu học theo chủ đề sở thích
              AppButton(
                label: _isLoadingTopic
                    ? 'Đang chuẩn bị lộ trình...'
                    : 'Bắt đầu học: ${_matchedTopic?.titleVi ?? 'Khám phá sở thích'} →',
                isFullWidth: true,
                variant: AppButtonVariant.primary,
                height: 52,
                isLoading: _isLoadingTopic,
                onPressed: _matchedTopic == null
                    ? null
                    : () async {
                        final navigator = Navigator.of(context);
                        final targetTopic = _matchedTopic!;
                        await _completeOnboarding();
                        if (!mounted) return;
                        navigator.pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const MainShell()),
                          (route) => false,
                        );
                        navigator.push(
                          MaterialPageRoute(
                            builder: (_) => InterestTopicDetailScreen(topic: targetTopic),
                          ),
                        );
                      },
              ),
              const SizedBox(height: 8),

              // Nút phụ 1: Học thử SGK Unit 1
              AppButton(
                label: 'Học thử SGK Unit 1 (Steve Jobs)',
                isFullWidth: true,
                variant: AppButtonVariant.outlined,
                height: 44,
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  await _completeOnboarding();
                  if (!mounted) return;
                  navigator.pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const MainShell()),
                    (route) => false,
                  );
                  navigator.push(
                    MaterialPageRoute(builder: (_) => const TrialLessonScreen()),
                  );
                },
              ),
              const SizedBox(height: 4),

              // Nút phụ 2: Về Trang chủ
              TextButton(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  await _completeOnboarding();
                  if (!mounted) return;
                  navigator.pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const MainShell()),
                    (route) => false,
                  );
                },
                child: Text(
                  'Về Trang chủ khám phá ứng dụng',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildSummaryItem({required String badge, required String label}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          badge,
          style: const TextStyle(
            fontFamily: 'BeVietnamPro',
            fontWeight: FontWeight.w900,
            fontSize: 19,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 11,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildPhaseCard({
    required String step,
    required String title,
    required String desc,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: color.withAlpha(isDark ? 50 : 35),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                step,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: color,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 11.5,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
