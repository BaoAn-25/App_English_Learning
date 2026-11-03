class IpaSound {
  final String id;
  final String symbol; // Ví dụ: /iː/, /æ/, /b/
  final String type; // 'vowel' (nguyên âm đơn), 'diphthong' (nguyên âm đôi), 'consonant' (phụ âm)
  final String name; // Tên âm: Long E, Short A, Voiced B...
  final String exampleWord; // Từ ví dụ: sheep, cat, book
  final String exampleIpa; // Phiên âm từ ví dụ: /ʃiːp/, /kæt/
  final String exampleMeaning; // Nghĩa từ: con cừu, con mèo
  final String? audioFile;
  final int order;
  final int masteryLevel; // 0 - 100% độ thuần thục

  const IpaSound({
    required this.id,
    required this.symbol,
    required this.type,
    required this.name,
    required this.exampleWord,
    required this.exampleIpa,
    required this.exampleMeaning,
    this.audioFile,
    required this.order,
    this.masteryLevel = 0,
  });

  bool get isVowel => type == 'vowel';
  bool get isDiphthong => type == 'diphthong';
  bool get isConsonant => type == 'consonant';

  factory IpaSound.fromMap(Map<String, dynamic> map, {int mastery = 0}) {
    return IpaSound(
      id: map['id'] as String,
      symbol: map['symbol'] as String,
      type: map['type'] as String,
      name: map['name'] as String? ?? '',
      exampleWord: map['exampleWord'] as String,
      exampleIpa: map['exampleIpa'] as String? ?? '',
      exampleMeaning: map['exampleMeaning'] as String? ?? '',
      audioFile: map['audioFile'] as String?,
      order: (map['order'] as num?)?.toInt() ?? 0,
      masteryLevel: mastery,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'symbol': symbol,
      'type': type,
      'name': name,
      'exampleWord': exampleWord,
      'exampleIpa': exampleIpa,
      'exampleMeaning': exampleMeaning,
      'audioFile': audioFile,
      'order': order,
    };
  }

  IpaSound copyWith({
    int? masteryLevel,
  }) {
    return IpaSound(
      id: id,
      symbol: symbol,
      type: type,
      name: name,
      exampleWord: exampleWord,
      exampleIpa: exampleIpa,
      exampleMeaning: exampleMeaning,
      audioFile: audioFile,
      order: order,
      masteryLevel: masteryLevel ?? this.masteryLevel,
    );
  }
}
