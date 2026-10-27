import 'dart:math';

import '../../../data/models/attempt.dart';
import '../../../data/models/attempt_answer.dart';
import '../../../data/models/question.dart';
import '../../../data/models/wrong_book_entry.dart';
import '../models/adaptive_models.dart';
import '../models/adaptive_plan_models.dart';
import 'adaptive_question_selector.dart';
import 'exam_builder_service.dart';

/// Service tự động sinh Lộ trình học tập cá nhân hóa (Personalized Learning Plan)
class AdaptivePlanGenerator {
  final AdaptiveQuestionSelector _selector;

  AdaptivePlanGenerator({AdaptiveQuestionSelector? selector, int? seed})
    : _selector = selector ?? AdaptiveQuestionSelector(seed: seed);

  /// Sinh kế hoạch học tập cá nhân hóa tối đa 3 nhiệm vụ dựa trên hồ sơ học sinh
  ///
  /// - [profile]: Hồ sơ năng lực học sinh được tính toán bởi AdaptiveLearningService
  /// - [allQuestions]: Toàn bộ ngân hàng câu hỏi (chuẩn 125 câu)
  /// - [allAnswers]: Toàn bộ lịch sử trả lời câu hỏi
  /// - [allAttempts]: Toàn bộ lịch sử các lượt làm bài
  /// - [wrongBookEntries]: Danh sách các câu hỏi trong sổ câu sai
  /// - [referenceTime]: Thời điểm tham chiếu (hỗ trợ deterministic testing)
  AdaptiveLearningPlan generatePlan({
    required AdaptiveStudentProfile profile,
    required List<Question> allQuestions,
    List<AttemptAnswer> allAnswers = const [],
    List<Attempt> allAttempts = const [],
    List<WrongBookEntry> wrongBookEntries = const [],
    DateTime? referenceTime,
  }) {
    final now = referenceTime ?? DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;

    // 1. Lập tập hợp questionId đã làm và timestamp lần làm gần nhất
    final seenQuestionIds = <String>{};
    final lastSeenTimestamps = <String, int>{};

    final attemptTimeMap = <int, int>{
      for (final a in allAttempts)
        if (a.id != null) a.id!: a.startedAt,
    };

    for (final ans in allAnswers) {
      seenQuestionIds.add(ans.questionId);
      final t = attemptTimeMap[ans.attemptId] ?? 0;
      final existing = lastSeenTimestamps[ans.questionId];
      if (existing == null || t > existing) {
        lastSeenTimestamps[ans.questionId] = t;
      }
    }

    final questionMap = <String, Question>{
      for (final q in allQuestions) q.id: q,
    };

    final tasks = <AdaptiveTask>[];

    // =========================================================================
    // NHIỆM VỤ 1: TRỌNG TÂM CÁ NHÂN HÓA (Điểm yếu hoặc Khảo sát ban đầu)
    // =========================================================================
    final task1 = _buildPrimaryTask(
      profile: profile,
      allQuestions: allQuestions,
      seenQuestionIds: seenQuestionIds,
      lastSeenTimestamps: lastSeenTimestamps,
      nowMs: nowMs,
    );

    final task1Ids = task1?.questions.map((q) => q.id).toSet() ?? <String>{};
    if (task1 != null && task1.isValid) {
      tasks.add(task1);
    }

    // =========================================================================
    // NHIỆM VỤ 2: ÔN TẬP CÂU SAI HOẶC CỦNG CỐ CHUYÊN ĐỀ
    // =========================================================================
    final task1TargetType = task1?.targetType;
    final task2 = _buildRemediationTask(
      profile: profile,
      allQuestions: allQuestions,
      questionMap: questionMap,
      wrongBookEntries: wrongBookEntries,
      seenQuestionIds: seenQuestionIds,
      lastSeenTimestamps: lastSeenTimestamps,
      excludedType: task1TargetType,
      excludedQuestionIds: task1Ids,
      nowMs: nowMs,
    );

    final task2Ids = task2?.questions.map((q) => q.id).toSet() ?? <String>{};
    if (task2 != null && task2.isValid) {
      tasks.add(task2);
    }

    // =========================================================================
    // NHIỆM VỤ 3: KIỂM TRA TỔNG HỢP (Bài test ngắn 10 câu đa dạng)
    // =========================================================================
    final combinedExcludedIds = <String>{...task1Ids, ...task2Ids};
    final task3 = _buildComprehensiveTask(
      allQuestions: allQuestions,
      excludedQuestionIds: combinedExcludedIds,
    );

    if (task3 != null && task3.isValid) {
      tasks.add(task3);
    }

    // Đánh số lại thứ tự ưu tiên (1, 2, 3) cho các nhiệm vụ hợp lệ
    final finalizedTasks = <AdaptiveTask>[];
    for (int i = 0; i < tasks.length; i++) {
      final t = tasks[i];
      finalizedTasks.add(
        AdaptiveTask(
          id: t.id,
          type: t.type,
          targetType: t.targetType,
          title: t.title,
          subtitle: t.subtitle,
          reasoning: t.reasoning,
          questions: t.questions,
          priorityOrder: i + 1,
        ),
      );
    }

    final planId =
        'plan_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

    return AdaptiveLearningPlan(
      id: planId,
      generatedAt: now,
      tasks: finalizedTasks,
    );
  }

