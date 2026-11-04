import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:sqflite/sqflite.dart';
import 'package:thpt_english/data/app_database.dart';
import 'package:thpt_english/data/app_repository.dart';
import 'package:thpt_english/data/models/learning_session.dart';
import 'package:thpt_english/data/remote/api_client.dart';
import 'package:thpt_english/ui/auth/auth_controller.dart';
import 'package:thpt_english/ui/auth/google_auth_service.dart';
import 'package:thpt_english/ui/auth/login_screen.dart';

import 'support/sqlite_bridge.dart';

/// Mock Platform Interface để kiểm thử các tình huống SDK Google Sign In
class FakeGoogleSignInPlatform extends GoogleSignInPlatform {
  InitParameters? lastInitParams;
  int initCallCount = 0;
  bool shouldSupportAuthenticate = true;
  Object? authenticateError;
  AuthenticationResults? authenticateResult;
  bool signOutCalled = false;

  @override
  Future<void> init(InitParameters params) async {
    initCallCount++;
    lastInitParams = params;
  }

  @override
  bool supportsAuthenticate() => shouldSupportAuthenticate;

  @override
  Future<AuthenticationResults> authenticate(AuthenticateParameters params) async {
    if (authenticateError != null) {
      throw authenticateError!;
    }
    return authenticateResult ??
        AuthenticationResults(
          user: const GoogleSignInUserData(
            displayName: 'Nguyễn Văn An',
            email: 'nguyenvanan.test@gmail.com',
            id: '109876543210987654321',
            photoUrl: 'https://example.com/avatar.jpg',
          ),
          authenticationTokens: const AuthenticationTokenData(
            idToken: 'mock.header.payload.signature_google_id_token',
          ),
        );
  }

  @override
  Future<void> signOut(SignOutParams params) async {
    signOutCalled = true;
  }

  @override
  Future<void> disconnect(DisconnectParams params) async {}

  @override
  bool authorizationRequiresUserInteraction() => false;

  @override
  Future<ClientAuthorizationTokenData?> clientAuthorizationTokensForScopes(
    ClientAuthorizationTokensForScopesParameters params,
  ) async => null;

  @override
  Future<ServerAuthorizationTokenData?> serverAuthorizationTokensForScopes(
    ServerAuthorizationTokensForScopesParameters params,
  ) async => null;

  @override
  Future<AuthenticationResults?>? attemptLightweightAuthentication(
    AttemptLightweightAuthenticationParameters params,
  ) async => null;
}

/// Fake ApiClient để giả lập các phản hồi từ Backend
class FakeAuthApiClient extends ApiClient {
  ApiResponse? googleResponse;
  String? lastSentIdToken;

  FakeAuthApiClient({this.googleResponse});

