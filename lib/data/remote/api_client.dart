import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Kết quả trả về tiêu chuẩn từ API
class ApiResponse {
  final bool isSuccess;
  final int statusCode;
  final Map<String, dynamic>? data;
  final String? errorMessage;

  const ApiResponse({
    required this.isSuccess,
    required this.statusCode,
    this.data,
    this.errorMessage,
  });

  factory ApiResponse.success(int statusCode, Map<String, dynamic>? data) {
    return ApiResponse(
      isSuccess: true,
      statusCode: statusCode,
      data: data,
    );
  }

  factory ApiResponse.error(int statusCode, String message, [Map<String, dynamic>? data]) {
    return ApiResponse(
      isSuccess: false,
      statusCode: statusCode,
      errorMessage: message,
      data: data,
    );
  }
}

/// API Client chuẩn kết nối tới Backend English 12.
/// Dùng thư viện lõi dart:io, có timeout toàn phần cho mỗi request.
class ApiClient {
  /// Địa chỉ Backend API chính thức trên Render HTTPS
  static const String officialBaseUrl = 'https://english12-backend.onrender.com/api';
  static const String defaultBaseUrl = officialBaseUrl;

  final String baseUrl;
  final String? Function()? tokenProvider;
  final HttpClient _httpClient;
  static const Duration requestTimeout = Duration(seconds: 30);

  ApiClient({
    String? baseUrl,
    this.tokenProvider,
  }) : baseUrl = officialBaseUrl,
       _httpClient = HttpClient()..connectionTimeout = const Duration(seconds: 30);

  /// Kiểm tra và chuyển đổi cấu hình cũ trên thiết bị về Render chính thức.
  /// Tuyệt đối không xóa SQLite, bài làm, tiến độ học hoặc dữ liệu cá nhân.
  static Future<void> sanitizeOrMigrateApiUrl(dynamic repository) async {
    try {
      final saved = await repository.getSetting('api_server_url');
      if (saved != null) {
        final s = (saved as String).trim().toLowerCase();
        final isLocalOrInsecure = s.contains('localhost') ||
            s.contains('127.0.0.1') ||
            s.contains('10.0.2.2') ||
            s.contains('192.168.') ||
            s.startsWith('http://');
        if (isLocalOrInsecure || s != officialBaseUrl.toLowerCase()) {
          // Ghi nhận cấu hình Render chính thức
          await repository.setSetting('api_server_url', officialBaseUrl);
        }
      }
    } catch (_) {}
  }

  Map<String, String> _headers([String? overrideToken]) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final token = overrideToken ?? tokenProvider?.call();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  String _formatNetworkError(Object error) {
    if (error is TimeoutException) {
      return 'Kết nối máy chủ Render quá thời gian (hơn 15 giây). Máy chủ có thể đang khởi động lại từ trạng thái nghỉ, vui lòng thử lại sau ít giây.';
    }
    if (error is SocketException) {
      return 'Không thể kết nối đến máy chủ Render. Vui lòng kiểm tra kết nối mạng Internet trên thiết bị của bạn.';
    }
    if (error is FormatException) {
      return 'Phản hồi từ máy chủ không đúng định dạng.';
    }
    return 'Lỗi kết nối máy chủ: $error';
  }

  /// Kiểm tra trạng thái máy chủ Render & Neon PostgreSQL
  Future<bool> checkHealth() async {
    // 1. Kiểm tra trực tiếp endpoint /health tại root domain Render (đã xác thực trên production)
    try {
      final rootUrl = baseUrl.endsWith('/api')
          ? baseUrl.substring(0, baseUrl.length - 4)
          : baseUrl;
      final uri = Uri.parse('$rootUrl/health');
      final request = await _httpClient.getUrl(uri).timeout(requestTimeout);
      final response = await request.close().timeout(requestTimeout);
      if (response.statusCode == 200) {
        return true;
      }
    } catch (_) {}

    // 2. Dự phòng: kiểm tra /api/health nếu backend cập nhật route
    try {
      final uri = Uri.parse('$baseUrl/health');
      final request = await _httpClient.getUrl(uri).timeout(requestTimeout);
      final response = await request.close().timeout(requestTimeout);
      if (response.statusCode == 200) {
        return true;
      }
    } catch (_) {}

    return false;
  }

