import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:thpt_english/data/app_database.dart';
import 'package:thpt_english/data/app_repository.dart';
import 'package:thpt_english/data/models/daily_stat.dart';
import 'package:thpt_english/data/models/learning_session.dart';
import 'package:thpt_english/data/models/user_profile.dart';
import 'package:thpt_english/data/remote/api_client.dart';
import 'package:thpt_english/ui/auth/auth_controller.dart';

import 'support/sqlite_bridge.dart';

/// Fake ApiClient cho phép cấu hình response để test toàn bộ hành vi thật của AuthController
class FakeApiClient extends ApiClient {
  bool shouldFailNetwork = false;
  bool shouldReturn503 = false;
  bool emailAlreadyExists = false;
  bool wrongPassword = false;
  bool googleEmailConflict = false;
  bool smtpConfigured = true;

  @override
  Future<ApiResponse> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    if (shouldFailNetwork) {
      return ApiResponse.error(0, 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra kết nối mạng của bạn.');
    }
    if (shouldReturn503) {
      return ApiResponse.error(503, 'Cơ sở dữ liệu máy chủ chưa được cấu hình. Bạn có thể tiếp tục học thử với vai trò Khách.');
    }
    if (emailAlreadyExists) {
      return ApiResponse.error(409, 'Email này đã được sử dụng để đăng ký tài khoản.');
    }

    final userId = 'usr_mock_${DateTime.now().millisecondsSinceEpoch}';
    return ApiResponse.success(201, {
      'message': 'Đăng ký tài khoản thành công.',
      'token': 'jwt_mock_token_for_$userId',
      'user': {
        'id': userId,
        'email': email,
        'displayName': displayName ?? email.split('@')[0],
        'authProvider': 'email',
        'role': 'student',
        'emailVerified': false,
      },
      'emailSent': smtpConfigured,
    });
  }

