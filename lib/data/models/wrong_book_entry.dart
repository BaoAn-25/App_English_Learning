class WrongBookEntry {
  final String questionId;
  final String? ownerId;
  final int wrongCount;
  final int lastWrongAt;
  final int nextReviewAt;

  const WrongBookEntry({
    required this.questionId,
    this.ownerId,
    required this.wrongCount,
    required this.lastWrongAt,
    required this.nextReviewAt,
  });

  factory WrongBookEntry.fromMap(Map<String, dynamic> map) {
    return WrongBookEntry(
      questionId: map['questionId'] as String,
      ownerId: map['ownerId'] as String?,
      wrongCount: (map['wrongCount'] as num).toInt(),
      lastWrongAt: (map['lastWrongAt'] as num).toInt(),
      nextReviewAt: (map['nextReviewAt'] as num).toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'questionId': questionId,
      'wrongCount': wrongCount,
      'lastWrongAt': lastWrongAt,
      'nextReviewAt': nextReviewAt,
    };
    if (ownerId != null && ownerId!.isNotEmpty) {
      map['ownerId'] = ownerId;
    }
    return map;
  }
}
