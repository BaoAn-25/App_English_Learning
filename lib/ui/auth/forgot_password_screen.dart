import 'package:flutter/material.dart';

import '../theme/components/app_button.dart';
import 'auth_controller.dart';
import 'reset_password_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _isSuccess = false;
  String _submittedEmail = '';

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập địa chỉ email hợp lệ.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final auth = AuthController.instance;
    final result = await auth.forgotPassword(email);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.isSuccess) {
        _isSuccess = true;
        _submittedEmail = email;
      } else {
        _errorMessage = result.errorMessage ?? 'Không thể gửi yêu cầu đặt lại mật khẩu.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isSuccess) {
      return _buildDuolingoSuccessView();
    }
    return _buildInputFormView();
  }

  /// Màn hình thông báo chuẩn phong cách Duolingo: "Hãy vào kiểm tra email nhé!"
  Widget _buildDuolingoSuccessView() {
    return Scaffold(
      backgroundColor: const Color(0xFF131F24), // Màu tối chuẩn giao diện Duolingo
      appBar: AppBar(
        backgroundColor: const Color(0xFF131F24),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'English 12',
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: Color(0xFF1CB0F6),
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF131F24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'ĐĂNG NHẬP',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),

              // Hình minh họa linh vật cầm phong bì chuẩn phong cách Duolingo
              Center(
                child: SizedBox(
                  width: 140,
                  height: 120,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // Các hạt pháo giấy confetti trang trí
                      const Positioned(
                        top: 4,
                        left: 12,
                        child: Text('✨', style: TextStyle(fontSize: 16)),
                      ),
                      const Positioned(
                        top: 14,
                        right: 8,
                        child: Text('🎉', style: TextStyle(fontSize: 16)),
                      ),
                      const Positioned(
                        bottom: 8,
                        left: 8,
                        child: Text('⭐', style: TextStyle(fontSize: 14)),
                      ),
                      const Positioned(
                        bottom: 12,
                        right: 16,
                        child: Text('✨', style: TextStyle(fontSize: 14)),
                      ),

                      // Linh vật màu xanh lá Duolingo
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: const Color(0xFF58CC02),
                          borderRadius: BorderRadius.circular(45),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0xFF46A302),
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Stack(
                          alignment: Alignment.center,
                          children: [
                            // Mắt linh vật
                            Positioned(
                              top: 22,
                              left: 20,
                              child: CircleAvatar(
                                radius: 10,
                                backgroundColor: Colors.white,
                                child: CircleAvatar(radius: 5, backgroundColor: Color(0xFF131F24)),
                              ),
                            ),
                            Positioned(
                              top: 22,
                              right: 20,
                              child: CircleAvatar(
                                radius: 10,
                                backgroundColor: Colors.white,
                                child: CircleAvatar(radius: 5, backgroundColor: Color(0xFF131F24)),
                              ),
                            ),
                            // Mỏ cam
                            Positioned(
                              top: 36,
                              child: Icon(Icons.arrow_drop_down_rounded, size: 24, color: Color(0xFFFF9600)),
                            ),
                          ],
                        ),
                      ),

                      // Phong bì thư vàng cầm trên tay
                      Positioned(
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFC800),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0xFFE5A500),
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.mail_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Tiêu đề chuẩn Duolingo
              const Text(
                'Hãy vào kiểm tra email nhé!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 14),

              // Đoạn mô tả với email người dùng
              Text(
                'Nếu có tài khoản liên kết với email\n$_submittedEmail, bạn sẽ nhận được đường dẫn đặt lại mật khẩu sau giây lát.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF94A3B8),
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const Spacer(flex: 3),

              // Nút quay lại đăng nhập
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1CB0F6),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'QUAY LẠI ĐĂNG NHẬP',
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Nút thử lại nếu nhập sai email
              Center(
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _isSuccess = false;
                      _errorMessage = null;
                    });
                  },
                  child: const Text(
                    'Chưa nhận được? Thử lại với email khác',
                    style: TextStyle(
                      color: Color(0xFF1CB0F6),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// Màn hình nhập email ban đầu
  Widget _buildInputFormView() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Đặt lại mật khẩu',
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: Color(0xFF0F172A),
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
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(
                    child: Icon(Icons.lock_reset_rounded, size: 36, color: Color(0xFF2563EB)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Quên mật khẩu?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Nhập địa chỉ email đăng ký tài khoản của bạn để nhận liên kết đặt lại mật khẩu.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF64748B),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 28),

              // Trường nhập email
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Địa chỉ email',
                  hintText: 'vidu@gmail.com',
                  prefixIcon: const Icon(Icons.email_outlined, size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Thông báo lỗi nếu có
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Color(0xFFDC2626), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(fontSize: 13, color: Color(0xFFB91C1C), height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Nút Gửi yêu cầu
              AppButton(
                label: _isLoading ? 'Đang xử lý...' : 'Gửi liên kết đặt lại mật khẩu',
                isFullWidth: true,
                height: 52,
                onPressed: _isLoading ? null : _handleSubmit,
              ),
              const SizedBox(height: 16),

              // Nút dẫn sang màn hình nhập mã xác nhận (dự phòng)
              Center(
                child: TextButton.icon(
                  icon: const Icon(Icons.key_rounded, size: 18, color: Color(0xFF2563EB)),
                  label: const Text(
                    'Tôi đã có mã xác nhận (Token)',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
