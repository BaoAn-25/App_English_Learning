import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Kết quả của thao tác đăng nhập Google
class GoogleSignInResult {
  final bool isSuccess;
  final bool isCanceled;
  final String? idToken;
  final GoogleSignInAccount? account;
  final String? errorMessage;
  final String? technicalDetails;

  const GoogleSignInResult._({
    required this.isSuccess,
    this.isCanceled = false,
    this.idToken,
    this.account,
    this.errorMessage,
    this.technicalDetails,
  });

  factory GoogleSignInResult.success({
    required String idToken,
    required GoogleSignInAccount account,
  }) {
    return GoogleSignInResult._(
      isSuccess: true,
      idToken: idToken,
      account: account,
    );
  }

  factory GoogleSignInResult.canceled({String? technicalDetails}) {
    return GoogleSignInResult._(
      isSuccess: false,
      isCanceled: true,
      technicalDetails: technicalDetails,
    );
  }

  factory GoogleSignInResult.failure({
    required String errorMessage,
    String? technicalDetails,
  }) {
    return GoogleSignInResult._(
      isSuccess: false,
      errorMessage: errorMessage,
      technicalDetails: technicalDetails,
    );
  }
}

/// Dịch vụ quản trị Đăng nhập Google chuẩn hóa cho ứng dụng Flutter English 12.
/// Tương thích toàn diện với google_sign_in 7.x và Android Credential Manager.
class GoogleAuthService {
  GoogleAuthService._();
  static final GoogleAuthService instance = GoogleAuthService._();

