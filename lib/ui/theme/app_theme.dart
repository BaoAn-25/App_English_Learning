import 'package:flutter/material.dart';
import 'app_tokens.dart';

/// Định nghĩa ThemeData cho ứng dụng theo chuẩn Material 3.
/// Tuân thủ palette: Primary #1E6FE8, Accent #FFC53D, Background #F3F8FF, Text #1F2A44, Success #1FA971.
/// Sử dụng font Be Vietnam Pro và bo góc lớn 16-24.
class AppTheme {
  AppTheme._();

  // Theme Sáng
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppTokens.primary,
      brightness: Brightness.light,
      primary: AppTokens.primary,
      secondary: AppTokens.accentYellow,
      surface: Colors.white,
      onSurface: AppTokens.textMain,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: AppTokens.fontFamily,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppTokens.backgroundLight,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppTokens.textMain,
        titleTextStyle: TextStyle(
          fontFamily: AppTokens.fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppTokens.textMain,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 2,
          backgroundColor: AppTokens.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(88, AppTokens.minTouchTargetSize),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
          ),
          textStyle: const TextStyle(
            fontFamily: AppTokens.fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTokens.primary,
          minimumSize: const Size(88, AppTokens.minTouchTargetSize),
          side: const BorderSide(color: AppTokens.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
          ),
          textStyle: const TextStyle(
            fontFamily: AppTokens.fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 2,
        backgroundColor: Colors.white,
        indicatorColor: AppTokens.primary.withAlpha(38),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontFamily: AppTokens.fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTokens.primary,
            );
          }
          return const TextStyle(
            fontFamily: AppTokens.fontFamily,
            fontSize: 12,
            color: Color(0xFF6B7280),
          );
        }),
      ),
    );
  }

  // Theme Tối
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppTokens.primary,
      brightness: Brightness.dark,
      primary: const Color(0xFF5390F5),
      secondary: AppTokens.accentYellow,
      surface: const Color(0xFF1E2430),
      onSurface: const Color(0xFFF3F4F6),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: AppTokens.fontFamily,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF121620),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Color(0xFFF3F4F6),
        titleTextStyle: TextStyle(
          fontFamily: AppTokens.fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFFF3F4F6),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFF1E2430),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 2,
          backgroundColor: const Color(0xFF5390F5),
          foregroundColor: const Color(0xFF121620),
          minimumSize: const Size(88, AppTokens.minTouchTargetSize),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
          ),
          textStyle: const TextStyle(
            fontFamily: AppTokens.fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF5390F5),
          minimumSize: const Size(88, AppTokens.minTouchTargetSize),
          side: const BorderSide(color: Color(0xFF5390F5), width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
          ),
          textStyle: const TextStyle(
            fontFamily: AppTokens.fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 2,
        backgroundColor: const Color(0xFF1E2430),
        indicatorColor: const Color(0xFF5390F5).withAlpha(51),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontFamily: AppTokens.fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF5390F5),
            );
          }
          return const TextStyle(
            fontFamily: AppTokens.fontFamily,
            fontSize: 12,
            color: Color(0xFF9CA3AF),
          );
        }),
      ),
    );
  }
}
