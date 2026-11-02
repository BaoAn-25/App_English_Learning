import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../navigation/main_shell.dart';
import '../theme/components/app_button.dart';
import '../trial/trial_lesson_screen.dart';

class PlanReadyScreen extends StatelessWidget {
  final double? targetScore;
  final int dailyMinutes;
  final bool reminderEnabled;
  final String reminderTime;

  const PlanReadyScreen({
    super.key,
    this.targetScore,
    required this.dailyMinutes,
    required this.reminderEnabled,
    this.reminderTime = '20:00',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              // Icon Checkmark Duolingo
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF22C55E), width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1516A34A),
                        offset: Offset(0, 4),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.check_rounded,
                      color: Color(0xFF16A34A),
                      size: 38,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'Kế hoạch của bạn đã sẵn sàng',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'English 12 đã điều chỉnh bài học theo mục tiêu và thời gian của bạn.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 13,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 20),

              // Thẻ tóm tắt 3 thông số
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x202563EB),
                      offset: Offset(0, 4),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryItem(
                      badge: targetScore != null
                          ? (targetScore == 10.0 ? '10' : '${targetScore!.toStringAsFixed(0)}+')
                          : 'Chưa đặt',
                      label: 'Điểm mục tiêu',
                    ),
                    Container(width: 1, height: 32, color: Colors.white24),
                    _buildSummaryItem(
                      badge: "$dailyMinutes'",
                      label: 'Mỗi ngày',
                    ),
                    Container(width: 1, height: 32, color: Colors.white24),
                    _buildSummaryItem(
                      badge: reminderEnabled ? reminderTime : 'Tắt',
                      label: 'Nhắc học',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Lộ trình 3 giai đoạn
              const Text(
                'Lộ trình ba giai đoạn',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: ListView(
                  children: [
                    _buildPhaseCard(
                      step: '1',
                      title: 'Nền tảng SGK',
                      desc: 'Học từng Unit trong sách, rèn từ vựng và ngữ pháp trọng tâm.',
                      color: const Color(0xFF3B82F6),
                    ),
                    const SizedBox(height: 10),
                    _buildPhaseCard(
                      step: '2',
                      title: 'Luyện 8 dạng bài THPT',
                      desc: 'Tập trung rèn sâu các dạng hay mất điểm, có giải thích chi tiết.',
                      color: const Color(0xFFF59E0B),
                    ),
                    const SizedBox(height: 10),
                    _buildPhaseCard(
                      step: '3',
                      title: 'Luyện đề & Thi thử',
                      desc: 'Luyện đề chuẩn 40 câu 50 phút, phân tích điểm mạnh yếu tức thì.',
                      color: const Color(0xFF10B981),
                    ),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lightbulb_outline_rounded, color: Color(0xFF2563EB), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Bắt đầu ngay với bài đọc Unit 1 (Steve Jobs) để trải nghiệm phương pháp học và làm bài tập SGK thật.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF), height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Nút chính: Bắt đầu học thử
              AppButton(
                label: 'Bắt đầu học thử',
                isFullWidth: true,
                variant: AppButtonVariant.primary,
                height: 52,
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('has_completed_onboarding', true);
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const TrialLessonScreen()),
                      (route) => false,
                    );
                  }
                },
              ),
              const SizedBox(height: 10),

              // Nút phụ: Khám phá ứng dụng (mới về Trang chủ)
              AppButton(
                label: 'Khám phá ứng dụng',
                isFullWidth: true,
                variant: AppButtonVariant.outlined,
                height: 48,
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('has_completed_onboarding', true);
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const MainShell()),
                      (route) => false,
                    );
                  }
                },
              ),
              const SizedBox(height: 4),
            ],
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
            fontSize: 20,
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
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                step,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: color,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: const TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 12.5,
                    color: Color(0xFF64748B),
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
