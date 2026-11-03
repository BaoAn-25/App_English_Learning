import 'package:flutter/material.dart';

import '../theme/components/app_button.dart';
import 'auth_controller.dart';
import 'login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String? initialToken;

  const ResetPasswordScreen({super.key, this.initialToken});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  late final TextEditingController _tokenCtrl;
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _statusMessage;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _tokenCtrl = TextEditingController(text: widget.initialToken ?? '');
  }

  @override
  void dispose() {
    _tokenCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final token = _tokenCtrl.text.trim();
    final password = _passwordCtrl.text;
    final confirmPassword = _confirmPasswordCtrl.text;

    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập mã xác nhận từ email.')),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mật khẩu mới phải chứa từ 6 ký tự trở lên.')),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mật khẩu nhập lại không khớp.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _statusMessage = null;
    });

    final auth = AuthController.instance;
    final result = await auth.resetPassword(token: token, newPassword: password);

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _isSuccess = result.isSuccess;
      _statusMessage = result.isSuccess
          ? (result.data?['message'] as String? ?? 'Mật khẩu đã được cập nhật thành công!')
          : (result.errorMessage ?? 'Không thể đặt lại mật khẩu.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121620) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E2430) : Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: isDark ? Colors.white : const Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Tạo mật khẩu mới',
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E3A8A).withAlpha(120) : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.lock_reset_rounded, size: 32, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB)),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Đặt mật khẩu mới',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Nhập mã xác nhận nhận được trong thư điện tử và mật khẩu mới cho tài khoản của bạn.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),

              if (_statusMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _isSuccess ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _isSuccess ? const Color(0xFF86EFAC) : const Color(0xFFFECACA),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _isSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                        color: _isSuccess ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _statusMessage!,
                          style: TextStyle(
                            fontSize: 13,
                            color: _isSuccess ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],

              if (!_isSuccess) ...[
                // Trường Token
                Text(
                  'Mã xác nhận (Token)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _tokenCtrl,
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    hintText: 'Dán mã xác nhận từ email',
                    prefixIcon: const Icon(Icons.vpn_key_outlined, size: 20),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E2430) : Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 16),

                // Mật khẩu mới
                Text(
                  'Mật khẩu mới',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _passwordCtrl,
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'Tối thiểu 6 ký tự',
                    prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E2430) : Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 16),

                // Nhập lại mật khẩu
                Text(
                  'Xác nhận mật khẩu mới',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _confirmPasswordCtrl,
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'Nhập lại mật khẩu mới',
                    prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E2430) : Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 24),

                AppButton(
                  label: _isSubmitting ? 'Đang cập nhật...' : 'Cập nhật mật khẩu',
                  isFullWidth: true,
                  height: 52,
                  onPressed: _isSubmitting ? null : _handleSubmit,
                ),
              ] else ...[
                AppButton(
                  label: 'Đăng nhập ngay',
                  isFullWidth: true,
                  height: 52,
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

