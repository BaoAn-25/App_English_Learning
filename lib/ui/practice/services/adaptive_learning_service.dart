import 'dart:math';

import '../../../data/models/attempt.dart';
import '../../../data/models/attempt_answer.dart';
import '../../../data/models/question.dart';
import '../../../data/models/wrong_book_entry.dart';
import '../models/adaptive_models.dart';

/// Cấu hình tham số toán học cho Adaptive Analysis Engine
class AdaptiveConfig {
  /// Ngưỡng số câu hỏi duy nhất (distinct) để đạt chỉ số đủ mẫu tối đa (Confidence = 1.0)
  static const int targetSampleCount = 8;

  /// Ngưỡng số câu duy nhất tối thiểu để không bị coi là insufficientData
  static const int minQuestionsForAssessment = 3;

  /// Điểm thành thạo tiên nghiệm trung bình (Prior Mastery) khi chưa có đủ bằng chứng
  static const double priorMastery = 50.0;

  /// Sức mạnh tiên nghiệm (Prior Strength) tương đương số lượng câu giả định làm bằng chứng
  static const double priorWeight = 4.0;

  /// Ngưỡng phân loại cấp độ năng lực
  static const double minConfidenceForAssessment = 0.35;
  static const double weakMasteryThreshold = 55.0;
  static const double strongMasteryThreshold = 75.0;
  static const double minConfidenceForStrongLevel = 0.50;

  /// Trọng số thời gian (Recency decay) theo số ngày tính từ thời điểm tham chiếu
  static double getRecencyWeight(int daysAgo) {
    if (daysAgo <= 7) return 1.0;
    if (daysAgo <= 30) return 0.75;
    return 0.50;
  }

  /// Hệ số nhân theo độ khó câu hỏi (Difficulty Multiplier)
  /// Difficulty 1: Dễ / Nhận biết
  /// Difficulty 2: Trung bình / Thông hiểu
  /// Difficulty 3: Khó / Vận dụng cao
  static double getDifficultyMultiplier(int difficulty) {
    switch (difficulty) {
      case 3:
        return 1.35;
      case 2:
        return 1.15;
      case 1:
      default:
        return 1.0;
    }
  }

  /// Trọng số giảm dần cho các lần làm lặp lại cùng một câu hỏi (Anti-grinding weights)
  /// Lần 1 (mới nhất): 1.0, Lần 2: 0.3, Lần 3: 0.1, Lần 4+: 0.0
  static double getRepeatWeight(int occurrenceIndexFromLatest) {
    switch (occurrenceIndexFromLatest) {
      case 0:
        return 1.0;
      case 1:
        return 0.3;
      case 2:
        return 0.1;
      default:
        return 0.0;
    }
  }
}

/// Bản ghi chi tiết của một lần trả lời câu hỏi kèm ngữ cảnh thời gian
class _AnswerContext {
  final AttemptAnswer answer;
  final Question? question;
  final int startedAt;

  const _AnswerContext({
    required this.answer,
    required this.question,
    required this.startedAt,
  });
}

/// Dịch vụ phân tích năng lực học sinh thích ứng (Adaptive Learning Analysis Engine)
class AdaptiveLearningService {
  /// Thứ tự chuẩn của 8 dạng bài tốt nghiệp THPT
  static const List<String> standardTypes = [
    'grammar',
    'vocab',
    'synonym_antonym',
    'communication',
    'signs',
    'arrange',
    'cloze',
    'reading',
  ];

  /// Tên tiếng Việt chuẩn cho từng dạng bài
  static const Map<String, String> typeTitles = {
    'grammar': 'Ngữ pháp',
    'arrange': 'Sắp xếp câu',
    'vocab': 'Từ vựng',
    'synonym_antonym': 'Đồng - Trái nghĩa',
    'communication': 'Giao tiếp',
    'signs': 'Biển báo',
    'cloze': 'Điền từ',
    'reading': 'Đọc hiểu',
  };

  static String getTitleForType(String type) {
    return typeTitles[type] ?? type;
  }

