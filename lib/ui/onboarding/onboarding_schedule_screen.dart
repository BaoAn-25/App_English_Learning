import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../data/app_repository.dart';
import '../auth/auth_controller.dart';
import '../settings/notification_service.dart';
import '../theme/app_tokens.dart';
import '../theme/components/app_button.dart';
import '../theme/components/engpass_mascot.dart';
import 'onboarding_topics_screen.dart';

class OnboardingScheduleScreen extends StatefulWidget {
  final double? targetScore;
  final int? initialDailyMinutes;
  final bool? initialReminderEnabled;
  final TimeOfDay? initialReminderTime;
  final DateTime? initialExamDate;
  final bool autoLoadSavedSettings;

  const OnboardingScheduleScreen({
    super.key,
    this.targetScore,
    this.initialDailyMinutes,
    this.initialReminderEnabled,
    this.initialReminderTime,
    this.initialExamDate,
    this.autoLoadSavedSettings = true,
  });

  @override
  State<OnboardingScheduleScreen> createState() => _OnboardingScheduleScreenState();
}

class _OnboardingScheduleScreenState extends State<OnboardingScheduleScreen> {
  DateTime? _examDate;
  int _selectedMinutes = 20;
  bool _reminderEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);

  bool _isSaving = false;

  final List<Map<String, dynamic>> _minuteOptions = [
    {'minutes': 10, 'label': '10 phút'},
    {'minutes': 20, 'label': '20 phút'},
    {'minutes': 30, 'label': '30 phút'},
    {'minutes': 45, 'label': '45 phút+'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedMinutes = widget.initialDailyMinutes ?? 20;
    _reminderEnabled = widget.initialReminderEnabled ?? false;
    _reminderTime = widget.initialReminderTime ?? const TimeOfDay(hour: 20, minute: 0);
    _examDate = widget.initialExamDate;

    if (widget.autoLoadSavedSettings &&
        widget.initialDailyMinutes == null &&
        widget.initialReminderEnabled == null &&
        widget.initialExamDate == null) {
      _loadSavedSettings();
    }
  }

  Future<void> _loadSavedSettings() async {
    try {
      final repo = AppRepository();
      final savedMinutes = await repo.getSetting('daily_minutes') ?? await repo.getSetting('daily_goal');
      final savedExamDateStr = await repo.getSetting('exam_date');
      final savedReminderEnabled = await repo.getSetting('reminder_enabled');
      final savedHour = await repo.getSetting('reminder_hour');
      final savedMinute = await repo.getSetting('reminder_minute');
      final savedTime = await repo.getSetting('reminder_time');

      if (!mounted) return;

      setState(() {
        if (savedMinutes != null) {
          final m = int.tryParse(savedMinutes);
          if (m != null && [10, 20, 30, 45].contains(m)) {
            _selectedMinutes = m;
          }
        }

        if (savedExamDateStr != null && savedExamDateStr.isNotEmpty) {
          _examDate = DateTime.tryParse(savedExamDateStr);
        }

        if (savedReminderEnabled != null) {
          _reminderEnabled = savedReminderEnabled == 'true';
        }

        if (savedHour != null && savedMinute != null) {
          final h = int.tryParse(savedHour);
          final min = int.tryParse(savedMinute);
          if (h != null && min != null) {
            _reminderTime = TimeOfDay(hour: h, minute: min);
          }
        } else if (savedTime != null && savedTime.contains(':')) {
          final parts = savedTime.split(':');
          final h = int.tryParse(parts[0]);
          final min = int.tryParse(parts[1]);
          if (h != null && min != null) {
            _reminderTime = TimeOfDay(hour: h, minute: min);
          }
        }
      });
    } catch (_) {}
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _getDurationLabel(int minutes) {
    if (minutes == 45) return '45 phút+';
    return '$minutes phút';
  }

  String? _getTimePeriodNote(TimeOfDay time) {
    if (time.hour == 0 && time.minute == 0) {
      return 'Nửa đêm';
    }
    if (time.hour == 12 && time.minute == 0) {
      return 'Buổi trưa';
    }
    return null;
  }

  String _getExplanationText() {
    final durationLabel = _getDurationLabel(_selectedMinutes);
    if (_reminderEnabled) {
      final timeStr = _formatTimeOfDay(_reminderTime);
      final periodNote = _getTimePeriodNote(_reminderTime);
      if (periodNote != null) {
        return 'Nhắc lúc $timeStr mỗi ngày · $periodNote · Mục tiêu $durationLabel học';
      }
      return 'Nhắc lúc $timeStr mỗi ngày · Mục tiêu $durationLabel học';
    } else {
      return 'Mục tiêu $durationLabel học mỗi ngày · Chưa bật nhắc nhở';
    }
  }

  Future<void> _pickExamDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstDate = today;
    final lastDate = DateTime(today.year + 5, 12, 31);

    // Đảm bảo initialDate luôn nằm trong khoảng [firstDate, lastDate]
    DateTime initial = _examDate ?? DateTime(today.year + (today.month > 6 ? 1 : 0), 6, 27);
    if (initial.isBefore(firstDate)) {
      initial = firstDate;
    } else if (initial.isAfter(lastDate)) {
      initial = lastDate;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'CHỌN NGÀY THI THPT',
    );
    if (picked != null) {
      setState(() {
        _examDate = picked;
      });
    }
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      initialEntryMode: TimePickerEntryMode.input,
      helpText: 'CHỌN GIỜ NHẮC HỌC HẰNG NGÀY',
      cancelText: 'HỦY',
      confirmText: 'XÁC NHẬN',
      hourLabelText: 'Giờ',
      minuteLabelText: 'Phút',
      errorInvalidText: 'Giờ hoặc phút không hợp lệ',
      builder: (BuildContext context, Widget? child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: isDark ? const Color(0xFF1E2430) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              hourMinuteShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              hourMinuteColor: WidgetStateColor.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.45) : const Color(0xFFEFF6FF);
                }
                return isDark ? const Color(0xFF121620) : const Color(0xFFF8FAFC);
              }),
              hourMinuteTextColor: WidgetStateColor.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
                }
                return isDark ? Colors.white : const Color(0xFF1E293B);
              }),
              dayPeriodShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              dayPeriodColor: WidgetStateColor.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const Color(0xFF2563EB);
                }
                return isDark ? const Color(0xFF2D3748) : const Color(0xFFF1F5F9);
              }),
              dayPeriodTextColor: WidgetStateColor.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                return isDark ? const Color(0xFFE2E8F0) : const Color(0xFF475569);
              }),
              dayPeriodBorderSide: BorderSide(
                color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                width: 1,
              ),
              entryModeIconColor: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
              dialHandColor: const Color(0xFF2563EB),
              dialBackgroundColor: isDark ? const Color(0xFF121620) : const Color(0xFFF1F5F9),
              cancelButtonStyle: TextButton.styleFrom(
                foregroundColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                textStyle: const TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              confirmButtonStyle: TextButton.styleFrom(
                foregroundColor: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                textStyle: const TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (!mounted) return;
    if (picked != null) {
      setState(() {
        _reminderTime = picked;
      });
    }
  }

  Future<void> _handleContinue() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final examDateStr = _examDate != null ? DateFormat('yyyy-MM-dd').format(_examDate!) : '';
    final timeStr = _formatTimeOfDay(_reminderTime);
    bool finalReminderEnabled = _reminderEnabled;

    try {
      final notifService = NotificationService();

      if (_reminderEnabled) {
        final granted = await notifService.requestPermission();
        if (granted) {
          final scheduled = await notifService.scheduleDailyReminder(_reminderTime);
          if (!scheduled) {
            finalReminderEnabled = false;
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Không thể lên lịch thông báo trên thiết bị. Bạn có thể tiếp tục học và thử lại sau trong Cài đặt.'),
                  duration: Duration(seconds: 3),
                ),
              );
            }
          }
        } else {
          finalReminderEnabled = false;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Chưa được cấp quyền thông báo. Bạn có thể tiếp tục học và bật lại trong Cài đặt.'),
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      } else {
        await notifService.cancelReminder();
      }

      // Lưu cục bộ đồng bộ cho cả Onboarding và Settings
      final repo = AppRepository();
      await repo.setSetting('exam_date', examDateStr);
      if (widget.targetScore != null) {
        await repo.setSetting('target_score', widget.targetScore.toString());
        await repo.setSetting('target_score_confirmed', 'true');
      }
      await repo.setSetting('daily_minutes', _selectedMinutes.toString());
      await repo.setSetting('daily_goal', _selectedMinutes.toString());
      await repo.setSetting('reminder_enabled', finalReminderEnabled ? 'true' : 'false');
      await repo.setSetting('reminder_time', timeStr);
      await repo.setSetting('reminder_hour', _reminderTime.hour.toString());
      await repo.setSetting('reminder_minute', _reminderTime.minute.toString());

      final auth = AuthController.instance;
      final effectiveScore = widget.targetScore ?? auth.user.targetScore;
      if (effectiveScore != null) {
        auth.setPlan(
          targetScore: effectiveScore,
          examDate: examDateStr,
          dailyMinutes: _selectedMinutes,
          reminderEnabled: finalReminderEnabled,
          reminderTime: timeStr,
        );
      }

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OnboardingTopicsScreen(
            targetScore: widget.targetScore,
            dailyMinutes: _selectedMinutes,
            examDate: examDateStr,
            reminderEnabled: finalReminderEnabled,
            reminderTime: timeStr,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã có lỗi khi lưu thiết lập: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
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
    final sectionTitleColor = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155);

    // Tính số ngày đếm ngược theo ngày lịch địa phương
    String dateDisplay;
    String badgeText;
    Color badgeBg;
    Color badgeTextColor;

    if (_examDate == null) {
      dateDisplay = 'Chọn ngày thi';
      badgeText = 'Chưa đặt (Tùy chọn)';
      badgeBg = isDark ? const Color(0xFF2D3748) : const Color(0xFFF1F5F9);
      badgeTextColor = textSecondary;
    } else {
      dateDisplay = DateFormat('dd/MM/yyyy').format(_examDate!);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final target = DateTime(_examDate!.year, _examDate!.month, _examDate!.day);
      final diff = target.difference(today).inDays;

      if (diff < 0) {
        badgeText = 'Ngày thi đã qua';
        badgeBg = isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.4) : const Color(0xFFFEF2F2);
        badgeTextColor = isDark ? const Color(0xFFF87171) : AppTokens.errorRed;
      } else if (diff == 0) {
        badgeText = 'Hôm nay thi';
        badgeBg = isDark ? const Color(0xFF14532D).withValues(alpha: 0.4) : const Color(0xFFF0FDF4);
        badgeTextColor = isDark ? const Color(0xFF4ADE80) : AppTokens.successGreen;
      } else {
        badgeText = 'Còn $diff ngày';
        badgeBg = selectedCardBg;
        badgeTextColor = isDark ? const Color(0xFF60A5FA) : AppTokens.primary;
      }
    }

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
            value: 2 / 3,
            minHeight: 8,
            backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            valueColor: const AlwaysStoppedAnimation<Color>(AppTokens.primary),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '2/3',
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
                          'Khi nào bạn thi và mỗi\nngày học được bao lâu?',
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
                          'EngPass sẽ phân chia số lượng bài học vừa vặn, đều đặn đến ngày thi để không bị quá tải.',
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
                    mood: MascotMood.study,
                    size: 62,
                  ),
                ],
              ),
              const SizedBox(height: 18),

              Expanded(
                child: ListView(
                  children: [
                    // --- MỤC 1: NGÀY THI THPT ---
                    Text(
                      'Ngày thi THPT',
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: sectionTitleColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _pickExamDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_month_rounded,
                              color: isDark ? const Color(0xFF60A5FA) : AppTokens.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                dateDisplay,
                                style: TextStyle(
                                  fontFamily: 'BeVietnamPro',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15.5,
                                  color: _examDate == null ? textSecondary : textPrimary,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: badgeBg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                badgeText,
                                style: TextStyle(
                                  fontFamily: 'BeVietnamPro',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: badgeTextColor,
                                ),
                              ),
                            ),
                            if (_examDate != null) ...[
                              const SizedBox(width: 4),
                              IconButton(
                                icon: Icon(Icons.close_rounded, size: 18, color: textSecondary),
                                tooltip: 'Bỏ chọn ngày thi',
                                onPressed: () {
                                  setState(() => _examDate = null);
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // --- MỤC 2: THỜI GIAN HỌC MỖI NGÀY ---
                    Text(
                      'Thời gian học mỗi ngày',
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: sectionTitleColor,
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

                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            setState(() {
                              _selectedMinutes = min;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? selectedCardBg : cardBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? AppTokens.primary : borderColor,
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isSelected
                                      ? AppTokens.primary.withValues(alpha: 0.14)
                                      : (isDark ? const Color(0x20000000) : const Color(0x06000000)),
                                  offset: const Offset(0, 2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                opt['label'] as String,
                                style: TextStyle(
                                  fontFamily: 'BeVietnamPro',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: isSelected
                                      ? (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8))
                                      : textPrimary,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // --- MỤC 3: NHẮC HỌC HẰNG NGÀY ---
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: selectedCardBg,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.notifications_active_rounded,
                                  color: isDark ? const Color(0xFF60A5FA) : AppTokens.primary,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Nhắc học hằng ngày',
                                      style: TextStyle(
                                        fontFamily: 'BeVietnamPro',
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Thông báo cục bộ trên thiết bị',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _reminderEnabled,
                                activeThumbColor: AppTokens.primary,
                                onChanged: (val) {
                                  setState(() {
                                    _reminderEnabled = val;
                                  });
                                },
                              ),
                            ],
                          ),
                          if (_reminderEnabled) ...[
                            Divider(height: 24, color: borderColor),
                            InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: _pickReminderTime,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Giờ nhắc',
                                        style: TextStyle(
                                          fontFamily: 'BeVietnamPro',
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14.5,
                                          color: sectionTitleColor,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: selectedCardBg,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isDark ? const Color(0xFF1D4ED8) : const Color(0xFFBFDBFE),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.access_time_rounded,
                                            size: 16,
                                            color: isDark ? const Color(0xFF60A5FA) : AppTokens.primary,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            _formatTimeOfDay(_reminderTime),
                                            style: TextStyle(
                                              fontFamily: 'BeVietnamPro',
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14.5,
                                              color: isDark ? const Color(0xFF60A5FA) : AppTokens.primary,
                                            ),
                                          ),
                                          if (_getTimePeriodNote(_reminderTime) != null) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                _getTimePeriodNote(_reminderTime)!,
                                                style: TextStyle(
                                                  fontFamily: 'BeVietnamPro',
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Thông báo có thể đến muộn do cài đặt hệ thống.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: textSecondary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF121620) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline_rounded, size: 14, color: textSecondary),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _getExplanationText(),
                                    style: TextStyle(
                                      fontFamily: 'BeVietnamPro',
                                      fontSize: 12,
                                      color: sectionTitleColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),

              AppButton(
                label: _isSaving ? 'Đang lưu thiết lập...' : 'Tiếp tục',
                isFullWidth: true,
                variant: AppButtonVariant.primary,
                height: 52,
                onPressed: _isSaving ? null : _handleContinue,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