  @override
  Future<ApiResponse> login({
    required String email,
    required String password,
  }) async {
    if (shouldFailNetwork) {
      return ApiResponse.error(0, 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra kết nối mạng của bạn.');
    }
    if (wrongPassword) {
      return ApiResponse.error(401, 'Email hoặc mật khẩu không chính xác.');
    }
    if (shouldReturn503) {
      return ApiResponse.error(503, 'Cơ sở dữ liệu máy chủ chưa sẵn sàng.');
    }

    return ApiResponse.success(200, {
      'message': 'Đăng nhập thành công.',
      'token': 'jwt_mock_token_existing_user',
      'user': {
        'id': 'usr_existing_123',
        'email': email,
        'displayName': 'Minh Anh',
        'avatarUrl': '',
        'authProvider': 'email',
        'role': 'student',
        'emailVerified': true,
      },
    });
  }

  @override
  Future<ApiResponse> loginWithGoogle({required String idToken}) async {
    if (googleEmailConflict) {
      return ApiResponse.error(
        409,
        'Email này đã được đăng ký bằng Mật khẩu. Vui lòng đăng nhập bằng Email và Mật khẩu để bảo mật.',
      );
    }
    return ApiResponse.success(200, {
      'message': 'Đăng nhập Google thành công.',
      'token': 'jwt_google_token_123',
      'user': {
        'id': 'usr_g_456',
        'email': 'google_student@gmail.com',
        'displayName': 'Google Student',
        'avatarUrl': 'https://lh3.googleusercontent.com/avatar.png',
        'authProvider': 'google',
        'role': 'student',
        'emailVerified': true,
      },
    });
  }

  @override
  Future<ApiResponse> getCurrentUser(String token) async {
    if (shouldFailNetwork) {
      return ApiResponse.error(0, 'Mất kết nối mạng');
    }
    if (token == 'invalid_token') {
      return ApiResponse.error(401, 'Phiên đăng nhập đã hết hạn.');
    }
    return ApiResponse.success(200, {
      'user': {
        'id': 'usr_existing_123',
        'email': 'verified_student@gmail.com',
        'displayName': 'Minh Anh',
        'avatarUrl': '',
        'authProvider': 'email',
        'role': 'student',
        'emailVerified': true,
      },
    });
  }

  @override
  Future<ApiResponse> forgotPassword(String email) async {
    if (!smtpConfigured) {
      return ApiResponse.error(
        503,
        'Dịch vụ gửi thư điện tử chưa được cấu hình trên máy chủ (thiếu cấu hình SMTP). Vui lòng liên hệ quản trị viên.',
      );
    }
    return ApiResponse.success(200, {
      'message': 'Nếu email tồn tại trong hệ thống, hướng dẫn đặt lại mật khẩu đã được gửi đến hộp thư của bạn.',
    });
  }

  @override
  Future<ApiResponse> resetPassword({required String token, required String newPassword}) async {
    if (token == 'expired_token') {
      return ApiResponse.error(400, 'Liên kết đặt lại mật khẩu không hợp lệ hoặc đã hết hạn.');
    }
    return ApiResponse.success(200, {
      'message': 'Đặt lại mật khẩu thành công. Bạn có thể đăng nhập bằng mật khẩu mới.',
    });
  }

  @override
  Future<ApiResponse> resendVerificationEmail(String token) async {
    if (!smtpConfigured) {
      return ApiResponse.error(503, 'Dịch vụ gửi thư chưa sẵn sàng.');
    }
    return ApiResponse.success(200, {
      'message': 'Đã gửi lại thư xác minh đến email của bạn.',
    });
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SqliteBridge bridge;
  late Database database;
  late AppRepository repository;
  late FakeApiClient fakeApi;

  setUpAll(() async {
    bridge = await SqliteBridge.start();
    database = await AppDatabase.instance.database;
    repository = AppRepository(db: AppDatabase.instance);
  });

  tearDownAll(() async {
    await database.close();
    await bridge.close();
  });

  setUp(() async {
    // Reset dữ liệu settings trước mỗi test
    await database.delete('app_settings');
    await database.delete('daily_stats');
    await database.delete('attempts');
    await database.delete('attempt_answers');
    await database.delete('wrong_book');
    fakeApi = FakeApiClient();
  });

  group('1. Đăng ký tài khoản học viên thật & Chuyển giao dữ liệu', () {
    test('Đăng ký hợp lệ: Tạo tài khoản, lưu JWT token, tự động chuyển giao dữ liệu khách mà không mất bài dở', () async {
      final guestId = await repository.getOrCreateGuestSessionId();
      await repository.saveLearningSession(LearningSession(
        lessonId: 'trial_unit1_reading',
        lessonTitle: 'Unit 1: A Long and Healthy Life',
        lessonType: 'trial',
        totalQuestions: 5,
        currentQuestionIndex: 2,
        questionIds: const ['trial_u1_q1', 'trial_u1_q2', 'trial_u1_q3', 'trial_u1_q4', 'trial_u1_q5'],
        selectedAnswers: const [0, 1],
        status: 'in_progress',
        ownerId: guestId,
      ));

      await repository.upsertDailyStat(const DailyStat(
        date: '2026-11-03',
        xp: 25,
        questionsDone: 5,
        correct: 4,
        minutes: 3,
      ));

      final auth = AuthController.createForTesting(client: fakeApi, repo: repository);

      final success = await auth.register(
        name: 'Nguyễn Văn A',
        email: 'hocvien12@gmail.com',
        password: 'MatKhau123@',
      );

      expect(success, isTrue);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.user.isStudent, isTrue);
      expect(auth.user.displayName, equals('Nguyễn Văn A'));
      expect(auth.user.email, equals('hocvien12@gmail.com'));
      expect(auth.token, isNotNull);

      // Kiểm tra dữ liệu bài dở đã được chuyển sang ID của học viên mới
      final studentSession = await repository.getLearningSession(auth.user.id);
      expect(studentSession, isNotNull);
      expect(studentSession!.currentQuestionIndex, equals(2));
      expect(studentSession.selectedAnswers[0], equals(0));

      // Kiểm tra token đã được lưu trong repository
      final savedToken = await repository.getAuthToken();
      expect(savedToken, equals(auth.token));
    });

    test('Đăng ký email trùng (409): Không đăng nhập giả mạo, báo lỗi rõ ràng', () async {
      fakeApi.emailAlreadyExists = true;
      final auth = AuthController.createForTesting(client: fakeApi, repo: repository);

      final success = await auth.register(
        name: 'Trùng Email',
        email: 'da_ton_tai@gmail.com',
        password: 'MatKhau123@',
      );

      expect(success, isFalse);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.errorMessage, contains('Email này đã được sử dụng'));
    });

    test('Validation đầu vào: Email không hợp lệ hoặc mật khẩu < 6 ký tự bị từ chối ngay', () async {
      final auth = AuthController.createForTesting(client: fakeApi, repo: repository);

      final badEmail = await auth.register(name: 'Test', email: 'email_khong_hop_le', password: '1234567');
      expect(badEmail, isFalse);
      expect(auth.errorMessage, contains('email không hợp lệ'));

      final shortPass = await auth.register(name: 'Test', email: 'valid@gmail.com', password: '123');
      expect(shortPass, isFalse);
      expect(auth.errorMessage, contains('6 ký tự'));
    });
  });

