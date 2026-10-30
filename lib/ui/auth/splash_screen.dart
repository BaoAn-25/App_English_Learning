import 'package:flutter/material.dart';
import '../theme/components/app_button.dart';
import '../theme/components/prep_logo.dart';
import 'welcome_screen.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2563EB), Color(0xFF1D4ED8), Color(0xFF1E40AF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              children: [
                const Spacer(flex: 3),
                // Logo & Tên ứng dụng
                const PrepLogo(
                  size: 96,
                  showText: false,
                ),
                const SizedBox(height: 24),
                const Text(
                  'English 12',
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Học tiếng Anh 12, theo cách của bạn',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
                const Spacer(flex: 4),
                // Thanh tiến độ nhỏ trang trí
                Container(
                  width: 64,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC53D),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Đang chuẩn bị kho tài liệu môn tiếng Anh 12',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 24),
                // Nút Bắt đầu
                AppButton(
                  label: 'Bắt đầu',
                  isFullWidth: true,
                  height: 54,
                  variant: AppButtonVariant.secondary,
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

