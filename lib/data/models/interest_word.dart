class InterestWord {
  final String id;
  final String topicId;
  final String english;
  final String ipa;
  final String meaningVi;
  final String exampleEn;
  final String exampleVi;
  final String category; // 'word' (từ vựng) hoặc 'phrase' (câu đàm thoại Guidebook)
  final int order;

  const InterestWord({
    required this.id,
    required this.topicId,
    required this.english,
    required this.ipa,
    required this.meaningVi,
    required this.exampleEn,
    required this.exampleVi,
    this.category = 'word',
    required this.order,
  });

  bool get isPhrase => category == 'phrase';

  factory InterestWord.fromMap(Map<String, dynamic> map) {
    return InterestWord(
      id: map['id'] as String,
      topicId: map['topicId'] as String,
      english: map['english'] as String,
      ipa: map['ipa'] as String? ?? '',
      meaningVi: map['meaningVi'] as String,
      exampleEn: map['exampleEn'] as String? ?? '',
      exampleVi: map['exampleVi'] as String? ?? '',
      category: map['category'] as String? ?? 'word',
      order: (map['order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'topicId': topicId,
      'english': english,
      'ipa': ipa,
      'meaningVi': meaningVi,
      'exampleEn': exampleEn,
      'exampleVi': exampleVi,
      'category': category,
      'order': order,
    };
  }
}

