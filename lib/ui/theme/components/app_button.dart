import 'package:flutter/material.dart';
import '../app_tokens.dart';

enum AppButtonVariant { primary, secondary, outlined, text }

/// Nút bấm chuẩn của ứng dụng.
/// Đảm bảo vùng bấm tối thiểu 48dp (Accessibility), hỗ trợ trạng thái đang tải (loading) và disable.
///
/// Cách dùng:
/// ```dart
/// AppButton(
///   label: 'Tiếp tục luyện tập',
///   icon: Icons.play_arrow_rounded,
///   onPressed: () {},
///   variant: AppButtonVariant.primary,
/// )
/// ```
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;
  final AppButtonVariant variant;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.variant = AppButtonVariant.primary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget childContent;
    if (isLoading) {
      childContent = SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(
            variant == AppButtonVariant.primary ? Colors.white : theme.colorScheme.primary,
          ),
        ),
      );
    } else {
      childContent = Row(
        mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20),
            const SizedBox(width: AppTokens.space8),
          ],
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
        ],
      );
    }

    Widget button;
    switch (variant) {
      case AppButtonVariant.primary:
        button = ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTokens.primary,
            foregroundColor: Colors.white,
            elevation: 2,
            minimumSize: Size(isFullWidth ? double.infinity : 64, AppTokens.minTouchTargetSize),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusMedium)),
          ),
          child: childContent,
        );
        break;
      case AppButtonVariant.secondary:
        button = ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTokens.accentYellow,
            foregroundColor: AppTokens.textMain,
            elevation: 1,
            minimumSize: Size(isFullWidth ? double.infinity : 64, AppTokens.minTouchTargetSize),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusMedium)),
          ),
          child: childContent,
        );
        break;
      case AppButtonVariant.outlined:
        button = OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.primary,
            minimumSize: Size(isFullWidth ? double.infinity : 64, AppTokens.minTouchTargetSize),
            side: BorderSide(color: theme.colorScheme.primary, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusMedium)),
          ),
          child: childContent,
        );
        break;
      case AppButtonVariant.text:
        button = TextButton(
          onPressed: isLoading ? null : onPressed,
          style: TextButton.styleFrom(
            foregroundColor: theme.colorScheme.primary,
            minimumSize: Size(isFullWidth ? double.infinity : 64, AppTokens.minTouchTargetSize),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusMedium)),
          ),
          child: childContent,
        );
        break;
    }

    if (isFullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}
