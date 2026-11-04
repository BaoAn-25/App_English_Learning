import 'package:flutter/material.dart';
import '../theme/components/app_button.dart';
import '../theme/components/engpass_mascot.dart';

class ReadingCompletionScreen extends StatelessWidget {
  final int unitNumber;
  final int correctCount;
  final int totalQuestions;
  final int xpEarned;
  final int currentStreak;
  final int newWordsCount;

  const ReadingCompletionScreen({
    super.key,
    required this.unitNumber,
    required this.correctCount,
    required this.totalQuestions,
    required this.xpEarned,
    this.currentStreak = 0,
    this.newWordsCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double accuracy = totalQuestions > 0 ? (correctCount / totalQuestions * 100) : 0;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121620) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              const SizedBox(height: 16),

              // Linh vật đội mũ tốt nghiệp giơ cúp vàng ăn mừng
              const EngPassMascot(
                mood: MascotMood.celebrate,
                size: 112,
              ),
              const SizedBox(height: 20),

              Text(
                'Hoàn thành Reading!',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Bạn đã hoàn thành bài luyện tập đọc hiểu với kết quả $correctCount/$totalQuestions câu đúng.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 14,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),

              // 3 Stats
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      badge: xpEarned > 0 ? '+$xpEarned' : '0',
                      label: 'XP',
                      color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                      bgColor: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.35) : const Color(0xFFEFF6FF),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      badge: '${accuracy.toInt()}%',
                      label: 'Chính xác',
                      color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A),
                      bgColor: isDark ? const Color(0xFF14532D).withValues(alpha: 0.35) : const Color(0xFFDCFCE7),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      badge: currentStreak > 0 ? '$currentStreak ngày' : '0 ngày',
                      label: 'Streak 🔥',
                      color: isDark ? const Color(0xFFFB923C) : const Color(0xFFEA580C),
                      bgColor: isDark ? const Color(0xFF7C2D12).withValues(alpha: 0.35) : const Color(0xFFFFEDD5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Banner thông báo từ mới (nếu có lưu từ thật)
              if (newWordsCount > 0)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2430) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x06000000),
                        offset: Offset(0, 2),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.collections_bookmark_rounded,
                        color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Đã lưu $newWordsCount từ mới vào sổ từ',
                              style: TextStyle(
                                fontFamily: 'BeVietnamPro',
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Các từ này sẽ được nhắc ôn tập theo lịch SRS.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 32),

              // 2 Nút hành động
              AppButton(
                label: 'Phần tiếp theo: Speaking',
                isFullWidth: true,
                variant: AppButtonVariant.primary,
                height: 52,
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 12),
              AppButton(
                label: 'Về trang Unit',
                isFullWidth: true,
                variant: AppButtonVariant.outlined,
                height: 50,
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String badge,
    required String label,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            badge,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontWeight: FontWeight.w600,
              fontSize: 11,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

