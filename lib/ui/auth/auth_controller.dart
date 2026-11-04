import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/app_database.dart';
import '../../data/app_repository.dart';
import '../../data/models/user_profile.dart';
import '../../data/remote/api_client.dart';
import 'google_auth_service.dart';

class AuthController extends ChangeNotifier {
  static final AuthController instance = AuthController._internal();
  factory AuthController() => instance;
  AuthController._internal({ApiClient? client, AppRepository? repo})
      : _apiClient = client ?? ApiClient(),
        _repository = repo ?? AppRepository() {
    loadSavedProfile();
  }

  @visibleForTesting
  AuthController.createForTesting({ApiClient? client, AppRepository? repo})
      : _apiClient = client ?? ApiClient(),
        _repository = repo ?? AppRepository() {
    loadSavedProfile();
  }

  @visibleForTesting
  void setUserForTesting(UserProfile user) {
    _user = user;
    notifyListeners();
  }

  final ApiClient _apiClient;
  final AppRepository _repository;

  UserProfile _user = const UserProfile();
  bool _isLoading = false;
  bool _isRestoringSession = false;
  String? _errorMessage;
  String? _successMessage;
  bool _hasDismissedGuestPrompt = false;
  bool _hasGuestDataToMerge = false;
  String? _token;

  UserProfile get user => _user;
  bool get isLoading => _isLoading;
  bool get isRestoringSession => _isRestoringSession;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  bool get isAuthenticated => _user.isLoggedIn;
  bool get hasDismissedGuestPrompt => _hasDismissedGuestPrompt;
  bool get hasGuestDataToMerge => _hasGuestDataToMerge;
  String? get token => _token;

  void dismissGuestPrompt() {
    _hasDismissedGuestPrompt = true;
    notifyListeners();
  }

  /// Nạp cài đặt học tập đã lưu của người dùng
  Future<void> loadSavedProfile() async {
    try {
      final savedExamDate = await _repository.getSetting('exam_date');
      final savedTargetScoreStr = await _repository.getSetting('target_score');
      final savedTargetConfirmedStr = await _repository.getSetting('target_score_confirmed');
      final isTargetConfirmed = savedTargetConfirmedStr == 'true';
      final savedDailyMinutesStr = await _repository.getSetting('daily_minutes');
      final savedReminderEnabledStr = await _repository.getSetting('reminder_enabled');
      final savedReminderTime = await _repository.getSetting('reminder_time');
      final savedReminderHour = await _repository.getSetting('reminder_hour');
      final savedReminderMinute = await _repository.getSetting('reminder_minute');

      final targetScore = (isTargetConfirmed && savedTargetScoreStr != null)
          ? double.tryParse(savedTargetScoreStr)
          : null;
      final dailyMinutes = savedDailyMinutesStr != null ? int.tryParse(savedDailyMinutesStr) : null;
      final reminderEnabled = savedReminderEnabledStr != null ? savedReminderEnabledStr == 'true' : null;

      String? computedReminderTime = savedReminderTime;
      if (computedReminderTime == null && savedReminderHour != null && savedReminderMinute != null) {
        computedReminderTime = '${savedReminderHour.padLeft(2, '0')}:${savedReminderMinute.padLeft(2, '0')}';
      }

      _user = _user.copyWith(
        examDate: savedExamDate ?? _user.examDate,
        targetScore: targetScore ?? _user.targetScore,
        isTargetScoreConfirmed: isTargetConfirmed || _user.isTargetScoreConfirmed,
        dailyMinutes: dailyMinutes ?? _user.dailyMinutes,
        reminderEnabled: reminderEnabled ?? _user.reminderEnabled,
        reminderTime: computedReminderTime ?? _user.reminderTime,
      );
      notifyListeners();
    } catch (_) {}
  }

