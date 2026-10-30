import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../auth/auth_controller.dart';
import '../theme/components/app_button.dart';
import 'onboarding_topics_screen.dart';

class OnboardingScheduleScreen extends StatefulWidget {
  final double targetScore;

  const OnboardingScheduleScreen({
    super.key,
    required this.targetScore,
  });

  @override
  State<OnboardingScheduleScreen> createState() => _OnboardingScheduleScreenState();
}

class _OnboardingScheduleScreenState extends State<OnboardingScheduleScreen> {
  DateTime _examDate = DateTime(2026, 6, 27);
  int _selectedMinutes = 20;
  bool _reminderEnabled = true;

  final List<Map<String, dynamic>> _minuteOptions = [
    {'minutes': 10, 'label': '10 phút', 'tag': null},
    {'minutes': 20, 'label': '20 phút', 'tag': 'Gợi ý'},
    {'minutes': 30, 'label': '30 phút', 'tag': null},
    {'minutes': 45, 'label': '45 phút+', 'tag': null},
  ];

  Future<void> _pickExamDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _examDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030, 12, 31),
      helpText: 'CHỌN NGÀY THI THPT',
    );
    if (picked != null) {
      setState(() {
        _examDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd/MM/yyyy').format(_examDate);
    final daysRemaining = _examDate.difference(DateTime.now()).inDays.clamp(0, 9999);

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
          child: LinearProgressIndicator(
            value: 2 / 3,
            minHeight: 8,
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '2/3',
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
                'Khi nào bạn thi và mỗi\nngày học được bao lâu?',
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
                'Prep12 sẽ phân chia số lượng bài học vừa vặn, đều đặn đến ngày thi để không bị quá tải.',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 13,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 20),

              Expanded(
                child: ListView(
                  children: [
                    // Mục chọn ngày thi
                    const Text(
                      'Ngày thi THPT',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _pickExamDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month_rounded, color: Color(0xFF2563EB)),
                            const SizedBox(width: 12),
                            Text(
                              dateStr,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Còn $daysRemaining ngày',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Thời gian học mỗi ngày
                    const Text(
                      'Thời gian học mỗi ngày',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 10),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 2.1,
                      ),
                      itemCount: _minuteOptions.length,
                      itemBuilder: (context, index) {
                        final opt = _minuteOptions[index];
                        final int min = opt['minutes'] as int;
                        final isSelected = _selectedMinutes == min;
                        final String? tag = opt['tag'] as String?;

                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            setState(() {
                              _selectedMinutes = min;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isSelected
                                      ? const Color(0xFF2563EB).withValues(alpha: 0.1)
                                      : const Color(0x06000000),
                                  offset: const Offset(0, 2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                Center(
                                  child: Text(
                                    opt['label'] as String,
                                    style: TextStyle(
                                      fontFamily: 'BeVietnamPro',
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      color: isSelected
                                          ? const Color(0xFF1D4ED8)
                                          : const Color(0xFF1E293B),
                                    ),
                                  ),
                                ),
                                if (tag != null)
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFC107),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        tag,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 10,
                                          color: Color(0xFF78350F),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // Nhắc nhở
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.notifications_active_rounded,
                              color: Color(0xFF2563EB),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Nhắc tôi học lúc 20:00',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Mỗi ngày có thông báo giữ streak',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _reminderEnabled,
                            activeThumbColor: const Color(0xFF2563EB),
                            onChanged: (val) {
                              setState(() {
                                _reminderEnabled = val;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              AppButton(
                label: 'Tiếp tục',
                isFullWidth: true,
                variant: AppButtonVariant.primary,
                height: 52,
                onPressed: () {
                  final auth = AuthController.instance;
                  final examDateStr = DateFormat('yyyy-MM-dd').format(_examDate);
                  auth.setPlan(
                    targetScore: widget.targetScore,
                    examDate: examDateStr,
                    dailyMinutes: _selectedMinutes,
                    reminderEnabled: _reminderEnabled,
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OnboardingTopicsScreen(
                        targetScore: widget.targetScore,
                        dailyMinutes: _selectedMinutes,
                        examDate: examDateStr,
                        reminderEnabled: _reminderEnabled,
                      ),
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
