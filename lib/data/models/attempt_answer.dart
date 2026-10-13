class AttemptAnswer {
  final int attemptId;
  final String questionId;
  final int chosenIndex;
  final bool isCorrect;

  const AttemptAnswer({
    required this.attemptId,
    required this.questionId,
    required this.chosenIndex,
    required this.isCorrect,
  });

  factory AttemptAnswer.fromMap(Map<String, dynamic> map) {
    final rawIsCorrect = map['isCorrect'];
    final bool parsedIsCorrect;
    if (rawIsCorrect is bool) {
      parsedIsCorrect = rawIsCorrect;
    } else if (rawIsCorrect is num) {
      parsedIsCorrect = rawIsCorrect == 1;
    } else {
      parsedIsCorrect = false;
    }

    return AttemptAnswer(
      attemptId: (map['attemptId'] as num).toInt(),
      questionId: map['questionId'] as String,
      chosenIndex: (map['chosenIndex'] as num).toInt(),
      isCorrect: parsedIsCorrect,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'attemptId': attemptId,
      'questionId': questionId,
      'chosenIndex': chosenIndex,
      'isCorrect': isCorrect ? 1 : 0,
    };
  }
}
