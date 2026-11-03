import 'package:flutter/material.dart';
import '../onboarding/onboarding_target_screen.dart';
import '../theme/app_tokens.dart';
import '../theme/components/app_button.dart';
import '../theme/components/prep_logo.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121620) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              // Logo
              const Align(
                alignment: Alignment.centerLeft,
                child: PrepLogo(size: 44),
              ),
              const SizedBox(height: 20),
              // Tiêu đề & phụ đề
              Text(
                'Ôn thi tiếng Anh 12,\nđúng chỗ bạn đang yếu',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Toàn bộ sách giáo khoa và đề thi THPT nằm ngay trong điện thoại. Học được cả khi không có mạng.',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 14,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              // 3 Thẻ lợi ích
              Expanded(
                child: ListView(
                  children: [
                    _buildFeatureCard(
                      isDark: isDark,
                      icon: Icons.auto_stories_rounded,
                      iconBg: isDark ? const Color(0xFF1E3A8A).withAlpha(120) : const Color(0xFFEFF6FF),
                      iconColor: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                      title: 'Học theo từng Unit trong sách',
                      subtitle: 'Bài đọc, từ vựng, ngữ pháp theo chuẩn SGK Global Success 12.',
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureCard(
                      isDark: isDark,
                      icon: Icons.track_changes_rounded,
                      iconBg: isDark ? const Color(0xFF78350F).withAlpha(120) : const Color(0xFFFEF3C7),
                      iconColor: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                      title: 'Lộ trình theo điểm mục tiêu',
                      subtitle: 'Điều chỉnh số câu và dạng bài phù hợp theo thời gian đến kỳ thi.',
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureCard(
                      isDark: isDark,
                      icon: Icons.psychology_rounded,
                      iconBg: isDark ? const Color(0xFF14532D).withAlpha(120) : const Color(0xFFDCFCE7),
                      iconColor: isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A),
                      title: 'Nhớ từ lâu bằng lặp ngắt quãng',
                      subtitle: 'Ôn tập SRS khoa học, nhớ sâu từ vựng trọng tâm kỳ thi THPT.',
                    ),
                  ],
                ),
              ),

              // 2 Nút hành động
              AppButton(
                label: 'Bắt đầu học ngay',
                isFullWidth: true,
                variant: AppButtonVariant.primary,
                height: 52,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const OnboardingTargetScreen()),
                  );
                },
              ),
              const SizedBox(height: 12),
              AppButton(
                label: 'Tôi đã có tài khoản',
                isFullWidth: true,
                variant: AppButtonVariant.outlined,
                height: 50,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Khi tiếp tục nghĩa là bạn đã đồng ý với Điều khoản của EngPass',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required bool isDark,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2430) : Colors.white,
        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x20000000) : const Color(0x08000000),
            offset: const Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 13,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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