  /// Xác định độ khó ưu tiên từ cấp độ năng lực
  int _determinePreferredDifficulty(AdaptiveSkillLevel level) {
    switch (level) {
      case AdaptiveSkillLevel.weak:
        return 1; // Ưu tiên câu dễ & trung bình để củng cố nền tảng
      case AdaptiveSkillLevel.moderate:
      case AdaptiveSkillLevel.insufficientData:
        return 2; // Ưu tiên câu trung bình
      case AdaptiveSkillLevel.strong:
        return 3; // Ưu tiên câu phân hóa / thử thách
    }
  }

  /// Xây dựng Nhiệm vụ 1: Luyện điểm yếu nhất hoặc Khảo sát năng lực
  AdaptiveTask? _buildPrimaryTask({
    required AdaptiveStudentProfile profile,
    required List<Question> allQuestions,
    required Set<String> seenQuestionIds,
    required Map<String, int> lastSeenTimestamps,
    required int nowMs,
  }) {
    AdaptiveSkillProfile? targetSkill;
    AdaptiveTaskType taskType;
    String title;
    String subtitle;
    String reasoning;

    if (profile.primaryWeakness != null) {
      // Trường hợp 1: Có điểm yếu rõ ràng
      targetSkill = profile.primaryWeakness!;
      taskType = AdaptiveTaskType.weaknessRemediation;
      title = 'Chinh phục điểm yếu: ${targetSkill.typeTitle}';
      subtitle =
          'Tập trung cải thiện dạng bài có điểm thành thạo ${targetSkill.masteryScore.toStringAsFixed(0)}%';
      reasoning =
          'Dạng bài này hiện có độ chính xác thấp nhất (${targetSkill.rawAccuracy.toStringAsFixed(0)}%). Luyện tập chuyên sâu sẽ giúp bạn cải thiện điểm số nhanh nhất.';
    } else if (profile.unassessedSkills.isNotEmpty) {
      // Trường hợp 2: Chưa có điểm yếu hoặc học sinh mới -> Khảo sát chuyên đề chưa đủ dữ liệu
      targetSkill = profile.unassessedSkills.first;
      taskType = AdaptiveTaskType.surveyUnassessed;
      title = 'Khảo sát năng lực: ${targetSkill.typeTitle}';
      subtitle =
          'Làm quen và đánh giá ban đầu chuyên đề ${targetSkill.typeTitle}';
      reasoning =
          'Chuyên đề này chưa có đủ dữ liệu để đánh giá chính xác. Hãy hoàn thành lượt luyện tập để hệ thống xây dựng lộ trình riêng cho bạn.';
    } else if (profile.skills.isNotEmpty) {
      // Trường hợp 3: Tất cả dạng bài đều mạnh (strong) -> Duy trì phong độ dạng có điểm thấp nhất trong nhóm
      final sortedSkills = List<AdaptiveSkillProfile>.from(profile.skills)
        ..sort((a, b) => a.masteryScore.compareTo(b.masteryScore));
      targetSkill = sortedSkills.first;
      taskType = AdaptiveTaskType.masteryMaintenance;
      title = 'Duy trì phong độ: ${targetSkill.typeTitle}';
      subtitle = 'Ôn luyện chuyên sâu chuyên đề ${targetSkill.typeTitle}';
      reasoning =
          'Bạn đã nắm khá vững chuyên đề này. Hãy luyện tập thêm để củng cố phản xạ tốt nhất.';
    } else {
      return null;
    }

    final preferredDiff = _determinePreferredDifficulty(targetSkill.level);

    final selection = _selector.selectQuestions(
      bank: allQuestions,
      targetType: targetSkill.type,
      requestedCount: 10,
      seenQuestionIds: seenQuestionIds,
      lastSeenTimestamps: lastSeenTimestamps,
      preferredDifficulty: preferredDiff,
      referenceTimeMs: nowMs,
    );

    if (selection.questions.isEmpty) return null;

    return AdaptiveTask(
      id: 'task_primary_${targetSkill.type}',
      type: taskType,
      targetType: targetSkill.type,
      title: title,
      subtitle: subtitle,
      reasoning: reasoning,
      questions: selection.questions,
      priorityOrder: 1,
    );
  }

