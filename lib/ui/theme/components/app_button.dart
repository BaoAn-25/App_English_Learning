import 'package:flutter/material.dart';
import '../app_tokens.dart';

enum AppButtonVariant { primary, secondary, outlined, text, google, success }

/// Nút bấm chuẩn của ứng dụng mang phong cách Duolingo 3D (rounded + bottom bevel).
/// Đảm bảo vùng bấm tối thiểu 48dp (Accessibility), hỗ trợ trạng thái loading và Google Sign-in.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Widget? leading;
  final bool isLoading;
  final bool isFullWidth;
  final AppButtonVariant variant;
  final double height;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.leading,
    this.isLoading = false,
    this.isFullWidth = false,
    this.variant = AppButtonVariant.primary,
    this.height = 52.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEnabled = onPressed != null && !isLoading;

    // Màu sắc theo variant
    Color bgColor;
    Color bevelColor;
    Color textColor;
    Border? border;

    switch (variant) {
      case AppButtonVariant.primary:
        bgColor = const Color(0xFF2563EB); // Royal Blue
        bevelColor = const Color(0xFF1D4ED8);
        textColor = Colors.white;
        break;
      case AppButtonVariant.success:
        bgColor = const Color(0xFF16A34A); // Green Duolingo
        bevelColor = const Color(0xFF15803D);
        textColor = Colors.white;
        break;
      case AppButtonVariant.secondary:
        bgColor = const Color(0xFFFFC53D); // Warm Yellow
        bevelColor = const Color(0xFFD97706);
        textColor = const Color(0xFF1F2937);
        break;
      case AppButtonVariant.outlined:
        bgColor = Colors.white;
        bevelColor = const Color(0xFFE2E8F0);
        textColor = theme.colorScheme.primary;
        border = Border.all(color: const Color(0xFFCBD5E1), width: 1.5);
        break;
      case AppButtonVariant.google:
        bgColor = Colors.white;
        bevelColor = const Color(0xFFE2E8F0);
        textColor = const Color(0xFF1E293B);
        border = Border.all(color: const Color(0xFFE2E8F0), width: 1.5);
        break;
      case AppButtonVariant.text:
        bgColor = Colors.transparent;
        bevelColor = Colors.transparent;
        textColor = theme.colorScheme.primary;
        break;
    }

    if (!isEnabled && variant != AppButtonVariant.text) {
      bgColor = const Color(0xFFE2E8F0);
      bevelColor = const Color(0xFFCBD5E1);
      textColor = const Color(0xFF94A3B8);
      border = null;
    }

    Widget content;
    if (isLoading) {
      content = SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(
            variant == AppButtonVariant.primary || variant == AppButtonVariant.success
                ? Colors.white
                : theme.colorScheme.primary,
          ),
        ),
      );
    } else {
      content = Row(
        mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AppTokens.space12),
          ] else if (variant == AppButtonVariant.google) ...[
            _buildGoogleGIcon(),
            const SizedBox(width: AppTokens.space12),
          ] else if (icon != null) ...[
            Icon(icon, size: 20, color: textColor),
            const SizedBox(width: AppTokens.space8),
          ],
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: textColor,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      );
    }

    final buttonWidget = AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      height: height,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: border,
        boxShadow: isEnabled && variant != AppButtonVariant.text
            ? [
                BoxShadow(
                  color: bevelColor,
                  offset: const Offset(0, 3.5),
                  blurRadius: 0,
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isEnabled ? onPressed : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Center(child: content),
          ),
        ),
      ),
    );

    if (isFullWidth) {
      return SizedBox(width: double.infinity, child: buttonWidget);
    }
    return buttonWidget;
  }

  Widget _buildGoogleGIcon() {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
      child: Center(
        child: RichText(
          text: const TextSpan(
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            children: [
              TextSpan(text: 'G', style: TextStyle(color: Color(0xFF4285F4))),
            ],
          ),
        ),
      ),
    );
  }
}
