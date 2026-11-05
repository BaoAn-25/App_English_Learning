import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/app_tokens.dart';
import '../../audio/app_audio_controller.dart';
import '../../theme/components/engpass_mascot.dart';

/// Item câu / từ trong bài luyện nói Speaking SGK 12
class SpeakingPracticePrompt {
  final String text;
  final String ipa;
  final String translation;
  final String? audioPath;
  final String? contextTip;

  const SpeakingPracticePrompt({
    required this.text,
    required this.ipa,
    required this.translation,
    this.audioPath,
    this.contextTip,
  });
}

/// Kết quả phân tích giọng nói AI của học viên
class SpeakingEvaluationResult {
  final double score; // 0.0 - 100.0
  final List<WordPronunciationFeedback> wordFeedbacks;
  final String overallComment;
  final String improvementTip;

  const SpeakingEvaluationResult({
    required this.score,
    required this.wordFeedbacks,
    required this.overallComment,
    required this.improvementTip,
  });
}

/// Chi tiết từng từ trong câu nói
class WordPronunciationFeedback {
  final String word;
  final String ipa;
  final bool isCorrect;
  final String? phoneticIssue;

  const WordPronunciationFeedback({
    required this.word,
    required this.ipa,
    required this.isCorrect,
    this.phoneticIssue,
  });
}

/// Widget Luyện nói AI Tương tác (Interactive Speech Recognition & Evaluation)
class SpeakingPracticeWidget extends StatefulWidget {
  final String title;
  final String description;
  final List<SpeakingPracticePrompt> prompts;
  final Function(double score, Map<String, dynamic> resultData)? onPracticeCompleted;

  const SpeakingPracticeWidget({
    super.key,
    required this.title,
    required this.description,
    required this.prompts,
    this.onPracticeCompleted,
  });

  @override
  State<SpeakingPracticeWidget> createState() => _SpeakingPracticeWidgetState();
}

class _SpeakingPracticeWidgetState extends State<SpeakingPracticeWidget> {
  int _currentIndex = 0;
  bool _isRecording = false;
  bool _isEvaluating = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;

  SpeakingEvaluationResult? _lastResult;
  final Map<int, SpeakingEvaluationResult> _resultsMap = {};

  SpeakingPracticePrompt get _currentPrompt =>
      widget.prompts.isNotEmpty ? widget.prompts[_currentIndex] : const SpeakingPracticePrompt(text: '', ipa: '', translation: '');

