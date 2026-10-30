import 'package:flutter/material.dart';
import '../auth/auth_controller.dart';
import '../theme/components/app_button.dart';
import 'onboarding_schedule_screen.dart';

class OnboardingTargetScreen extends StatefulWidget {
  const OnboardingTargetScreen({super.key});

  @override
  State<OnboardingTargetScreen> createState() => _OnboardingTargetScreenState();
}

class _OnboardingTargetScreenState extends State<OnboardingTargetScreen> {
  double _selectedScore = 8.0;

  final List<Map<String, dynamic>> _targets = [
    {
      'score': 6.0,
      'badge': '6+',
      'title': 'Đủ điểm tốt nghiệp',
      'desc': 'Nắm chắc kiến thức căn bản',
    },
    {
      'score': 7.0,
      'badge': '7+',
      'title': 'Khá',
      'desc': 'Làm chắc câu hỏi mức độ vừa và thông hiểu',
    },
    {
      'score': 8.0,
      'badge': '8+',
      'title': 'Giỏi',
      'desc': 'Mục tiêu chuẩn, đạt điều kiện vào ĐH top',
    },
    {
      'score': 9.0,
      'badge': '9+',
      'title': 'Xuất sắc',
      'desc': 'Xét tuyển khối D/A1 vào trường top đầu',
    },
    {
      'score': 10.0,
      'badge': '10',
      'title': 'Tuyệt đối',
      'desc': 'Chinh phục 10 điểm trọn vẹn mọi dạng bài',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: const LinearProgressIndicator(
            value: 1 / 3,
            minHeight: 8,
            backgroundColor: Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '1/3',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Bạn muốn đạt bao nhiêu\nđiểm môn tiếng Anh?',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Prep12 sẽ phân bổ các bài học từ cơ bản đến nâng cao giúp bạn đạt được mục tiêu này.',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 13,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 20),

              Expanded(
                child: ListView.separated(
                  itemCount: _targets.length,
                  separatorBuilder: (context, i) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = _targets[index];
                    final double score = item['score'] as double;
                    final bool isSelected = _selectedScore == score;

                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        setState(() {
                          _selectedScore = score;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                            width: isSelected ? 2.0 : 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isSelected
                                  ? const Color(0xFF2563EB).withValues(alpha: 0.12)
                                  : const Color(0x08000000),
                              offset: const Offset(0, 3),
                              blurRadius: isSelected ? 8 : 4,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  item['badge'] as String,
                                  style: TextStyle(
                                    fontFamily: 'BeVietnamPro',
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                    color: isSelected ? Colors.white : const Color(0xFF334155),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['title'] as String,
                                    style: TextStyle(
                                      fontFamily: 'BeVietnamPro',
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    item['desc'] as String,
                                    style: const TextStyle(
                                      fontFamily: 'BeVietnamPro',
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF2563EB),
                                size: 24,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              AppButton(
                label: 'Tiếp tục',
                isFullWidth: true,
                variant: AppButtonVariant.primary,
                height: 52,
                onPressed: () {
                  final auth = AuthController.instance;
                  auth.setPlan(
                    targetScore: _selectedScore,
                    examDate: auth.user.examDate,
                    dailyMinutes: auth.user.dailyMinutes,
                    reminderEnabled: auth.user.reminderEnabled,
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OnboardingScheduleScreen(targetScore: _selectedScore),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
