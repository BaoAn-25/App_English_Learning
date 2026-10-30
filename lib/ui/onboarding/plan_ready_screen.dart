import 'package:flutter/material.dart';
import '../../navigation/main_shell.dart';
import '../auth/register_screen.dart';
import '../theme/components/app_button.dart';

class PlanReadyScreen extends StatelessWidget {
  final double targetScore;
  final int dailyMinutes;
  final bool reminderEnabled;

  const PlanReadyScreen({
    super.key,
    required this.targetScore,
    required this.dailyMinutes,
    required this.reminderEnabled,
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
                'Prep12 đã điều chỉnh bài học theo mục tiêu và thời gian của bạn.',
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
                      badge: '${targetScore.toStringAsFixed(0)}+',
                      label: 'Điểm mục tiêu',
                    ),
                    Container(width: 1, height: 32, color: Colors.white24),
                    _buildSummaryItem(
                      badge: "$dailyMinutes'",
                      label: 'Mỗi ngày',
                    ),
                    Container(width: 1, height: 32, color: Colors.white24),
                    _buildSummaryItem(
                      badge: reminderEnabled ? '20:00' : 'Tắt',
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
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Bạn đang học với tư cách khách. Để không mất chuỗi streak và đồng bộ máy khác, hãy tạo tài khoản.',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 14),

              // Nút Vào học
              AppButton(
                label: 'Vào học ngay',
                isFullWidth: true,
                variant: AppButtonVariant.primary,
                height: 52,
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const MainShell()),
                    (route) => false,
                  );
                },
              ),
              const SizedBox(height: 8),
              AppButton(
                label: 'Tạo tài khoản để lưu tiến độ',
                isFullWidth: true,
                variant: AppButtonVariant.outlined,
                height: 48,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  );
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

