import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
        systemOverlayStyle: SystemUiOverlayStyle.dark,
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
      timePickerTheme: TimePickerThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
        ),
        dayPeriodColor: WidgetStateColor.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTokens.primary;
          }
          return const Color(0xFFF1F5F9);
        }),
        dayPeriodTextColor: WidgetStateColor.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return const Color(0xFF475569);
        }),
        dayPeriodBorderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
        dayPeriodShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        hourMinuteColor: WidgetStateColor.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFFEFF6FF);
          }
          return const Color(0xFFF8FAFC);
        }),
        hourMinuteTextColor: WidgetStateColor.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTokens.primary;
          }
          return AppTokens.textMain;
        }),
        entryModeIconColor: AppTokens.primary,
        confirmButtonStyle: ButtonStyle(
          foregroundColor: WidgetStateProperty.all(AppTokens.primary),
          textStyle: WidgetStateProperty.all(
            const TextStyle(
              fontFamily: AppTokens.fontFamily,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        cancelButtonStyle: ButtonStyle(
          foregroundColor: WidgetStateProperty.all(const Color(0xFF64748B)),
          textStyle: WidgetStateProperty.all(
            const TextStyle(
              fontFamily: AppTokens.fontFamily,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        titleTextStyle: TextStyle(
          fontFamily: AppTokens.fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Color(0xFF0F172A),
        ),
        contentTextStyle: TextStyle(
          fontFamily: AppTokens.fontFamily,
          fontSize: 14,
          color: Color(0xFF334155),
        ),
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
        systemOverlayStyle: SystemUiOverlayStyle.light,
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
          backgroundColor: AppTokens.primary,
          foregroundColor: Colors.white,
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
      timePickerTheme: TimePickerThemeData(
        backgroundColor: const Color(0xFF1E2430),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
        ),
        dayPeriodColor: WidgetStateColor.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF5390F5);
          }
          return const Color(0xFF2D3748);
        }),
        dayPeriodTextColor: WidgetStateColor.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF121620);
          }
          return const Color(0xFFE2E8F0);
        }),
        dayPeriodBorderSide: const BorderSide(color: Color(0xFF4A5568), width: 1.0),
        dayPeriodShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        hourMinuteColor: WidgetStateColor.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF2A364F);
          }
          return const Color(0xFF232A38);
        }),
        hourMinuteTextColor: WidgetStateColor.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF5390F5);
          }
          return const Color(0xFFF3F4F6);
        }),
        entryModeIconColor: const Color(0xFF5390F5),
        confirmButtonStyle: ButtonStyle(
          foregroundColor: WidgetStateProperty.all(const Color(0xFF5390F5)),
          textStyle: WidgetStateProperty.all(
            const TextStyle(
              fontFamily: AppTokens.fontFamily,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        cancelButtonStyle: ButtonStyle(
          foregroundColor: WidgetStateProperty.all(const Color(0xFF94A3B8)),
          textStyle: WidgetStateProperty.all(
            const TextStyle(
              fontFamily: AppTokens.fontFamily,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Color(0xFF1E293B),
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        titleTextStyle: TextStyle(
          fontFamily: AppTokens.fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
        contentTextStyle: TextStyle(
          fontFamily: AppTokens.fontFamily,
          fontSize: 14,
          color: Colors.white70,
        ),
      ),
    );
  }
}
