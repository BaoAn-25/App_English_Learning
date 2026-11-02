import 'package:flutter/material.dart';
import '../auth/auth_controller.dart';
import '../theme/components/app_button.dart';
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
        ),
      ),
    );
  }

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
          child: LinearProgressIndicator(
            value: 1.0,
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
                '3/3',
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
                'Bạn thích chủ đề nào?',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Từ vựng và bài đọc thêm sẽ xoay quanh những chủ đề này, giúp việc học bớt nhàm chán hơn. Chọn tối đa 4.',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 13,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 20),

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
                            color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF334155),
                            fontSize: 14,
                          ),
                        ),
                        selectedColor: const Color(0xFFEFF6FF),
                        backgroundColor: Colors.white,
                        checkmarkColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
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
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
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

