import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../data/trial_lesson_repository.dart';
import '../../data/translation_service.dart';
import '../theme/app_tokens.dart';

/// Loại hỗ trợ người học đã sử dụng
enum ReadingAssistanceType {
  wordLookup, // Tra từ/cụm từ
  selectionTranslate, // Bôi đen dịch đoạn chọn
  paragraphTranslate, // Mở bản dịch toàn đoạn/câu
}

/// Widget hiển thị văn bản bài đọc hoặc ngữ cảnh có hỗ trợ đọc hiểu tương tác:
/// - Chạm vào từ/cụm từ bất kỳ: giải nghĩa theo ngữ cảnh câu thực tế (nhận diện trợ động từ, dạng chia, cụm từ).
/// - Bôi đen văn bản và chọn "Dịch phần đã chọn": dịch đúng phần được chọn (có cache, kết nối dịch máy trực tuyến, thông báo ngoại tuyến trung thực, không bao giờ lấy bản dịch cả đoạn thế vào).
/// - Nút bấm độc lập "Dịch đoạn / Dịch câu": bật/tắt bản dịch tiếng Việt biên soạn ngay dưới nguyên văn, chỉ mở khi người học chủ động chọn.
/// - Hoạt động nhất quán trong bài đọc, ngữ cảnh câu hỏi, phần đọc lại và phương án trả lời.
class InteractiveReadingText extends StatefulWidget {
  final String text; // Văn bản tiếng Anh gốc
  final String? translation; // Bản dịch tiếng Việt biên soạn
  final Map<String, String>? keyVocabulary; // Từ vựng bài học
  final List<String>? highlightWords; // Các từ cần làm nổi bật nhẹ
  final String translateButtonLabel; // Ví dụ: "Dịch đoạn (Tiếng Việt)" hoặc "Dịch câu ngữ cảnh"
  final TextStyle? style;
  final bool showTranslateButton;
  final TrialLessonData? currentLesson;
  final ValueChanged<ReadingAssistanceType>? onAssistanceUsed;
  final VoidCallback? onInteractionStart; // Thông báo khi bắt đầu tương tác tra từ/dịch để chống xung đột

  const InteractiveReadingText({
    super.key,
    required this.text,
    this.translation,
    this.keyVocabulary,
    this.highlightWords,
    this.translateButtonLabel = 'Dịch đoạn (Tiếng Việt)',
    this.style,
    this.showTranslateButton = true,
    this.currentLesson,
    this.onAssistanceUsed,
    this.onInteractionStart,
  });

  @override
  State<InteractiveReadingText> createState() => _InteractiveReadingTextState();
}

class _InteractiveReadingTextState extends State<InteractiveReadingText> {
  bool _isTranslationExpanded = false;
  int _activeTranslationRequestId = 0;

  /// Tìm câu ngữ cảnh chứa từ trong văn bản
  String _findSentenceForWord(String rawWord) {
    final text = widget.text;
    final sentences = text.split(RegExp(r'(?<=[.!?])\s+|\n+'));
    final lowerWord = rawWord.toLowerCase();

    for (final s in sentences) {
      if (s.toLowerCase().contains(lowerWord)) {
        return s.trim();
      }
    }
    return text.trim();
  }

  void _onWordTapped(String rawWord) {
    widget.onInteractionStart?.call();

    final sentence = _findSentenceForWord(rawWord);
    final lookup = TrialLessonRepository.instance.lookupWordInContext(
      word: rawWord,
      sentence: sentence,
      currentLesson: widget.currentLesson,
    );

    // Chỉ ghi nhận hỗ trợ khi tra cứu có nội dung thực tế
    if (lookup.isFoundInDictionary || lookup.phraseSuggestion != null) {
      widget.onAssistanceUsed?.call(ReadingAssistanceType.wordLookup);
    }

    _showLookupModal(lookup);
  }

