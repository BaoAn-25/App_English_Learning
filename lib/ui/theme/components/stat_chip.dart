import 'package:flutter/material.dart';
import '../app_tokens.dart';

enum StatChipType { streak, xp, time, accuracy, custom }

/// Chip hiển thị các chỉ số nhanh: Streak, XP, thời gian hoặc tỷ lệ đúng.
///
/// Cách dùng:
/// ```dart
/// StatChip(
///   type: StatChipType.streak,
///   value: '5 ngày',
/// )
/// ```
class StatChip extends StatelessWidget {
  final StatChipType type;
  final String value;
  final String? label;
  final IconData? customIcon;
  final Color? customColor;
  final VoidCallback? onTap;

  const StatChip({
    super.key,
    required this.type,
    required this.value,
    this.label,
    this.customIcon,
    this.customColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    IconData icon;
    Color chipColor;
    Color iconColor;

    switch (type) {
      case StatChipType.streak:
        icon = Icons.local_fire_department_rounded;
        chipColor = isDark ? const Color(0xFF3A2B14) : const Color(0xFFFFF4DE);
        iconColor = const Color(0xFFFF9800);
        break;
      case StatChipType.xp:
        icon = Icons.bolt_rounded;
        chipColor = isDark ? const Color(0xFF383216) : const Color(0xFFFFF9E5);
        iconColor = const Color(0xFFFFB300);
        break;
      case StatChipType.time:
        icon = Icons.schedule_rounded;
        chipColor = isDark ? const Color(0xFF1E2E42) : const Color(0xFFE8F2FF);
        iconColor = AppTokens.primary;
        break;
      case StatChipType.accuracy:
        icon = Icons.check_circle_outline_rounded;
        chipColor = isDark ? const Color(0xFF163529) : const Color(0xFFE6F7F0);
        iconColor = AppTokens.successGreen;
        break;
      case StatChipType.custom:
        icon = customIcon ?? Icons.star_rounded;
        chipColor = isDark ? const Color(0xFF262E3D) : const Color(0xFFF1F5F9);
        iconColor = customColor ?? AppTokens.primary;
        break;
    }

    Widget content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: AppTokens.space4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppTokens.textMain,
            ),
          ),
          if (label != null) ...[
            const SizedBox(width: AppTokens.space4),
            Text(
              label!,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
        child: content,
      );
    }
    return content;
  }
}