  /// Khôi phục phiên đăng nhập thật khi khởi động ứng dụng
  Future<void> restoreSession() async {
    _isRestoringSession = true;
    notifyListeners();

    try {
      final savedUser = await _repository.getAuthUser();
      final savedToken = await _repository.getAuthToken();

      if (savedUser != null && savedToken != null && savedToken.isNotEmpty) {
        _user = savedUser.copyWith(
          examDate: _user.examDate,
          targetScore: _user.targetScore,
          isTargetScoreConfirmed: _user.isTargetScoreConfirmed,
          dailyMinutes: _user.dailyMinutes,
          reminderEnabled: _user.reminderEnabled,
          reminderTime: _user.reminderTime,
        );
        _token = savedToken;

        // Đối chiếu với server backend (nếu có mạng)
        final res = await _apiClient.getCurrentUser(savedToken);
        if (res.isSuccess && res.data != null) {
          final serverUser = res.data!['user'] as Map<String, dynamic>?;
          if (serverUser != null) {
            final sEmail = serverUser['email'] as String? ?? _user.email;
            _user = _user.copyWith(
              displayName: serverUser['displayName'] as String? ?? _user.displayName,
              email: sEmail,
              avatarUrl: serverUser['avatarUrl'] as String? ?? _user.avatarUrl,
              role: UserProfile.isSystemAdmin(sEmail)
                  ? 'admin'
                  : (serverUser['role'] as String? ?? _user.role),
              emailVerified: serverUser['emailVerified'] == true,
              isLocked: serverUser['isLocked'] == true,
              lockedReason: serverUser['lockedReason'] as String? ?? '',
            );
            await _repository.saveAuthUser(_user);
          }
        } else if (res.statusCode == 401 || (res.statusCode == 403 && res.data?['isLocked'] == true)) {
          final lockMsg = res.errorMessage;
          await logout();
          if (lockMsg != null && lockMsg.isNotEmpty) {
            _errorMessage = lockMsg;
          }
        }
        if (UserProfile.isSystemAdmin(_user.email)) {
          _user = _user.copyWith(role: 'admin');
          await _repository.saveAuthUser(_user);
        }
      }
    } catch (_) {
    } finally {
      _isRestoringSession = false;
      notifyListeners();
    }
  }

  void updateProfile(UserProfile updated) {
    _user = updated;
    notifyListeners();
  }

