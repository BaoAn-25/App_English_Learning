class MinimalPairQuestion {
  final String id;
  final String soundAId;
  final String soundBId;
  final String wordA;
  final String ipaA;
  final String meaningA;
  final String wordB;
  final String ipaB;
  final String meaningB;
  final int difficulty;

  const MinimalPairQuestion({
    required this.id,
    required this.soundAId,
    required this.soundBId,
    required this.wordA,
    required this.ipaA,
    required this.meaningA,
    required this.wordB,
    required this.ipaB,
    required this.meaningB,
    this.difficulty = 1,
  });

  factory MinimalPairQuestion.fromMap(Map<String, dynamic> map) {
    return MinimalPairQuestion(
      id: map['id'] as String,
      soundAId: map['soundAId'] as String,
      soundBId: map['soundBId'] as String,
      wordA: map['wordA'] as String,
      ipaA: map['ipaA'] as String,
      meaningA: map['meaningA'] as String? ?? '',
      wordB: map['wordB'] as String,
      ipaB: map['ipaB'] as String,
      meaningB: map['meaningB'] as String? ?? '',
      difficulty: (map['difficulty'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'soundAId': soundAId,
      'soundBId': soundBId,
      'wordA': wordA,
      'ipaA': ipaA,
      'meaningA': meaningA,
      'wordB': wordB,
      'ipaB': ipaB,
      'meaningB': meaningB,
      'difficulty': difficulty,
    };
  }
}
