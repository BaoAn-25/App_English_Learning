import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/app_repository.dart';
import '../auth/auth_controller.dart';
import '../theme/components/app_button.dart';
import '../theme/components/engpass_mascot.dart';
import 'onboarding_schedule_screen.dart';

class OnboardingTargetScreen extends StatefulWidget {
  final double? initialTargetScore;
  final bool autoLoadSavedSettings;

  const OnboardingTargetScreen({
    super.key,
    this.initialTargetScore,
    this.autoLoadSavedSettings = false,
  });

  @override
  State<OnboardingTargetScreen> createState() => _OnboardingTargetScreenState();
}

class _OnboardingTargetScreenState extends State<OnboardingTargetScreen> {
  double? _selectedScore;
  bool _isSaving = false;
  bool _userHasInteracted = false;

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
  void initState() {
    super.initState();
    _selectedScore = widget.initialTargetScore;
    if (widget.initialTargetScore != null) {
      _userHasInteracted = true;
    } else if (widget.autoLoadSavedSettings) {
      _loadSavedTarget();
    }
  }

  Future<void> _loadSavedTarget() async {
    try {
      final repo = AppRepository();
      final isConfirmed = await repo.getSetting('target_score_confirmed');
      final savedTargetStr = await repo.getSetting('target_score');

      if (!mounted) return;

      // Không ghi đè nếu người dùng đã chủ động chọn trên giao diện
      if (_userHasInteracted) return;

      // Chỉ khôi phục khi người dùng thực sự đã xác nhận mục tiêu trước đó
      if (isConfirmed == 'true' && savedTargetStr != null) {
        final score = double.tryParse(savedTargetStr);
        if (score != null && [6.0, 7.0, 8.0, 9.0, 10.0].contains(score)) {
          setState(() {
            _selectedScore = score;
          });
        }
      }
    } catch (_) {}
  }

  void _onSelectTarget(double score) {
    setState(() {
      _userHasInteracted = true;
      _selectedScore = score;
    });
  }

  Future<void> _handleContinue() async {
    if (_selectedScore == null || _isSaving) return;

    setState(() => _isSaving = true);

    try {
      final repo = AppRepository();
      await repo.setSetting('target_score', _selectedScore!.toString());
      await repo.setSetting('target_score_confirmed', 'true');

      final auth = AuthController.instance;
      auth.setPlan(
        targetScore: _selectedScore!,
        examDate: auth.user.examDate,
        dailyMinutes: auth.user.dailyMinutes,
        reminderEnabled: auth.user.reminderEnabled,
        reminderTime: auth.user.reminderTime,
      );

      if (!mounted) return;
      setState(() => _isSaving = false);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OnboardingScheduleScreen(targetScore: _selectedScore),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể lưu mục tiêu điểm. Vui lòng thử lại.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121620) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E2430) : Colors.white;
    final selectedCardBg =
        isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.35) : const Color(0xFFEFF6FF);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
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
            value: 1 / 3,
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
                '1/3',
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
                          'Bạn muốn đạt bao nhiêu\nđiểm môn tiếng Anh?',
                          style: TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: textPrimary,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'EngPass sẽ phân bổ các bài học từ cơ bản đến nâng cao giúp bạn đạt được mục tiêu này.',
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
                  EngPassMascot(
                    mood: _selectedScore != null && _selectedScore! >= 9.0
                        ? MascotMood.celebrate
                        : MascotMood.cheer,
                    size: 62,
                  ),
                ],
              ),
              const SizedBox(height: 16),

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
                      onTap: () => _onSelectTarget(score),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected ? selectedCardBg : cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF2563EB) : borderColor,
                            width: isSelected ? 2.0 : 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isSelected
                                  ? const Color(0xFF2563EB).withValues(alpha: 0.16)
                                  : (isDark ? const Color(0x20000000) : const Color(0x08000000)),
                              offset: const Offset(0, 3),
                              blurRadius: isSelected ? 8 : 4,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF2563EB)
                                    : (isDark ? const Color(0xFF2D3748) : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  item['badge'] as String,
                                  style: TextStyle(
                                    fontFamily: 'BeVietnamPro',
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155)),
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
                                      color: isSelected
                                          ? (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8))
                                          : textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    item['desc'] as String,
                                    style: TextStyle(
                                      fontFamily: 'BeVietnamPro',
                                      fontSize: 12,
                                      color: textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              isSelected
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: isSelected
                                  ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB))
                                  : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                              size: 24,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Dòng hướng dẫn
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Center(
                  child: Text(
                    _selectedScore == null
                        ? 'Chọn mục tiêu để tiếp tục'
                        : 'Đã chọn mục tiêu ${_selectedScore == 10.0 ? '10' : '${_selectedScore!.toStringAsFixed(0)}+'} · Có thể thay đổi sau',
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 13,
                      fontWeight: _selectedScore == null ? FontWeight.w500 : FontWeight.w600,
                      color: _selectedScore == null
                          ? textSecondary
                          : (isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB)),
                    ),
                  ),
                ),
              ),

              AppButton(
                label: _isSaving ? 'Đang lưu...' : 'Tiếp tục',
                isFullWidth: true,
                variant: AppButtonVariant.primary,
                height: 52,
                onPressed: (_selectedScore == null || _isSaving) ? null : _handleContinue,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
