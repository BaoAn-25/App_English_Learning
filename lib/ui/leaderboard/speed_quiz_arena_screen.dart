import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/app_repository.dart';
import '../../data/models/daily_stat.dart';
import '../theme/components/app_button.dart';

/// Màn hình Đấu Trường Tốc Độ 60s (Speed Quiz Arena)
class SpeedQuizArenaScreen extends StatefulWidget {
  const SpeedQuizArenaScreen({super.key});

  @override
  State<SpeedQuizArenaScreen> createState() => _SpeedQuizArenaScreenState();
}

class _SpeedQuizArenaScreenState extends State<SpeedQuizArenaScreen> {
  final AppRepository _repo = AppRepository();
  List<Map<String, dynamic>> _questions = [];
  bool _isLoading = true;
  int _currentIndex = 0;
  int _secondsRemaining = 60;
  Timer? _timer;

  int _score = 0;
  int _correctCount = 0;
  int _combo = 0;
  int _maxCombo = 0;

  int? _selectedAnswerIndex;
  bool _isAnswered = false;
  bool _isGameEnded = false;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/data/questions.json');
      final List<dynamic> data = jsonDecode(jsonStr);
      final random = Random();
      final shuffled = List<Map<String, dynamic>>.from(data)..shuffle(random);
      // Lấy 15 câu hỏi để học sinh làm tối đa trong 60s
      _questions = shuffled.take(15).toList();
    } catch (_) {
      _questions = [];
    }

    if (mounted) {
      setState(() => _isLoading = false);
      _startTimer();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _endGame();
      }
    });
  }

  void _handleSelectAnswer(int optionIndex) {
    if (_isAnswered || _isGameEnded) return;

    final currentQ = _questions[_currentIndex];
    final int correctIdx = currentQ['correctIndex'] as int? ?? 0;
    final bool isCorrect = optionIndex == correctIdx;

    HapticFeedback.lightImpact();

    setState(() {
      _selectedAnswerIndex = optionIndex;
      _isAnswered = true;
      if (isCorrect) {
        _correctCount++;
        _combo++;
        if (_combo > _maxCombo) _maxCombo = _combo;
        final bonus = _combo > 2 ? 15 : 10;
        _score += bonus;
      } else {
        _combo = 0;
      }
    });

    // Tự động chuyển câu sau 600ms
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted || _isGameEnded) return;
      if (_currentIndex < _questions.length - 1) {
        setState(() {
          _currentIndex++;
          _selectedAnswerIndex = null;
          _isAnswered = false;
        });
      } else {
        _endGame();
      }
    });
  }

  void _endGame() {
    _timer?.cancel();
    if (_isGameEnded) return;

    // Lưu điểm XP kiếm được vào repository
    if (_score > 0) {
      final now = DateTime.now();
      final dateStr =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      _repo.upsertDailyStat(DailyStat(
        date: dateStr,
        xp: _score,
        questionsDone: _currentIndex + (_isAnswered ? 1 : 0),
        correct: _correctCount,
        minutes: 1,
      ));
    }

    setState(() {
      _isGameEnded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF121620) : const Color(0xFFF8FAFC),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB))),
      );
    }

    if (_isGameEnded) {
      return _buildResultView(isDark);
    }

    if (_questions.isEmpty) {
      return Scaffold(
        body: Center(
          child: Text('Không tải được câu hỏi.', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        ),
      );
    }

    final currentQ = _questions[_currentIndex];
    final options = (currentQ['options'] as List).cast<String>();
    final int correctIdx = currentQ['correctIndex'] as int? ?? 0;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121620) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E2430) : Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          onPressed: () => _confirmExitDialog(isDark),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.timer_outlined,
              size: 20,
              color: _secondsRemaining <= 10 ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
            ),
            const SizedBox(width: 6),
            Text(
              '${_secondsRemaining}s',
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: _secondsRemaining <= 10 ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '⚡ +$_score XP',
                style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFD97706), fontSize: 14),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Thanh tiến trình thời gian
            LinearProgressIndicator(
              value: _secondsRemaining / 60.0,
              minHeight: 6,
              backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                _secondsRemaining <= 10 ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Câu ${_currentIndex + 1}/${_questions.length}',
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  if (_combo >= 2)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '🔥 COMBO x$_combo',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),

            // Câu hỏi
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E2430) : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        boxShadow: const [
                          BoxShadow(color: Color(0x08000000), offset: Offset(0, 4), blurRadius: 10),
                        ],
                      ),
                      child: Text(
                        currentQ['stem'] as String? ?? '',
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          height: 1.45,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 4 Lựa chọn A, B, C, D
                    ...List.generate(options.length, (idx) {
                      final option = options[idx];
                      Color bgColor = isDark ? const Color(0xFF1E2430) : Colors.white;
                      Color borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
                      Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);

                      if (_isAnswered) {
                        if (idx == correctIdx) {
                          bgColor = const Color(0xFFDCFCE7);
                          borderColor = const Color(0xFF16A34A);
                          textColor = const Color(0xFF15803D);
                        } else if (idx == _selectedAnswerIndex) {
                          bgColor = const Color(0xFFFEE2E2);
                          borderColor = const Color(0xFFDC2626);
                          textColor = const Color(0xFF991B1B);
                        }
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () => _handleSelectAnswer(idx),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: borderColor, width: 1.6),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: borderColor.withAlpha(40),
                                  child: Text(
                                    String.fromCharCode(65 + idx),
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    option,
                                    style: TextStyle(
                                      fontFamily: 'BeVietnamPro',
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: textColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Màn hình kết quả khi hết 60s
  Widget _buildResultView(bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121620) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEF3C7),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('⚡', style: TextStyle(fontSize: 48)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Hoàn Thành Đấu Trường!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Bạn đã hoàn thành xuất sắc thử thách phản xạ nhanh 60 giây.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
              const SizedBox(height: 28),

              // Thống kê kết quả
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2430) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildResultStat('ĐIỂM THƯỞNG', '+$_score XP', const Color(0xFFD97706), isDark),
                    Container(width: 1, height: 40, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    _buildResultStat('SỐ CÂU ĐÚNG', '$_correctCount', const Color(0xFF16A34A), isDark),
                    Container(width: 1, height: 40, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    _buildResultStat('MAX COMBO', 'x$_maxCombo', const Color(0xFF2563EB), isDark),
                  ],
                ),
              ),

              const Spacer(),
              AppButton(
                label: 'VỀ BẢNG XẾP HẠNG',
                isFullWidth: true,
                height: 52,
                variant: AppButtonVariant.primary,
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultStat(String label, String value, Color color, bool isDark) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontFamily: 'BeVietnamPro', fontWeight: FontWeight.w900, fontSize: 18, color: color)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
      ],
    );
  }

  void _confirmExitDialog(bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: const Text('Thoát Đấu Trường?'),
        content: const Text('Thời gian vẫn đang đếm ngược. Nếu thoát ngay bạn sẽ không nhận được trọn vẹn điểm XP.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tiếp tục làm')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Thoát', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
