import 'package:flutter/material.dart';

/// Design tokens quy định màu sắc chuẩn, khoảng cách, bo góc và đổ bóng.
/// Được chiết xuất chính xác từ bộ nhận diện thương hiệu `assets/images/app_logo.png`:
/// - Nền Navy thương hiệu: `#0F172A` / `#162846`
/// - Điểm nhấn Vàng/Cam hổ phách: `#F59E36` (Streak, XP, badges)
/// - Màu kem dịu mắt: `#FEEAC5` (Highlight, container, surfaces)
/// - Nền sáng trung tính: `#F8FAFC` (dễ đọc sách lâu không mỏi mắt)
class AppTokens {
  AppTokens._();

  // Font chữ chuẩn SGK
  static const String fontFamily = 'BeVietnamPro';

  // Palette màu sắc thương hiệu (Dựa theo logo EngPass)
  static const Color navyDark = Color(0xFF0F172A); // Navy đen sâu
  static const Color primary = Color(0xFF1E3A8A); // Navy chủ đạo (Action, Header)
  static const Color primaryLight = Color(0xFF2563EB); // Navy sáng
  static const Color accentYellow = Color(0xFFF59E36); // Vàng/Cam hổ phách (từ chi tiết logo)
  static const Color accentCream = Color(0xFFFEEAC5); // Màu kem nhẹ (từ logo)
  static const Color backgroundLight = Color(0xFFF8FAFC); // Nền sáng trung tính
  static const Color surfaceWarm = Color(0xFFFFFDF8); // Nền thẻ kem ấm
  static const Color textMain = Color(0xFF0F172A); // Màu chữ chính
  static const Color textSecondary = Color(0xFF64748B); // Màu chữ phụ
  static const Color successGreen = Color(0xFF16A34A); // Màu thành công / đúng
  static const Color errorRed = Color(0xFFDC2626); // Màu báo lỗi / sai
  static const Color borderLight = Color(0xFFE2E8F0); // Viền nhẹ
  static const Color cardShadowColor = Color(0x0A0F172A); // Đổ bóng nhẹ tinh tế

  // Khoảng cách (Spacing)
  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;

  // Bo góc (Radius lớn 12 - 24)
  static const double radiusSmall = 12.0;
  static const double radiusMedium = 16.0;
  static const double radiusLarge = 20.0;
  static const double radiusXLarge = 24.0;

  static const BorderRadius borderRadiusMedium = BorderRadius.all(Radius.circular(radiusMedium));
  static const BorderRadius borderRadiusLarge = BorderRadius.all(Radius.circular(radiusLarge));
  static const BorderRadius borderRadiusXLarge = BorderRadius.all(Radius.circular(radiusXLarge));

  // Kích thước tương tác tối thiểu theo chuẩn khả năng tiếp cận (Accessibility)
  static const double minTouchTargetSize = 48.0;

  // Đổ bóng thẻ mềm (Soft card elevation)
  static const List<BoxShadow> softCardShadow = [
    BoxShadow(
      color: Color(0x080F172A),
      blurRadius: 14,
      offset: Offset(0, 4),
      spreadRadius: 0,
    ),
  ];
}
