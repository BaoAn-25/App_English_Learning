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
      constraints: BoxConstraints(minHeight: height),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      alignment: Alignment.center,
      child: const CustomPaint(
        size: Size(22, 22),
        painter: GoogleLogoPainter(),
      ),
    );
  }
}

/// Vẽ chuẩn logo 4 màu đặc trưng của Google (Xanh, Đỏ, Vàng, Xanh lá) bằng Vector Path chính thức
class GoogleLogoPainter extends CustomPainter {
  const GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / 48.0;
    canvas.save();
    canvas.scale(scale, scale);

    // 1. Cung Đỏ (Trên cùng)
    final redPath = Path()
      ..moveTo(24.0, 9.5)
      ..cubicTo(27.54, 9.5, 30.71, 10.72, 33.21, 13.1)
      ..lineTo(40.06, 6.25)
      ..cubicTo(35.9, 2.38, 30.47, 0.0, 24.0, 0.0)
      ..cubicTo(14.62, 0.0, 6.51, 5.38, 2.56, 13.22)
      ..lineTo(10.54, 19.41)
      ..cubicTo(12.43, 13.72, 17.74, 9.5, 24.0, 9.5)
      ..close();
    canvas.drawPath(
      redPath,
      Paint()
        ..color = const Color(0xFFEA4335)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );

    // 2. Cung Xanh dương (Bên phải + thanh ngang)
    final bluePath = Path()
      ..moveTo(46.98, 24.55)
      ..cubicTo(46.98, 22.98, 46.83, 21.46, 46.6, 20.0)
      ..lineTo(24.0, 20.0)
      ..lineTo(24.0, 29.02)
      ..lineTo(36.94, 29.02)
      ..cubicTo(36.36, 31.98, 34.68, 34.5, 32.16, 36.2)
      ..lineTo(39.89, 42.2)
      ..cubicTo(44.4, 38.02, 46.98, 31.84, 46.98, 24.55)
      ..close();
    canvas.drawPath(
      bluePath,
      Paint()
        ..color = const Color(0xFF4285F4)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );

    // 3. Cung Xanh lá (Dưới cùng)
    final greenPath = Path()
      ..moveTo(24.0, 48.0)
      ..cubicTo(30.48, 48.0, 35.93, 45.87, 39.89, 42.19)
      ..lineTo(32.16, 36.19)
      ..cubicTo(30.01, 37.64, 27.24, 38.49, 24.0, 38.49)
      ..cubicTo(17.74, 38.49, 12.43, 34.27, 10.53, 28.59)
      ..lineTo(2.56, 34.78)
      ..cubicTo(6.51, 42.62, 14.62, 48.0, 24.0, 48.0)
      ..close();
    canvas.drawPath(
      greenPath,
      Paint()
        ..color = const Color(0xFF34A853)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );

    // 4. Cung Vàng (Trái)
    final yellowPath = Path()
      ..moveTo(10.53, 28.59)
      ..cubicTo(10.05, 27.14, 9.77, 25.6, 9.77, 24.0)
      ..cubicTo(9.77, 22.4, 10.04, 20.86, 10.53, 19.41)
      ..lineTo(2.56, 13.22)
      ..cubicTo(0.92, 16.46, 0.0, 20.12, 0.0, 24.0)
      ..cubicTo(0.0, 27.88, 0.92, 31.54, 2.56, 34.78)
      ..lineTo(10.53, 28.59)
      ..close();
    canvas.drawPath(
      yellowPath,
      Paint()
        ..color = const Color(0xFFFBBC05)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
