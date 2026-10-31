import 'package:flutter/material.dart';
import '../../data/models/user_profile.dart';

class AuthController extends ChangeNotifier {
  static final AuthController instance = AuthController._internal();
  factory AuthController() => instance;
  AuthController._internal();

  UserProfile _user = const UserProfile();
  bool _isLoading = false;
  String? _errorMessage;

  UserProfile get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user.isLoggedIn;

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

    // Giả lập network delay ngắn tạo cảm giác tương tác thật
    await Future.delayed(const Duration(milliseconds: 500));

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

    _user = _user.copyWith(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      displayName: name.isNotEmpty ? name : 'Học sinh English 12',
      email: email,
      isLoggedIn: true,
      authProvider: 'email',
    );

    _isLoading = false;
    notifyListeners();
    return true;
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 500));

    if (email.isEmpty || password.isEmpty) {
      _errorMessage = 'Vui lòng nhập email và mật khẩu';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    _user = _user.copyWith(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      displayName: email.split('@').first,
      email: email,
      isLoggedIn: true,
      authProvider: 'email',
    );

    _isLoading = false;
    notifyListeners();
    return true;
  }

  Future<bool> loginWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 600));

    _user = _user.copyWith(
      id: 'google_1092837465',
      displayName: 'Minh Anh (Google)',
      email: 'minhanh.thpt12@gmail.com',
      avatarUrl: 'https://lh3.googleusercontent.com/a/default-user',
      isLoggedIn: true,
      authProvider: 'google',
    );

    _isLoading = false;
    notifyListeners();
    return true;
  }

  void logout() {
    _user = const UserProfile(
      isLoggedIn: false,
      authProvider: 'guest',
    );
    notifyListeners();
  }
}

