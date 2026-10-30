class ProfileValidation {
  static String? nameError(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Vui lòng nhập họ tên.';
    if (name.runes.length > 100) return 'Họ tên tối đa 100 ký tự.';
    return null;
  }

  static String? scoreError(String? value) {
    final score = double.tryParse(value?.trim() ?? '');
    if (score == null || !score.isFinite || score < 0 || score > 10) {
      return 'Điểm mục tiêu phải từ 0 đến 10.';
    }
    return null;
  }
}
