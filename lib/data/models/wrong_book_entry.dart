class WrongBookEntry {
  final String questionId;
  final int wrongCount;
  final int lastWrongAt;
  final int nextReviewAt;

  const WrongBookEntry({
    required this.questionId,
    required this.wrongCount,
    required this.lastWrongAt,
    required this.nextReviewAt,
  });

  factory WrongBookEntry.fromMap(Map<String, dynamic> map) {
    return WrongBookEntry(
      questionId: map['questionId'] as String,
      wrongCount: (map['wrongCount'] as num).toInt(),
      lastWrongAt: (map['lastWrongAt'] as num).toInt(),
      nextReviewAt: (map['nextReviewAt'] as num).toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'questionId': questionId,
      'wrongCount': wrongCount,
      'lastWrongAt': lastWrongAt,
      'nextReviewAt': nextReviewAt,
    };
  }
}