  /// Web OAuth Client ID được truyền qua cờ build/run (--dart-define)
  /// hoặc dùng Client ID mặc định đã được đăng ký trên Google Cloud Console
  static const String environmentServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: String.fromEnvironment(
      'GOOGLE_WEB_CLIENT_ID',
      defaultValue: '861391043852-s9fh2a4hg1k675bk6molo0au254qhqgj.apps.googleusercontent.com',
    ),
  );

  String? _customServerClientId;
  bool _isInitialized = false;
  Completer<void>? _initCompleter;
  bool _isSigningIn = false;

  bool get isSigningIn => _isSigningIn;
  bool get isInitialized => _isInitialized;

  /// Web Client ID thực tế đang sử dụng
  String get effectiveServerClientId {
    if (_customServerClientId != null) {
      return _customServerClientId!.trim();
    }
    return environmentServerClientId.trim();
  }

  /// Đã cấu hình Client ID hợp lệ hay chưa
  bool get isConfigured => effectiveServerClientId.isNotEmpty;

  /// Cho phép thiết lập Client ID qua code khi cần (ví dụ test hoặc config runtime)
  void setCustomServerClientId(String? clientId) {
    _customServerClientId = clientId;
  }

  /// Khởi tạo GoogleSignIn một lần duy nhất theo đúng tài liệu chuẩn của google_sign_in 7.x
  Future<void> initialize({String? serverClientId}) async {
    if (serverClientId != null && serverClientId.trim().isNotEmpty) {
      _customServerClientId = serverClientId.trim();
    }

    if (_isInitialized) return;
    if (_initCompleter != null) return _initCompleter!.future;

    _initCompleter = Completer<void>();
    try {
      final clientIdToUse = effectiveServerClientId;
      await GoogleSignIn.instance.initialize(
        serverClientId: clientIdToUse.isNotEmpty ? clientIdToUse : null,
      );
      _isInitialized = true;
      _initCompleter!.complete();
    } catch (e) {
      _initCompleter!.completeError(e);
      _initCompleter = null;
      rethrow;
    }
  }

  /// Thực hiện đăng nhập Google và trả về ID Token đã ký
  Future<GoogleSignInResult> signIn({String? serverClientId}) async {
    if (_isSigningIn) {
      return GoogleSignInResult.failure(
        errorMessage: 'Yêu cầu đăng nhập Google đang được xử lý. Vui lòng chờ trong giây lát.',
      );
    }

    _isSigningIn = true;
    try {
      // 1. Kiểm tra cấu hình serverClientId
      if (serverClientId != null && serverClientId.trim().isNotEmpty) {
        _customServerClientId = serverClientId.trim();
      }

      final clientId = effectiveServerClientId;
      if (clientId.isEmpty) {
        debugPrint('[GoogleAuth] CẢNH BÁO: Chưa cấu hình GOOGLE_SERVER_CLIENT_ID (Web OAuth Client ID).');
        debugPrint('[GoogleAuth] Hướng dẫn: Chạy app với cờ: flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=<web-client-id>');
        return GoogleSignInResult.failure(
          errorMessage: 'Chức năng Đăng nhập Google chưa được cấu hình Client ID. Vui lòng kiểm tra hướng dẫn cấu hình hệ thống.',
          technicalDetails: 'Missing serverClientId / GOOGLE_SERVER_CLIENT_ID',
        );
      }

      // 2. Bảo đảm khởi tạo hoàn tất trước khi gọi authenticate()
      await initialize(serverClientId: clientId);

      // 3. Kiểm tra nền tảng có hỗ trợ authenticate()
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        return GoogleSignInResult.failure(
          errorMessage: 'Thiết bị hoặc hệ điều hành hiện tại không hỗ trợ đăng nhập Google trực tiếp.',
          technicalDetails: 'supportsAuthenticate returned false',
        );
      }

      // 4. Gọi authenticate() nhận thông tin tài khoản
      final GoogleSignInAccount account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;

      if (idToken == null || idToken.isEmpty) {
        return GoogleSignInResult.failure(
          errorMessage: 'Không nhận được mã xác thực idToken từ Google. Vui lòng thử lại sau.',
          technicalDetails: 'idToken was null or empty in account.authentication',
        );
      }

      return GoogleSignInResult.success(
        idToken: idToken,
        account: account,
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        debugPrint('[GoogleAuth] Người dùng huỷ chọn tài khoản Google hoặc CredentialManager trả về canceled. Chi tiết: ${e.description ?? e.code.name}');
        return GoogleSignInResult.canceled(
          technicalDetails: 'GoogleSignInExceptionCode.canceled: ${e.description}',
        );
      } else if (e.code == GoogleSignInExceptionCode.clientConfigurationError) {
        debugPrint('[GoogleAuth] Lỗi cấu hình Google Client: ${e.description}');
        return GoogleSignInResult.failure(
          errorMessage: 'Lỗi cấu hình đăng nhập Google. Vui lòng kiểm tra lại cấu hình ứng dụng trên Google Cloud.',
          technicalDetails: e.description,
        );
      } else if (e.code == GoogleSignInExceptionCode.providerConfigurationError) {
        debugPrint('[GoogleAuth] Lỗi dịch vụ Google Play: ${e.description}');
        return GoogleSignInResult.failure(
          errorMessage: 'Dịch vụ Google Play hoặc tài khoản Google trên thiết bị chưa sẵn sàng.',
          technicalDetails: e.description,
        );
      } else if (e.code == GoogleSignInExceptionCode.uiUnavailable) {
        return GoogleSignInResult.failure(
          errorMessage: 'Không thể mở hộp thoại chọn tài khoản Google lúc này. Vui lòng thử lại.',
          technicalDetails: e.description,
        );
      } else {
        debugPrint('[GoogleAuth] Lỗi GoogleSignInException [${e.code.name}]: ${e.description}');
        return GoogleSignInResult.failure(
          errorMessage: 'Đăng nhập Google không thành công. Vui lòng thử lại sau.',
          technicalDetails: e.description,
        );
      }
    } catch (e) {
      debugPrint('[GoogleAuth] Lỗi ngoại lệ không xác định: $e');
      return GoogleSignInResult.failure(
        errorMessage: 'Lỗi kết nối khi đăng nhập Google. Vui lòng thử lại sau.',
        technicalDetails: e.toString(),
      );
    } finally {
      _isSigningIn = false;
    }
  }

  /// Đăng xuất tài khoản Google
  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      debugPrint('[GoogleAuth] Lỗi signOut: $e');
    }
  }

  @visibleForTesting
  void resetForTesting() {
    _isInitialized = false;
    _initCompleter = null;
    _isSigningIn = false;
    _customServerClientId = null;
  }
}