  /// Xây dựng Nhiệm vụ 2: Ôn tập câu sai hoặc Củng cố chuyên đề trung bình
  AdaptiveTask? _buildRemediationTask({
    required AdaptiveStudentProfile profile,
    required List<Question> allQuestions,
    required Map<String, Question> questionMap,
    required List<WrongBookEntry> wrongBookEntries,
    required Set<String> seenQuestionIds,
    required Map<String, int> lastSeenTimestamps,
    required String? excludedType,
    Set<String> excludedQuestionIds = const {},
    required int nowMs,
  }) {
    // 1. Kiểm tra Sổ câu sai (Wrong Book)
    // Sắp xếp các câu sai theo 3 tầng ưu tiên minh bạch dựa trên dữ liệu SQLite:
    // Tầng 1: Câu đến hạn ôn (nextReviewAt > 0 và <= nowMs)
    // Tầng 2: Câu sai nhiều lần (wrongCount giảm dần)
    // Tầng 3: Câu chưa được ôn gần đây (lastWrongAt cũ hơn đứng trước)
    final sortedEntries = List<WrongBookEntry>.from(wrongBookEntries)
      ..sort((a, b) {
        final aDue = a.nextReviewAt > 0 && a.nextReviewAt <= nowMs;
        final bDue = b.nextReviewAt > 0 && b.nextReviewAt <= nowMs;
        if (aDue != bDue) {
          return aDue ? -1 : 1;
        }
        if (b.wrongCount != a.wrongCount) {
          return b.wrongCount.compareTo(a.wrongCount);
        }
        return a.lastWrongAt.compareTo(b.lastWrongAt);
      });

    final validWrongNonExcluded = <Question>[];
    final validWrongExcluded = <Question>[];
    final seenWrongIds = <String>{};

    for (final entry in sortedEntries) {
      if (entry.wrongCount > 0) {
        final q = questionMap[entry.questionId];
        if (q != null && seenWrongIds.add(q.id)) {
          if (excludedQuestionIds.contains(q.id)) {
            validWrongExcluded.add(q);
          } else {
            validWrongNonExcluded.add(q);
          }
        }
      }
    }

    // Ghép câu chưa trùng trong Task 1 trước, nếu thiếu mới lấy câu trùng lặp
    final combinedWrong = [...validWrongNonExcluded, ...validWrongExcluded];

    if (combinedWrong.isNotEmpty) {
      final pickedCount = min(10, combinedWrong.length);
      final selectedWrong = combinedWrong.take(pickedCount).toList();

      return AdaptiveTask(
        id: 'task_wrong_book',
        type: AdaptiveTaskType.wrongBookReview,
        targetType: 'wrong_review',
        title: 'Ôn tập sổ câu sai',
        subtitle:
            'Khắc phục ${selectedWrong.length} câu hỏi bạn đã từng trả lời sai',
        reasoning:
            'Luyện lại các câu từng làm sai giúp củng cố lỗ hổng kiến thức và tránh lặp lại lỗi sai tương tự.',
        questions: selectedWrong,
        priorityOrder: 2,
      );
    }

    // 2. Nếu không có câu sai: Tìm dạng bài thứ hai để củng cố (khác với dạng ở Nhiệm vụ 1)
    AdaptiveSkillProfile? secondSkill;

    // Ưu tiên 1: Dạng bài ở mức trung bình (moderate)
    final moderateSkills = profile.skills
        .where(
          (s) =>
              s.level == AdaptiveSkillLevel.moderate && s.type != excludedType,
        )
        .toList();
    if (moderateSkills.isNotEmpty) {
      secondSkill = moderateSkills.first;
    }

    // Ưu tiên 2: Dạng bài chưa đủ dữ liệu tiếp theo (khác excludedType)
    if (secondSkill == null) {
      final unassessedRemaining = profile.unassessedSkills
          .where((s) => s.type != excludedType)
          .toList();
      if (unassessedRemaining.isNotEmpty) {
        secondSkill = unassessedRemaining.first;
      }
    }

    // Ưu tiên 3: Dạng bài có practicePriority cao tiếp theo
    if (secondSkill == null) {
      final remainingSkills =
          profile.skills.where((s) => s.type != excludedType).toList()
            ..sort((a, b) => b.practicePriority.compareTo(a.practicePriority));
      if (remainingSkills.isNotEmpty) {
        secondSkill = remainingSkills.first;
      }
    }

    if (secondSkill == null) return null;

    final preferredDiff = _determinePreferredDifficulty(secondSkill.level);

    // Bổ sung excludedQuestionIds vào seenQuestionIds để selector ưu tiên câu khác tránh trùng Task 1
    final combinedSeenIds = {...seenQuestionIds, ...excludedQuestionIds};

    final selection = _selector.selectQuestions(
      bank: allQuestions,
      targetType: secondSkill.type,
      requestedCount: 10,
      seenQuestionIds: combinedSeenIds,
      lastSeenTimestamps: lastSeenTimestamps,
      preferredDifficulty: preferredDiff,
      referenceTimeMs: nowMs,
    );

    if (selection.questions.isEmpty) return null;

    final isModerate = secondSkill.level == AdaptiveSkillLevel.moderate;

    return AdaptiveTask(
      id: 'task_reinforce_${secondSkill.type}',
      type: isModerate
          ? AdaptiveTaskType.skillReinforcement
          : AdaptiveTaskType.surveyUnassessed,
      targetType: secondSkill.type,
      title: isModerate
          ? 'Củng cố chuyên đề: ${secondSkill.typeTitle}'
          : 'Khảo sát năng lực: ${secondSkill.typeTitle}',
      subtitle: isModerate
          ? 'Nâng cao điểm thành thạo chuyên đề ${secondSkill.typeTitle}'
          : 'Làm quen và đánh giá ban đầu chuyên đề ${secondSkill.typeTitle}',
      reasoning: isModerate
          ? 'Chuyên đề này đang ở mức trung bình (${secondSkill.masteryScore.toStringAsFixed(0)}%). Luyện tập thêm để nâng lên mức thành thạo.'
          : 'Chuyên đề này chưa có đủ dữ liệu đánh giá. Hoàn thành để làm dày dặn hồ sơ năng lực.',
      questions: selection.questions,
      priorityOrder: 2,
    );
  }

