class Attempt {
  final int? id;
  final String mode; // "practice" hoặc "mock"
  final String? type;
  final int startedAt; // millisecondsSinceEpoch
  final int durationSec;
  final int score;
  final int total;

  const Attempt({
    this.id,
    required this.mode,
    this.type,
    required this.startedAt,
    required this.durationSec,
    required this.score,
    required this.total,
  });

  factory Attempt.fromMap(Map<String, dynamic> map) {
    return Attempt(
      id: map['id'] as int?,
      mode: map['mode'] as String,
      type: map['type'] as String?,
      startedAt: (map['startedAt'] as num).toInt(),
      durationSec: (map['durationSec'] as num).toInt(),
      score: (map['score'] as num).toInt(),
      total: (map['total'] as num).toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'mode': mode,
      'type': type,
      'startedAt': startedAt,
      'durationSec': durationSec,
      'score': score,
      'total': total,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }
}
