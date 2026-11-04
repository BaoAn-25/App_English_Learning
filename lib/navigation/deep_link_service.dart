import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ui/auth/login_screen.dart';

/// Dịch vụ lắng nghe và điều hướng Deep Link từ trình duyệt web vào ứng dụng EngPass
class DeepLinkService {
  static const MethodChannel _channel = MethodChannel('com.example.thpt_english/deeplink');
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static bool _isInitialized = false;

  static void init() {
    if (_isInitialized) return;
    _isInitialized = true;

    // Lắng nghe khi app được kích hoạt từ trình duyệt (onNewIntent)
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onDeepLink') {
        final uri = call.arguments as String?;
        _handleDeepLink(uri);
      }
    });

    // Kiểm tra Deep Link ban đầu nếu app được bật từ trạng thái tắt
    _checkInitialDeepLink();
  }

  static Future<void> _checkInitialDeepLink() async {
    try {
      final initialUri = await _channel.invokeMethod<String>('getInitialDeepLink');
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (_) {}
  }

  static void _handleDeepLink(String? uri) {
    if (uri == null) return;

    // Khi người dùng bấm liên kết đăng nhập (ví dụ: english12://login)
    if (uri.contains('login')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final nav = navigatorKey.currentState;
        if (nav != null) {
          nav.push(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
      });
    }
  }
}

