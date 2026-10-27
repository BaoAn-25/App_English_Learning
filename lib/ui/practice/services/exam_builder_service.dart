import 'dart:math';

import '../../../data/models/question.dart';

/// Kết quả ghép đề.
class ExamBuildResult {
  /// Danh sách câu hỏi theo đúng thứ tự làm bài (cụm bài đọc liền nhau).
  final List<Question> questions;

  /// Số câu được yêu cầu.
  final int requestedCount;

  /// Số câu của từng dạng bài thực tế được chọn.
  final Map<String, int> typeCounts;

  /// Số bài đọc (passage) bị cắt thành một phần (chỉ xảy ra khi bắt buộc).
  final int splitPassageCount;

  const ExamBuildResult({
    required this.questions,
    required this.requestedCount,
    required this.typeCounts,
    required this.splitPassageCount,
  });

  /// Đủ số câu yêu cầu hay chưa.
  bool get isComplete => questions.length == requestedCount;

  /// Số câu còn thiếu so với yêu cầu (0 nếu đủ).
  int get shortage => requestedCount - questions.length;
}

/// Service ghép đề thi thử / bộ câu luyện tập.
///
/// - Chọn câu theo ma trận phân bổ 8 dạng bài.
/// - Câu cùng `passageId` luôn được xếp thành cụm liên tiếp, đúng thứ tự trong bài.
/// - Ưu tiên chọn nguyên cụm; chỉ cắt cụm khi không còn cách nào khác.
/// - Không sao chép/sửa câu hỏi: options và correctIndex giữ nguyên.
class ExamBuilderService {
  /// Thứ tự các dạng bài trong đề thi.
  static const List<String> typeOrder = [
    'grammar',
    'vocab',
    'synonym_antonym',
    'communication',
    'signs',
    'arrange',
    'cloze',
    'reading',
  ];

  /// Ma trận phân bổ chuẩn cho 3 chế độ thi (tổng đúng bằng số câu).
  static const Map<int, Map<String, int>> matrices = {
    10: {
      'grammar': 2,
      'vocab': 1,
      'synonym_antonym': 1,
      'communication': 1,
      'signs': 1,
      'arrange': 1,
      'cloze': 1,
      'reading': 2,
    },
    20: {
      'grammar': 3,
      'vocab': 3,
      'synonym_antonym': 2,
      'communication': 2,
      'signs': 1,
      'arrange': 2,
      'cloze': 3,
      'reading': 4,
    },
    50: {
      'grammar': 8,
      'vocab': 6,
      'synonym_antonym': 6,
      'communication': 4,
      'signs': 4,
      'arrange': 4,
      'cloze': 8,
      'reading': 10,
    },
  };

  final Random _random;

  ExamBuilderService({Random? random}) : _random = random ?? Random();

  /// Ma trận cho [count] câu. Với số câu không có sẵn, phân bổ tỉ lệ theo
  /// ma trận 50 câu (phương pháp phần dư lớn nhất).
  static Map<String, int> matrixFor(int count) {
    final preset = matrices[count];
    if (preset != null) return preset;
    if (count <= 0) return {for (final t in typeOrder) t: 0};

    final base = matrices[50]!;
    final result = <String, int>{};
    final remainders = <String, double>{};
    var assigned = 0;
    for (final type in typeOrder) {
      final exact = base[type]! * count / 50.0;
      result[type] = exact.floor();
      remainders[type] = exact - exact.floor();
      assigned += result[type]!;
    }
    final byRemainder = [...typeOrder]
      ..sort((a, b) => remainders[b]!.compareTo(remainders[a]!));
    var i = 0;
    while (assigned < count) {
      result[byRemainder[i % byRemainder.length]] =
          result[byRemainder[i % byRemainder.length]]! + 1;
      assigned++;
      i++;
    }
    return result;
  }

