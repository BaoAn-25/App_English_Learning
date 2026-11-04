import 'package:flutter/material.dart';

/// Logo chuẩn của ứng dụng EngPass.
/// Tông màu Xanh Thương Hiệu (#2168DC) tràn viền vừa khít (Full-Bleed)
/// và tự động đồng bộ màu chữ trên cả chế độ Sáng (Light) và Tối (Dark).
class PrepLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final Color? textColor;
  final String appName;

  const PrepLogo({
    super.key,
    this.size = 56,
    this.showText = true,
    this.textColor,
    this.appName = 'EngPass',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(size * 0.24);

    final iconBox = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF2168DC),
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2168DC).withValues(alpha: isDark ? 0.32 : 0.22),
            offset: const Offset(0, 3),
            blurRadius: 8,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/images/app_logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) => _buildFallback(size),
      ),
    );

    if (!showText) return iconBox;

    final effectiveTitleColor =
        textColor ?? (isDark ? Colors.white : const Color(0xFF0F172A));
    final effectiveSubtitleColor = textColor != null
        ? textColor!.withValues(alpha: 0.85)
        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B));

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        iconBox,
        SizedBox(width: size * 0.22),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              appName,
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontWeight: FontWeight.w900,
                fontSize: size * 0.45,
                letterSpacing: -0.5,
                height: 1.1,
                color: effectiveTitleColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Luyện Thi THPT',
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontWeight: FontWeight.w700,
                fontSize: size * 0.23,
                color: effectiveSubtitleColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFallback(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF2168DC),
        borderRadius: BorderRadius.circular(size * 0.24),
      ),
      child: Center(
        child: Icon(
          Icons.school_rounded,
          size: size * 0.55,
          color: const Color(0xFFFBBF24),
        ),
      ),
    );
  }
}
