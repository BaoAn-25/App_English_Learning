import '../../../data/models/question.dart';

/// Phân loại mục đích của nhiệm vụ học tập thích ứng
enum AdaptiveTaskType {
  /// Ôn luyện và khắc phục dạng bài yếu nhất
  weaknessRemediation,

  /// Khảo sát và đánh giá ban đầu chuyên đề chưa có đủ dữ liệu
  surveyUnassessed,

  /// Củng cố và nâng cao chuyên đề ở mức trung bình
  skillReinforcement,

  /// Ôn tập lại các câu hỏi đã từng trả lời sai trong Sổ câu sai
  wrongBookReview,

  /// Duy trì phản xạ và phong độ cho chuyên đề đã vững chắc
  masteryMaintenance,

  /// Bài kiểm tra tổng hợp phản xạ nhanh (mô phỏng rút gọn đề THPT)
  comprehensiveCheck,
}

/// Mô hình một nhiệm vụ học tập thích ứng độc lập (Adaptive Task)
///
/// Hoàn toàn độc lập với Flutter UI (không chứa IconData, Color)
class AdaptiveTask {
  /// Mã định danh ổn định của nhiệm vụ (ví dụ: 'task_weakness_grammar')
  final String id;

  /// Loại nhiệm vụ
  final AdaptiveTaskType type;

  /// Mã dạng câu hỏi mục tiêu (ví dụ: 'grammar', 'reading', hoặc 'mixed' nếu là bài kiểm tra tổng hợp)
  final String targetType;

  /// Tiêu đề hiển thị ngắn gọn bằng tiếng Việt
  final String title;

  /// Mô tả ngắn về nội dung nhiệm vụ
  final String subtitle;

  /// Lời giải thích lý do hệ thống đề xuất nhiệm vụ này
  final String reasoning;

  /// Danh sách câu hỏi cụ thể đã được chọn sẵn cho nhiệm vụ
  final List<Question> questions;

  /// Thứ tự ưu tiên thực hiện (1: Ưu tiên cao nhất, 2: Ưu tiên nhì, 3: Ưu tiên ba)
  final int priorityOrder;

  const AdaptiveTask({
    required this.id,
    required this.type,
    required this.targetType,
    required this.title,
    required this.subtitle,
    required this.reasoning,
    required this.questions,
    required this.priorityOrder,
  });

  /// Số lượng câu hỏi thực tế của nhiệm vụ
  int get questionCount => questions.length;

  /// Nhiệm vụ có câu hỏi hợp lệ để thực hiện hay không
  bool get isValid => questions.isNotEmpty;

  @override
  String toString() =>
      'AdaptiveTask(id: $id, type: ${type.name}, target: $targetType, count: $questionCount, priority: $priorityOrder)';
}

/// Kế hoạch học tập cá nhân hóa được sinh ra cho học sinh
class AdaptiveLearningPlan {
  /// Mã định danh duy nhất của kế hoạch
  final String id;

  /// Thời điểm kế hoạch được sinh
  final DateTime generatedAt;

  /// Danh sách các nhiệm vụ được đề xuất (tối đa 3 nhiệm vụ, được sắp xếp theo thứ tự ưu tiên)
  final List<AdaptiveTask> tasks;

  const AdaptiveLearningPlan({
    required this.id,
    required this.generatedAt,
    required this.tasks,
  });

  /// Nhiệm vụ ưu tiên hàng đầu cần thực hiện ngay
  AdaptiveTask? get primaryTask => tasks.isNotEmpty ? tasks.first : null;

  /// Tổng số câu hỏi trong toàn bộ kế hoạch hôm nay
  int get totalQuestions =>
      tasks.fold(0, (sum, task) => sum + task.questionCount);

  /// Kiểm tra xem kế hoạch có nhiệm vụ nào khả dụng hay không
  bool get hasTasks => tasks.isNotEmpty;

  @override
  String toString() =>
      'AdaptiveLearningPlan(id: $id, tasks: ${tasks.length}, totalQ: $totalQuestions, time: $generatedAt)';
}

/// Kết quả của thao tác chọn câu hỏi thích ứng từ ngân hàng đề
class AdaptiveQuestionSelectionResult {
  /// Danh sách câu hỏi được chọn theo đúng thứ tự làm bài
  final List<Question> questions;

  /// Số lượng câu hỏi được yêu cầu ban đầu
  final int requestedCount;

  /// Số câu hỏi chưa từng làm (unseen) trong danh sách được chọn
  final int unseenCount;

  /// Số câu hỏi cũ được tái sử dụng từ lịch sử
  final int recycledCount;

  /// Cụm bài đọc (passage) có được bảo toàn trọn vẹn hay không
  final bool isPassagePreserved;

  const AdaptiveQuestionSelectionResult({
    required this.questions,
    required this.requestedCount,
    required this.unseenCount,
    required this.recycledCount,
    required this.isPassagePreserved,
  });

  /// Số lượng câu hỏi thực tế được chọn
  int get actualCount => questions.length;

  /// Số câu thừa hoặc thiếu so với yêu cầu ban đầu (do bảo toàn passage hoặc thiếu câu)
  int get countDifference => actualCount - requestedCount;
}