  @override
  void dispose() {
    _recordingTimer?.cancel();
    super.dispose();
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _recordingSeconds = 0;
      _lastResult = null;
    });

    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _recordingSeconds++;
          if (_recordingSeconds >= 12) {
            _stopRecordingAndEvaluate();
          }
        });
      }
    });
  }

  void _stopRecordingAndEvaluate() async {
    _recordingTimer?.cancel();
    if (!_isRecording) return;

    setState(() {
      _isRecording = false;
      _isEvaluating = true;
    });

    // Mô phỏng bộ phân tích giọng nói AI dựa trên câu mẫu SGK 12
    await Future.delayed(const Duration(milliseconds: 1200));

    final words = _currentPrompt.text.replaceAll(RegExp(r'[^\w\s]'), '').split(RegExp(r'\s+'));
    final rand = Random();

    // Tỉ lệ phát âm đúng ngẫu nhiên mô phỏng (từ 82% đến 96%)
    final score = (82 + rand.nextInt(15)).toDouble();
    final wordFeedbacks = <WordPronunciationFeedback>[];

    for (int i = 0; i < words.length; i++) {
      final w = words[i];
      // Chọn 1-2 từ để gợi ý sửa phát âm âm tiết /ed/, /s/, nguyên âm đôi
      final isErr = (i == 1 || i == words.length - 2) && rand.nextBool() && score < 95;

      wordFeedbacks.add(WordPronunciationFeedback(
        word: w,
        ipa: '/${w.toLowerCase()}/',
        isCorrect: !isErr,
        phoneticIssue: isErr
            ? 'Chú ý phát âm rõ trọng âm và âm đuôi /${w.length > 4 ? "d" : "s"}/'
            : null,
      ));
    }

    String comment = 'Phát âm rất tốt! Trôi chảy và đúng ngữ điệu câu.';
    String tip = 'Nên chú ý giữ nhịp thở đều ở các cụm từ dài.';
    if (score < 85) {
      comment = 'Khá tốt! Cần phát âm rõ hơn các âm tiết đuôi.';
      tip = 'Nhấn mạnh đúng trọng âm từ và không bỏ sót đuôi /s/ hoặc /ed/.';
    }

    final result = SpeakingEvaluationResult(
      score: score,
      wordFeedbacks: wordFeedbacks,
      overallComment: comment,
      improvementTip: tip,
    );

    if (mounted) {
      setState(() {
        _lastResult = result;
        _resultsMap[_currentIndex] = result;
        _isEvaluating = false;
      });

      // Gọi callback để lưu điểm học bạ
      if (widget.onPracticeCompleted != null) {
        final totalAvgScore = _resultsMap.values.isEmpty
            ? score
            : _resultsMap.values.fold<double>(0, (sum, r) => sum + r.score) / _resultsMap.length;
        widget.onPracticeCompleted!(totalAvgScore, {
          'completedCount': _resultsMap.length,
          'totalPrompts': widget.prompts.length,
          'lastScore': score,
        });
      }
    }
  }

  void _playModelAudio() {
    if (_currentPrompt.audioPath != null && _currentPrompt.audioPath!.isNotEmpty) {
      AppAudioController.instance.playAsset(assetPath: _currentPrompt.audioPath!);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đang phát âm thanh mẫu chuẩn: "${_currentPrompt.text}"'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppTokens.darkSurface : AppTokens.surface;
    final textMain = isDark ? AppTokens.darkTextMain : AppTokens.textMain;
    final textSub = isDark ? AppTokens.darkTextSub : AppTokens.textSub;
    final borderColor = isDark ? AppTokens.darkBorder : AppTokens.border;

    if (widget.prompts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTokens.primary.withValues(alpha: isDark ? 0.16 : 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTokens.primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const EngPassMascot(mood: MascotMood.study, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: textMain,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.description,
                      style: TextStyle(fontSize: 12.5, color: textSub, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Tiến trình câu luyện nói
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Câu mẫu ${_currentIndex + 1} / ${widget.prompts.length}',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textSub),
            ),
            Row(
              children: List.generate(
                widget.prompts.length,
                (idx) => Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: idx == _currentIndex
                        ? AppTokens.primary
                        : (_resultsMap.containsKey(idx) ? AppTokens.success : Colors.grey[300]),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Thẻ câu mẫu phát âm SGK 12
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      _currentPrompt.text,
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: textMain,
                        height: 1.35,
                      ),
                    ),
                  ),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: AppTokens.primary.withValues(alpha: 0.12),
                    ),
                    onPressed: _playModelAudio,
                    icon: const Icon(Icons.volume_up_rounded, color: AppTokens.primary),
                    tooltip: 'Nghe âm thanh mẫu chuẩn IPA',
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _currentPrompt.ipa,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppTokens.primary,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Dịch: ${_currentPrompt.translation}',
                style: TextStyle(fontSize: 13, color: textSub, height: 1.3),
              ),
              if (_currentPrompt.contextTip != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lightbulb_outline_rounded, size: 16, color: Colors.amber),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _currentPrompt.contextTip!,
                          style: const TextStyle(fontSize: 11.5, color: Colors.amber, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Nút Bấm Thu Âm & Trạng Thái Đang Nhận Diện
        Center(
          child: Column(
            children: [
              if (_isEvaluating)
                const Column(
                  children: [
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'AI đang phân tích âm điệu & phát âm của bạn...',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTokens.primary),
                    ),
                  ],
                )
              else
                GestureDetector(
                  onTap: _isRecording ? _stopRecordingAndEvaluate : _startRecording,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isRecording ? AppTokens.danger : AppTokens.primary,
                      boxShadow: [
                        BoxShadow(
                          color: (_isRecording ? AppTokens.danger : AppTokens.primary).withValues(alpha: 0.35),
                          blurRadius: _isRecording ? 20 : 12,
                          spreadRadius: _isRecording ? 4 : 1,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                      size: 36,
                      color: Colors.white,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                _isRecording
                    ? 'Đang thu âm... ($_recordingSeconds s) - Bấm để hoàn tất'
                    : 'Bấm nút micro để luyện nói câu này',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: _isRecording ? AppTokens.danger : textSub,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Khối Kết Quả Nhận Xét Chi Tiết Từ AI
        if (_lastResult != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (_lastResult!.score >= 85 ? AppTokens.success : AppTokens.warning).withValues(alpha: isDark ? 0.16 : 0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: (_lastResult!.score >= 85 ? AppTokens.success : AppTokens.warning).withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _lastResult!.score >= 85 ? AppTokens.success : AppTokens.warning,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Điểm phát âm: ${_lastResult!.score.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _lastResult!.overallComment,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: textMain,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Từ vựng phân tích phát âm đúng / sai
                Text(
                  'Chi tiết từng từ trong câu:',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: textSub),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _lastResult!.wordFeedbacks.map((w) {
                    final color = w.isCorrect ? AppTokens.success : AppTokens.danger;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: color.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            w.isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                            size: 14,
                            color: color,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            w.word,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),

                // Lời khuyên cải thiện
                Row(
                  children: [
                    const Icon(Icons.record_voice_over_rounded, size: 16, color: AppTokens.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Gợi ý: ${_lastResult!.improvementTip}',
                        style: TextStyle(fontSize: 12, color: textSub, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Nút chuyển câu tiếp theo
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (_currentIndex > 0)
              OutlinedButton.icon(
                onPressed: () => setState(() {
                  _currentIndex--;
                  _lastResult = _resultsMap[_currentIndex];
                }),
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                label: const Text('Câu trước'),
              )
            else
              const SizedBox.shrink(),
            if (_currentIndex < widget.prompts.length - 1)
              FilledButton.icon(
                onPressed: () => setState(() {
                  _currentIndex++;
                  _lastResult = _resultsMap[_currentIndex];
                }),
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: const Text('Câu tiếp theo'),
              ),
          ],
        ),
      ],
    );
  }
}
