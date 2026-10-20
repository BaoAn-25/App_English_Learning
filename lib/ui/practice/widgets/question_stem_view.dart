import 'package:flutter/material.dart';

/// Widget chuyên dụng hiển thị nội dung câu hỏi (stem) chuẩn UI/UX EdTech.
///
/// Hỗ trợ định dạng thông minh cho:
/// 1. Dạng Sắp xếp câu (Arrange):
///    Tách các câu a., b., c., d., e. hoặc lời thoại ra từng dòng riêng biệt
///    kèm huy hiệu (badge) rõ ràng, dễ nhìn cho học sinh.
/// 2. Dạng Đọc hiểu (Reading):
///    Tách đoạn trích/đoạn văn vào khung đọc riêng và câu hỏi phía dưới.
/// 3. Dạng Biển báo (Signs):
///    Làm nổi bật nội dung biển báo trong khung biển báo chuyên biệt.
/// 4. Dạng Điền từ (Cloze) & các dạng khác:
///    Hiển thị với khoảng cách dòng và phân cấp chữ chuẩn Material 3.
///
/// QUY TẮC BẢO TOÀN DỮ LIỆU:
/// - Chỉ xử lý hiển thị trực quan trên giao diện.
/// - Tuyệt đối không thay đổi chuỗi gốc trong cơ sở dữ liệu.
/// - Nếu phát hiện chuỗi không khớp mẫu một cách an toàn, giữ nguyên văn bản gốc.
class QuestionStemView extends StatelessWidget {
  final String stem;
  final String? type;

  const QuestionStemView({super.key, required this.stem, this.type});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 1. Kiểm tra dạng Sắp xếp câu (Arrange)
    if (_isArrangeQuestion()) {
      final parsed = _parseArrangeStem();
      if (parsed != null) {
        return _buildArrangeView(context, parsed);
      }
    }

    // 2. Kiểm tra dạng Đọc hiểu (Reading)
    if (_isReadingQuestion()) {
      final parsed = _parseReadingStem();
      if (parsed != null) {
        return _buildReadingView(context, parsed);
      }
    }

    // 3. Kiểm tra dạng Biển báo (Signs)
    if (_isSignsQuestion()) {
      final parsed = _parseSignsStem();
      if (parsed != null) {
        return _buildSignsView(context, parsed);
      }
    }