  /// Đăng ký tài khoản học viên mới bằng Email & Mật khẩu
  Future<ApiResponse> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/auth/register');
      final request = await _httpClient.postUrl(uri).timeout(requestTimeout);
      _headers().forEach((k, v) => request.headers.set(k, v));
      request.write(jsonEncode({
        'email': email,
        'password': password,
        'displayName': displayName,
      }));
      final response = await request.close().timeout(requestTimeout);
      final body = await response.transform(utf8.decoder).join();
      final Map<String, dynamic> data = body.isNotEmpty ? jsonDecode(body) as Map<String, dynamic> : {};

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResponse.success(response.statusCode, data);
      } else {
        final errorMsg = data['error'] as String? ?? 'Đăng ký không thành công (${response.statusCode}).';
        return ApiResponse.error(response.statusCode, errorMsg, data);
      }
    } catch (e) {
      return ApiResponse.error(0, _formatNetworkError(e));
    }
  }

  /// Đăng nhập bằng Email & Mật khẩu
  Future<ApiResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/auth/login');
      final request = await _httpClient.postUrl(uri).timeout(requestTimeout);
      _headers().forEach((k, v) => request.headers.set(k, v));
      request.write(jsonEncode({'email': email, 'password': password}));
      final response = await request.close().timeout(requestTimeout);
      final body = await response.transform(utf8.decoder).join();
      final Map<String, dynamic> data = body.isNotEmpty ? jsonDecode(body) as Map<String, dynamic> : {};

      if (response.statusCode == 200) {
        return ApiResponse.success(response.statusCode, data);
      } else {
        final errorMsg = data['error'] as String? ?? 'Đăng nhập không thành công (${response.statusCode}).';
        return ApiResponse.error(response.statusCode, errorMsg, data);
      }
    } catch (e) {
      return ApiResponse.error(0, _formatNetworkError(e));
    }
  }

  /// Đăng nhập bằng Google thật (Gửi idToken đã ký từ Google)
  Future<ApiResponse> loginWithGoogle({
    required String idToken,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/auth/google');
      final request = await _httpClient.postUrl(uri).timeout(requestTimeout);
      _headers().forEach((k, v) => request.headers.set(k, v));
      request.write(jsonEncode({'idToken': idToken, 'id_token': idToken}));
      final response = await request.close().timeout(requestTimeout);
      final body = await response.transform(utf8.decoder).join();
      final Map<String, dynamic> data = body.isNotEmpty ? jsonDecode(body) as Map<String, dynamic> : {};

      if (response.statusCode == 200) {
        return ApiResponse.success(response.statusCode, data);
      } else {
        final errorMsg = data['error'] as String? ?? 'Đăng nhập Google thất bại (${response.statusCode}).';
        return ApiResponse.error(response.statusCode, errorMsg, data);
      }
    } catch (e) {
      return ApiResponse.error(0, _formatNetworkError(e));
    }
  }

  /// Lấy thông tin tài khoản hiện tại từ Token (Khôi phục phiên)
  Future<ApiResponse> getCurrentUser(String token) async {
    try {
      final uri = Uri.parse('$baseUrl/auth/me');
      final request = await _httpClient.getUrl(uri).timeout(requestTimeout);
      _headers(token).forEach((k, v) => request.headers.set(k, v));
      final response = await request.close().timeout(requestTimeout);
      final body = await response.transform(utf8.decoder).join();
      final Map<String, dynamic> data = body.isNotEmpty ? jsonDecode(body) as Map<String, dynamic> : {};

      if (response.statusCode == 200) {
        return ApiResponse.success(response.statusCode, data);
      } else {
        final errorMsg = data['error'] as String? ?? 'Phiên đăng nhập đã hết hạn.';
        return ApiResponse.error(response.statusCode, errorMsg, data);
      }
    } catch (e) {
      return ApiResponse.error(0, _formatNetworkError(e));
    }
  }

  /// Yêu cầu đặt lại mật khẩu qua email
  Future<ApiResponse> forgotPassword(String email) async {
    try {
      final uri = Uri.parse('$baseUrl/auth/forgot-password');
      final request = await _httpClient.postUrl(uri).timeout(requestTimeout);
      _headers().forEach((k, v) => request.headers.set(k, v));
      request.write(jsonEncode({'email': email}));
      final response = await request.close().timeout(requestTimeout);
      final body = await response.transform(utf8.decoder).join();
      final Map<String, dynamic> data = body.isNotEmpty ? jsonDecode(body) as Map<String, dynamic> : {};

      if (response.statusCode == 200) {
        return ApiResponse.success(response.statusCode, data);
      } else {
        final errorMsg = data['error'] as String? ?? 'Lỗi gửi yêu cầu đặt lại mật khẩu.';
        return ApiResponse.error(response.statusCode, errorMsg, data);
      }
    } catch (e) {
      return ApiResponse.error(0, _formatNetworkError(e));
    }
  }

  /// Đặt lại mật khẩu mới bằng Token
  Future<ApiResponse> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/auth/reset-password');
      final request = await _httpClient.postUrl(uri).timeout(requestTimeout);
      _headers().forEach((k, v) => request.headers.set(k, v));
      request.write(jsonEncode({
        'token': token,
        'newPassword': newPassword,
      }));
      final response = await request.close().timeout(requestTimeout);
      final body = await response.transform(utf8.decoder).join();
      final Map<String, dynamic> data = body.isNotEmpty ? jsonDecode(body) as Map<String, dynamic> : {};

      if (response.statusCode == 200) {
        return ApiResponse.success(response.statusCode, data);
      } else {
        final errorMsg = data['error'] as String? ?? 'Đặt lại mật khẩu thất bại.';
        return ApiResponse.error(response.statusCode, errorMsg, data);
      }
    } catch (e) {
      return ApiResponse.error(0, _formatNetworkError(e));
    }
  }

  /// Gửi lại thư xác minh email
  Future<ApiResponse> resendVerificationEmail(String token) async {
    try {
      final uri = Uri.parse('$baseUrl/auth/resend-verification');
      final request = await _httpClient.postUrl(uri).timeout(requestTimeout);
      _headers(token).forEach((k, v) => request.headers.set(k, v));
      final response = await request.close().timeout(requestTimeout);
      final body = await response.transform(utf8.decoder).join();
      final Map<String, dynamic> data = body.isNotEmpty ? jsonDecode(body) as Map<String, dynamic> : {};

      if (response.statusCode == 200) {
        return ApiResponse.success(response.statusCode, data);
      } else {
        final errorMsg = data['error'] as String? ?? 'Không thể gửi lại thư xác minh.';
        return ApiResponse.error(response.statusCode, errorMsg, data);
      }
    } catch (e) {
      return ApiResponse.error(0, _formatNetworkError(e));
    }
  }

  /// Cập nhật hồ sơ & lộ trình học
  Future<bool> updateProfile(Map<String, dynamic> profileData) async {
    try {
      final uri = Uri.parse('$baseUrl/profile');
      final request = await _httpClient.putUrl(uri).timeout(requestTimeout);
      _headers().forEach((k, v) => request.headers.set(k, v));
      request.write(jsonEncode(profileData));
      final response = await request.close().timeout(requestTimeout);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Đồng bộ một bản ghi thống kê ngày lên máy chủ
  Future<ApiResponse> syncDailyStat({
    required String statDate,
    required int questionsDone,
    required int correctCount,
    required int xpEarned,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/stats/daily');
      final request = await _httpClient.postUrl(uri).timeout(requestTimeout);
      _headers().forEach((k, v) => request.headers.set(k, v));
      request.write(jsonEncode({
        'statDate': statDate,
        'questionsDone': questionsDone,
        'correctCount': correctCount,
        'xpEarned': xpEarned,
      }));
      final response = await request.close().timeout(requestTimeout);
      final body = await response.transform(utf8.decoder).join();
      final Map<String, dynamic> data =
          body.isNotEmpty ? jsonDecode(body) as Map<String, dynamic> : {};
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResponse.success(response.statusCode, data);
      }
      return ApiResponse.error(
        response.statusCode,
        data['error'] as String? ?? 'Đồng bộ thất bại (${response.statusCode})',
        data,
      );
    } catch (e) {
      return ApiResponse.error(0, _formatNetworkError(e));
    }
  }

  /// Lưu kết quả bài thi thử 40 câu THPT
  Future<Map<String, dynamic>?> submitExamAttempt({
    required String examType,
    required int totalQuestions,
    required int correctCount,
    required double score,
    required int durationSeconds,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/exams/submit');
      final request = await _httpClient.postUrl(uri).timeout(requestTimeout);
      _headers().forEach((k, v) => request.headers.set(k, v));
      request.write(jsonEncode({
        'examType': examType,
        'totalQuestions': totalQuestions,
        'correctCount': correctCount,
        'score': score,
        'durationSeconds': durationSeconds,
      }));
      final response = await request.close().timeout(requestTimeout);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = await response.transform(utf8.decoder).join();
        return jsonDecode(body) as Map<String, dynamic>;
      }
    } catch (_) {
      /* Fallback offline */
    }
    return null;
  }

  /// Gửi câu hỏi đến Gia sư Trợ lý AI
  Future<ApiResponse> askAiTutor({
    required String question,
    int? unitNumber,
    String? section,
    String? contextText,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/ai/ask');
      final request = await _httpClient.postUrl(uri).timeout(const Duration(seconds: 15));
      _headers().forEach((k, v) => request.headers.set(k, v));
      request.write(jsonEncode({
        'question': question,
        'unitNumber': unitNumber,
        'section': section,
        'contextText': contextText,
      }));
      final response = await request.close().timeout(const Duration(seconds: 15));
      final body = await response.transform(utf8.decoder).join();
      final Map<String, dynamic> data =
          body.isNotEmpty ? jsonDecode(body) as Map<String, dynamic> : {};
      if (response.statusCode == 200) {
        return ApiResponse.success(response.statusCode, data);
      }
      return ApiResponse.error(
        response.statusCode,
        data['error'] as String? ?? 'Không thể kết nối dịch vụ AI (${response.statusCode})',
        data,
      );
    } catch (e) {
      return ApiResponse.error(0, _formatNetworkError(e));
    }
  }
}
