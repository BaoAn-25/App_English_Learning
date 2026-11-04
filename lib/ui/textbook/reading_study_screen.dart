import 'package:flutter/material.dart';
import '../../data/trial_lesson_repository.dart';
import '../trial/trial_lesson_screen.dart';

/// Màn hình học đọc hiểu tương tác, sử dụng cấu trúc bài học dùng chung
/// và bộ tương tác tra từ/dịch đoạn thống nhất.
class ReadingStudyScreen extends StatelessWidget {
  final int unitNumber;
  final String unitTitle;
  final String articleTitle;

  const ReadingStudyScreen({
    super.key,
    this.unitNumber = 1,
    this.unitTitle = 'Life Stories We Admire',
    this.articleTitle = 'Steve Jobs: Life and Achievements',
  });

  @override
  Widget build(BuildContext context) {
    // Tìm bài học tương ứng theo Unit number
    final lesson = TrialLessonRepository.instance.getLessonByUnit(unitNumber) ??
        TrialLessonRepository.instance.getDefaultLesson();

    return TrialLessonScreen(
      lessonId: lesson.lessonId,
      initialStep: 0,
    );
  }
}
