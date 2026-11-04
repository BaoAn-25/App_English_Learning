import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../auth/auth_controller.dart';
import '../theme/components/app_button.dart';
import '../theme/components/engpass_mascot.dart';
import 'plan_ready_screen.dart';

class OnboardingTopicsScreen extends StatefulWidget {
  final double? targetScore;
  final int dailyMinutes;
  final String examDate;
  final bool reminderEnabled;
  final String reminderTime;
  final List<String>? initialTopics;

  const OnboardingTopicsScreen({
    super.key,
    this.targetScore,
    required this.dailyMinutes,
    required this.examDate,
    required this.reminderEnabled,
    this.reminderTime = '20:00',
    this.initialTopics,
  });

  @override
  State<OnboardingTopicsScreen> createState() => _OnboardingTopicsScreenState();
}

class _OnboardingTopicsScreenState extends State<OnboardingTopicsScreen> {
  late final Set<String> _selectedTopics;

  @override
  void initState() {
    super.initState();
    _selectedTopics = widget.initialTopics != null
        ? Set<String>.from(widget.initialTopics!)
        : <String>{};
  }

  final List<String> _allTopics = [
    'Game',
    'Bóng đá',
    'Công nghệ',
    'Âm nhạc',
    'Phim ảnh',
    'Du lịch',
    'Nấu ăn',
    'Môi trường',
    'Thể thao',
    'Khoa học',
    'Nghệ thuật',
    'Phong cách sống',
    'Văn hoá',
    'Đọc sách',
  ];

  void _toggle(String topic) {
    setState(() {
      if (_selectedTopics.contains(topic)) {
        _selectedTopics.remove(topic);
      } else {
        if (_selectedTopics.length < 4) {
          _selectedTopics.add(topic);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bạn chỉ nên chọn tối đa 4 chủ đề yêu thích nhất'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    });
  }

  void _submit() {
    final auth = AuthController.instance;
    final score = widget.targetScore ?? auth.user.targetScore;
    if (score != null) {
      auth.setPlan(
        targetScore: score,
        examDate: widget.examDate,
        dailyMinutes: widget.dailyMinutes,
        reminderEnabled: widget.reminderEnabled,
        reminderTime: widget.reminderTime,
        favoriteTopics: _selectedTopics.toList(),
      );
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlanReadyScreen(
          targetScore: widget.targetScore,
          dailyMinutes: widget.dailyMinutes,
          reminderEnabled: widget.reminderEnabled,
          reminderTime: widget.reminderTime,
          favoriteTopics: _selectedTopics.toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121620) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E2430) : Colors.white;
    final selectedBg =
        isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFEFF6FF);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: 1.0,
            minHeight: 8,
            backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '3/3',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bạn thích chủ đề nào?',
                          style: TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Từ vựng và bài đọc thêm sẽ xoay quanh những chủ đề này, giúp việc học bớt nhàm chán hơn. Chọn tối đa 4.',
                          style: TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontSize: 13,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const EngPassMascot(
                    mood: MascotMood.fire,
                    size: 62,
                  ),
                ],
              ),
              const SizedBox(height: 18),

              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 12,
                    children: _allTopics.map((topic) {
                      final isSelected = _selectedTopics.contains(topic);
                      return FilterChip(
                        selected: isSelected,
                        label: Text(
                          topic,
                          style: TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8))
                                : (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155)),
                            fontSize: 14,
                          ),
                        ),
                        selectedColor: selectedBg,
                        backgroundColor: cardBg,
                        checkmarkColor: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected ? const Color(0xFF2563EB) : borderColor,
                            width: isSelected ? 1.8 : 1.0,
                          ),
                        ),
                        onSelected: (_) => _toggle(topic),
                      );
                    }).toList(),
                  ),
                ),
              ),

              Text(
                'Đã chọn: ${_selectedTopics.length}/4',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 16),

              AppButton(
                label: 'Tạo kế hoạch cho tôi',
                isFullWidth: true,
                variant: AppButtonVariant.primary,
                height: 52,
                onPressed: _submit,
              ),
              const SizedBox(height: 10),
              AppButton(
                label: 'Bỏ qua bước này',
                isFullWidth: true,
                variant: AppButtonVariant.text,
                onPressed: _submit,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

