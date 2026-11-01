import 'dart:convert';
import 'dart:io';

/// API Client chuẩn kết nối tới Backend Render.com và Neon Database.
/// Dùng thư viện lõi dart:io (không cần thêm dependency bên ngoài), hỗ trợ SSL và fallback offline.
class ApiClient {
  final String baseUrl;
  final String? Function()? tokenProvider;
  final HttpClient _httpClient;

  ApiClient({
    this.baseUrl = 'https://english12-backend.onrender.com/api',
    this.tokenProvider,
  }) : _httpClient = HttpClient()..connectionTimeout = const Duration(seconds: 5);

  Map<String, String> _headers() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final token = tokenProvider?.call();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Kiểm tra trạng thái máy chủ backend
  Future<bool> checkHealth() async {
    try {
      final uri = Uri.parse('$baseUrl/health');
      final request = await _httpClient.getUrl(uri);
      final response = await request.close();
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Đăng ký tài khoản
  Future<Map<String, dynamic>?> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/auth/register');
      final request = await _httpClient.postUrl(uri);
      _headers().forEach((k, v) => request.headers.set(k, v));
      request.write(jsonEncode({
        'email': email,
        'password': password,
        'displayName': displayName,
      }));
      final response = await request.close();
      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = await response.transform(utf8.decoder).join();
        return jsonDecode(body) as Map<String, dynamic>;
      }
    } catch (_) {
      /* Fallback offline */
    }
    return null;
  }

  /// Đăng nhập bằng Email & Mật khẩu
  Future<Map<String, dynamic>?> login({
    required String email,
    required String password,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/auth/login');
      final request = await _httpClient.postUrl(uri);
      _headers().forEach((k, v) => request.headers.set(k, v));
      request.write(jsonEncode({'email': email, 'password': password}));
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        return jsonDecode(body) as Map<String, dynamic>;
      }
    } catch (_) {
      /* Fallback offline */
    }
    return null;
  }

  /// Đăng nhập bằng Google
  Future<Map<String, dynamic>?> loginWithGoogle({
    required String email,
    required String displayName,
    String? avatarUrl,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/auth/google');
      final request = await _httpClient.postUrl(uri);
      _headers().forEach((k, v) => request.headers.set(k, v));
      request.write(jsonEncode({
        'email': email,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
      }));
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        return jsonDecode(body) as Map<String, dynamic>;
      }
    } catch (_) {
      /* Fallback offline */
    }
    return null;
  }

  /// Yêu cầu đặt lại mật khẩu qua email
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final uri = Uri.parse('$baseUrl/auth/forgot-password');
      final request = await _httpClient.postUrl(uri);
      _headers().forEach((k, v) => request.headers.set(k, v));
      request.write(jsonEncode({'email': email}));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      return {
        'statusCode': response.statusCode,
        'success': response.statusCode == 200,
        'message': data['message'] ?? (data['error'] ?? 'Lỗi không xác định'),
      };
    } catch (e) {
      return {
        'statusCode': 0,
        'success': false,
        'message': 'Không thể kết nối đến máy chủ: $e',
      };
    }
  }

  /// Cập nhật hồ sơ & lộ trình học lên đám mây Neon
  Future<bool> updateProfile(Map<String, dynamic> profileData) async {
    try {
      final uri = Uri.parse('$baseUrl/profile');
      final request = await _httpClient.putUrl(uri);
      _headers().forEach((k, v) => request.headers.set(k, v));
      request.write(jsonEncode(profileData));
      final response = await request.close();
      return response.statusCode == 200;
    } catch (_) {
      return false;
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
      final request = await _httpClient.postUrl(uri);
      _headers().forEach((k, v) => request.headers.set(k, v));
      request.write(jsonEncode({
        'examType': examType,
        'totalQuestions': totalQuestions,
        'correctCount': correctCount,
        'score': score,
        'durationSeconds': durationSeconds,
      }));
      final response = await request.close();
      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = await response.transform(utf8.decoder).join();
        return jsonDecode(body) as Map<String, dynamic>;
      }
    } catch (_) {
      /* Fallback offline */
    }
    return null;
  }
}