  /// Đánh giá toàn diện hồ sơ năng lực học sinh từ dữ liệu lịch sử
  ///
  /// Hàm thuần túy (pure function): nhận vào dữ liệu và trả về hồ sơ độc lập,
  /// cho phép truyền [referenceTime] để unit tests hoàn toàn độc lập với thời gian thực.
  static AdaptiveStudentProfile evaluateStudentProfile({
    required List<Question> questions,
    required List<Attempt> attempts,
    required List<AttemptAnswer> answers,
    List<WrongBookEntry> wrongEntries = const [],
    DateTime? referenceTime,
  }) {
    final now = referenceTime ?? DateTime.now();

    // 1. Lập bản đồ tra cứu nhanh
    final questionMap = <String, Question>{for (final q in questions) q.id: q};

    final attemptTimeMap = <int, int>{
      for (final a in attempts)
        if (a.id != null) a.id!: a.startedAt,
    };

    final wrongCountByType = <String, int>{};
    for (final entry in wrongEntries) {
      final q = questionMap[entry.questionId];
      if (q != null) {
        wrongCountByType[q.type] = (wrongCountByType[q.type] ?? 0) + 1;
      }
    }

    // 2. Gom nhóm câu trả lời theo từng dạng bài
    final answersByType = <String, List<_AnswerContext>>{};
    for (final t in standardTypes) {
      answersByType[t] = [];
    }

    int totalQuestionsDone = 0;

    for (final ans in answers) {
      final q = questionMap[ans.questionId];
      if (q == null) continue;

      totalQuestionsDone++;
      final startedAt = attemptTimeMap[ans.attemptId] ?? 0;

      answersByType
          .putIfAbsent(q.type, () => [])
          .add(_AnswerContext(answer: ans, question: q, startedAt: startedAt));
    }

    // 3. Phân tích từng dạng bài
    final List<AdaptiveSkillProfile> skillProfiles = [];

    for (final type in standardTypes) {
      final contextList = answersByType[type] ?? [];
      final wrongCount = wrongCountByType[type] ?? 0;

      final profile = _evaluateSingleSkill(
        type: type,
        typeTitle: getTitleForType(type),
        contexts: contextList,
        wrongBookCount: wrongCount,
        referenceTime: now,
      );

      skillProfiles.add(profile);
    }

    // 4. Xác định điểm mạnh, điểm yếu và dạng bài chưa đủ dữ liệu
    final assessedSkills = skillProfiles
        .where((s) => s.level != AdaptiveSkillLevel.insufficientData)
        .toList();

    final unassessedSkills = skillProfiles
        .where((s) => s.level == AdaptiveSkillLevel.insufficientData)
        .toList();

    AdaptiveSkillProfile? primaryWeakness;
    AdaptiveSkillProfile? primaryStrength;

    if (assessedSkills.isNotEmpty) {
      // Điểm yếu nhất: Mastery thấp nhất. Nếu bằng nhau -> Practice Priority cao nhất
      final sortedByWeakness = List<AdaptiveSkillProfile>.from(assessedSkills)
        ..sort((a, b) {
          final mCompare = a.masteryScore.compareTo(b.masteryScore);
          if (mCompare != 0) return mCompare;
          return b.practicePriority.compareTo(a.practicePriority);
        });

      if (sortedByWeakness.first.level == AdaptiveSkillLevel.weak ||
          sortedByWeakness.first.level == AdaptiveSkillLevel.moderate) {
        primaryWeakness = sortedByWeakness.first;
      }

      // Điểm mạnh nhất: Mastery cao nhất (chỉ xét level moderate hoặc strong)
      final sortedByStrength = List<AdaptiveSkillProfile>.from(assessedSkills)
        ..sort((a, b) => b.masteryScore.compareTo(a.masteryScore));

      if (sortedByStrength.first.masteryScore >= 65.0) {
        primaryStrength = sortedByStrength.first;
      }
    }

    // 5. Tính điểm năng lực tổng hợp (Overall Mastery)
    // Người học chưa có bài làm xác thực thì overallMastery = 0.0 (trạng thái khảo sát ban đầu)
    double overallMastery = 0.0;
    if (assessedSkills.isNotEmpty) {
      double totalWeightedMastery = 0.0;
      double totalWeight = 0.0;
      for (final s in assessedSkills) {
        final w = s.confidence;
        totalWeightedMastery += s.masteryScore * w;
        totalWeight += w;
      }
      overallMastery = totalWeight > 0
          ? (totalWeightedMastery / totalWeight)
          : 0.0;
    }

    return AdaptiveStudentProfile(
      skills: skillProfiles,
      primaryWeakness: primaryWeakness,
      primaryStrength: primaryStrength,
      unassessedSkills: unassessedSkills,
      overallMastery: overallMastery.clamp(0.0, 100.0),
      totalQuestionsDone: totalQuestionsDone,
      evaluatedAt: now,
    );
  }

