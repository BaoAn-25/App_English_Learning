/// Trạng thái phân loại năng lực của học sinh cho một dạng bài
enum AdaptiveSkillLevel {
  /// Chưa có đủ dữ liệu / số lượng câu hỏi đã làm quá ít để đưa ra đánh giá tin cậy
  insufficientData,

  /// Năng lực còn yếu, tỷ lệ làm sai cao, cần ưu tiên ôn luyện
  weak,

  /// Năng lực ở mức trung bình, đang trong quá trình phát triển
  moderate,

  /// Năng lực vững chắc, tỷ lệ chính xác cao và số lượng mẫu đủ tin cậy
  strong,
}

/// Thống kê và đánh giá năng lực chi tiết của một dạng bài cụ thể
class AdaptiveSkillProfile {
  /// Mã dạng bài (ví dụ: 'grammar', 'reading', ...)
  final String type;

  /// Tên tiếng Việt hiển thị của dạng bài
  final String typeTitle;

  /// Tổng số lượt làm câu hỏi thuộc dạng này (kể cả câu lặp lại)
  final int totalAttempts;

  /// Tổng số lượt trả lời đúng
  final int totalCorrect;

  /// Tổng số lượt trả lời sai
  final int totalWrong;

  /// Tổng số lượt bỏ trống (chosenIndex < 0 hoặc null)
  final int totalUnanswered;

  /// Số lượng câu hỏi duy nhất (distinct questionId) học sinh đã gặp
  final int uniqueQuestionsSeen;

  /// Tỷ lệ trả lời đúng thô (%), tính trên tổng số lượt làm: (totalCorrect / totalAttempts) * 100
  /// Bằng 0.0 nếu chưa từng làm câu nào
  final double rawAccuracy;

  /// Chỉ số độ đủ mẫu / độ tin cậy heuristic (0.0 đến 1.0)
  /// Phản ánh mức độ đầy đủ của dữ liệu câu hỏi đã làm so với ngưỡng mục tiêu
  final double confidence;

  /// Điểm thành thạo ước tính (0.0 đến 100.0)
  /// Được làm mượt theo mô hình Bayesian kết hợp trọng số thời gian, độ khó và kiểm soát câu lặp
  final double masteryScore;

  /// Phân loại cấp độ năng lực
  final AdaptiveSkillLevel level;

  /// Mức độ ưu tiên luyện tập (càng cao càng cần được ưu tiên đề xuất)
  final double practicePriority;

  /// Đánh giá xu hướng tiến bộ: true nếu phong độ gần đây tốt hơn trung bình lịch sử cũ
  final bool isImproving;

  /// Số lượng câu hỏi của dạng bài này hiện đang có trong sổ câu sai
  final int wrongBookCount;

  const AdaptiveSkillProfile({
    required this.type,
    required this.typeTitle,
    required this.totalAttempts,
    required this.totalCorrect,
    required this.totalWrong,
    required this.totalUnanswered,
    required this.uniqueQuestionsSeen,
    required this.rawAccuracy,
    required this.confidence,
    required this.masteryScore,
    required this.level,
    required this.practicePriority,
    required this.isImproving,
    this.wrongBookCount = 0,
  });

  /// Kiểm tra xem dạng bài có đủ dữ liệu đáng tin cậy hay chưa
  bool get hasSufficientData => level != AdaptiveSkillLevel.insufficientData;

  @override
  String toString() =>
      'AdaptiveSkillProfile($type: mastery=${masteryScore.toStringAsFixed(1)}, '
      'conf=${confidence.toStringAsFixed(2)}, level=${level.name}, priority=${practicePriority.toStringAsFixed(1)})';
}

/// Hồ sơ năng lực tổng thể của học sinh bao gồm đầy đủ 8 dạng bài THPT
class AdaptiveStudentProfile {
  /// Danh sách đánh giá của 8 dạng bài chuẩn
  final List<AdaptiveSkillProfile> skills;

  /// Dạng bài yếu nhất cần ưu tiên cải thiện hàng đầu (nếu có)
  final AdaptiveSkillProfile? primaryWeakness;

  /// Dạng bài mạnh nhất hiện tại (nếu có)
  final AdaptiveSkillProfile? primaryStrength;

  /// Danh sách các dạng bài chưa đủ dữ liệu để đánh giá
  final List<AdaptiveSkillProfile> unassessedSkills;

  /// Điểm thành thạo tổng hợp toàn diện (0.0 đến 100.0)
  final double overallMastery;

  /// Tổng số câu hỏi học sinh đã làm qua mọi dạng bài
  final int totalQuestionsDone;

  /// Thời điểm tham chiếu tính toán hồ sơ
  final DateTime evaluatedAt;

  const AdaptiveStudentProfile({
    required this.skills,
    required this.primaryWeakness,
    required this.primaryStrength,
    required this.unassessedSkills,
    required this.overallMastery,
    required this.totalQuestionsDone,
    required this.evaluatedAt,
  });

  /// Tìm hồ sơ của một dạng bài cụ thể theo mã type
  AdaptiveSkillProfile? findSkill(String type) {
    try {
      return skills.firstWhere((s) => s.type == type);
    } catch (_) {
      return null;
    }
  }

  /// Kiểm tra xem học sinh có dữ liệu làm bài nào chưa
  bool get hasAnyHistory => totalQuestionsDone > 0;
}
