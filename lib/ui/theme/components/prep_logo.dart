import 'package:flutter/material.dart';

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
    this.appName = 'Prep12',
  });

  @override
  Widget build(BuildContext context) {
    final iconBox = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D4ED8).withValues(alpha: 0.35),
            offset: const Offset(0, 4),
            blurRadius: 10,
          ),
          // Duolingo 3D bottom bevel
          BoxShadow(
            color: const Color(0xFF172554).withValues(alpha: 0.4),
            offset: const Offset(0, 3),
            spreadRadius: 0,
          ),
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.5),
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Biểu tượng sách mở sáng tạo
            Icon(
              Icons.menu_book_rounded,
              size: size * 0.54,
              color: Colors.white,
            ),
            // Ngôi sao tri thức vàng ở góc
            Positioned(
              top: size * 0.16,
              right: size * 0.16,
              child: Container(
                padding: EdgeInsets.all(size * 0.04),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFC107),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.star_rounded,
                  size: size * 0.22,
                  color: const Color(0xFF78350F),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (!showText) return iconBox;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        iconBox,
        SizedBox(width: size * 0.25),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              appName,
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontWeight: FontWeight.w800,
                fontSize: size * 0.52,
                letterSpacing: -0.5,
                color: textColor ?? const Color(0xFF1E293B),
              ),
            ),
            Text(
              'Luyện Thi THPT',
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontWeight: FontWeight.w600,
                fontSize: size * 0.24,
                color: (textColor ?? const Color(0xFF64748B)).withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

