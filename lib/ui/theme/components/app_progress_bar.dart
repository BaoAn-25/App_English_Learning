import 'package:flutter/material.dart';
import '../app_tokens.dart';

/// Thanh tiến độ học tập bo tròn mềm mại, hỗ trợ animation chuyển động mượt mà.
///
/// Cách dùng:
/// ```dart
/// AppProgressBar(
///   value: 0.65, // 0.0 -> 1.0
///   height: 10,
///   color: AppTokens.primary,
/// )
/// ```
class AppProgressBar extends StatelessWidget {
  final double value; // từ 0.0 đến 1.0
  final double height;
  final Color? color;
  final Color? backgroundColor;

  const AppProgressBar({
    super.key,
    required this.value,
    this.height = 8.0,
    this.color,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clampedValue = value.clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final progressWidth = totalWidth * clampedValue;

        return Container(
          height: height,
          width: totalWidth,
          decoration: BoxDecoration(
            color: backgroundColor ?? (theme.brightness == Brightness.dark
                ? const Color(0xFF2C3545)
                : const Color(0xFFE2EAF8)),
            borderRadius: BorderRadius.circular(height / 2),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              width: progressWidth,
              height: height,
              decoration: BoxDecoration(
                color: color ?? AppTokens.primary,
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
          ),
        );
      },
    );
  }
}
