class Word {
  final String id;
  final String topicId;
  final int grade;
  final String english;
  final String ipa;
  final String meaningVi;
  final String example;

  const Word({
    required this.id,
    required this.topicId,
    required this.grade,
    required this.english,
    required this.ipa,
    required this.meaningVi,
    required this.example,
  });

  factory Word.fromMap(Map<String, dynamic> map) {
    return Word(
      id: map['id'] as String,
      topicId: map['topicId'] as String,
      grade: (map['grade'] as num).toInt(),
      english: map['english'] as String,
      ipa: map['ipa'] as String,
      meaningVi: map['meaningVi'] as String,
      example: map['example'] as String,
    );
  }

  Word copyWith({
    String? id,
    String? topicId,
    int? grade,
    String? english,
    String? ipa,
    String? meaningVi,
    String? example,
  }) {
    return Word(
      id: id ?? this.id,
      topicId: topicId ?? this.topicId,
      grade: grade ?? this.grade,
      english: english ?? this.english,
      ipa: ipa ?? this.ipa,
      meaningVi: meaningVi ?? this.meaningVi,
      example: example ?? this.example,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'topicId': topicId,
      'grade': grade,
      'english': english,
      'ipa': ipa,
      'meaningVi': meaningVi,
      'example': example,
    };
  }
}
