import 'package:flutter/material.dart';

/// Design tokens quy định khoảng cách, bo góc, màu sắc palette chuẩn và đổ bóng.
/// Dùng thống nhất trong toàn bộ ứng dụng để giao diện hài hòa, hiện đại.
class AppTokens {
  AppTokens._();

  // Font family
  static const String fontFamily = 'BeVietnamPro';

  // Palette màu theo yêu cầu thiết kế
  static const Color primary = Color(0xFF1E6FE8); // Xanh chủ đạo
  static const Color accentYellow = Color(0xFFFFC53D); // Nhấn vàng (Streak, XP)
  static const Color backgroundLight = Color(0xFFF3F8FF); // Nền sáng
  static const Color textMain = Color(0xFF1F2A44); // Màu chữ chính
  static const Color successGreen = Color(0xFF1FA971); // Màu thành công / đúng
  static const Color errorRed = Color(0xFFE53935); // Màu báo lỗi / sai
  static const Color cardShadowColor = Color(0x0D000000); // Bóng nhẹ tinh tế

  // Khoảng cách (Spacing)
  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;

  // Bo góc (Radius lớn 16 - 24)
  static const double radiusSmall = 12.0;
  static const double radiusMedium = 16.0;
  static const double radiusLarge = 20.0;
  static const double radiusXLarge = 24.0;

  static const BorderRadius borderRadiusMedium = BorderRadius.all(Radius.circular(radiusMedium));
  static const BorderRadius borderRadiusLarge = BorderRadius.all(Radius.circular(radiusLarge));
  static const BorderRadius borderRadiusXLarge = BorderRadius.all(Radius.circular(radiusXLarge));

  // Kích thước tương tác tối thiểu theo chuẩn khả năng tiếp cận (Accessibility)
  static const double minTouchTargetSize = 48.0;

  // Đổ bóng thẻ nhẹ nhàng (Soft card elevation)
  static const List<BoxShadow> softCardShadow = [
    BoxShadow(
      color: Color(0x0A1F2A44),
      blurRadius: 16,
      offset: Offset(0, 6),
      spreadRadius: 0,
    ),
  ];
}
