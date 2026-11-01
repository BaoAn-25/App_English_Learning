import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/app_repository.dart';
import '../auth/auth_controller.dart';
import '../settings/notification_service.dart';
import '../theme/app_tokens.dart';
import '../theme/components/app_button.dart';
import 'onboarding_topics_screen.dart';

class OnboardingScheduleScreen extends StatefulWidget {
  final double targetScore;
  final int? initialDailyMinutes;
  final bool? initialReminderEnabled;
  final TimeOfDay? initialReminderTime;
  final DateTime? initialExamDate;
  final bool autoLoadSavedSettings;

  const OnboardingScheduleScreen({
    super.key,
    required this.targetScore,
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
    {'minutes': 10, 'label': '10 phút', 'tag': null},
    {'minutes': 20, 'label': '20 phút', 'tag': 'Gợi ý'},
    {'minutes': 30, 'label': '30 phút', 'tag': null},
    {'minutes': 45, 'label': '45 phút+', 'tag': null},
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

  String _getExplanationText() {
    final durationLabel = _getDurationLabel(_selectedMinutes);
    if (_reminderEnabled) {
      final timeStr = _formatTimeOfDay(_reminderTime);
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
      helpText: 'CHỌN GIỜ NHẮC HỌC HẰNG NGÀY',
    );
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
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Không thể lên lịch thông báo trên thiết bị. Bạn có thể tiếp tục học và thử lại sau.'),
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
      await repo.setSetting('target_score', widget.targetScore.toString());
      await repo.setSetting('daily_minutes', _selectedMinutes.toString());
      await repo.setSetting('daily_goal', _selectedMinutes.toString());
      await repo.setSetting('reminder_enabled', finalReminderEnabled ? 'true' : 'false');
      await repo.setSetting('reminder_time', timeStr);
      await repo.setSetting('reminder_hour', _reminderTime.hour.toString());
      await repo.setSetting('reminder_minute', _reminderTime.minute.toString());

      final auth = AuthController.instance;
      auth.setPlan(
        targetScore: widget.targetScore,
        examDate: examDateStr,
        dailyMinutes: _selectedMinutes,
        reminderEnabled: finalReminderEnabled,
        reminderTime: timeStr,
      );

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
    // Tính số ngày đếm ngược theo ngày lịch địa phương
    String dateDisplay;
    String badgeText;
    Color badgeBg;
    Color badgeTextColor;

    if (_examDate == null) {
      dateDisplay = 'Chọn ngày thi';
      badgeText = 'Chưa đặt (Tùy chọn)';
      badgeBg = const Color(0xFFF1F5F9);
      badgeTextColor = const Color(0xFF64748B);
    } else {
      dateDisplay = DateFormat('dd/MM/yyyy').format(_examDate!);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final target = DateTime(_examDate!.year, _examDate!.month, _examDate!.day);
      final diff = target.difference(today).inDays;

      if (diff < 0) {
        badgeText = 'Ngày thi đã qua';
        badgeBg = const Color(0xFFFEF2F2);
        badgeTextColor = AppTokens.errorRed;
      } else if (diff == 0) {
        badgeText = 'Hôm nay thi';
        badgeBg = const Color(0xFFF0FDF4);
        badgeTextColor = AppTokens.successGreen;
      } else {
        badgeText = 'Còn $diff ngày';
        badgeBg = const Color(0xFFEFF6FF);
        badgeTextColor = AppTokens.primary;
      }
    }

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
            value: 2 / 3,
            minHeight: 8,
            backgroundColor: Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary),
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
                'English 12 sẽ phân chia số lượng bài học vừa vặn, đều đặn đến ngày thi để không bị quá tải.',
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
                    // --- MỤC 1: NGÀY THI THPT ---
                    const Text(
                      'Ngày thi THPT',
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
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
                            const Icon(Icons.calendar_month_rounded, color: AppTokens.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                dateDisplay,
                                style: TextStyle(
                                  fontFamily: 'BeVietnamPro',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15.5,
                                  color: _examDate == null
                                      ? const Color(0xFF64748B)
                                      : const Color(0xFF0F172A),
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
                                icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
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
                    const Text(
                      'Thời gian học mỗi ngày',
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
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
                                color: isSelected ? AppTokens.primary : const Color(0xFFE2E8F0),
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isSelected
                                      ? AppTokens.primary.withValues(alpha: 0.1)
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

                    // --- MỤC 3: NHẮC HỌC HẰNG NGÀY ---
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.notifications_active_rounded,
                                  color: AppTokens.primary,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Nhắc học hằng ngày',
                                      style: TextStyle(
                                        fontFamily: 'BeVietnamPro',
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Thông báo cục bộ trên thiết bị',
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
                            const Divider(height: 24, color: Color(0xFFE2E8F0)),
                            InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: _pickReminderTime,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Giờ nhắc',
                                      style: TextStyle(
                                        fontFamily: 'BeVietnamPro',
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14.5,
                                        color: Color(0xFF334155),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFBFDBFE)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.access_time_rounded, size: 16, color: AppTokens.primary),
                                          const SizedBox(width: 6),
                                          Text(
                                            _formatTimeOfDay(_reminderTime),
                                            style: const TextStyle(
                                              fontFamily: 'BeVietnamPro',
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14.5,
                                              color: AppTokens.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF64748B)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _getExplanationText(),
                                    style: const TextStyle(
                                      fontFamily: 'BeVietnamPro',
                                      fontSize: 12,
                                      color: Color(0xFF475569),
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
