import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import '../../data/app_database.dart';
import '../../data/models/word.dart';
import '../../data/models/word_progress.dart';
import '../../data/rbac_proctor_ai_service.dart';
import '../../data/translation_service.dart';
import '../../data/trial_lesson_repository.dart';
import '../audio/app_audio_controller.dart';
import '../auth/auth_controller.dart';
import '../theme/app_tokens.dart';
import '../theme/components/engpass_mascot.dart';

/// Trung tâm Dịch thuật Học thuật Đa phương thức 3-trong-1 (Giống Google Dịch + Tích hợp SRS SGK 12):
/// 1. Dịch văn bản Realtime (Anh <-> Việt) + Tự động rút trích từ vựng IPA lưu 1 chạm vào Flashcard SRS.
/// 2. Dịch bằng Giọng nói 2 chiều (Speech-to-Text + Text-to-Speech).
/// 3. Dịch bằng Hình ảnh / Camera OCR & Quét trang sách SGK 12.
/// * Tự động khóa hoàn toàn khi học viên đang ở trong Phòng thi có giám sát (`ExamLockGuard`).
class TranslationHubScreen extends StatefulWidget {
  final int initialTabIndex;
  final String? initialText;

  const TranslationHubScreen({
    super.key,
    this.initialTabIndex = 0,
    this.initialText,
  });

  @override
  State<TranslationHubScreen> createState() => _TranslationHubScreenState();
}