  @override
  Future<ApiResponse> loginWithGoogle({required String idToken}) async {
    lastSentIdToken = idToken;
    if (googleResponse != null) {
      return googleResponse!;
    }
    return ApiResponse.success(200, {
      'message': 'Đăng nhập Google thành công.',
      'user': {
        'id': 'usr_g_1712049200_abc',
        'email': 'nguyenvanan.test@gmail.com',
        'displayName': 'Nguyễn Văn An',
        'avatarUrl': 'https://example.com/avatar.jpg',
        'authProvider': 'google',
        'role': 'student',
        'emailVerified': true,
      },
      'token': 'app_jwt_session_token_xyz_123',
    });
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SqliteBridge bridge;
  late Database database;
  late FakeGoogleSignInPlatform fakePlatform;
  late GoogleSignInPlatform originalPlatform;

  setUpAll(() async {
    bridge = await SqliteBridge.start();
    database = await AppDatabase.instance.database;
    originalPlatform = GoogleSignInPlatform.instance;
  });

  tearDownAll(() async {
    GoogleSignInPlatform.instance = originalPlatform;
    await database.close();
    await bridge.close();
  });

  setUp(() {
    fakePlatform = FakeGoogleSignInPlatform();
    GoogleSignInPlatform.instance = fakePlatform;
    GoogleAuthService.instance.resetForTesting();
  });

  group('1. GoogleAuthService - Khởi tạo & Kiểm soát Cấu hình', () {
    test('Thiếu serverClientId -> Báo lỗi có kiểm soát, không gọi authenticate', () async {
      GoogleAuthService.instance.setCustomServerClientId('');

      final result = await GoogleAuthService.instance.signIn();

      expect(result.isSuccess, isFalse);
      expect(result.isCanceled, isFalse);
      expect(result.errorMessage, contains('chưa được cấu hình Client ID'));
      expect(result.technicalDetails, contains('Missing serverClientId'));
    });

    test('Nền tảng không hỗ trợ authenticate -> Báo lỗi thân thiện', () async {
      GoogleAuthService.instance.setCustomServerClientId('test-web-client-id.apps.googleusercontent.com');
      fakePlatform.shouldSupportAuthenticate = false;

      final result = await GoogleAuthService.instance.signIn();

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('không hỗ trợ đăng nhập Google trực tiếp'));
    });

    test('Người dùng huỷ chọn tài khoản (canceled) -> Trở lại bình thường, không hiện lỗi', () async {
      GoogleAuthService.instance.setCustomServerClientId('test-web-client-id.apps.googleusercontent.com');
      fakePlatform.authenticateError = const GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
        description: 'The user canceled the account picker dialog.',
      );

      final result = await GoogleAuthService.instance.signIn();

      expect(result.isSuccess, isFalse);
      expect(result.isCanceled, isTrue);
      expect(result.errorMessage, isNull);
    });

    test('Lỗi clientConfigurationError từ SDK -> Trả thông điệp hướng dẫn rõ ràng, không văng stack trace', () async {
      GoogleAuthService.instance.setCustomServerClientId('test-web-client-id.apps.googleusercontent.com');
      fakePlatform.authenticateError = const GoogleSignInException(
        code: GoogleSignInExceptionCode.clientConfigurationError,
        description: 'serverClientId must be provided on Android',
      );

      final result = await GoogleAuthService.instance.signIn();

      expect(result.isSuccess, isFalse);
      expect(result.isCanceled, isFalse);
      expect(result.errorMessage, contains('Lỗi cấu hình đăng nhập Google'));
      expect(result.technicalDetails, 'serverClientId must be provided on Android');
    });

    test('Đăng nhập thành công -> Nhận idToken và thông tin tài khoản', () async {
      GoogleAuthService.instance.setCustomServerClientId('test-web-client-id.apps.googleusercontent.com');

      final result = await GoogleAuthService.instance.signIn();

      expect(result.isSuccess, isTrue);
      expect(result.idToken, 'mock.header.payload.signature_google_id_token');
      expect(result.account?.email, 'nguyenvanan.test@gmail.com');
      expect(fakePlatform.lastInitParams?.serverClientId, 'test-web-client-id.apps.googleusercontent.com');
    });

    test('Khởi tạo lặp -> Chỉ gọi GoogleSignInPlatform.init một lần duy nhất', () async {
      GoogleAuthService.instance.setCustomServerClientId('test-web-client-id.apps.googleusercontent.com');

      await GoogleAuthService.instance.initialize();
      await GoogleAuthService.instance.initialize();
      await GoogleAuthService.instance.initialize();

      expect(fakePlatform.initCallCount, 1);
    });
  });

  group('2. AuthController - Luồng Đăng nhập Google Toàn Phần', () {
    test('Huỷ chọn tài khoản -> Không để lại trạng thái đăng nhập nửa vời', () async {
      GoogleAuthService.instance.setCustomServerClientId('test-web-client-id.apps.googleusercontent.com');
      fakePlatform.authenticateError = const GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
      );

      final fakeApi = FakeAuthApiClient();
      final auth = AuthController.createForTesting(client: fakeApi);

      final ok = await auth.loginWithGoogle();

      expect(ok, isFalse);
      expect(auth.isLoading, isFalse);
      expect(auth.errorMessage, isNull);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.user.isLoggedIn, isFalse);
      expect(fakeApi.lastSentIdToken, isNull);
    });

    test('Backend trả về 503 (Server chưa cấu hình GOOGLE_CLIENT_ID) -> Báo lỗi máy chủ chính xác', () async {
      GoogleAuthService.instance.setCustomServerClientId('test-web-client-id.apps.googleusercontent.com');

      final fakeApi = FakeAuthApiClient(
        googleResponse: ApiResponse.error(
          503,
          'Dịch vụ Đăng nhập Google chưa sẵn sàng (Máy chủ chưa cấu hình GOOGLE_CLIENT_ID).',
        ),
      );
      final auth = AuthController.createForTesting(client: fakeApi);

      final ok = await auth.loginWithGoogle();

      expect(ok, isFalse);
      expect(auth.errorMessage, contains('Dịch vụ Đăng nhập Google chưa sẵn sàng'));
      expect(auth.isAuthenticated, isFalse);
    });

    test('Backend trả về 409 (Email đã đăng ký bằng Mật khẩu) -> Từ chối gộp tự động, yêu cầu mật khẩu', () async {
      GoogleAuthService.instance.setCustomServerClientId('test-web-client-id.apps.googleusercontent.com');

      final fakeApi = FakeAuthApiClient(
        googleResponse: ApiResponse.error(
          409,
          'Email này đã được đăng ký bằng Mật khẩu. Vui lòng đăng nhập bằng Email và Mật khẩu để bảo mật.',
        ),
      );
      final auth = AuthController.createForTesting(client: fakeApi);

      final ok = await auth.loginWithGoogle();

      expect(ok, isFalse);
      expect(auth.errorMessage, contains('Email này đã được đăng ký bằng Mật khẩu'));
      expect(auth.isAuthenticated, isFalse);
    });

    test('Đăng nhập Google thành công -> Cấp phiên hợp lệ, lưu token, bảo lưu dữ liệu khách', () async {
      GoogleAuthService.instance.setCustomServerClientId('test-web-client-id.apps.googleusercontent.com');

      final repo = AppRepository();
      // Giả lập khách có bài học thử
      final guestId = await repo.getOrCreateGuestSessionId();
      await repo.saveLearningSession(
        LearningSession(
          ownerId: guestId,
          lessonId: 'trial_unit1_reading',
          lessonTitle: 'Life Stories of Famous People',
          currentQuestionIndex: 2,
          totalQuestions: 5,
          questionIds: const ['q1', 'q2', 'q3', 'q4', 'q5'],
        ),
      );

      final fakeApi = FakeAuthApiClient();
      final auth = AuthController.createForTesting(client: fakeApi, repo: repo);

      final ok = await auth.loginWithGoogle();

      expect(ok, isTrue);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.user.email, 'nguyenvanan.test@gmail.com');
      expect(auth.user.role, 'student');
      expect(auth.user.authProvider, 'google');
      expect(auth.token, 'app_jwt_session_token_xyz_123');
      expect(auth.hasGuestDataToMerge, isTrue); // Phát hiện dữ liệu khách cần gộp

      // Đăng xuất -> Xoá phiên và gọi Google signOut
      await auth.logout();
      expect(auth.isAuthenticated, isFalse);
      expect(auth.token, isNull);
      expect(fakePlatform.signOutCalled, isTrue);
    });
  });

  group('3. UI Integration - Nút Đăng nhập Google', () {
    testWidgets('Nút Google hiển thị và xử lý lỗi không crash', (tester) async {
      GoogleAuthService.instance.setCustomServerClientId('test-web-client-id.apps.googleusercontent.com');
      fakePlatform.authenticateError = const GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final googleBtn = find.text('Tiếp tục với Google');
      expect(googleBtn, findsOneWidget);

      await tester.tap(googleBtn);
      await tester.pump();
      await tester.pumpAndSettle();

      // Sau khi huỷ, màn hình vẫn hoạt động bình thường, không hiện exception thô
      expect(find.textContaining('GoogleSignInException'), findsNothing);
      expect(find.textContaining('clientConfigurationError'), findsNothing);
    });
  });
}
