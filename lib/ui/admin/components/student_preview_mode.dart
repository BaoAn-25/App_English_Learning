import 'package:flutter/foundation.dart';

/// Quản lý trạng thái Chế độ Xem trước Giao diện Học sinh (Student Preview Mode).
/// Cho phép Quản trị viên (Admin) xem thử toàn bộ trải nghiệm học tập của học viên
/// mà không làm mất phiên làm việc quản trị.
class StudentPreviewMode extends ChangeNotifier {
  StudentPreviewMode._();
  static final StudentPreviewMode instance = StudentPreviewMode._();

  bool _isPreviewActive = false;
  bool get isPreviewActive => _isPreviewActive;

  /// Bật chế độ xem trước học viên
  void enterPreview() {
    if (_isPreviewActive) return;
    _isPreviewActive = true;
    notifyListeners();
  }

  /// Thoát chế độ xem trước, quay lại Giao diện Quản trị Admin
  void exitPreview() {
    if (!_isPreviewActive) return;
    _isPreviewActive = false;
    notifyListeners();
  }
}

