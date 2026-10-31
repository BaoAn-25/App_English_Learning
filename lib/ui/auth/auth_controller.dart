import 'package:flutter/material.dart';
import '../../data/app_database.dart';
import '../../data/app_repository.dart';
import '../../data/models/user_profile.dart';

class AuthController extends ChangeNotifier {
  static final AuthController instance = AuthController._internal();
  factory AuthController() => instance;
  AuthController._internal() {
    loadSavedProfile();
  }

  UserProfile _user = const UserProfile();
  bool _isLoading = false;
  String? _errorMessage;
  bool _hasDismissedGuestPrompt = false;

  UserProfile get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user.isLoggedIn;
  bool get hasDismissedGuestPrompt => _hasDismissedGuestPrompt;

  void dismissGuestPrompt() {
    _hasDismissedGuestPrompt = true;
    notifyListeners();
  }

  Future<void> loadSavedProfile() async {
    try {
      final savedExamDate = await AppRepository().getSetting('exam_date');
      final savedTargetScoreStr = await AppRepository().getSetting('target_score');
      final savedDailyMinutesStr = await AppRepository().getSetting('daily_minutes');

      final targetScore = savedTargetScoreStr != null ? double.tryParse(savedTargetScoreStr) : null;
      final dailyMinutes = savedDailyMinutesStr != null ? int.tryParse(savedDailyMinutesStr) : null;

      if (savedExamDate != null || targetScore != null || dailyMinutes != null) {
        _user = _user.copyWith(
          examDate: savedExamDate ?? _user.examDate,
          targetScore: targetScore ?? _user.targetScore,
          dailyMinutes: dailyMinutes ?? _user.dailyMinutes,
        );
        notifyListeners();
      }
    } catch (_) {}
  }

  void updateProfile(UserProfile updated) {
    _user = updated;
    notifyListeners();
  }

  void setPlan({
    required double targetScore,
    required String examDate,
    required int dailyMinutes,
    required bool reminderEnabled,
    List<String>? favoriteTopics,
  }) {
    _user = _user.copyWith(
      targetScore: targetScore,
      examDate: examDate,
      dailyMinutes: dailyMinutes,
      reminderEnabled: reminderEnabled,
      favoriteTopics: favoriteTopics ?? _user.favoriteTopics,
    );
    AppRepository().setSetting('exam_date', examDate);
    AppRepository().setSetting('target_score', targetScore.toString());
    AppRepository().setSetting('daily_minutes', dailyMinutes.toString());
    notifyListeners();
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    if (email.isEmpty || !email.contains('@')) {
      _errorMessage = 'Email không hợp lệ';
      _isLoading = false;
      notifyListeners();
      return false;
    }
    if (password.length < 6) {
      _errorMessage = 'Mật khẩu phải từ 6 ký tự trở lên';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    // Ranh giới bắt buộc: Xác thực thực tế chưa sẵn sàng.
    // Không gán đăng nhập giả mạo hoặc cấp token giả.
    _errorMessage = 'Hệ thống xác thực tài khoản đang bảo trì hoặc chưa sẵn sàng. Bạn có thể tiếp tục với vai trò Khách để học thử.';
    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    if (email.isEmpty || password.isEmpty) {
      _errorMessage = 'Vui lòng nhập email và mật khẩu';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    // Không tự động gán isLoggedIn = true khi chưa kiểm tra mật khẩu thật
    _errorMessage = 'Tính năng đăng nhập tài khoản thực tế chưa sẵn sàng. Vui lòng trải nghiệm tính năng với tư cách Khách.';
    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> loginWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // Ranh giới: Không giả lập đăng nhập Google
    _errorMessage = 'Đăng nhập Google hiện chưa khả dụng trên phiên bản này.';
    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Xử lý chuyển giao dữ liệu khách sang tài khoản mới sau khi xác thực thật thành công.
  /// Đáp ứng các yêu cầu:
  /// - Gắn đúng dữ liệu của phiên khách hiện tại vào tài khoản mới.
  /// - Giữ nguyên câu trả lời, kết quả, sổ sai và tiến độ từ vựng.
  /// - Chạy lại không tạo trùng dữ liệu hoặc nhân đôi XP.
  Future<TransferResult> transferGuestDataAfterAuth({
    required String targetUserId,
    required String displayName,
    required String email,
    String authProvider = 'email',
  }) async {
    final guestSessionId = await AppRepository().getOrCreateGuestSessionId();
    final result = await AppRepository().transferGuestData(
      fromGuestId: guestSessionId,
      toUserId: targetUserId,
    );

    // Cập nhật profile người dùng mới
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

  /// Đăng nhập tài khoản đã tồn tại (existing account).
  /// Tuân thủ Quy tắc 6: Không tự ghi đè lịch sử tài khoản bằng dữ liệu khách.
  /// Mặc định giữ riêng dữ liệu khách trừ khi người dùng chủ động chọn hợp nhất.
  Future<TransferResult?> signInExistingAccount({
    required UserProfile existingUser,
    bool mergeGuestData = false,
  }) async {
    TransferResult? result;
    if (mergeGuestData) {
      final guestSessionId = await AppRepository().getOrCreateGuestSessionId();
      result = await AppRepository().transferGuestData(
        fromGuestId: guestSessionId,
        toUserId: existingUser.id,
      );
    }
    _user = existingUser;
    notifyListeners();
    return result;
  }

  /// Đăng xuất tài khoản
  /// Tuân thủ Quy tắc 6: Không để phiên khách sau đó truy cập dữ liệu riêng của tài khoản vừa đăng xuất.
  /// Tự động reset guestSessionId để phiên khách tiếp theo được hoàn toàn cô lập.
  void logout() {
    _user = const UserProfile(
      id: 'guest_user',
      displayName: 'Khách',
      isLoggedIn: false,
      authProvider: 'guest',
      streakDays: 0,
      xp: 0,
    );
    AppRepository().resetGuestSessionId();
    notifyListeners();
  }
}
