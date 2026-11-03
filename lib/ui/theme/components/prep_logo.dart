import 'package:flutter/material.dart';

/// Logo chuẩn của ứng dụng EngPass.
/// Tông màu Xanh Navy (#0F172A) & Vàng Kim (#F59E0B) đồng bộ tuyệt đối với giao diện chính.
/// Hiển thị hình ảnh linh vật chú chim xanh EngPass cầm sách điểm A.
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
    final iconBox = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.15),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: Image.asset(
          'assets/images/app_logo.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => _buildFallback(size),
        ),
      ),
    );

    if (!showText) return iconBox;

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
                fontSize: size * 0.46,
                letterSpacing: -0.5,
                color: textColor ?? const Color(0xFF0F172A),
              ),
            ),
            Text(
              'Luyện Thi THPT',
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontWeight: FontWeight.w700,
                fontSize: size * 0.23,
                color: (textColor ?? const Color(0xFF64748B)).withValues(alpha: 0.9),
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
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(size * 0.22),
        border: Border.all(color: const Color(0xFFFBBF24), width: 1.5),
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