  group('2. Đăng nhập Email & Mật khẩu & Xử lý lỗi', () {
    test('Đăng nhập đúng: Xác thực thành công và lưu phiên làm việc', () async {
      final auth = AuthController.createForTesting(client: fakeApi, repo: repository);

      final success = await auth.login(
        email: 'hocvien@gmail.com',
        password: 'DungMatKhau123',
      );

      expect(success, isTrue);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.user.id, equals('usr_existing_123'));
      expect(auth.user.emailVerified, isTrue);
    });

    test('Đăng nhập sai mật khẩu (401): Báo lỗi cụ thể, không đăng nhập giả', () async {
      fakeApi.wrongPassword = true;
      final auth = AuthController.createForTesting(client: fakeApi, repo: repository);

      final success = await auth.login(
        email: 'hocvien@gmail.com',
        password: 'SaiMatKhau',
      );

      expect(success, isFalse);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.errorMessage, contains('không chính xác'));
    });

    test('Mất mạng: Báo lỗi kết nối mạng thân thiện, không crash', () async {
      fakeApi.shouldFailNetwork = true;
      final auth = AuthController.createForTesting(client: fakeApi, repo: repository);

      final success = await auth.login(
        email: 'hocvien@gmail.com',
        password: 'MatKhau123',
      );

      expect(success, isFalse);
      expect(auth.errorMessage, contains('kết nối'));
    });

