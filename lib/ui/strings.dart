/// Tập trung chuỗi tiếng Việt cho ứng dụng, đảm bảo tính nhất quán và dễ mở rộng.
class AppStrings {
  AppStrings._();

  // App & Navigation
  static const appName = 'Luyện Thi Tiếng Anh THPT';
  static const tabHome = 'Trang chủ';
  static const tabLearn = 'Học';
  static const tabPractice = 'Luyện đề';
  static const tabStats = 'Thống kê';
  static const tabSettings = 'Cá nhân';

  // Common Actions & States
  static const retry = 'Thử lại';
  static const cancel = 'Hủy';
  static const save = 'Lưu thay đổi';
  static const close = 'Đóng';
  static const loading = 'Đang tải...';
  static const emptyData = 'Chưa có dữ liệu';
  static const success = 'Thành công';
  static const error = 'Đã có lỗi xảy ra';

  // Offline & Sync Status
  static const syncStatusSyncing = 'Đang đồng bộ...';
  static const syncStatusSynced = 'Đã đồng bộ';
  static const syncStatusOffline = 'Lưu trên thiết bị';
  static const syncStatusError = 'Lỗi đồng bộ';
  static const syncNow = 'Đồng bộ ngay';
  static const lastSyncedAt = 'Đồng bộ lần cuối:';
  static const offlineModeNotice = 'Dữ liệu luôn được lưu an toàn trên máy của bạn.';

  // Home Screen
  static const greeting = 'Chào bạn!';
  static const streakTitle = 'Chuỗi ngày học';
  static const xpLabel = 'XP';
  static const levelLabel = 'Cấp {level}';
  static const dailyGoalTitle = 'Mục tiêu hôm nay';
  static const todayPlan = 'Kế hoạch hôm nay';
  static const continueLearning = 'Tiếp tục luyện tập';
  static const roadmapTitle = 'Lộ trình chuyên đề lớp 12';
  static const lockedTopic = 'Hoàn thành bài trước để mở khóa';
  static const completedTopic = 'Đã hoàn thành';
  static const startTopic = 'Bắt đầu ngay';
  static const questionsDoneUnit = 'câu';

  // Stats Screen
  static const statsTitle = 'Thống kê tiến độ';
  static const statsRange7Days = '7 ngày qua';
  static const statsRange30Days = '30 ngày qua';
  static const totalQuestions = 'Tổng số câu';
  static const accuracyRate = 'Tỷ lệ đúng';
  static const totalTime = 'Tổng thời gian';
  static const minutesUnit = 'phút';
  static const performanceByType = 'Kết quả theo 8 dạng bài thi';
  static const weakestTypeAlert = 'Dạng cần lưu ý';
  static const recommendPractice = 'Gợi ý luyện tập ngay dạng này để cải thiện điểm số';
  static const practiceNow = 'Luyện ngay';

  // 8 dạng câu hỏi THPT
  static const typeVocab = 'Từ vựng';
  static const typeGrammar = 'Ngữ pháp';
  static const typeSynonymAntonym = 'Đồng/trái nghĩa';
  static const typeCommunication = 'Giao tiếp';
  static const typeSigns = 'Biển báo';
  static const typeArrange = 'Sắp xếp câu';
  static const typeCloze = 'Điền từ';
  static const typeReading = 'Đọc hiểu';

  static String questionTypeName(String type) {
    switch (type.toLowerCase()) {
      case 'vocab':
        return typeVocab;
      case 'grammar':
        return typeGrammar;
      case 'synonym_antonym':
        return typeSynonymAntonym;
      case 'communication':
        return typeCommunication;
      case 'signs':
        return typeSigns;
      case 'arrange':
        return typeArrange;
      case 'cloze':
        return typeCloze;
      case 'reading':
        return typeReading;
      default:
        return type;
    }
  }

  // Settings Screen
  static const settingsTitle = 'Cài đặt & Cá nhân';
  static const profileSection = 'Hồ sơ học sinh';
  static const fullName = 'Họ và tên';
  static const studentGrade = 'Lớp';
  static const targetScore = 'Mục tiêu điểm thi THPT';
  static const dailyTargetSection = 'Mục tiêu luyện tập mỗi ngày';
  static const questionsPerDay = 'câu / ngày';
  static const reminderSection = 'Nhắc nhở học tập';
  static const enableDailyReminder = 'Bật nhắc nhở hằng ngày';
  static const reminderTime = 'Giờ nhắc';
  static const reminderNotificationTitle = 'Đã đến giờ ôn luyện tiếng Anh!';
  static const reminderNotificationBody = 'Dành ít phút hôm nay để hoàn thành mục tiêu học tập bạn nhé!';
  static const appearanceSection = 'Giao diện';
  static const themeSystem = 'Theo hệ thống';
  static const themeLight = 'Giao diện sáng';
  static const themeDark = 'Giao diện tối';
  static const appInfoSection = 'Thông tin ứng dụng';
  static const appVersion = 'Phiên bản 1.0.0 (THPT 2026)';
  static const logout = 'Đăng xuất tài khoản';
  static const confirmLogout = 'Bạn có chắc chắn muốn đăng xuất?';
}
