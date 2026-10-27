import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Quản lý trạng thái giao diện (Sáng / Tối / Theo hệ thống)
/// Kế thừa ChangeNotifier và tự động lưu vào SharedPreferences.
class ThemeController extends ChangeNotifier {
  static const String _themePrefKey = 'app_theme_mode';

  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  ThemeController() {
    _loadThemeFromPrefs();
  }

  Future<void> _loadThemeFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString(_themePrefKey);
      if (savedTheme != null) {
        switch (savedTheme) {
          case 'light':
            _themeMode = ThemeMode.light;
            break;
          case 'dark':
            _themeMode = ThemeMode.dark;
            break;
          default:
            _themeMode = ThemeMode.system;
        }
        notifyListeners();
      }
    } catch (_) {
      // Khi chạy test hoặc thiết bị lỗi prefs, fallback về system mặc định
      _themeMode = ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      String val = 'system';
      if (mode == ThemeMode.light) val = 'light';
      if (mode == ThemeMode.dark) val = 'dark';
      await prefs.setString(_themePrefKey, val);
    } catch (_) {}
  }
}
