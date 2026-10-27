import 'package:flutter/material.dart';

/// Card lựa chọn đáp án chuẩn Material 3 cho bài làm trắc nghiệm.
///
/// Đáp ứng tiêu chuẩn UI/UX EdTech:
/// - Vùng chạm lớn tối thiểu 52dp.
/// - Huy hiệu A, B, C, D tròn, rõ ràng.
/// - Trạng thái chọn hiển thị viền nổi bật và nền tint nhẹ.
/// - Khi đã nộp bài (submitted):
///   * Đáp án đúng: Viền xanh lá, nền xanh nhạt, icon check_circle.
///   * Đáp án chọn sai: Viền đỏ, nền đỏ nhạt, icon cancel.
class QuizOptionCard extends StatelessWidget {
  final int index;
  final String text;
  final bool isSelected;
  final bool isSubmitted;
  final bool isCorrect;
  final VoidCallback? onTap;

  const QuizOptionCard({
    super.key,
    required this.index,
    required this.text,
    required this.isSelected,
    this.isSubmitted = false,
    this.isCorrect = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final letter = String.fromCharCode(65 + index);

    // Xác định màu sắc theo trạng thái
    Color borderColor;
    Color? backgroundColor;
    Color letterBgColor;
    Color letterTextColor;
    Widget? trailingIcon;

    if (isSubmitted) {
      if (isCorrect) {
        borderColor = Colors.green.shade600;
        backgroundColor = Colors.green.withValues(alpha: 0.12);
        letterBgColor = Colors.green.shade600;
        letterTextColor = Colors.white;
        trailingIcon = const Icon(
          Icons.check_circle_rounded,
          color: Colors.green,
          size: 24,
        );
      } else if (isSelected && !isCorrect) {
        borderColor = Colors.red.shade600;
        backgroundColor = Colors.red.withValues(alpha: 0.12);
        letterBgColor = Colors.red.shade600;
        letterTextColor = Colors.white;
        trailingIcon = const Icon(
          Icons.cancel_rounded,
          color: Colors.red,
          size: 24,
        );
      } else {
        borderColor = colorScheme.outlineVariant.withValues(alpha: 0.5);
        backgroundColor = colorScheme.surface;
        letterBgColor = colorScheme.surfaceContainerHighest;
        letterTextColor = colorScheme.onSurfaceVariant;
      }
    } else {
      if (isSelected) {
        borderColor = colorScheme.primary;
        backgroundColor = colorScheme.primaryContainer.withValues(alpha: 0.25);
        letterBgColor = colorScheme.primary;
        letterTextColor = colorScheme.onPrimary;
        trailingIcon = Icon(
          Icons.radio_button_checked_rounded,
          color: colorScheme.primary,
          size: 22,
        );
      } else {
        borderColor = colorScheme.outlineVariant.withValues(alpha: 0.6);
        backgroundColor = colorScheme.surface;
        letterBgColor = colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.8,
        );
        letterTextColor = colorScheme.onSurfaceVariant;
        trailingIcon = Icon(
          Icons.radio_button_off_rounded,
          color: colorScheme.outline.withValues(alpha: 0.5),
          size: 22,
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Material(
        color: backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: borderColor,
            width: isSelected || (isSubmitted && isCorrect) ? 2.0 : 1.0,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Huy hiệu chữ cái A, B, C, D
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: letterBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    letter,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: letterTextColor,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Nội dung đáp án
                Expanded(
                  child: Text(
                    text,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      height: 1.35,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),

                if (trailingIcon != null) ...[
                  const SizedBox(width: 10),
                  trailingIcon,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
