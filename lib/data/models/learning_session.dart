import 'dart:convert';

/// Model lưu trạng thái bài học đang làm dở hoặc bài vừa hoàn thành
class LearningSession {
  final String ownerId;
  final String lessonId; // e.g. 'type_grammar', 'topic_12_u1'
  final String lessonTitle; // e.g. 'Ngữ pháp', 'Life Stories'
  final String lessonType; // 'question_type' | 'topic'
  final String status; // 'in_progress' | 'completed'
  final int currentQuestionIndex;
  final int totalQuestions;
  final int? score;
  final List<String> questionIds;
  final List<int?> selectedAnswers;
  final String? nextLessonId;
  final String? nextLessonTitle;
  final int updatedAt;

  LearningSession({
    required this.ownerId,
    required this.lessonId,
    required this.lessonTitle,
    this.lessonType = 'question_type',
    this.status = 'in_progress',
    required this.currentQuestionIndex,
    required this.totalQuestions,
    this.score,
    required this.questionIds,
    this.selectedAnswers = const [],
    this.nextLessonId,
    this.nextLessonTitle,
    int? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  bool get isInProgress => status == 'in_progress';
  bool get isCompleted => status == 'completed';

  LearningSession copyWith({
    String? ownerId,
    String? lessonId,
    String? lessonTitle,
    String? lessonType,
    String? status,
    int? currentQuestionIndex,
    int? totalQuestions,
    int? score,
    List<String>? questionIds,
    List<int?>? selectedAnswers,
    String? nextLessonId,
    String? nextLessonTitle,
    int? updatedAt,
  }) {
    return LearningSession(
      ownerId: ownerId ?? this.ownerId,
      lessonId: lessonId ?? this.lessonId,
      lessonTitle: lessonTitle ?? this.lessonTitle,
      lessonType: lessonType ?? this.lessonType,
      status: status ?? this.status,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      score: score ?? this.score,
      questionIds: questionIds ?? this.questionIds,
      selectedAnswers: selectedAnswers ?? this.selectedAnswers,
      nextLessonId: nextLessonId ?? this.nextLessonId,
      nextLessonTitle: nextLessonTitle ?? this.nextLessonTitle,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'lessonId': lessonId,
      'lessonTitle': lessonTitle,
      'lessonType': lessonType,
      'status': status,
      'currentQuestionIndex': currentQuestionIndex,
      'totalQuestions': totalQuestions,
      'score': score,
      'questionIds': questionIds,
      'selectedAnswers': selectedAnswers,
      'nextLessonId': nextLessonId,
      'nextLessonTitle': nextLessonTitle,
      'updatedAt': updatedAt,
    };
  }

  String toJson() => jsonEncode(toMap());

  factory LearningSession.fromMap(Map<String, dynamic> map) {
    return LearningSession(
      ownerId: map['ownerId'] as String? ?? '',
      lessonId: map['lessonId'] as String? ?? '',
      lessonTitle: map['lessonTitle'] as String? ?? '',
      lessonType: map['lessonType'] as String? ?? 'question_type',
      status: map['status'] as String? ?? 'in_progress',
      currentQuestionIndex: (map['currentQuestionIndex'] as num?)?.toInt() ?? 0,
      totalQuestions: (map['totalQuestions'] as num?)?.toInt() ?? 0,
      score: (map['score'] as num?)?.toInt(),
      questionIds: (map['questionIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      selectedAnswers: (map['selectedAnswers'] as List<dynamic>?)
              ?.map((e) => e == null ? null : (e as num).toInt())
              .toList() ??
          [],
      nextLessonId: map['nextLessonId'] as String?,
      nextLessonTitle: map['nextLessonTitle'] as String?,
      updatedAt: (map['updatedAt'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }

  factory LearningSession.fromJson(String source) =>
      LearningSession.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
