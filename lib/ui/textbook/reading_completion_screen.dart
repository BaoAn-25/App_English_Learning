import 'package:flutter/material.dart';
import '../theme/components/app_button.dart';

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
    final double accuracy = totalQuestions > 0 ? (correctCount / totalQuestions * 100) : 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Cúp Trophy Vàng toả sáng Duolingo
              Container(
                width: 108,
                height: 108,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFEF08A), Color(0xFFFACC15), Color(0xFFEAB308)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEAB308).withValues(alpha: 0.35),
                      offset: const Offset(0, 8),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.emoji_events_rounded,
                    size: 64,
                    color: Color(0xFF854D0E),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Hoàn thành Reading!',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Bạn đã hoàn thành bài luyện tập đọc hiểu với kết quả $correctCount/$totalQuestions câu đúng.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),

              // 3 Stats
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStatCard(
                    badge: xpEarned > 0 ? '+$xpEarned' : '0',
                    label: 'XP',
                    color: const Color(0xFF2563EB),
                    bgColor: const Color(0xFFEFF6FF),
                  ),
                  const SizedBox(width: 12),
                  _buildStatCard(
                    badge: '${accuracy.toInt()}%',
                    label: 'Chính xác',
                    color: const Color(0xFF16A34A),
                    bgColor: const Color(0xFFDCFCE7),
                  ),
                  const SizedBox(width: 12),
                  _buildStatCard(
                    badge: currentStreak > 0 ? '$currentStreak ngày' : '0 ngày',
                    label: 'Streak 🔥',
                    color: const Color(0xFFEA580C),
                    bgColor: const Color(0xFFFFEDD5),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Banner thông báo từ mới (nếu có lưu từ thật)
              if (newWordsCount > 0)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
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
                      const Icon(Icons.collections_bookmark_rounded, color: Color(0xFF2563EB), size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Đã lưu $newWordsCount từ mới vào sổ từ',
                              style: const TextStyle(
                                fontFamily: 'BeVietnamPro',
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Các từ này sẽ được nhắc ôn tập theo lịch SRS.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              const Spacer(flex: 3),

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
      width: 96,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            badge,
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

