import 'models/question.dart';
import 'trial_lesson_repository.dart';

/// Model câu hỏi đọc hiểu học thử tương thích ngược
typedef TrialQuestion = TrialQuestionData;

/// Chính sách học thử tập trung của ứng dụng Tiếng Anh 12 Global Success.
///
/// Hỗ trợ luồng học thử mở rộng cho toàn bộ 10 Unit trong SGK:
/// - Khách có thể tự chọn bài học thử đã sẵn sàng ở bất kỳ Unit nào (không ép buộc duy nhất Unit 1).
/// - Mỗi phiên khách được hoàn thành 1 bài thử miễn phí và có thể ôn lại bài đó bất cứ lúc nào.
/// - Trước khi hoàn thành, khách có thể đổi lựa chọn bài thử khác mà không bị trộn đáp án hay mất tiến độ bài cũ.
/// - Tra cứu từ, nhận diện cụm từ và bản dịch câu/đoạn hỗ trợ hoạt động hoàn toàn ngoại tuyến.
/// - Không gán dữ liệu giả, không tự đặt isLoggedIn = true, lưu thực tế vào SQLite qua guestSessionId.
class TrialPolicy {
  TrialPolicy._();

  /// ID định danh bài học thử mặc định (Unit 1 Reading)
  static const String trialLessonId = 'trial_unit1_reading';

  /// Số Unit mặc định
  static const int trialUnitNumber = 1;

  /// Tiêu đề Unit 1
  static const String trialUnitTitle = 'Life Stories We Admire';

  /// Phần bài học dùng để học thử
  static const String trialSection = 'Reading';

  /// Tiêu đề bài đọc học thử mặc định
  static const String trialArticleTitle = 'Steve Jobs: Life and Achievements';

  /// Nguồn gốc tài liệu
  static const String textbookSourceInfo =
      'SGK Tiếng Anh 12 Global Success · Unit 1: Life Stories We Admire · Reading (Trang in 11-12)';

  /// Đoạn văn chuẩn SGK Tiếng Anh 12 Unit 1 trang in 11 (Tương thích ngược)
  static String get paragraphA =>
      TrialLessonRepository.instance.getLessonById(trialLessonId)?.paragraphs[0].text ?? '';

  static String get paragraphB =>
      TrialLessonRepository.instance.getLessonById(trialLessonId)?.paragraphs[1].text ?? '';

  static String get paragraphC =>
      TrialLessonRepository.instance.getLessonById(trialLessonId)?.paragraphs[2].text ?? '';

  /// 5 câu hỏi trắc nghiệm Activity 2 chuẩn SGK Tiếng Anh 12 Unit 1 trang in 12
  static List<TrialQuestionData> get unit1Questions =>
      TrialLessonRepository.instance.getLessonById(trialLessonId)?.questions ?? [];

  /// Danh sách câu hỏi học thử dạng Question model để lưu vào SQLite / Sổ câu sai
  static List<Question> get questionsAsStandardQuestions =>
      TrialLessonRepository.instance.getAllReadyStandardQuestions();

  /// Từ điển tra cứu nhanh các từ in đậm trong bài đọc Unit 1
  static Map<String, String> get keyVocabulary =>
      TrialLessonRepository.instance.getLessonById(trialLessonId)?.vocabulary ?? {};

  /// Kiểm tra xem một Unit và phân mục có bài học thử sẵn sàng hay không
  static bool isTrialContent({
    required int unitNumber,
    required String sectionTitle,
  }) {
    if (sectionTitle.trim().toLowerCase() != trialSection.toLowerCase()) {
      return false;
    }
    final lesson = TrialLessonRepository.instance.getLessonByUnit(unitNumber);
    return lesson != null && lesson.isReady;
  }

  /// Kiểm tra xem người học có quyền truy cập bài học thử cụ thể hay không.
  ///
  /// Chính sách học thử hiện có:
  /// 1. Tất cả các bài học thử đã có nội dung sẵn sàng (isReady == true) trong 10 Unit
  ///    đều mở cho người học (kể cả khách) trải nghiệm học tập và ôn tập.
  /// 2. Tuyệt đối không tự ý đặt giới hạn số bài học thử đối với khách khi chưa có quy định xác nhận.
  /// 3. Các bài học chưa sẵn sàng (isReady == false) không mở làm câu hỏi tương tác để đảm bảo
  ///    chất lượng học liệu chuẩn SGK, người dùng được hỗ trợ mở trực tiếp trang sách gốc.
  static bool canAccessTrialLesson({
    required String lessonId,
    bool isGuest = true,
  }) {
    final lesson = TrialLessonRepository.instance.getLessonById(lessonId);
    if (lesson == null) return false;
    return lesson.isReady;
  }

  /// Tương thích ngược: kiểm tra quyền truy cập bài học thử
  static bool canGuestAccessLesson({
    required bool isGuest,
    required String targetLessonId,
    String? completedLessonId,
  }) {
    return canAccessTrialLesson(lessonId: targetLessonId, isGuest: isGuest);
  }

  /// Thông điệp giải thích lợi ích tài khoản khi người dùng muốn mở rộng các tính năng nâng cao
  /// (đồng bộ đa thiết bị, mở khóa đầy đủ 10 Unit, lộ trình thi thử THPT toàn diện...)
  static const String accountBenefitsExplanation =
      'Đăng ký tài khoản miễn phí để:\n'
      '• Lưu toàn bộ kết quả, điểm số và sổ câu sai đã làm.\n'
      '• Mở khóa lộ trình học và bài tập tương tác cho toàn bộ 10 Unit trong SGK 12.\n'
      '• Luyện tập 8 dạng bài bám sát cấu trúc đề thi tốt nghiệp THPT mới.\n'
      '• Đồng bộ tiến độ khi kết nối hệ thống máy chủ.';
}
