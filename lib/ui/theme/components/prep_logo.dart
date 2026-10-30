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
    this.appName = 'English 12',
  });

  @override
  Widget build(BuildContext context) {
    final iconBox = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFF97316), // Nền cam ấm theo ảnh logo
        borderRadius: BorderRadius.circular(size * 0.24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEA580C).withValues(alpha: 0.35),
            offset: const Offset(0, 4),
            blurRadius: 8,
          ),
          // Duolingo 3D bottom bevel
          BoxShadow(
            color: const Color(0xFFC2410C).withValues(alpha: 0.4),
            offset: const Offset(0, 3),
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.24),
        child: Image.asset(
          'assets/images/app_logo.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // Fallback vẽ vector huy hiệu khi asset chưa kịp nạp trong test
            return Container(
              color: const Color(0xFFF97316),
              child: Center(
                child: Container(
                  width: size * 0.82,
                  height: size * 0.82,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B), // Navy blue
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFEF3C7), width: 1.5),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.menu_book_rounded,
                        size: size * 0.45,
                        color: const Color(0xFFFEF3C7),
                      ),
                      Positioned(
                        top: size * 0.12,
                        child: Icon(
                          Icons.school_rounded,
                          size: size * 0.35,
                          color: const Color(0xFFFDE68A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
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