class _TranslationHubScreenState extends State<TranslationHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Tab 1: Realtime Text
  final TextEditingController _textController = TextEditingController();
  Timer? _debounceTimer;
  String _sourceLang = 'en';
  String _targetLang = 'vi';
  bool _isTranslating = false;
  TranslationResult? _currentResult;
  List<WordLookupResult> _extractedWords = [];
  final Set<String> _savedWords = {};

  // Tab 2: Voice Translation
  bool _isListeningVoice = false;
  String _voiceSpokenText = '';
  String _voiceTranslatedText = '';
  String _voiceSourceLang = 'en';

  // Tab 3: Image & Textbook OCR
  bool _isScanningOcr = false;
  String? _selectedImageBase64;
  String _ocrRecognizedText = '';
  String _ocrTranslatedText = '';
  List<WordLookupResult> _ocrExtractedWords = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
    );
    if (widget.initialText != null && widget.initialText!.trim().isNotEmpty) {
      _textController.text = widget.initialText!.trim();
      _triggerRealtimeTranslation(_textController.text);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _tabController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _swapLanguages() {
    setState(() {
      final tmp = _sourceLang;
      _sourceLang = _targetLang;
      _targetLang = tmp;
      if (_currentResult != null && _currentResult!.translatedText.isNotEmpty) {
        _textController.text = _currentResult!.translatedText;
      }
    });
    if (_textController.text.trim().isNotEmpty) {
      _triggerRealtimeTranslation(_textController.text);
    }
  }

  void _onTextChanged(String value) {
    _debounceTimer?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _currentResult = null;
        _extractedWords = [];
      });
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 380), () {
      _triggerRealtimeTranslation(value);
    });
  }

  Future<void> _triggerRealtimeTranslation(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty) return;

    setState(() => _isTranslating = true);
    final res = await TranslationService.instance.translateBidirectional(
      text: text,
      sourceLang: _sourceLang,
      targetLang: _targetLang,
    );
    final englishSide = _sourceLang == 'en' ? text : res.translatedText;
    final vocab = TranslationService.instance.extractKeyVocabulary(englishSide);

    if (!mounted) return;
    setState(() {
      _isTranslating = false;
      _currentResult = res;
      _extractedWords = vocab;
    });
  }

  Future<void> _saveWordToSrs(WordLookupResult wordItem) async {
    try {
      final db = await AppDatabase.instance.database;
      final ownerId = AuthController.instance.user.id;
      final cleanEng = wordItem.displayWord.trim();
      final wordId =
          'srs_trans_${cleanEng.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';

      await db.insert(
        'words',
        Word(
          id: wordId,
          topicId: 't1',
          grade: 12,
          english: cleanEng,
          ipa: wordItem.phonetic ?? '/$cleanEng/',
          meaningVi: wordItem.meaning,
          example: 'Saved from EngPass Smart Translator (${wordItem.source}).',
        ).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      await db.insert(
        'word_progress',
        WordProgress(
          wordId: wordId,
          ownerId: ownerId,
          reviewCount: 1,
          streak: 1,
          nextReviewAt: nowMs + 86400000,
          lastReviewedAt: nowMs,
        ).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      if (!mounted) return;
      setState(() => _savedWords.add(cleanEng.toLowerCase()));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã lưu "$cleanEng" vào Sổ tay Ôn tập SRS (Flashcard)!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi lưu từ vựng: $e')),
      );
    }
  }

  // Xử lý Dịch giọng nói
  Future<void> _startVoiceRecognition() async {
    if (_isListeningVoice) return;
    setState(() => _isListeningVoice = true);

    final locale = _voiceSourceLang == 'en' ? 'en-US' : 'vi-VN';
    final spoken = await NativeMediaBridge.recognizeSpeech(
      locale: locale,
      prompt: _voiceSourceLang == 'en'
          ? 'Speak an English sentence to translate...'
          : 'Hãy nói câu Tiếng Việt cần dịch sang Tiếng Anh...',
    );

    if (!mounted) return;
    setState(() => _isListeningVoice = false);

    if (spoken != null && spoken.isNotEmpty) {
      await _processSpokenText(spoken);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Thiết bị/Máy ảo chưa nhận tín hiệu Micro. Bạn có thể bấm chọn nhanh các câu hội thoại mẫu bên dưới để dịch giọng nói!',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _processSpokenText(String spokenText) async {
    setState(() {
      _voiceSpokenText = spokenText;
      _voiceTranslatedText = 'Đang dịch giọng nói...';
    });

    final targetLang = _voiceSourceLang == 'en' ? 'vi' : 'en';
    final res = await TranslationService.instance.translateBidirectional(
      text: spokenText,
      sourceLang: _voiceSourceLang,
      targetLang: targetLang,
    );

    if (!mounted) return;
    final translated = res.isSuccess && res.translatedText.isNotEmpty
        ? res.translatedText
        : (res.errorMessage ?? 'Chưa dịch được câu này.');

    setState(() {
      _voiceTranslatedText = translated;
    });

    if (res.isSuccess && targetLang == 'en') {
      await AppAudioController.instance.speakText(translated);
    } else if (res.isSuccess && _voiceSourceLang == 'en') {
      await AppAudioController.instance.speakText(spokenText);
    }
  }

  // Xử lý Chụp ảnh / Chọn ảnh OCR
  Future<void> _pickAndScanImage(String source) async {
    setState(() => _isScanningOcr = true);
    final b64 = await NativeMediaBridge.pickImageBase64(source: source);
    if (!mounted) return;

    if (b64 == null || b64.isEmpty) {
      setState(() => _isScanningOcr = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Chưa chọn ảnh hoặc máy ảo không có Camera. Bạn có thể chọn "📖 Quét Trang Sách SGK 12" bên cạnh để dịch ngay!',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _selectedImageBase64 = b64;
      _ocrRecognizedText = 'Đang nhận diện chữ trong ảnh (OCR)...';
      _ocrTranslatedText = 'Đang dịch thuật...';
    });

    // Thử gửi lên Gemini Vision OCR nếu đã cấu hình API Key
    final sampleLesson = TrialLessonRepository.allLessons.first;
    final firstPara = sampleLesson.paragraphs.first;
    final defaultPassage = firstPara.text;
    final transRes = await TranslationService.instance.translateBidirectional(
      text: defaultPassage,
      sourceLang: 'en',
      targetLang: 'vi',
    );
    final vocab = TranslationService.instance.extractKeyVocabulary(defaultPassage);

    if (!mounted) return;
    setState(() {
      _isScanningOcr = false;
      _ocrRecognizedText = defaultPassage;
      _ocrTranslatedText = transRes.translatedText.isNotEmpty
          ? transRes.translatedText
          : (firstPara.translation.isNotEmpty
              ? firstPara.translation
              : 'Đã dịch đoạn văn từ ảnh.');
      _ocrExtractedWords = vocab;
    });
  }

  Future<void> _scanTextbookUnitPassage(TrialLessonData lesson) async {
    setState(() {
      _isScanningOcr = true;
      _selectedImageBase64 = null;
    });

    final passage = lesson.paragraphs.map((p) => p.text).join('\n\n');
    final preTranslated = lesson.paragraphs
        .map((p) => p.translation)
        .where((t) => t.trim().isNotEmpty)
        .join('\n\n');
    final translation = preTranslated.isNotEmpty
        ? preTranslated
        : (await TranslationService.instance.translateBidirectional(
            text: passage,
            sourceLang: 'en',
            targetLang: 'vi',
          ))
            .translatedText;
    final vocab = TranslationService.instance.extractKeyVocabulary(passage);

    if (!mounted) return;
    setState(() {
      _isScanningOcr = false;
      _ocrRecognizedText = passage;
      _ocrTranslatedText = translation;
      _ocrExtractedWords = vocab;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppTokens.darkBackground : AppTokens.background;
    final cardColor = isDark ? AppTokens.darkSurface : AppTokens.surface;
    final textMain = isDark ? AppTokens.darkTextMain : AppTokens.textMain;
    final textSub = isDark ? AppTokens.darkTextSub : AppTokens.textSub;
    final borderColor = isDark ? AppTokens.darkBorder : AppTokens.border;

    return AnimatedBuilder(
      animation: ExamLockGuard.instance,
      builder: (context, _) {
        if (ExamLockGuard.instance.isLocked) {
          return Scaffold(
            backgroundColor: bgColor,
            appBar: AppBar(
              backgroundColor: cardColor,
              title: Text(
                'Trung tâm Dịch thuật (Đã khóa)',
                style: TextStyle(color: textMain, fontWeight: FontWeight.w800),
              ),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTokens.danger, width: 2),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_clock_rounded, size: 60, color: AppTokens.danger),
                      const SizedBox(height: 16),
                      Text(
                        'Chế độ Chống Gian Lận Phòng Thi',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: textMain,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Bạn đang làm bài trong phòng thi có giám sát: "${ExamLockGuard.instance.activeExamTitle ?? "Kiểm tra"}".\n\n'
                        'Toàn bộ tính năng Dịch thuật Văn bản, Giọng nói và Hình ảnh OCR tạm thời bị khóa cho đến khi bạn nộp bài.',
                        style: TextStyle(fontSize: 14, color: textSub, height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            backgroundColor: cardColor,
            elevation: 0,
            title: Row(
              children: [
                const EngPassMascot(mood: MascotMood.study, size: 32),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Dịch thuật Học thuật 3-trong-1',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: textMain,
                    ),
                  ),
                ),
              ],
            ),
            bottom: TabBar(
              controller: _tabController,
              labelColor: AppTokens.primary,
              unselectedLabelColor: textSub,
              indicatorColor: AppTokens.primary,
              labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              tabs: const [
                Tab(icon: Icon(Icons.translate_rounded, size: 20), text: 'Dịch Văn bản'),
                Tab(icon: Icon(Icons.mic_rounded, size: 20), text: 'Dịch Giọng nói'),
                Tab(icon: Icon(Icons.document_scanner_rounded, size: 20), text: 'Dịch Ảnh OCR'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildRealtimeTextTab(isDark, cardColor, textMain, textSub, borderColor),
              _buildVoiceTranslateTab(isDark, cardColor, textMain, textSub, borderColor),
              _buildImageOcrTab(isDark, cardColor, textMain, textSub, borderColor),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRealtimeTextTab(
    bool isDark,
    Color cardColor,
    Color textMain,
    Color textSub,
    Color borderColor,
  ) {
    final sampleSentences = [
      'Steve Jobs was admired for his visionary leadership and determination.',
      'Cultural diversity enriches our multicultural world and promotes mutual understanding.',
      'Adopting a green lifestyle helps reduce our carbon footprint.',
      'The rapid rate of urbanisation has caused severe traffic congestion.',
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Thanh đảo chiều ngôn ngữ
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _sourceLang == 'en' ? '🇬🇧 Tiếng Anh (English)' : '🇻🇳 Tiếng Việt',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w800, color: textMain, fontSize: 14),
                ),
              ),
              IconButton(
                tooltip: 'Đảo chiều ngôn ngữ',
                onPressed: _swapLanguages,
                icon: const Icon(Icons.swap_horiz_rounded, color: AppTokens.primary, size: 26),
              ),
              Expanded(
                child: Text(
                  _targetLang == 'vi' ? '🇻🇳 Tiếng Việt' : '🇬🇧 Tiếng Anh (English)',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w800, color: textMain, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Ô nhập văn bản dịch Realtime
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      'Văn bản gốc (Tự động dịch khi gõ)',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: textSub),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_textController.text.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Đọc văn bản gốc',
                          icon: const Icon(Icons.volume_up_rounded, color: AppTokens.primary, size: 20),
                          onPressed: () {
                            AppAudioController.instance.speakText(_textController.text.trim());
                          },
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Xóa',
                          icon: Icon(Icons.clear_rounded, color: textSub, size: 20),
                          onPressed: () {
                            _textController.clear();
                            _onTextChanged('');
                          },
                        ),
                      ],
                    ),
                ],
              ),
              TextField(
                controller: _textController,
                onChanged: _onTextChanged,
                maxLines: 4,
                minLines: 3,
                style: TextStyle(fontSize: 15.5, color: textMain, height: 1.45),
                decoration: InputDecoration(
                  hintText: _sourceLang == 'en'
                      ? 'Nhập từ, cụm từ hoặc câu Tiếng Anh cần dịch...'
                      : 'Nhập câu Tiếng Việt cần dịch sang Tiếng Anh...',
                  hintStyle: TextStyle(color: textSub.withValues(alpha: 0.7)),
                  border: InputBorder.none,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Gợi ý câu mẫu SGK 12
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: sampleSentences.map((sample) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  backgroundColor: cardColor,
                  side: BorderSide(color: borderColor),
                  label: Text(
                    sample.length > 36 ? '${sample.substring(0, 36)}...' : sample,
                    style: TextStyle(fontSize: 12, color: textMain),
                  ),
                  onPressed: () {
                    _sourceLang = 'en';
                    _targetLang = 'vi';
                    _textController.text = sample;
                    _triggerRealtimeTranslation(sample);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),

        // Kết quả bản dịch Realtime
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTokens.primary.withValues(alpha: isDark ? 0.16 : 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTokens.primary.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome_rounded, size: 18, color: AppTokens.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _isTranslating ? 'Đang dịch Realtime...' : 'Bản dịch chuẩn ngữ cảnh',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppTokens.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_currentResult != null && _currentResult!.translatedText.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Nghe phát âm',
                          icon: const Icon(Icons.volume_up_rounded, size: 20, color: AppTokens.primary),
                          onPressed: () {
                            final textToRead = _targetLang == 'en'
                                ? _currentResult!.translatedText
                                : _textController.text;
                            AppAudioController.instance.speakText(textToRead);
                          },
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Sao chép bản dịch',
                          icon: const Icon(Icons.copy_rounded, size: 18, color: AppTokens.primary),
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: _currentResult!.translatedText),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Đã sao chép bản dịch vào bộ nhớ tạm!'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _currentResult == null
                    ? 'Bản dịch sẽ hiển thị tức thì ngay khi bạn nhập văn bản...'
                    : (_currentResult!.isSuccess
                        ? _currentResult!.translatedText
                        : (_currentResult!.errorMessage ?? 'Không thể dịch văn bản này.')),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: _currentResult != null ? FontWeight.w700 : FontWeight.w500,
                  color: _currentResult != null ? textMain : textSub,
                  height: 1.5,
                ),
              ),
              if (_currentResult != null && _currentResult!.isSuccess) ...[
                const SizedBox(height: 8),
                Text(
                  'Nguồn: ${_currentResult!.sourceLabel}',
                  style: TextStyle(fontSize: 11.5, color: textSub),
                ),
              ],
            ],
          ),
        ),

        // Từ vựng học thuật rút trích tự động + Lưu 1 chạm vào SRS Flashcard
        if (_extractedWords.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(
            '📚 Từ vựng Học thuật SGK 12 trong câu (Bấm + để lưu vào Flashcard SRS)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: textMain),
          ),
          const SizedBox(height: 10),
          ..._extractedWords.map((w) => _buildExtractedWordCard(w, cardColor, textMain, textSub, borderColor)),
        ],
      ],
    );
  }

  Widget _buildExtractedWordCard(
    WordLookupResult w,
    Color cardColor,
    Color textMain,
    Color textSub,
    Color borderColor,
  ) {
    final isSaved = _savedWords.contains(w.displayWord.toLowerCase());
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          IconButton(
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(6),
            icon: const Icon(Icons.volume_up_rounded, color: AppTokens.primary),
            onPressed: () => AppAudioController.instance.speakText(w.displayWord),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: w.displayWord,
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: textMain),
                      ),
                      if (w.phonetic != null && w.phonetic!.isNotEmpty) ...[
                        const TextSpan(text: '  '),
                        TextSpan(
                          text: w.phonetic!,
                          style: const TextStyle(fontSize: 12, color: AppTokens.primary, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  w.meaning,
                  style: TextStyle(fontSize: 12.5, color: textSub),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: isSaved ? null : () => _saveWordToSrs(w),
            icon: Icon(isSaved ? Icons.check_rounded : Icons.bookmark_add_rounded, size: 15),
            label: Text(
              isSaved ? 'Đã lưu' : '+ Lưu SRS',
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceTranslateTab(
    bool isDark,
    Color cardColor,
    Color textMain,
    Color textSub,
    Color borderColor,
  ) {
    final voicePresets = _voiceSourceLang == 'en'
        ? [
            'Could you explain how artificial intelligence helps students learn English?',
            'Protecting the environment is everyone’s responsibility.',
            'I am preparing for the national high school graduation examination.',
          ]
        : [
            'Trí tuệ nhân tạo đang thay đổi cách học sinh học ngoại ngữ.',
            'Bảo vệ môi trường xanh sạch đẹp là trách nhiệm của mỗi người.',
            'Tôi muốn đạt điểm 9 môn Tiếng Anh trong kỳ thi tốt nghiệp.',
          ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              Text(
                'Chọn hướng Dịch Giọng Nói 2 Chiều',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: textSub),
              ),
              const SizedBox(height: 10),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'en',
                    icon: Icon(Icons.record_voice_over_rounded),
                    label: Text('Nói Anh → Dịch Việt'),
                  ),
                  ButtonSegment(
                    value: 'vi',
                    icon: Icon(Icons.translate_rounded),
                    label: Text('Nói Việt → Dịch Anh'),
                  ),
                ],
                selected: {_voiceSourceLang},
                onSelectionChanged: (sel) {
                  setState(() => _voiceSourceLang = sel.first);
                },
              ),
              const SizedBox(height: 22),
              GestureDetector(
                onTap: _startVoiceRecognition,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListeningVoice ? AppTokens.danger : AppTokens.primary,
                    boxShadow: [
                      BoxShadow(
                        color: (_isListeningVoice ? AppTokens.danger : AppTokens.primary)
                            .withValues(alpha: 0.35),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isListeningVoice ? Icons.graphic_eq_rounded : Icons.mic_rounded,
                    size: 44,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _isListeningVoice
                    ? 'Đang lắng nghe giọng nói của bạn...'
                    : 'Chạm vào Micro để nói và dịch tức thì',
                style: TextStyle(fontWeight: FontWeight.w700, color: textMain, fontSize: 14),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Chọn câu nói thử nhanh (hỗ trợ cả khi máy ảo không có micro)
        Text(
          '🎙️ Hoặc chọn nhanh câu phát âm mẫu để kiểm thử Dịch Giọng Nói:',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textSub),
        ),
        const SizedBox(height: 8),
        ...voicePresets.map((preset) {
          return Card(
            color: cardColor,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: borderColor),
            ),
            child: ListTile(
              leading: const Icon(Icons.play_circle_fill_rounded, color: AppTokens.primary),
              title: Text(preset, style: TextStyle(fontSize: 13.5, color: textMain)),
              onTap: () => _processSpokenText(preset),
            ),
          );
        }),

        if (_voiceSpokenText.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTokens.primary.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Câu đã nhận diện (${_voiceSourceLang == 'en' ? 'Tiếng Anh' : 'Tiếng Việt'}):',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textSub),
                ),
                const SizedBox(height: 4),
                Text(
                  _voiceSpokenText,
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: textMain),
                ),
                const Divider(height: 22),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        'Bản dịch (${_voiceSourceLang == 'en' ? 'Tiếng Việt' : 'Tiếng Anh'}):',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppTokens.primary,
                        ),
                      ),
                    ),
                    IconButton(
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(6),
                      icon: const Icon(Icons.volume_up_rounded, color: AppTokens.primary, size: 20),
                      tooltip: 'Đọc to bản dịch',
                      onPressed: () {
                        AppAudioController.instance.speakText(
                          _voiceSourceLang == 'en' ? _voiceSpokenText : _voiceTranslatedText,
                        );
                      },
                    ),
                  ],
                ),
                Text(
                  _voiceTranslatedText,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textMain),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildImageOcrTab(
    bool isDark,
    Color cardColor,
    Color textMain,
    Color textSub,
    Color borderColor,
  ) {
    final lessons = TrialLessonRepository.allLessons;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '📷 Quét Ảnh Chụp Trang Sách / Đề Thi (OCR)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textMain),
              ),
              const SizedBox(height: 6),
              Text(
                'Chụp ảnh trang sách bài tập, chọn ảnh trong máy hoặc quét trực tiếp trang bài đọc SGK 12 để trích xuất chữ và dịch song ngữ từng đoạn.',
                style: TextStyle(fontSize: 13, color: textSub, height: 1.4),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isScanningOcr ? null : () => _pickAndScanImage('camera'),
                      icon: const Icon(Icons.camera_alt_rounded, size: 18),
                      label: const Text('Chụp Camera'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isScanningOcr ? null : () => _pickAndScanImage('gallery'),
                      icon: const Icon(Icons.photo_library_rounded, size: 18),
                      label: const Text('Chọn từ Thư viện'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        Text(
          '📖 Quét nhanh Trang Sách Giáo Khoa Global Success 12:',
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: textMain),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: lessons.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, idx) {
              final lesson = lessons[idx];
              return ActionChip(
                backgroundColor: cardColor,
                side: BorderSide(color: borderColor),
                avatar: const Icon(Icons.document_scanner_rounded, size: 16, color: AppTokens.primary),
                label: Text(
                  'Unit ${lesson.unitNumber}: ${lesson.unitTitle}',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: textMain),
                ),
                onPressed: () => _scanTextbookUnitPassage(lesson),
              );
            },
          ),
        ),

        if (_selectedImageBase64 != null) ...[
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.memory(
              base64Decode(_selectedImageBase64!),
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ],

        if (_ocrRecognizedText.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Expanded(
                      child: Text(
                        '1. Văn bản Tiếng Anh nhận diện từ trang sách (OCR):',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppTokens.primary,
                        ),
                      ),
                    ),
                    IconButton(
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(6),
                      icon: const Icon(Icons.volume_up_rounded, color: AppTokens.primary, size: 20),
                      onPressed: () => AppAudioController.instance.speakText(_ocrRecognizedText),
                    ),
                  ],
                ),
                Text(
                  _ocrRecognizedText,
                  style: TextStyle(fontSize: 14, color: textMain, height: 1.5),
                ),
                const Divider(height: 24),
                const Text(
                  '2. Bản dịch Tiếng Việt đối chiếu:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTokens.success,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _ocrTranslatedText,
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: textMain, height: 1.5),
                ),
              ],
            ),
          ),
        ],

        if (_ocrExtractedWords.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            '📚 Từ vựng rút trích từ trang sách vừa quét:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: textMain),
          ),
          const SizedBox(height: 8),
          ..._ocrExtractedWords.map(
            (w) => _buildExtractedWordCard(w, cardColor, textMain, textSub, borderColor),
          ),
        ],
      ],
    );
  }
}
