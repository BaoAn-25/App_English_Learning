import 'package:flutter/material.dart';
import '../app_tokens.dart';

/// Thẻ Card chuẩn phong cách Material 3 với bo góc lớn (16-24) và bóng nhẹ.
///
/// Cách dùng:
/// ```dart
/// AppCard(
///   padding: EdgeInsets.all(16),
///   onTap: () {},
///   child: Text('Nội dung'),
/// )
/// ```
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final double borderRadius;
  final Border? border;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppTokens.space16),
    this.onTap,
    this.color,
    this.borderRadius = AppTokens.radiusLarge,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardColor = color ?? (isDark ? theme.colorScheme.surface : Colors.white);

    final cardWidget = Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: border ??
            Border.all(
              color: isDark ? const Color(0xFF2C3545) : const Color(0xFFE8EEF8),
              width: 1,
            ),
        boxShadow: isDark
            ? []
            : const [
                BoxShadow(
                  color: Color(0x0A1F2A44),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: cardWidget,
        ),
      );
    }

    return cardWidget;
  }
}