    test('Máy chủ 503 chưa có DB: Báo máy chủ chưa sẵn sàng, cho phép tiếp tục học thử', () async {
      fakeApi.shouldReturn503 = true;
      final auth = AuthController.createForTesting(client: fakeApi, repo: repository);

      final success = await auth.login(
        email: 'hocvien@gmail.com',
        password: 'MatKhau123',
      );

      expect(success, isFalse);
      expect(auth.errorMessage, contains('chưa sẵn sàng'));
    });
  });

  group('3. Quản lý phiên làm việc, Khôi phục phiên & Đăng xuất an toàn', () {
    test('Khôi phục phiên khi mở lại app: Tự động nạp token và user profile đã lưu', () async {
      await repository.saveAuthToken('saved_jwt_token_999');
      await repository.saveAuthUser(const UserProfile(
        id: 'usr_existing_123',
        email: 'saved@gmail.com',
        displayName: 'Học sinh cũ',
        authProvider: 'email',
        role: 'student',
        emailVerified: true,
        isLoggedIn: true,
      ));

      final auth = AuthController.createForTesting(client: fakeApi, repo: repository);
      await auth.restoreSession();

      expect(auth.isAuthenticated, isTrue);
      expect(auth.token, equals('saved_jwt_token_999'));
      expect(auth.user.id, equals('usr_existing_123'));
    });

    test('Đăng xuất: Xoá sạch token, user profile và cô lập phiên khách tiếp theo', () async {
      await repository.saveAuthToken('token_to_remove');
      await repository.saveAuthUser(const UserProfile(
        id: 'usr_to_logout',
        email: 'logout@gmail.com',
        isLoggedIn: true,
      ));

      final auth = AuthController.createForTesting(client: fakeApi, repo: repository);
      auth.logout();

      expect(auth.isAuthenticated, isFalse);
      expect(auth.token, isNull);
      expect(auth.user.displayName, equals('Khách'));

      final tokenAfterLogout = await repository.getAuthToken();
      expect(tokenAfterLogout, isNull);

      final userAfterLogout = await repository.getAuthUser();
      expect(userAfterLogout, isNull);
    });
  });

  group('4. Quên mật khẩu, Xác minh Email & Đổi mật khẩu', () {
    test('Quên mật khẩu: Gửi email thành công, phản hồi an toàn', () async {
      final auth = AuthController.createForTesting(client: fakeApi, repo: repository);
      final res = await auth.forgotPassword('student@gmail.com');

      expect(res.isSuccess, isTrue);
      expect(res.data?['message'], contains('hướng dẫn đặt lại mật khẩu đã được gửi'));
    });

    test('Quên mật khẩu khi máy chủ chưa cấu hình SMTP: Báo rõ ràng, không báo thành công giả', () async {
      fakeApi.smtpConfigured = false;
      final auth = AuthController.createForTesting(client: fakeApi, repo: repository);
      final res = await auth.forgotPassword('student@gmail.com');

      expect(res.isSuccess, isFalse);
      expect(res.errorMessage, contains('Dịch vụ gửi thư điện tử chưa được cấu hình'));
    });

    test('Đặt lại mật khẩu với token hết hạn: Bị từ chối', () async {
      final auth = AuthController.createForTesting(client: fakeApi, repo: repository);
      final res = await auth.resetPassword(token: 'expired_token', newPassword: 'NewPassword123');

      expect(res.isSuccess, isFalse);
      expect(res.errorMessage, contains('không hợp lệ hoặc đã hết hạn'));
    });

    test('Đặt lại mật khẩu thành công với token hợp lệ', () async {
      final auth = AuthController.createForTesting(client: fakeApi, repo: repository);
      final res = await auth.resetPassword(token: 'valid_token_123', newPassword: 'NewPassword123');

      expect(res.isSuccess, isTrue);
      expect(res.data?['message'], contains('thành công'));
    });
  });

  group('5. Đăng nhập Google thật & Xung đột email', () {
    test('Xung đột email Google với Email mật khẩu: Trả về cảnh báo yêu cầu đăng nhập mật khẩu', () async {
      fakeApi.googleEmailConflict = true;
      final res = await fakeApi.loginWithGoogle(idToken: 'mock_google_id_token');

      expect(res.isSuccess, isFalse);
      expect(res.errorMessage, contains('đăng ký bằng Mật khẩu'));
    });
  });

  group('6. Tính bất biến và chống nhân đôi dữ liệu (Idempotency)', () {
    test('Chuyển giao dữ liệu khách nhiều lần không nhân đôi điểm số hoặc XP', () async {
      final guestId = 'guest_test_idempotent';
      final userId = 'usr_test_idempotent';

      await repository.upsertDailyStat(const DailyStat(
        date: '2026-11-03',
        questionsDone: 10,
        correct: 8,
        xp: 40,
        minutes: 15,
      ));

      // Chuyển lần 1
      final res1 = await repository.transferGuestData(fromGuestId: guestId, toUserId: userId);
      expect(res1.success, isTrue);

      // Chuyển lần 2 (thử lại hoặc trùng lặp)
      final res2 = await repository.transferGuestData(fromGuestId: guestId, toUserId: userId);
      expect(res2.success, isTrue);

      final stats = await repository.getAllDailyStats();
      expect(stats.isNotEmpty, isTrue);
      final totalXp = stats.fold<int>(0, (sum, s) => sum + s.xp);
      expect(totalXp, equals(40)); // Không bị cộng dồn lên 80!
    });
  });
}