  void _onTranslateSelected(String selectedText) {
    widget.onInteractionStart?.call();

    final trimmed = selectedText.trim();
    if (trimmed.isEmpty) return;

    if (trimmed.length > 350) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Phần bôi đen quá dài (> 350 ký tự). Vui lòng chọn đoạn ngắn hơn hoặc dùng nút "Dịch đoạn" bên dưới.',
          ),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    _showSelectionTranslationModal(trimmed);
  }

  /// Modal tra từ ngữ cảnh: hiển thị từ loại, vai trò ngữ pháp, nghĩa trong câu, cụm từ gợi ý,
  /// và tự động tra nghĩa trực tuyến nếu từ chưa có trong từ điển ngoại tuyến.
  void _showLookupModal(WordLookupResult result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        bool isLoadingOnline = !result.isFoundInDictionary;
        String? onlineMeaning;
        String? onlineSource;
        bool onlineFailed = false;

        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            // Tự động tra nghĩa trực tuyến nếu từ chưa có trong từ điển ngoại tuyến
            if (isLoadingOnline && onlineMeaning == null && !onlineFailed) {
              TranslationService.instance
                  .translateSelection(
                text: result.query,
                currentLesson: widget.currentLesson,
                contextSentence: widget.text,
              )
                  .then((res) {
                if (modalCtx.mounted) {
                  setModalState(() {
                    isLoadingOnline = false;
                    if (res.isSuccess && res.translatedText.isNotEmpty) {
                      onlineMeaning = res.translatedText;
                      onlineSource = res.sourceLabel;
                      widget.onAssistanceUsed?.call(ReadingAssistanceType.wordLookup);
                    } else {
                      onlineFailed = true;
                    }
                  });
                }
              });
            }

            final isAvailable = result.isFoundInDictionary || onlineMeaning != null;

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 18,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: SafeArea(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle bar
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isAvailable
                                  ? const Color(0xFFEFF6FF)
                                  : const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isAvailable
                                  ? Icons.menu_book_rounded
                                  : Icons.lightbulb_outline_rounded,
                              color: isAvailable
                                  ? AppTokens.primary
                                  : const Color(0xFFD97706),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        result.displayWord,
                                        style: const TextStyle(
                                          fontFamily: 'BeVietnamPro',
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                    if (result.isPhrase) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE0E7FF),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'Cụm từ',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF3730A3),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (result.phonetic != null ||
                                    result.partOfSpeech != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    '${result.phonetic ?? ''}  ${result.partOfSpeech ?? ''}'
                                        .trim(),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF64748B),
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded,
                                color: Color(0xFF64748B)),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),

                      // Huy hiệu vai trò ngữ pháp theo ngữ cảnh
                      if (result.grammaticalRole != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFC7D2FE)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.psychology_outlined,
                                  size: 15, color: Color(0xFF4338CA)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Vai trò trong câu: ${result.grammaticalRole!}',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF3730A3),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),

                      // Hộp giải nghĩa
                      if (result.isFoundInDictionary) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Giải nghĩa theo ngữ cảnh trong câu:',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF475569),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                result.meaning,
                                style: const TextStyle(
                                  fontFamily: 'BeVietnamPro',
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (isLoadingOnline) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTokens.primary,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Đang tra cứu nghĩa cho từ này...',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: Color(0xFF475569),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (onlineMeaning != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Giải nghĩa tương ứng:',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E40AF),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                onlineMeaning!,
                                style: const TextStyle(
                                  fontFamily: 'BeVietnamPro',
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E3A8A),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.wifi_off_rounded,
                                      size: 16, color: Color(0xFFD97706)),
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Chưa có dữ liệu ngoại tuyến',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFB45309),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Vui lòng kết nối Internet để tra cứu trực tuyến từ "${result.displayWord}".',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF78350F),
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFB45309),
                                  side: const BorderSide(color: Color(0xFFF59E0B)),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                ),
                                icon: const Icon(Icons.refresh_rounded, size: 14),
                                label: const Text('Thử tra lại',
                                    style: TextStyle(fontSize: 12)),
                                onPressed: () {
                                  setModalState(() {
                                    isLoadingOnline = true;
                                    onlineFailed = false;
                                    onlineMeaning = null;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Thẻ gợi ý cụm từ có chứa từ này trong câu
                      if (result.phraseSuggestion != null &&
                          result.phraseMeaning != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.lightbulb_rounded,
                                      size: 16, color: Color(0xFF16A34A)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Cụm từ liên kết trong câu: "${result.phraseSuggestion}"',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF15803D),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                result.phraseMeaning!,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF166534),
                                ),
                              ),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _onWordTapped(result.phraseSuggestion!);
                                },
                                child: const Text(
                                  '👉 Chạm để tra cứu chi tiết cụm từ này',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF15803D),
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 10),
                      // Nguồn đối chiếu
                      Row(
                        children: [
                          const Icon(Icons.verified_outlined,
                              size: 13, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              onlineSource ?? result.source,
                              style: const TextStyle(
                                  fontSize: 11.5, color: Color(0xFF64748B)),
                            ),
                          ),
                        ],
                      ),

                      // Nút xem bản dịch toàn đoạn (tùy chọn)
                      if (!isAvailable && widget.translation != null) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTokens.primary,
                              side: const BorderSide(color: Color(0xFFBFDBFE)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.translate_rounded, size: 16),
                            label: const Text(
                                'Xem bản dịch toàn câu/đoạn chứa từ này',
                                style: TextStyle(fontSize: 12.5)),
                            onPressed: () {
                              Navigator.pop(ctx);
                              setState(() {
                                _isTranslationExpanded = true;
                              });
                              widget.onAssistanceUsed
                                  ?.call(ReadingAssistanceType.paragraphTranslate);
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Modal dịch cụm từ hoặc đoạn ngắn được chọn:
  /// - Giữ nguyên tiếng Anh gốc.
  /// - Dùng TranslationService kết nối trực tuyến hoặc cache hoặc từ điển cụm từ.
  /// - Nếu ngoại tuyến/mất mạng: báo rõ ràng, không tự ý thay thế bằng bản dịch cả đoạn.
  /// - Người học chỉ thấy bản dịch cả đoạn khi CHỦ ĐỘNG bấm nút "Xem bản dịch toàn đoạn".
  void _showSelectionTranslationModal(String selectedText) {
    final requestId = ++_activeTranslationRequestId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        TranslationResult? translationResult;
        bool isLoading = true;

        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            // Kích hoạt dịch lần đầu khi mở modal
            if (isLoading && translationResult == null) {
              TranslationService.instance
                  .translateSelection(
                text: selectedText,
                currentLesson: widget.currentLesson,
                contextSentence: widget.text,
              )
                  .then((res) {
                // Kiểm tra xem request này có còn là request mới nhất không
                if (requestId == _activeTranslationRequestId && modalContext.mounted) {
                  setModalState(() {
                    isLoading = false;
                    translationResult = res;
                  });
                  if (res.isSuccess) {
                    widget.onAssistanceUsed
                        ?.call(ReadingAssistanceType.selectionTranslate);
                  }
                }
              });
            }

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 18,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: SafeArea(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.g_translate_rounded,
                              color: AppTokens.primary, size: 22),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Dịch phần bôi đen',
                              style: TextStyle(
                                fontFamily: 'BeVietnamPro',
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded,
                                color: Color(0xFF64748B)),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Phần tiếng Anh gốc người dùng chọn (giữ nguyên để đối chiếu)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Đoạn văn bản tiếng Anh được chọn:',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '"$selectedText"',
                              style: const TextStyle(
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Trạng thái đang tải
                      if (isLoading) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: AppTokens.primary,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Đang tra cứu và dịch phần đã chọn...',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: Color(0xFF475569),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ]
                      // Đã có kết quả dịch thành công
                      else if (translationResult != null &&
                          translationResult!.isSuccess) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Bản dịch tiếng Việt tương ứng:',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E40AF),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                translationResult!.translatedText,
                                style: const TextStyle(
                                  fontFamily: 'BeVietnamPro',
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E3A8A),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.verified_outlined,
                                size: 13, color: Color(0xFF16A34A)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                translationResult!.sourceLabel,
                                style: const TextStyle(
                                    fontSize: 11.5, color: Color(0xFF64748B)),
                              ),
                            ),
                          ],
                        ),
                      ]
                      // Xử lý ngoại tuyến trung thực / Lỗi dịch
                      else ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.wifi_off_rounded,
                                      size: 16, color: Color(0xFFD97706)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      translationResult?.errorMessage ??
                                          'Cần kết nối mạng để dịch phần văn bản này.',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFB45309),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Cụm từ này chưa có trong từ điển học liệu ngoại tuyến. Vui lòng kết nối Internet để nhận bản dịch tức thì.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF78350F),
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFB45309),
                                  side: const BorderSide(
                                      color: Color(0xFFF59E0B)),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                ),
                                icon: const Icon(Icons.refresh_rounded, size: 15),
                                label: const Text('Thử dịch lại',
                                    style: TextStyle(fontSize: 12)),
                                onPressed: () {
                                  setModalState(() {
                                    isLoading = true;
                                    translationResult = null;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        // Nút tùy chọn: Người học chủ động bấm xem bản dịch toàn đoạn
                        if (widget.translation != null) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTokens.primary,
                                side: const BorderSide(color: Color(0xFFBFDBFE)),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.translate_rounded, size: 16),
                              label: const Text(
                                'Xem bản dịch toàn đoạn (Đối chiếu SGK)',
                                style: TextStyle(fontSize: 12.5),
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                setState(() {
                                  _isTranslationExpanded = true;
                                });
                                widget.onAssistanceUsed?.call(
                                    ReadingAssistanceType.paragraphTranslate);
                              },
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle = widget.style ??
        const TextStyle(
          fontSize: 14.5,
          height: 1.6,
          color: Color(0xFF1E293B),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Văn bản chính: hỗ trợ chạm vào từng từ VÀ bôi đen văn bản
        SelectableText.rich(
          _buildTextSpans(baseStyle),
          contextMenuBuilder: (context, editableTextState) {
            final List<ContextMenuButtonItem> buttonItems =
                editableTextState.contextMenuButtonItems;

            // Thêm nút "Dịch phần đã chọn" lên đầu menu ngữ cảnh
            buttonItems.insert(
              0,
              ContextMenuButtonItem(
                label: 'Dịch phần đã chọn',
                onPressed: () {
                  final text = editableTextState.textEditingValue.selection
                      .textInside(editableTextState.textEditingValue.text);
                  ContextMenuController.removeAny();
                  _onTranslateSelected(text);
                },
              ),
            );

            return AdaptiveTextSelectionToolbar.buttonItems(
              anchors: editableTextState.contextMenuAnchors,
              buttonItems: buttonItems,
            );
          },
        ),

        // Nút bấm độc lập Dịch đoạn / Dịch câu nếu có bản dịch
        if (widget.showTranslateButton && widget.translation != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  setState(() {
                    _isTranslationExpanded = !_isTranslationExpanded;
                  });
                  if (_isTranslationExpanded) {
                    widget.onAssistanceUsed
                        ?.call(ReadingAssistanceType.paragraphTranslate);
                  }
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isTranslationExpanded
                            ? Icons.expand_less_rounded
                            : Icons.translate_rounded,
                        size: 16,
                        color: AppTokens.primary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _isTranslationExpanded
                              ? 'Thu gọn bản dịch'
                              : widget.translateButtonLabel,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppTokens.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Khối bản dịch tiếng Việt bung ra ngay bên dưới
          if (_isTranslationExpanded) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.translate_rounded,
                          size: 13, color: Color(0xFF2563EB)),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Bản dịch hỗ trợ do ứng dụng biên soạn (Đối chiếu):',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E40AF),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.translation!,
                    style: const TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 13.5,
                      height: 1.5,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }

  /// Phân tích văn bản thành các TextSpan:
  /// - Ưu tiên nhận diện các cụm từ (Phrasal Verbs / Idioms / Multi-word terms).
  /// - Từng từ đơn lẻ đều có thể chạm để tra cứu với ngữ cảnh câu.
  /// - Các từ vựng trọng tâm được tô đậm nhẹ để học viên chú ý (không tô xanh toàn bộ).
  TextSpan _buildTextSpans(TextStyle baseStyle) {
    final text = widget.text;
    final spans = <InlineSpan>[];

    // Thu thập danh sách các từ/cụm từ ưu tiên tìm kiếm
    final lessonVocab =
        widget.keyVocabulary ?? widget.currentLesson?.vocabulary ?? {};
    final priorityKeys = <String>{
      ...lessonVocab.keys,
      ...TrialLessonRepository.phraseDictionary.keys,
      if (widget.highlightWords != null) ...widget.highlightWords!,
    }.toList()
      ..sort((a, b) => b.length.compareTo(a.length)); // Khớp cụm dài trước

    // Tách văn bản thành các token (từ và dấu câu/khoảng trắng)
    final tokenPattern = RegExp(r"(\b[a-zA-Z0-9'\u2019\-]+\b|\s+|[^\s\w])");
    final matches = tokenPattern.allMatches(text).toList();

    int i = 0;
    while (i < matches.length) {
      final match = matches[i];
      final token = match.group(0)!;

      // Kiểm tra xem tại vị trí này có bắt đầu bằng cụm từ ưu tiên hay không (2-3 từ)
      bool matchedPhrase = false;
      for (final key in priorityKeys) {
        if (!key.contains(' ')) continue; // Chỉ xét cụm từ có dấu cách
        final keyLower = key.toLowerCase();

        // Ghép thử các token tiếp theo để kiểm tra
        final wordsInKey = key.split(' ');
        if (i + (wordsInKey.length * 2) - 1 <= matches.length) {
          final candidateTokens = <String>[];
          for (int step = 0; step < wordsInKey.length * 2 - 1; step++) {
            candidateTokens.add(matches[i + step].group(0)!);
          }
          final candidateStr = candidateTokens.join('').toLowerCase();
          if (candidateStr == keyLower) {
            final matchedDisplay = candidateTokens.join('');
            spans.add(
              TextSpan(
                text: matchedDisplay,
                style: baseStyle.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1D4ED8),
                  backgroundColor: const Color(0xFFDBEAFE),
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () => _onWordTapped(key),
              ),
            );
            i += candidateTokens.length;
            matchedPhrase = true;
            break;
          }
        }
      }

      if (matchedPhrase) continue;

      // Nếu là từ thông thường
      if (RegExp(r"^[a-zA-Z0-9'\u2019\-]+$").hasMatch(token)) {
        final cleanLower = token.toLowerCase();
        final isKeyWord = lessonVocab.containsKey(cleanLower) ||
            (widget.highlightWords?.any((w) => w.toLowerCase() == cleanLower) ??
                false);

        spans.add(
          TextSpan(
            text: token,
            style: isKeyWord
                ? baseStyle.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1D4ED8),
                    backgroundColor: const Color(0xFFEFF6FF),
                  )
                : baseStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () => _onWordTapped(token),
          ),
        );
      } else {
        // Dấu câu hoặc khoảng trắng
        spans.add(TextSpan(text: token, style: baseStyle));
      }

      i++;
    }

    return TextSpan(children: spans);
  }
}
