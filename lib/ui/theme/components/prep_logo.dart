import 'package:flutter/material.dart';

/// Logo chuẩn của ứng dụng English 12 / Prep12.
/// Tông màu Xanh Navy (#0F172A) & Vàng Kim (#F59E0B) đồng bộ tuyệt đối với giao diện chính.
/// Thiết kế huy hiệu hình tròn: Vòng chữ ENGLISH 12, Mũ cử nhân và Sách mở tri thức.
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
    this.appName = 'English 12',
  });

  @override
  Widget build(BuildContext context) {
    final iconBox = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // Nền xanh Navy sang trọng đồng bộ giao diện
        borderRadius: BorderRadius.circular(size * 0.24),
        border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.2),
            offset: const Offset(0, 3),
            blurRadius: 6,
          ),
          // Duolingo 3D bottom bevel
          const BoxShadow(
            color: Color(0xFF1E293B),
            offset: Offset(0, 2.5),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: size * 0.86,
          height: size * 0.86,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF1E293B),
            border: Border.all(color: const Color(0xFFFBBF24), width: 1.5),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Nền vàng hào quang ở giữa
              Container(
                width: size * 0.58,
                height: size * 0.58,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFFEF3C7),
                ),
              ),
              // Sách mở
              Positioned(
                bottom: size * 0.16,
                child: Icon(
                  Icons.menu_book_rounded,
                  size: size * 0.44,
                  color: const Color(0xFF1E293B),
                ),
              ),
              // Mũ cử nhân
              Positioned(
                top: size * 0.16,
                child: Icon(
                  Icons.school_rounded,
                  size: size * 0.36,
                  color: const Color(0xFF0F172A),
                ),
              ),
              // Chấm ngôi sao vàng
              Positioned(
                top: size * 0.10,
                right: size * 0.16,
                child: Icon(
                  Icons.star_rounded,
                  size: size * 0.16,
                  color: const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
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
}
