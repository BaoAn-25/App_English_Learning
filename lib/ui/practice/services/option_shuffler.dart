import 'dart:math';

/// Quản lý ánh xạ xáo trộn vị trí hiển thị phương án trắc nghiệm.
///
/// Mục tiêu:
/// - Xáo trộn vị trí hiển thị (A, B, C, D) để tránh hiện tượng học vẹt hoặc lệch đáp án.
/// - Mỗi câu có hoán vị ổn định trong suốt vòng đời của lượt làm bài.
/// - Lưu trữ SQLite, chấm điểm và ghi sổ câu sai luôn dùng vị trí gốc (originalIndex).
class QuestionOptionMapping {
  /// Thứ tự index gốc theo từng vị trí hiển thị (display slot).
  ///
  /// Ví dụ: [2, 0, 3, 1] nghĩa là:
  /// - Vị trí A (slot 0) hiển thị options[2]
  /// - Vị trí B (slot 1) hiển thị options[0]
  /// - Vị trí C (slot 2) hiển thị options[3]
  /// - Vị trí D (slot 3) hiển thị options[1]
  final List<int> displayToOriginal;

  const QuestionOptionMapping(this.displayToOriginal);

  /// Tạo hoán vị ngẫu nhiên cho một câu hỏi có [optionsCount] phương án.
  factory QuestionOptionMapping.shuffled(int optionsCount, {Random? random}) {
    if (optionsCount <= 1) {
      return QuestionOptionMapping(List<int>.generate(optionsCount, (i) => i));
    }
    final list = List<int>.generate(optionsCount, (i) => i);
    list.shuffle(random ?? Random());
    return QuestionOptionMapping(list);
  }

  /// Tạo ánh xạ đồng nhất (không xáo trộn, slot i == originalIndex i).
  factory QuestionOptionMapping.identity(int optionsCount) {
    return QuestionOptionMapping(List<int>.generate(optionsCount, (i) => i));
  }

  /// Số lượng phương án.
  int get length => displayToOriginal.length;

  /// Lấy index gốc tại vị trí hiển thị [slot].
  int originalIndexAt(int slot) => displayToOriginal[slot];

  /// Lấy vị trí hiển thị (0..length-1) tương ứng với index gốc [originalIndex].
  int slotOfOriginal(int originalIndex) => displayToOriginal.indexOf(originalIndex);

  /// Chữ cái hiển thị (A, B, C, D) tương ứng với index gốc [originalIndex].
  String displayLetterOfOriginal(int originalIndex) {
    final slot = slotOfOriginal(originalIndex);
    if (slot < 0 || slot >= 26) return '?';
    return String.fromCharCode(65 + slot);
  }

  /// Chữ cái hiển thị (A, B, C, D) của một vị trí hiển thị [slot].
  static String slotLetter(int slot) {
    if (slot < 0 || slot >= 26) return '?';
    return String.fromCharCode(65 + slot);
  }
}
