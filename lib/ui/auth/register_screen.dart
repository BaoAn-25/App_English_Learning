import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../navigation/main_shell.dart';
import '../theme/components/app_button.dart';
import 'auth_controller.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _agreedToTerms = false; // Tuyệt đối không tích sẵn theo quy định
  bool _isSubmitting = false;

  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _formGeneralError;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _clearErrors() {
    setState(() {
      _nameError = null;
      _emailError = null;
      _passwordError = null;
      _formGeneralError = null;
    });
  }

  Future<void> _checkAndHandleGuestMerge(BuildContext context) async {
    final auth = AuthController.instance;
    if (auth.hasGuestDataToMerge) {
      final shouldMerge = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Hợp nhất dữ liệu học thử?',
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: const Text(
            'Trên thiết bị này đang có dữ liệu làm bài học thử của bạn. '
            'Bạn có muốn chuyển toàn bộ điểm số, từ vựng và câu sai vào tài khoản mới này không?',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF475569),
              height: 1.45,
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          actions: [
            TextButton(
              onPressed: () {
                auth.dismissGuestDataMerge();
                Navigator.pop(ctx, false);
              },
              child: const Text(
                'Bỏ qua',
                style: TextStyle(color: Color(0xFF94A3B8)),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Hợp nhất ngay',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );

      if (shouldMerge == true) {
        await auth.mergeGuestDataIntoAccount();
      }
    }
  }

  void _showTermsDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E2430) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Điều khoản dịch vụ & Chính sách bảo mật',
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '1. Mục đích sử dụng\n'
                    'Ứng dụng EngPass phục vụ học sinh lớp 12 ôn thi Tốt nghiệp THPT theo chương trình GDPT SGK Global Success. '
                    'Tài khoản học viên được sử dụng để lưu trữ tiến độ học tập, kết quả làm bài thi thử và đồng bộ hóa qua đám mây.\n\n'
                    '2. Quyền riêng tư & Bảo vệ dữ liệu\n'
                    '- Chúng tôi cam kết bảo mật tuyệt đối địa chỉ email và thông tin cá nhân của bạn.\n'
                    '- Mật khẩu được băm an toàn theo tiêu chuẩn mật mã học trước khi lưu trữ.\n'
                    '- Dữ liệu học tập thuộc quyền sở hữu của bạn và chỉ được sử dụng nhằm mục đích cá nhân hóa trải nghiệm học.\n\n'
                    '3. Trách nhiệm của người học\n'
                    'Người học có trách nhiệm bảo mật thông tin đăng nhập của mình và không sử dụng tài khoản vào các mục đích gây hại cho hệ thống.',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  AppButton(
                    label: 'Tôi đã hiểu',
                    isFullWidth: true,
                    onPressed: () => Navigator.pop(ctx),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleRegister() async {
    if (_isSubmitting) return; // Chặn gửi trùng
    _clearErrors();

    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim().toLowerCase();
    final password = _passwordCtrl.text;

    bool hasClientError = false;

    if (email.isEmpty) {
      _emailError = 'Vui lòng nhập địa chỉ email.';
      hasClientError = true;
    } else if (!email.contains('@') || !email.contains('.')) {
      _emailError = 'Định dạng email chưa chính xác.';
      hasClientError = true;
    }

    if (password.isEmpty) {
      _passwordError = 'Vui lòng nhập mật khẩu.';
      hasClientError = true;
    } else if (password.length < 6) {
      _passwordError = 'Mật khẩu phải chứa ít nhất 6 ký tự.';
      hasClientError = true;
    }

    if (!_agreedToTerms) {
      _formGeneralError = 'Bạn cần đồng ý với Điều khoản dịch vụ để tiếp tục.';
      hasClientError = true;
    }

    if (hasClientError) {
      setState(() {});
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final auth = AuthController.instance;
    final ok = await auth.register(
      name: name,
      email: email,
      password: password,
    );

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
    });

    if (ok) {
      await _checkAndHandleGuestMerge(context);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_completed_onboarding', true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.successMessage ?? 'Đăng ký tài khoản thành công!'),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
        (route) => false,
      );
    } else {
      setState(() {
        final err = auth.errorMessage ?? 'Đăng ký tài khoản thất bại.';
        if (err.toLowerCase().contains('email')) {
          _emailError = err;
        } else if (err.toLowerCase().contains('mật khẩu')) {
          _passwordError = err;
        } else {
          _formGeneralError = err;
        }
      });
    }
  }

  Future<void> _handleGoogleAuth() async {
    if (_isSubmitting) return;
    _clearErrors();

    setState(() {
      _isSubmitting = true;
    });

    final auth = AuthController.instance;
    final ok = await auth.loginWithGoogle();

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
    });

    if (ok) {
      await _checkAndHandleGuestMerge(context);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_completed_onboarding', true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Chào mừng ${auth.user.displayName}!'),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
        (route) => false,
      );
    } else {
      if (auth.errorMessage != null) {
        setState(() {
          _formGeneralError = auth.errorMessage;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121620) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Quay lại',
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo EngPass chú chim xanh thương hiệu
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'assets/images/app_logo.png',
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Tạo tài khoản EngPass',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tạo tài khoản học viên để lưu trữ mục tiêu, điểm số và bài làm của bạn.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 13.5,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 18),

                // Banner bảo toàn tiến độ học thử
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E3A8A).withAlpha(120) : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? const Color(0xFF1D4ED8) : const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Toàn bộ tiến độ học thử, câu trả lời và từ vựng của bạn sẽ được chuyển giao đầy đủ vào tài khoản này.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Lỗi chung của Form (nếu có)
                if (_formGeneralError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: Color(0xFFDC2626),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _formGeneralError!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFFB91C1C),
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_formGeneralError!.contains('Đăng nhập') ||
                            _formGeneralError!.contains('đã có tài khoản') ||
                            _formGeneralError!.contains('đã được sử dụng')) ...[
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const LoginScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.login_rounded, size: 16),
                              label: const Text(
                                'Đăng nhập ngay',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF2563EB),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 1. Tên hiển thị
                Text(
                  'Tên hiển thị',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameCtrl,
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  autofillHints: const [AutofillHints.name],
                  decoration: InputDecoration(
                    hintText: 'Tên',
                    errorText: _nameError,
                    prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF64748B)),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E2430) : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB), width: 1.8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Email
                Text(
                  'Email đăng ký',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _emailCtrl,
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(
                    hintText: 'Email',
                    errorText: _emailError,
                    prefixIcon: const Icon(Icons.mail_outline_rounded, color: Color(0xFF64748B)),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E2430) : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB), width: 1.8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Mật khẩu
                Text(
                  'Mật khẩu',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _passwordCtrl,
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  obscureText: _obscurePassword,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: InputDecoration(
                    hintText: 'Tối thiểu 6 ký tự',
                    errorText: _passwordError,
                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF64748B)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                        color: const Color(0xFF64748B),
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E2430) : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB), width: 1.8),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Checkbox điều khoản (Không tích sẵn)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _agreedToTerms,
                        activeColor: const Color(0xFF2563EB),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _agreedToTerms = val ?? false;
                            if (_agreedToTerms) {
                              _formGeneralError = null;
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Wrap(
                        children: [
                          Text(
                            'Tôi đồng ý với ',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                            ),
                          ),
                          GestureDetector(
                            onTap: _showTermsDialog,
                            child: Text(
                              'Điều khoản sử dụng & Chính sách bảo mật',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          Text(
                            ' của EngPass.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Nút tạo tài khoản
                AppButton(
                  label: _isSubmitting
                      ? 'Đang tạo tài khoản...'
                      : 'Tạo tài khoản',
                  isFullWidth: true,
                  variant: AppButtonVariant.primary,
                  height: 52,
                  onPressed: _isSubmitting ? null : _handleRegister,
                ),
                const SizedBox(height: 14),

                // Phân cách HOẶC
                const Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'HOẶC',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 14),

                // Nút Tiếp tục với Google
                AppButton(
                  label: 'Tiếp tục với Google',
                  isFullWidth: true,
                  variant: AppButtonVariant.google,
                  height: 52,
                  onPressed: _isSubmitting ? null : _handleGoogleAuth,
                ),
                const SizedBox(height: 20),

                // Link chuyển sang Đăng nhập
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Đã có tài khoản? ',
                      style: TextStyle(
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        fontSize: 13.5,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        );
                      },
                      child: Text(
                        'Đăng nhập',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
