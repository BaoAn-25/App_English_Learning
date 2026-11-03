import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/minimal_pair_question.dart';
import '../theme/components/app_button.dart';
import 'pronunciation_controller.dart';

/// Màn hình làm bài tập luyện nghe cặp âm đối lập (Minimal Pairs) chuẩn Duolingo
class MinimalPairsQuizScreen extends StatefulWidget {
  const MinimalPairsQuizScreen({super.key});

  @override
  State<MinimalPairsQuizScreen> createState() => _MinimalPairsQuizScreenState();
}

class _MinimalPairsQuizScreenState extends State<MinimalPairsQuizScreen> {
  int _currentIndex = 0;
  int? _selectedIndex;
  bool _isAnswerChecked = false;
  bool _isCorrect = false;
  int _score = 0;

  // Với dạng bài 2 loa (ảnh 5): ngẫu nhiên 50% cùng 1 từ, 50% 2 từ khác nhau
  bool _isSequentialPairSame = false;
  String _activeTargetWord = '';

  @override
  void initState() {
    super.initState();
    _prepareQuestion(0);
  }

  void _prepareQuestion(int index) {
    _selectedIndex = null;
    _isAnswerChecked = false;
    _isCorrect = false;

    // Xen kẽ dạng 1 (Ảnh 4: chọn giữa 2 từ) và dạng 2 (Ảnh 5: nghe 2 loa đoán giống/khác)
    final isDualSpeakerMode = index % 2 == 1;
    if (isDualSpeakerMode) {
      _isSequentialPairSame = index % 4 == 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PronunciationController>(
      create: (_) => PronunciationController(),
      child: Consumer<PronunciationController>(
        builder: (context, controller, child) {
          if (controller.isLoading) {
            return const Scaffold(
              backgroundColor: Color(0xFF131F24),
              body: Center(child: CircularProgressIndicator(color: Color(0xFF1CB0F6))),
            );
          }

          final questions = controller.minimalPairs;
          if (questions.isEmpty) {
            return Scaffold(
              backgroundColor: const Color(0xFF131F24),
              appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
              body: const Center(
                child: Text('Chưa có câu hỏi luyện âm.', style: TextStyle(color: Colors.white)),
              ),
            );
          }

          // Kiểm tra khi làm xong hết câu hỏi
          if (_currentIndex >= questions.length) {
            return _buildCompletionView(context, questions.length);
          }

          final currentQ = questions[_currentIndex];
          final bool isDualSpeakerMode = _currentIndex % 2 == 1;

          // Thiết lập từ mục tiêu cần nghe
          _activeTargetWord = currentQ.wordA;

          final progress = (_currentIndex + 1) / questions.length;

          return Scaffold(
            backgroundColor: const Color(0xFF131F24), // Nền tối chuẩn Duolingo
            body: SafeArea(
              child: Column(
                children: [
                  // 1. Thanh tiến độ trên đỉnh & nút Close
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF778D97), size: 24),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 12,
                              backgroundColor: const Color(0xFF37464F),
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF58CC02)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Text('⚡ 10 KN', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFFC800))),
                      ],
                    ),
                  ),

                  // 2. Nội dung bài tập (Dạng 1 hoặc Dạng 2)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: isDualSpeakerMode
                          ? _buildDualSpeakerType(currentQ, controller)
                          : _buildMinimalPairType(currentQ, controller),
                    ),
                  ),

                  // 3. Thanh kiểm tra / Banner kết quả trượt lên
                  _buildBottomActionSection(controller, currentQ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// DẠNG BÀI 1 (Ảnh 4 Duolingo): "Bạn nghe được gì?" -> Loa to ở giữa -> Chọn dock hay deck
  Widget _buildMinimalPairType(MinimalPairQuestion q, PronunciationController controller) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Bạn nghe được gì?',
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontWeight: FontWeight.w900,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 32),

        // Nút Loa to ở giữa màn hình (Ảnh 4)
        GestureDetector(
          onTap: () => controller.speakWord(_activeTargetWord),
          child: Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: const Color(0xFF1CB0F6),
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0xFF1899D6),
                  offset: Offset(0, 5),
                  blurRadius: 0,
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.volume_up_rounded, color: Colors.white, size: 54),
            ),
          ),
        ),
        const SizedBox(height: 48),

        // 2 lựa chọn cặp từ: [1] dock vs [2] deck
        Row(
          children: [
            Expanded(
              child: _buildOptionTile(
                index: 0,
                label: q.wordA,
                ipa: q.ipaA,
                onTap: () {
                  if (_isAnswerChecked) return;
                  setState(() => _selectedIndex = 0);
                  controller.speakWord(q.wordA);
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildOptionTile(
                index: 1,
                label: q.wordB,
                ipa: q.ipaB,
                onTap: () {
                  if (_isAnswerChecked) return;
                  setState(() => _selectedIndex = 1);
                  controller.speakWord(q.wordB);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// DẠNG BÀI 2 (Ảnh 5 Duolingo): "Nghe và trả lời" -> 2 loa nối tiếp -> Cùng 1 từ hay 2 từ khác nhau
  Widget _buildDualSpeakerType(MinimalPairQuestion q, PronunciationController controller) {
    final firstWord = q.wordA;
    final secondWord = _isSequentialPairSame ? q.wordA : q.wordB;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Nghe và trả lời',
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontWeight: FontWeight.w900,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),

        // Khung 2 nút loa (Ảnh 5)
        Container(
          width: 120,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF202F36),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF37464F), width: 2),
          ),
          child: Column(
            children: [
              IconButton(
                icon: const Icon(Icons.volume_up_rounded, color: Color(0xFF1CB0F6), size: 32),
                onPressed: () => controller.speakWord(firstWord),
              ),
              const Divider(color: Color(0xFF37464F), thickness: 1.5),
              IconButton(
                icon: const Icon(Icons.volume_up_rounded, color: Color(0xFF1CB0F6), size: 32),
                onPressed: () => controller.speakWord(secondWord),
              ),
            ],
          ),
        ),
        const SizedBox(height: 36),

        const Text(
          'Bạn nghe thấy gì?',
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),

        // 2 lựa chọn: [1] Cùng một từ vs [2] Hai từ khác nhau
        _buildOptionRowTile(
          index: 0,
          label: 'cùng một từ',
          onTap: () {
            if (_isAnswerChecked) return;
            setState(() => _selectedIndex = 0);
          },
        ),
        const SizedBox(height: 12),
        _buildOptionRowTile(
          index: 1,
          label: 'hai từ khác nhau',
          onTap: () {
            if (_isAnswerChecked) return;
            setState(() => _selectedIndex = 1);
          },
        ),
      ],
    );
  }

  Widget _buildOptionTile({
    required int index,
    required String label,
    required String ipa,
    required VoidCallback onTap,
  }) {
    final isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1CB0F6).withValues(alpha: 0.18) : const Color(0xFF202F36),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF1CB0F6) : const Color(0xFF37464F),
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? const Color(0xFF1899D6) : const Color(0xFF131F24),
              offset: const Offset(0, 3.5),
              blurRadius: 0,
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: isSelected ? const Color(0xFF1CB0F6) : Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              ipa,
              style: TextStyle(
                fontSize: 13,
                color: isSelected ? const Color(0xFF1CB0F6) : const Color(0xFF778D97),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionRowTile({
    required int index,
    required String label,
    required VoidCallback onTap,
  }) {
    final isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1CB0F6).withValues(alpha: 0.18) : const Color(0xFF202F36),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF1CB0F6) : const Color(0xFF37464F),
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? const Color(0xFF1899D6) : const Color(0xFF131F24),
              offset: const Offset(0, 3.5),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: isSelected ? const Color(0xFF1CB0F6) : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActionSection(
    PronunciationController controller,
    MinimalPairQuestion currentQ,
  ) {
    if (_isAnswerChecked) {
      // Banner chúc mừng / báo lỗi trượt từ dưới lên (chuẩn Duolingo)
      final color = _isCorrect ? const Color(0xFF58CC02) : const Color(0xFFFF4B4B);
      final bgColor = _isCorrect ? const Color(0xFF20382A) : const Color(0xFF382228);

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        color: bgColor,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  _isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: color,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isCorrect ? 'Tuyệt vời!' : 'Chưa chính xác!',
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: color,
                        ),
                      ),
                      Text(
                        _isCorrect
                            ? 'Bạn đã bắt âm rất chuẩn xác.'
                            : 'Từ đúng là: ${currentQ.wordA} (${currentQ.ipaA})',
                        style: TextStyle(
                          fontSize: 13,
                          color: color.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            AppButton(
              label: 'TIẾP TỤC',
              isFullWidth: true,
              height: 48,
              variant: _isCorrect ? AppButtonVariant.success : AppButtonVariant.primary,
              onPressed: () {
                setState(() {
                  _currentIndex++;
                  _prepareQuestion(_currentIndex);
                });
              },
            ),
          ],
        ),
      );
    }

    // Nút BỎ QUA & KIỂM TRA mặc định
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF131F24),
        border: Border(top: BorderSide(color: Color(0xFF2B3A42), width: 1.5)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: AppButton(
              label: 'BỎ QUA',
              variant: AppButtonVariant.outlined,
              height: 48,
              onPressed: () {
                setState(() {
                  _currentIndex++;
                  _prepareQuestion(_currentIndex);
                });
              },
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 3,
            child: AppButton(
              label: 'KIỂM TRA',
              variant: _selectedIndex != null ? AppButtonVariant.success : AppButtonVariant.outlined,
              height: 48,
              onPressed: _selectedIndex != null
                  ? () {
                      final bool isDual = _currentIndex % 2 == 1;
                      bool correct = false;
                      if (!isDual) {
                        // Dạng 1: target là wordA (index 0)
                        correct = _selectedIndex == 0;
                      } else {
                        // Dạng 2: 0 = cùng 1 từ, 1 = khác nhau
                        correct = (_selectedIndex == 0 && _isSequentialPairSame) ||
                            (_selectedIndex == 1 && !_isSequentialPairSame);
                      }

                      setState(() {
                        _isAnswerChecked = true;
                        _isCorrect = correct;
                        if (correct) _score += 10;
                      });

                      controller.recordPracticeResult(currentQ.soundAId, correct);
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionView(BuildContext context, int totalCount) {
    return Scaffold(
      backgroundColor: const Color(0xFF131F24),
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
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1CB0F6).withValues(alpha: 0.3),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: Image.asset('assets/images/app_logo.png', fit: BoxFit.cover),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Hoàn thành bài luyện âm!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Bạn đã hoàn thành xuất sắc các thử thách phân biệt âm thanh.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 14,
                  color: Color(0xFF8E9EA7),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF202F36),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF37464F), width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatBox(label: 'TỔNG ĐIỂM', value: '+${_score > 0 ? _score : 10} KN', color: const Color(0xFFFFC800)),
                    Container(width: 1.5, height: 40, color: const Color(0xFF37464F)),
                    _buildStatBox(label: 'CÂU HỎI', value: '$totalCount', color: const Color(0xFF1CB0F6)),
                  ],
                ),
              ),
              const Spacer(),
              AppButton(
                label: 'TIẾP TỤC',
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

  Widget _buildStatBox({required String label, required String value, required Color color}) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFF778D97),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }
}