  /// Ghép đề thi thử gồm [count] câu từ ngân hàng [bank].
  ///
  /// Nếu ngân hàng không đủ [count] câu, trả về toàn bộ câu có thể (kết quả có
  /// `isComplete == false`). Thiếu của một dạng bài được bù từ dạng còn dư.
  ExamBuildResult buildMockExam(List<Question> bank, {required int count}) {
    final unique = _dedupe(bank);
    final unitsByType = <String, List<List<Question>>>{};
    final availableByType = <String, int>{};
    for (final entry in _groupByType(unique).entries) {
      unitsByType[entry.key] = _toUnits(entry.value);
      availableByType[entry.key] = entry.value.length;
    }

    final matrix = matrixFor(count);
    final allTypes = <String>[
      ...typeOrder,
      ...availableByType.keys.where((t) => !typeOrder.contains(t)),
    ];

    // Bước 1: quota theo ma trận, giới hạn bởi số câu có sẵn.
    final target = <String, int>{};
    var total = 0;
    for (final type in allTypes) {
      final want = matrix[type] ?? 0;
      final have = availableByType[type] ?? 0;
      target[type] = min(want, have);
      total += target[type]!;
    }

    // Bước 2: bù phần thiếu từ các dạng còn dư (vòng tròn, mỗi lượt +1).
    var deficit = min(count, unique.length) - total;
    while (deficit > 0) {
      var progressed = false;
      for (final type in allTypes) {
        if (deficit == 0) break;
        if ((availableByType[type] ?? 0) > (target[type] ?? 0)) {
          target[type] = (target[type] ?? 0) + 1;
          deficit--;
          progressed = true;
        }
      }
      if (!progressed) break;
    }

    // Bước 3: chọn cụm cho từng dạng và xếp theo thứ tự dạng bài.
    final questions = <Question>[];
    final typeCounts = <String, int>{};
    var split = 0;
    for (final type in allTypes) {
      final quota = target[type] ?? 0;
      if (quota == 0) continue;
      final picked = _pickUnits(unitsByType[type]!, quota);
      split += picked.splitCount;
      final flat = picked.units.expand((u) => u).toList();
      typeCounts[type] = flat.length;
      questions.addAll(flat);
    }

    return ExamBuildResult(
      questions: questions,
      requestedCount: count,
      typeCounts: typeCounts,
      splitPassageCount: split,
    );
  }

  /// Chọn bộ câu luyện tập tối đa [count] câu. Câu cùng bài đọc được giữ
  /// thành cụm liên tiếp theo đúng thứ tự trong bài.
  List<Question> buildPracticeSet(List<Question> questions, {int count = 10}) {
    final unique = _dedupe(questions);
    if (unique.isEmpty || count <= 0) return [];
    final units = _toUnits(unique);
    final picked = _pickUnits(units, min(count, unique.length));
    return picked.units.expand((u) => u).toList();
  }

  // ---------------------------------------------------------------------------

  List<Question> _dedupe(List<Question> input) {
    final seen = <String>{};
    final result = <Question>[];
    for (final q in input) {
      if (seen.add(q.id)) result.add(q);
    }
    return result;
  }

  Map<String, List<Question>> _groupByType(List<Question> input) {
    final map = <String, List<Question>>{};
    for (final q in input) {
      map.putIfAbsent(q.type, () => []).add(q);
    }
    return map;
  }

  /// Gộp thành các "đơn vị": một cụm passage (đã sắp đúng thứ tự) hoặc 1 câu lẻ.
  List<List<Question>> _toUnits(List<Question> input) {
    final groups = <String, List<Question>>{};
    final units = <List<Question>>[];
    for (final q in input) {
      final pid = q.passageId;
      if (pid == null || pid.isEmpty) {
        units.add([q]);
      } else {
        groups.putIfAbsent(pid, () => []).add(q);
      }
    }
    for (final group in groups.values) {
      group.sort(_compareById);
      units.add(group);
    }
    return units;
  }

  static int _trailingNumber(String id) {
    final match = RegExp(r'(\d+)$').firstMatch(id);
    return match == null ? -1 : int.parse(match.group(1)!);
  }

  static int _compareById(Question a, Question b) {
    final na = _trailingNumber(a.id);
    final nb = _trailingNumber(b.id);
    if (na != nb) return na.compareTo(nb);
    return a.id.compareTo(b.id);
  }

  _PickResult _pickUnits(List<List<Question>> units, int quota) {
    // Thử nhiều thứ tự ngẫu nhiên để tìm tổ hợp nguyên cụm lấp đủ quota.
    var picked = <List<Question>>[];
    var unused = <List<Question>>[];
    var remaining = quota + 1;
    for (var attempt = 0; attempt < 60 && remaining > 0; attempt++) {
      final pool = List<List<Question>>.of(units)..shuffle(_random);
      final tryPicked = <List<Question>>[];
      final tryUnused = <List<Question>>[];
      var left = quota;
      // Ưu tiên chọn nguyên cụm vừa với số câu còn lại.
      for (final unit in pool) {
        if (left > 0 && unit.length <= left) {
          tryPicked.add(unit);
          left -= unit.length;
        } else {
          tryUnused.add(unit);
        }
      }
      if (left < remaining) {
        remaining = left;
        picked = tryPicked;
        unused = tryUnused;
      }
    }

    // Bắt buộc mới cắt cụm: lấy các câu đầu (liên tiếp) của một cụm chưa dùng.
    var split = 0;
    if (remaining > 0) {
      for (final unit in unused) {
        if (remaining == 0) break;
        final take = min(remaining, unit.length);
        picked.add(unit.sublist(0, take));
        remaining -= take;
        if (take < unit.length) split++;
      }
    }

    picked.shuffle(_random);
    return _PickResult(picked, split);
  }
}

class _PickResult {
  final List<List<Question>> units;
  final int splitCount;
  const _PickResult(this.units, this.splitCount);
}