  /// Xây dựng Nhiệm vụ 3: Bài kiểm tra tổng hợp ngắn 10 câu
  AdaptiveTask? _buildComprehensiveTask({
    required List<Question> allQuestions,
    Set<String> excludedQuestionIds = const {},
  }) {
    if (allQuestions.isEmpty) return null;

    // Hạn chế trùng lặp với các câu hỏi đã chọn trong Task 1 và Task 2
    final targetCount = min(10, allQuestions.length);
    List<Question> selectedQuestions = [];

    if (excludedQuestionIds.isNotEmpty) {
      final candidateBank = allQuestions
          .where((q) => !excludedQuestionIds.contains(q.id))
          .toList();

      if (candidateBank.length >= targetCount) {
        // Trường hợp lý tưởng: Ngân hàng chưa sử dụng đủ để tạo trọn vẹn đề
        final examAttempt = ExamBuilderService().buildMockExam(
          candidateBank,
          count: targetCount,
        );
        if (examAttempt.questions.length == targetCount) {
          selectedQuestions = examAttempt.questions;
        }
      }

      // Nếu candidateBank thiếu câu hoặc examAttempt không đủ targetCount câu:
      // Ưu tiên tối đa số câu chưa dùng từ candidateBank, chỉ bù phần thiếu từ các câu đã dùng
      if (selectedQuestions.isEmpty && candidateBank.isNotEmpty) {
        final candidateResult = ExamBuilderService().buildMockExam(
          candidateBank,
          count: min(targetCount, candidateBank.length),
        );
        final initialQuestions = candidateResult.questions;
        final selectedIds = initialQuestions.map((q) => q.id).toSet();

        final deficit = targetCount - initialQuestions.length;
        if (deficit > 0) {
          final supplementBank = allQuestions
              .where((q) => !selectedIds.contains(q.id))
              .toList();
          final supplementResult = ExamBuilderService().buildPracticeSet(
            supplementBank,
            count: deficit,
          );
          selectedQuestions = [...initialQuestions, ...supplementResult];
        } else {
          selectedQuestions = initialQuestions;
        }
      }
    }

    // Fallback an toàn tuyệt đối nếu các bước trên chưa chọn được câu nào
    if (selectedQuestions.isEmpty) {
      final buildResult = ExamBuilderService().buildMockExam(
        allQuestions,
        count: targetCount,
      );
      selectedQuestions = buildResult.questions;
    }

    if (selectedQuestions.isEmpty) return null;

    return AdaptiveTask(
      id: 'task_mini_mock_exam',
      type: AdaptiveTaskType.comprehensiveCheck,
      targetType: 'mixed',
      title: 'Kiểm tra tổng hợp ${selectedQuestions.length} câu',
      subtitle: 'Bài kiểm tra nhanh mô phỏng cấu trúc đề thi THPT',
      reasoning:
          'Luyện tập phản xạ chuyển đổi linh hoạt giữa các dạng bài khác nhau và kiểm tra độ vững vàng kiến thức tổng thể.',
      questions: selectedQuestions,
      priorityOrder: 3,
    );
  }
}
