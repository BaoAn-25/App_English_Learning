/// Model lưu tiến độ học từng từ (SRS – Spaced Repetition System)
class WordProgress {
  final String wordId;

  /// Số lần đã ôn thành công
  final int reviewCount;

  /// Số lần nhớ đúng liên tiếp
  final int streak;

  /// Timestamp lần ôn tiếp theo (milliseconds since epoch)
  final int nextReviewAt;

  /// Timestamp lần ôn gần nhất
  final int lastReviewedAt;

  const WordProgress({
    required this.wordId,
    this.reviewCount = 0,
    this.streak = 0,
    required this.nextReviewAt,
    required this.lastReviewedAt,
  });



  /// Trả về WordProgress mới sau khi người dùng ôn đúng:
  /// Hộp ôn từ đơn giản - Nhớ thì ôn lại sau 3 ngày
  WordProgress afterCorrect() {
    final newStreak = streak + 1;
    final now = DateTime.now().millisecondsSinceEpoch;
    return WordProgress(
      wordId: wordId,
      reviewCount: reviewCount + 1,
      streak: newStreak,
      lastReviewedAt: now,
      nextReviewAt: now + const Duration(days: 3).inMilliseconds,
    );
  }

  /// Trả về WordProgress mới sau khi người dùng ôn sai:
  /// Hộp ôn từ đơn giản - Chưa nhớ thì ôn lại ngày mai (sau 1 ngày)
  WordProgress afterWrong() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return WordProgress(
      wordId: wordId,
      reviewCount: reviewCount + 1,
      streak: 0,
      lastReviewedAt: now,
      nextReviewAt: now + const Duration(days: 1).inMilliseconds,
    );
  }

  /// Kiểm tra đã đến giờ ôn chưa
  bool get isDue => DateTime.now().millisecondsSinceEpoch >= nextReviewAt;

  /// Đã học (đã ôn ít nhất 1 lần)
  bool get isLearned => reviewCount > 0;

  /// Đã thành thạo (streak >= 4)
  bool get isMastered => streak >= 4;

  Map<String, dynamic> toMap() => {
        'wordId': wordId,
        'reviewCount': reviewCount,
        'streak': streak,
        'nextReviewAt': nextReviewAt,
        'lastReviewedAt': lastReviewedAt,
      };

  factory WordProgress.fromMap(Map<String, dynamic> m) => WordProgress(
        wordId: m['wordId'] as String,
        reviewCount: (m['reviewCount'] as num).toInt(),
        streak: (m['streak'] as num).toInt(),
        nextReviewAt: (m['nextReviewAt'] as num).toInt(),
        lastReviewedAt: (m['lastReviewedAt'] as num).toInt(),
      );

  /// Tạo tiến độ mới cho từ chưa học
  factory WordProgress.newWord(String wordId) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return WordProgress(
      wordId: wordId,
      reviewCount: 0,
      streak: 0,
      nextReviewAt: now,
      lastReviewedAt: now,
    );
  }
}