  /// Tính toán hồ sơ cho 1 dạng bài cụ thể
  static AdaptiveSkillProfile _evaluateSingleSkill({
    required String type,
    required String typeTitle,
    required List<_AnswerContext> contexts,
    required int wrongBookCount,
    required DateTime referenceTime,
  }) {
    if (contexts.isEmpty) {
      return AdaptiveSkillProfile(
        type: type,
        typeTitle: typeTitle,
        totalAttempts: 0,
        totalCorrect: 0,
        totalWrong: 0,
        totalUnanswered: 0,
        uniqueQuestionsSeen: 0,
        rawAccuracy: 0.0,
        confidence: 0.0,
        masteryScore: AdaptiveConfig.priorMastery,
        level: AdaptiveSkillLevel.insufficientData,
        practicePriority: 85.0, // Ưu tiên khảo sát ban đầu cao
        isImproving: false,
        wrongBookCount: wrongBookCount,
      );
    }

    int totalAttempts = contexts.length;
    int totalCorrect = 0;
    int totalWrong = 0;
    int totalUnanswered = 0;

    // Gom nhóm theo questionId để kiểm soát câu hỏi lặp lại
    final Map<String, List<_AnswerContext>> questionGroups = {};
    for (final ctx in contexts) {
      final qId = ctx.answer.questionId;
      questionGroups.putIfAbsent(qId, () => []).add(ctx);

      final chosen = ctx.answer.chosenIndex;
      if (chosen < 0) {
        totalUnanswered++;
      } else if (ctx.answer.isCorrect) {
        totalCorrect++;
      } else {
        totalWrong++;
      }
    }

    final uniqueQuestionsSeen = questionGroups.length;

    // 1. Raw Accuracy: tỷ lệ đúng thô (%)
    final rawAccuracy = totalAttempts > 0
        ? (totalCorrect / totalAttempts * 100.0)
        : 0.0;

    // 2. Confidence: chỉ số đủ mẫu heuristic (0.0 đến 1.0)
    final confidence = min(
      1.0,
      uniqueQuestionsSeen / AdaptiveConfig.targetSampleCount,
    );

    // 3. Tính điểm tích lũy có trọng số (Recency, Difficulty, Anti-grinding)
    double weightedEvidenceScore = 0.0;
    double weightedMaxEvidence = 0.0;

    for (final entry in questionGroups.entries) {
      final occurrences = entry.value;

      // Sắp xếp các lần làm câu hỏi theo thời gian giảm dần (mới nhất đứng đầu)
      occurrences.sort((a, b) => b.startedAt.compareTo(a.startedAt));

      for (int i = 0; i < occurrences.length; i++) {
        final ctx = occurrences[i];
        final repeatWeight = AdaptiveConfig.getRepeatWeight(i);
        if (repeatWeight <= 0.0) continue; // Bỏ qua từ lần làm thứ 4 trở đi

        final daysAgo = max(
          0,
          referenceTime
              .difference(DateTime.fromMillisecondsSinceEpoch(ctx.startedAt))
              .inDays,
        );
        final recencyWeight = AdaptiveConfig.getRecencyWeight(daysAgo);

        final difficulty = ctx.question?.difficulty ?? 1;
        final diffMultiplier = AdaptiveConfig.getDifficultyMultiplier(
          difficulty,
        );

        final totalWeight = recencyWeight * repeatWeight;
        final maxPoints = totalWeight * diffMultiplier;

        weightedMaxEvidence += maxPoints;

        if (ctx.answer.isCorrect) {
          weightedEvidenceScore += maxPoints;
        }
      }
    }

    // 4. Bayesian Smoothed Mastery Score
    // Áp dụng prior 50% với prior strength = AdaptiveConfig.priorWeight
    final priorPoints =
        (AdaptiveConfig.priorMastery / 100.0) * AdaptiveConfig.priorWeight;
    final smoothedRatio =
        (weightedEvidenceScore + priorPoints) /
        (weightedMaxEvidence + AdaptiveConfig.priorWeight);

    final masteryScore = (smoothedRatio * 100.0).clamp(0.0, 100.0);

    // 5. Phân cấp năng lực (Level)
    AdaptiveSkillLevel level;
    if (confidence < AdaptiveConfig.minConfidenceForAssessment ||
        uniqueQuestionsSeen < AdaptiveConfig.minQuestionsForAssessment) {
      level = AdaptiveSkillLevel.insufficientData;
    } else if (masteryScore < AdaptiveConfig.weakMasteryThreshold) {
      level = AdaptiveSkillLevel.weak;
    } else if (masteryScore >= AdaptiveConfig.strongMasteryThreshold &&
        confidence >= AdaptiveConfig.minConfidenceForStrongLevel) {
      level = AdaptiveSkillLevel.strong;
    } else {
      level = AdaptiveSkillLevel.moderate;
    }

    // 6. Tính Practice Priority (Mức độ ưu tiên luyện tập)
    double practicePriority;
    if (level == AdaptiveSkillLevel.insufficientData) {
      // Dạng chưa đủ dữ liệu: ưu tiên để khảo sát năng lực
      practicePriority =
          70.0 + (1.0 - confidence) * 20.0 + (wrongBookCount * 2.0);
    } else {
      // Dạng đã có dữ liệu: điểm yếu ưu tiên cao nhất, cộng thêm câu sai trong wrong book
      practicePriority = (100.0 - masteryScore) * 0.85 + (wrongBookCount * 3.0);
    }

    // 7. Đánh giá xu hướng tiến bộ
    bool isImproving = false;
    if (contexts.length >= 6) {
      // Sắp xếp toàn bộ theo thời gian tăng dần
      final sortedContexts = List<_AnswerContext>.from(contexts)
        ..sort((a, b) => a.startedAt.compareTo(b.startedAt));

      final splitIndex = sortedContexts.length ~/ 2;
      final olderHalf = sortedContexts.sublist(0, splitIndex);
      final recentHalf = sortedContexts.sublist(splitIndex);

      final olderCorrect = olderHalf.where((c) => c.answer.isCorrect).length;
      final recentCorrect = recentHalf.where((c) => c.answer.isCorrect).length;

      final olderAcc = olderHalf.isNotEmpty
          ? olderCorrect / olderHalf.length
          : 0.0;
      final recentAcc = recentHalf.isNotEmpty
          ? recentCorrect / recentHalf.length
          : 0.0;

      if (recentAcc > olderAcc + 0.05) {
        isImproving = true;
      }
    }

    return AdaptiveSkillProfile(
      type: type,
      typeTitle: typeTitle,
      totalAttempts: totalAttempts,
      totalCorrect: totalCorrect,
      totalWrong: totalWrong,
      totalUnanswered: totalUnanswered,
      uniqueQuestionsSeen: uniqueQuestionsSeen,
      rawAccuracy: rawAccuracy.clamp(0.0, 100.0),
      confidence: confidence.clamp(0.0, 1.0),
      masteryScore: masteryScore,
      level: level,
      practicePriority: practicePriority.clamp(0.0, 150.0),
      isImproving: isImproving,
      wrongBookCount: wrongBookCount,
    );
  }
}