    // 4. Mặc định: Hiển thị câu hỏi tiêu chuẩn với kiểu chữ thoáng, dễ đọc
    return Text(
      stem,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        height: 1.45,
        color: colorScheme.onSurface,
      ),
    );
  }

  bool _isArrangeQuestion() {
    if (type == 'arrange') return true;
    final lower = stem.toLowerCase();
    return lower.contains('arrange the sentences') ||
        lower.contains('arrange the dialogue') ||
        lower.contains('arrange the email');
  }

  bool _isReadingQuestion() {
    if (type == 'reading') return true;
    final lower = stem.toLowerCase();
    return lower.contains('read the passage:') ||
        lower.contains('read the following passage');
  }

  bool _isSignsQuestion() {
    if (type == 'signs') return true;
    final lower = stem.toLowerCase();
    return lower.contains('a sign reads:') ||
        lower.contains('what does the sign say') ||
        lower.contains('what does it mean');
  }

  // --- Parser & Renderer cho Dạng Sắp xếp (Arrange) ---

  _ArrangeData? _parseArrangeStem() {
    try {
      // Tìm vị trí bắt đầu của mục đầu tiên "a." hoặc "a)"
      final matchA = RegExp(
        r'\b(a[\.\)])\s+',
        caseSensitive: false,
      ).firstMatch(stem);
      if (matchA == null) return null;

      final intro = stem.substring(0, matchA.start).trim();
      final body = stem.substring(matchA.start);

      // Tách các mục a., b., c., d., e.
      final itemRegex = RegExp(r'([a-eA-E][\.\)])\s+');
      final matches = itemRegex.allMatches(body).toList();
      if (matches.isEmpty) return null;

      final items = <_ArrangeItem>[];
      for (int i = 0; i < matches.length; i++) {
        final currentMatch = matches[i];
        final label = currentMatch.group(1)!;
        final startContent = currentMatch.end;
        final endContent = (i + 1 < matches.length)
            ? matches[i + 1].start
            : body.length;

        final content = body.substring(startContent, endContent).trim();
        items.add(_ArrangeItem(label: label, content: content));
      }

      if (items.isEmpty) return null;

      return _ArrangeData(
        intro: intro.isNotEmpty ? intro : 'Arrange into a logical order:',
        items: items,
      );
    } catch (_) {
      return null;
    }
  }

  Widget _buildArrangeView(BuildContext context, _ArrangeData data) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Dòng yêu cầu đề bài
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Sắp xếp',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                data.intro,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Danh sách các ý a, b, c, d
        ...data.items.map((item) {
          final cleanLabel = item.label
              .replaceAll(RegExp(r'[\.\)]'), '')
              .trim();

          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.45,
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      cleanLabel,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.content,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.4,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // --- Parser & Renderer cho Dạng Đọc hiểu (Reading) ---

  _ReadingData? _parseReadingStem() {
    try {
      final questionIndex = stem.indexOf('Question:');
      if (questionIndex == -1) return null;

      var passagePart = stem.substring(0, questionIndex).trim();
      final questionPart = stem.substring(questionIndex).trim();

      // Bỏ tiền tố "Read the passage:" nếu có
      final passageMatch = RegExp(
        r'''^Read the passage:\s*['"“”]?([\s\S]+?)['"“”]?$''',
        caseSensitive: false,
      ).firstMatch(passagePart);
      if (passageMatch != null) {
        passagePart = passageMatch.group(1)?.trim() ?? passagePart;
      }

      return _ReadingData(passage: passagePart, question: questionPart);
    } catch (_) {
      return null;
    }
  }

  Widget _buildReadingView(BuildContext context, _ReadingData data) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Đoạn văn đọc hiểu
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.7),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.menu_book_rounded,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Đoạn văn đọc hiểu',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                data.passage,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Câu hỏi cho đoạn văn
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.help_outline_rounded,
              size: 20,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                data.question,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- Parser & Renderer cho Dạng Biển báo (Signs) ---

  _SignsData? _parseSignsStem() {
    try {
      // Ví dụ: A sign reads: 'NO LITTERING – KEEP THIS AREA CLEAN'. What does it mean?
      final signMatch = RegExp(
        r'''A sign reads:\s*['"“”]([\s\S]+?)['"“”]\.?\s*([\s\S]*)''',
        caseSensitive: false,
      ).firstMatch(stem);

      if (signMatch != null) {
        final signText = signMatch.group(1)?.trim() ?? '';
        var questionText = signMatch.group(2)?.trim() ?? '';
        if (questionText.isEmpty) {
          questionText = 'What does this sign mean?';
        }
        return _SignsData(signText: signText, questionText: questionText);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Widget _buildSignsView(BuildContext context, _SignsData data) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Hộp thông báo/biển báo
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.signpost_rounded,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'NOTICE / BIỂN BÁO',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                data.signText,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  height: 1.35,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Câu hỏi bên dưới
        Text(
          data.questionText,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            height: 1.4,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _ArrangeItem {
  final String label;
  final String content;

  const _ArrangeItem({required this.label, required this.content});
}

class _ArrangeData {
  final String intro;
  final List<_ArrangeItem> items;

  const _ArrangeData({required this.intro, required this.items});
}

class _ReadingData {
  final String passage;
  final String question;

  const _ReadingData({required this.passage, required this.question});
}

class _SignsData {
  final String signText;
  final String questionText;

  const _SignsData({required this.signText, required this.questionText});
}
