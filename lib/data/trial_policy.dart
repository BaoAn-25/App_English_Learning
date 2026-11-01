/// Chính sách học thử tập trung của ứng dụng Tiếng Anh 12 Global Success.
///
/// Khách mới có thể học thử bài đọc tương tác Unit 1 Reading ("Steve Jobs: Life and Achievements"),
/// tra cứu từ điển tương tác, làm bài kiểm tra đọc hiểu thật với 5 câu hỏi Activity 2 theo SGK,
/// xem điểm số và giải thích đáp án thực tế.
///
/// Dữ liệu học thử được lưu trên thiết bị với mã phiên khách [guestSessionId] và sẽ được
/// chuyển giao trọn vẹn sang tài khoản học viên khi đăng ký thành công.
class TrialPolicy {
  TrialPolicy._();

  /// Số Unit dùng để học thử
  static const int trialUnitNumber = 1;

  /// Phần bài học dùng để học thử
  static const String trialSection = 'Reading';

  /// Tiêu đề bài đọc học thử chuẩn SGK trang 13-14
  static const String trialArticleTitle = 'Steve Jobs: Life and Achievements';

  /// Kiểm tra xem nội dung có nằm trong phạm vi học thử có chấm điểm hay không
  static bool isTrialContent({
    required int unitNumber,
    required String sectionTitle,
  }) {
    return unitNumber == trialUnitNumber &&
        sectionTitle.trim().toLowerCase() == trialSection.toLowerCase();
  }

  /// Thông điệp giải thích lợi ích tài khoản khi người dùng muốn học nội dung ngoài phạm vi thử
  static const String accountBenefitsExplanation =
      'Bạn đang học thử nội dung Unit 1. Đăng ký tài khoản miễn phí để:\n'
      '• Lưu toàn bộ kết quả, điểm số và sổ câu sai đã làm.\n'
      '• Mở khóa lộ trình học và bài tập tương tác cho toàn bộ 10 Unit.\n'
      '• Đồng bộ tiến độ khi kết nối hệ thống máy chủ.';
}