  /// Chuyển đổi hoặc đồng bộ vai trò người dùng ('student' | 'teacher' | 'admin')
  Future<bool> switchRole(String targetRole) async {
    if (!['student', 'teacher', 'admin'].contains(targetRole)) return false;
    _isLoading = true;
    notifyListeners();
    try {
      if (_token != null && _token!.isNotEmpty) {
        await _apiClient.postJson(
          '/auth/switch-role',
          {'targetRole': targetRole},
          overrideToken: _token,
        );
      }
      _user = _user.copyWith(
        role: targetRole,
        isLoggedIn: _user.isLoggedIn || targetRole != 'student',
        authProvider: _user.isGuest && targetRole != 'student' ? 'email' : _user.authProvider,
        displayName: _user.isGuest && targetRole == 'teacher'
            ? 'Giáo viên EngPass'
            : (_user.isGuest && targetRole == 'admin' ? 'Quản trị viên EngPass' : _user.displayName),
      );
      await _repository.saveAuthUser(_user);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (_) {
      _user = _user.copyWith(role: targetRole);
      await _repository.saveAuthUser(_user);
      _isLoading = false;
      notifyListeners();
      return true;
    }
  }

  void setPlan({
    required double targetScore,
    required String examDate,
    required int dailyMinutes,
    required bool reminderEnabled,
    String? reminderTime,
    List<String>? favoriteTopics,
  }) {
    final finalReminderTime = reminderTime ?? _user.reminderTime;
    _user = _user.copyWith(
      targetScore: targetScore,
      isTargetScoreConfirmed: true,
      examDate: examDate,
      dailyMinutes: dailyMinutes,
      reminderEnabled: reminderEnabled,
      reminderTime: finalReminderTime,
      favoriteTopics: favoriteTopics ?? _user.favoriteTopics,
    );
    _repository.setSetting('exam_date', examDate);
    _repository.setSetting('target_score', targetScore.toString());
    _repository.setSetting('target_score_confirmed', 'true');
    _repository.setSetting('daily_minutes', dailyMinutes.toString());
    _repository.setSetting('daily_goal', dailyMinutes.toString());
    _repository.setSetting('reminder_enabled', reminderEnabled ? 'true' : 'false');
    _repository.setSetting('reminder_time', finalReminderTime);
    final parts = finalReminderTime.split(':');
    if (parts.length == 2) {
      _repository.setSetting('reminder_hour', parts[0]);
      _repository.setSetting('reminder_minute', parts[1]);
    }
    notifyListeners();
  }

  /// Đăng ký học viên bằng Email & Mật khẩu thật
  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      _errorMessage = 'Địa chỉ email không hợp lệ.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    if (password.length < 6) {
      _errorMessage = 'Mật khẩu phải từ 6 ký tự trở lên.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    try {
      final res = await _apiClient.register(
        email: cleanEmail,
        password: password,
        displayName: name.trim().isEmpty ? null : name.trim(),
      );

      if (!res.isSuccess || res.data == null) {
        if (res.statusCode == 503 ||
            res.statusCode == 0 ||
            (res.statusCode == 400 && (res.errorMessage?.contains('(400)') ?? false))) {
          _errorMessage =
              'Hệ thống xác thực tài khoản đang bảo trì hoặc chưa sẵn sàng. Bạn có thể tiếp tục với vai trò Khách để học thử.';
        } else {
          _errorMessage = res.errorMessage ?? 'Đăng ký tài khoản không thành công.';
        }
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final data = res.data!;
      final token = data['token'] as String;
      final userData = data['user'] as Map<String, dynamic>;

      _token = token;
      await _repository.saveAuthToken(token);

      final rEmail = userData['email'] as String? ?? cleanEmail;
      final registeredUser = UserProfile(
        id: userData['id'] as String,
        email: rEmail,
        displayName: userData['displayName'] as String? ?? name,
        avatarUrl: userData['avatarUrl'] as String? ?? '',
        authProvider: 'email',
        role: UserProfile.isSystemAdmin(rEmail)
            ? 'admin'
            : (userData['role'] as String? ?? 'student'),
        emailVerified: userData['emailVerified'] == true,
        isLoggedIn: true,
        targetScore: _user.targetScore,
        isTargetScoreConfirmed: _user.isTargetScoreConfirmed,
        dailyMinutes: _user.dailyMinutes,
        reminderEnabled: _user.reminderEnabled,
        reminderTime: _user.reminderTime,
      );

      // Chuyển toàn bộ dữ liệu học thử sang tài khoản mới
      await transferGuestDataAfterAuth(
        targetUserId: registeredUser.id,
        displayName: registeredUser.displayName,
        email: registeredUser.email,
        authProvider: 'email',
      );

      await _markOnboardingCompleted();
      await _repository.saveAuthUser(_user);
      _successMessage = data['message'] as String? ?? 'Đăng ký tài khoản thành công!';
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Lỗi hệ thống: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Đăng nhập bằng Email & Mật khẩu thật
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || password.isEmpty) {
      _errorMessage = 'Vui lòng nhập đầy đủ email và mật khẩu.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    try {
      final res = await _apiClient.login(
        email: cleanEmail,
        password: password,
      );

      if (!res.isSuccess || res.data == null) {
        if (res.statusCode == 503) {
          _errorMessage =
              'Tính năng đăng nhập tài khoản thực tế chưa sẵn sàng. Vui lòng trải nghiệm tính năng với tư cách Khách.';
        } else {
          _errorMessage = res.errorMessage ?? 'Đăng nhập không thành công.';
        }
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final data = res.data!;
      final token = data['token'] as String;
      final userData = data['user'] as Map<String, dynamic>;

      _token = token;
      await _repository.saveAuthToken(token);

      final lEmail = userData['email'] as String? ?? cleanEmail;
      final loggedInUser = UserProfile(
        id: userData['id'] as String,
        email: lEmail,
        displayName: userData['displayName'] as String? ?? 'Học sinh',
        avatarUrl: userData['avatarUrl'] as String? ?? '',
        authProvider: userData['authProvider'] as String? ?? 'email',
        role: UserProfile.isSystemAdmin(lEmail)
            ? 'admin'
            : (userData['role'] as String? ?? 'student'),
        emailVerified: userData['emailVerified'] == true,
        isLoggedIn: true,
        targetScore: _user.targetScore,
        isTargetScoreConfirmed: _user.isTargetScoreConfirmed,
        dailyMinutes: _user.dailyMinutes,
        reminderEnabled: _user.reminderEnabled,
        reminderTime: _user.reminderTime,
      );

      final currentGuestId = await _repository.getOrCreateGuestSessionId();
      final hasGuestData = await _repository.hasGuestData(currentGuestId);
      _hasGuestDataToMerge = hasGuestData;

      _user = loggedInUser;
      await _markOnboardingCompleted();
      await _repository.saveAuthUser(_user);

      _successMessage = 'Đăng nhập thành công!';
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Lỗi hệ thống khi đăng nhập: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Đăng nhập bằng Google thật (lấy idToken và gửi backend xác minh)
  Future<bool> loginWithGoogle({String? serverClientId}) async {
    if (_isLoading) return false;

    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final googleResult = await GoogleAuthService.instance.signIn(
        serverClientId: serverClientId,
      );

      // Nếu người dùng huỷ chọn tài khoản -> quay lại bình thường không báo lỗi
      if (googleResult.isCanceled) {
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
        return false;
      }

      if (!googleResult.isSuccess || googleResult.idToken == null) {
        _errorMessage = googleResult.errorMessage ?? 'Đăng nhập Google thất bại.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final res = await _apiClient.loginWithGoogle(idToken: googleResult.idToken!);
      if (!res.isSuccess || res.data == null) {
        _errorMessage = res.errorMessage ?? 'Đăng nhập Google thất bại.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final data = res.data!;
      final token = data['token'] as String;
      final userData = data['user'] as Map<String, dynamic>;

      _token = token;
      await _repository.saveAuthToken(token);

      final gEmail = userData['email'] as String? ?? googleResult.account?.email ?? '';
      final loggedInUser = UserProfile(
        id: userData['id'] as String,
        email: gEmail,
        displayName: userData['displayName'] as String? ?? googleResult.account?.displayName ?? 'Học sinh EngPass',
        avatarUrl: userData['avatarUrl'] as String? ?? googleResult.account?.photoUrl ?? '',
        authProvider: 'google',
        role: UserProfile.isSystemAdmin(gEmail)
            ? 'admin'
            : (userData['role'] as String? ?? 'student'),
        emailVerified: userData['emailVerified'] == true,
        isLoggedIn: true,
        targetScore: _user.targetScore,
        isTargetScoreConfirmed: _user.isTargetScoreConfirmed,
        dailyMinutes: _user.dailyMinutes,
        reminderEnabled: _user.reminderEnabled,
        reminderTime: _user.reminderTime,
      );

      final currentGuestId = await _repository.getOrCreateGuestSessionId();
      final hasGuestData = await _repository.hasGuestData(currentGuestId);
      _hasGuestDataToMerge = hasGuestData;

      _user = loggedInUser;
      await _markOnboardingCompleted();
      await _repository.saveAuthUser(_user);

      _successMessage = 'Đăng nhập Google thành công!';
      _isLoading = false;
      notifyListeners();
      return true;
    } on PlatformException catch (e) {
      if (e.code == 'network_error') {
        _errorMessage = 'Không có kết nối mạng để đăng nhập Google.';
      } else {
        _errorMessage = 'Lỗi kết nối Google: ${e.message ?? e.code}';
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Lỗi kết nối khi đăng nhập Google. Vui lòng thử lại sau.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Gộp dữ liệu của khách vào tài khoản đã đăng nhập
  Future<TransferResult?> mergeGuestDataIntoAccount() async {
    _isLoading = true;
    notifyListeners();

    try {
      final guestSessionId = await _repository.getOrCreateGuestSessionId();
      final result = await _repository.transferGuestData(
        fromGuestId: guestSessionId,
        toUserId: _user.id,
      );
      _hasGuestDataToMerge = false;
      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _errorMessage = 'Lỗi gộp dữ liệu: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Bỏ qua không gộp dữ liệu khách
  Future<void> dismissGuestDataMerge() async {
    _hasGuestDataToMerge = false;
    await _repository.resetGuestSessionId();
    notifyListeners();
  }

  /// Gửi lại thư xác minh email
  Future<bool> resendVerificationEmail() async {
    if (_token == null || _token!.isEmpty) {
      _errorMessage = 'Chưa có phiên làm việc hợp lệ.';
      notifyListeners();
      return false;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final res = await _apiClient.resendVerificationEmail(_token!);
    _isLoading = false;
    if (res.isSuccess) {
      _successMessage = res.data?['message'] as String? ?? 'Đã gửi lại thư xác minh.';
      notifyListeners();
      return true;
    } else {
      _errorMessage = res.errorMessage ?? 'Không thể gửi lại thư xác minh.';
      notifyListeners();
      return false;
    }
  }

  /// Quên mật khẩu
  Future<ApiResponse> forgotPassword(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final res = await _apiClient.forgotPassword(email.trim().toLowerCase());
    _isLoading = false;
    notifyListeners();
    return res;
  }

  /// Đặt lại mật khẩu mới bằng Token
  Future<ApiResponse> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final res = await _apiClient.resetPassword(token: token, newPassword: newPassword);
    _isLoading = false;
    notifyListeners();
    return res;
  }

  /// Chuyển giao dữ liệu khách sang tài khoản mới
  Future<TransferResult> transferGuestDataAfterAuth({
    required String targetUserId,
    required String displayName,
    required String email,
    String authProvider = 'email',
  }) async {
    final guestSessionId = await _repository.getOrCreateGuestSessionId();
    final result = await _repository.transferGuestData(
      fromGuestId: guestSessionId,
      toUserId: targetUserId,
    );

    _user = _user.copyWith(
      id: targetUserId,
      displayName: displayName,
      email: email,
      isLoggedIn: true,
      authProvider: authProvider,
    );

    notifyListeners();
    return result;
  }

  /// Đăng nhập tài khoản đã tồn tại
  Future<TransferResult?> signInExistingAccount({
    required UserProfile existingUser,
    bool mergeGuestData = false,
  }) async {
    TransferResult? result;
    if (mergeGuestData) {
      final guestSessionId = await _repository.getOrCreateGuestSessionId();
      result = await _repository.transferGuestData(
        fromGuestId: guestSessionId,
        toUserId: existingUser.id,
      );
    }
    _user = existingUser.copyWith(isLoggedIn: true);
    _hasGuestDataToMerge = false;
    await _markOnboardingCompleted();
    await _repository.saveAuthUser(_user);
    notifyListeners();
    return result;
  }

  Future<void> _markOnboardingCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_completed_onboarding', true);
    } catch (_) {}
  }

  /// Đăng xuất tài khoản an toàn
  Future<void> logout() async {
    _user = const UserProfile(
      id: 'guest_user',
      displayName: 'Khách',
      isLoggedIn: false,
      authProvider: 'guest',
      streakDays: 0,
      xp: 0,
    );
    _token = null;
    _hasGuestDataToMerge = false;
    _repository.clearAuthToken();
    _repository.clearAuthUser();
    _repository.resetGuestSessionId();

    try {
      await GoogleAuthService.instance.signOut();
    } catch (_) {}

    notifyListeners();
  }
}
