/// Model câu hỏi đọc hiểu học thử chuẩn SGK Tiếng Anh 12 Global Success trang 14
class TrialQuestion {
  final String id;
  final String word;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const TrialQuestion({
    required this.id,
    required this.word,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });
}

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

  /// ID định danh bài học thử thống nhất trong toàn app
  static const String trialLessonId = 'trial_unit1_reading';

  /// Số Unit dùng để học thử
  static const int trialUnitNumber = 1;

  /// Tiêu đề Unit
  static const String trialUnitTitle = 'Life Stories We Admire';

  /// Phần bài học dùng để học thử
  static const String trialSection = 'Reading';

  /// Tiêu đề bài đọc học thử chuẩn SGK trang 13-14
  static const String trialArticleTitle = 'Steve Jobs: Life and Achievements';

  /// Đoạn văn chuẩn SGK Tiếng Anh 12 Unit 1 trang 13-14
  static const String paragraphA =
      "Steven Paul Jobs was born on 24 February, 1955 in San Francisco, USA. His biological parents were not married and gave him up for adoption. He was adopted by Clara and Paul Jobs. In 1971, Jobs met Steve Wozniak, who was five years older than him, but they bonded over their love of electronics. After high school, Jobs attended Reed College in Oregon, but found the classes boring and dropped out after six months.";

  static const String paragraphB =
      "When Jobs was 21, he and Wozniak started Apple Computers in Jobs' family garage with money they got by selling Jobs' van and Wozniak's scientific calculator. By making computers smaller, cheaper, and accessible to everyday users, their company became a huge success and sales quickly increased. Although Jobs left Apple in 1985, he returned to his post in 1997 when the company needed new ideas. He helped invent new products such as the iMac, the iBook for students, the iPod music player, and iTunes music software. In 2007, he introduced the touch-screen iPhone which changed the way phones were used. Apple products were not only designed to be cutting-edge technology, but also to be stylish and easy to use. In addition, Jobs contributed to computer animation. In 1986, he bought a small company, which later became Pixar Animation Studios. It produced the first full-length computer-animated film Toy Story, followed by other blockbusters.";

  static const String paragraphC =
      "In 2003, Jobs was diagnosed with a rare form of pancreatic cancer. He fought the disease for several years, and stopped working in August, 2011. Two months later, he passed away. He had four children, three with his wife of 20 years and one from a previous relationship. On an Apple web page, a statement reads, 'Apple has lost a visionary and creative genius, and the world has lost an amazing human being.'";

  /// 5 câu hỏi trắc nghiệm Activity 2 chuẩn SGK Tiếng Anh 12 Unit 1 trang 14
  static const List<TrialQuestion> unit1Questions = [
    TrialQuestion(
      id: 'u1_rd_q1',
      word: '1. adopted (SGK trang 14)',
      options: [
        'A. given birth to',
        'B. taken by another family as their own child',
      ],
      correctIndex: 1,
      explanation:
          'Đoạn A: "His biological parents were not married and gave him up for adoption. He was adopted by Clara and Paul Jobs." -> Được nhận làm con nuôi bởi gia đình khác.',
    ),
    TrialQuestion(
      id: 'u1_rd_q2',
      word: '2. dropped out (SGK trang 14)',
      options: [
        'A. continued to study',
        'B. left school/college before completing your studies',
      ],
      correctIndex: 1,
      explanation:
          'Đoạn A: "Jobs attended Reed College in Oregon, but found the classes boring and dropped out after six months." -> Nghỉ học trước khi tốt nghiệp.',
    ),
    TrialQuestion(
      id: 'u1_rd_q3',
      word: '3. cancer (SGK trang 14)',
      options: [
        'A. a serious disease',
        'B. a dangerous animal',
      ],
      correctIndex: 0,
      explanation:
          'Đoạn C: "In 2003, Jobs was diagnosed with a rare form of pancreatic cancer. He fought the disease for several years..." -> Bệnh hiểm nghèo (ung thư tuyến tụy).',
    ),
    TrialQuestion(
      id: 'u1_rd_q4',
      word: '4. passed away (SGK trang 14)',
      options: [
        'A. died',
        'B. went past something',
      ],
      correctIndex: 0,
      explanation:
          'Đoạn C: "He stopped working in August, 2011. Two months later, he passed away." -> Qua đời, mất (cách nói trang trọng thay cho "died").',
    ),
    TrialQuestion(
      id: 'u1_rd_q5',
      word: '5. genius (SGK trang 14)',
      options: [
        'A. a very intelligent person',
        'B. an ordinary person',
      ],
      correctIndex: 0,
      explanation:
          'Đoạn C: "\'Apple has lost a visionary and creative genius...\'" -> Người xuất chúng, thiên tài.',
    ),
  ];

  /// Từ điển tra cứu nhanh các từ in đậm trong bài đọc SGK
  static const Map<String, String> keyVocabulary = {
    'adopted': 'được nhận làm con nuôi',
    'dropped out': 'bỏ học giữa chừng',
    'electronics': 'thiết bị điện tử',
    'garage': 'nhà để xe',
    'accessible': 'dễ tiếp cận, dễ sử dụng',
    'cutting-edge': 'tiên tiến, hiện đại nhất',
    'animation': 'hoạt hình máy tính (Pixar)',
    'cancer': 'bệnh ung thư (tuyến tụy)',
    'passed away': 'qua đời, mất',
    'genius': 'người xuất chúng, thiên tài',
  };

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
