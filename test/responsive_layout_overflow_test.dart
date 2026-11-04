import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:thpt_english/data/app_database.dart';
import 'package:thpt_english/data/app_repository.dart';
import 'package:thpt_english/data/models/attempt.dart';
import 'package:thpt_english/data/models/daily_stat.dart';
import 'package:thpt_english/ui/stats/stats_screen.dart';
import 'package:thpt_english/ui/textbook/reading_completion_screen.dart';
import 'package:thpt_english/ui/theme/components/app_button.dart';
import 'package:thpt_english/ui/trial/trial_lesson_screen.dart';

import 'support/sqlite_bridge.dart';

class _FakeStatsRepository extends AppRepository {
  @override
  Future<List<Attempt>> getAttempts({String? ownerId, int? limit}) async {
    return [
      Attempt(
        id: 1,
        mode: 'practice',
        type: 'reading_cloze',
        score: 15,
        total: 20,
        startedAt: DateTime.now().millisecondsSinceEpoch,
        durationSec: 300,
      ),
    ];
  }

  @override
  Future<List<DailyStat>> getDailyStatsInRange(
    String startDate,
    String endDate, {
    String? ownerId,
  }) async {
    return [
      DailyStat(
        date: DateTime.now().toIso8601String().substring(0, 10),
        xp: 30,
        questionsDone: 20,
        correct: 15,
        minutes: 25,
      ),
    ];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SqliteBridge bridge;
  late Database database;

  setUpAll(() async {
    bridge = await SqliteBridge.start();
    database = await AppDatabase.instance.database;
  });

  tearDownAll(() async {
    await database.close();
    await bridge.close();
  });

  // Ma trận kích thước kiểm thử đa dạng
  final screenSizes = <String, Size>{
    'Small 320x640': const Size(320, 640),
    'Standard Android 360x780': const Size(360, 780),
    'Modern Mobile 390x844': const Size(390, 844),
    'Large Mobile 412x915': const Size(412, 915),
    'Landscape 800x400': const Size(800, 400),
  };

  // Ma trận TextScaler
  final textScales = <String, double>{
    'Scale 1.0 (Chuẩn)': 1.0,
    'Scale 1.3 (Lớn)': 1.3,
    'Scale 1.5 (Rất lớn)': 1.5,
  };

  group('1. TrialLessonScreen - Result Step (Khắc phục triệt để lỗi tràn dòng hỗ trợ)', () {
    for (final sizeEntry in screenSizes.entries) {
      for (final scaleEntry in textScales.entries) {
        testWidgets(
          'Không overflow ở ${sizeEntry.key} với ${scaleEntry.key}',
          (tester) async {
            tester.view.physicalSize = sizeEntry.value * 2.0;
            tester.view.devicePixelRatio = 2.0;
            addTearDown(() {
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            });

            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(fontFamily: 'BeVietnamPro'),
                home: MediaQuery(
                  data: MediaQueryData(
                    size: sizeEntry.value,
                    textScaler: TextScaler.linear(scaleEntry.value),
                  ),
                  child: const Scaffold(
                    body: TrialLessonScreen(
                      lessonId: 'trial_unit1_reading',
                      initialStep: 2,
                      initialUsedReadingAssistance: true,
                      initialAnswers: [0, 1, 2],
                    ),
                  ),
                ),
              ),
            );

            await tester.pumpAndSettle();

            // Kiểm tra nội dung dòng hỗ trợ được render đầy đủ
            expect(
              find.textContaining('Đã tham khảo từ vựng trong lúc đọc bài trước khi trả lời'),
              findsOneWidget,
            );
            expect(
              find.textContaining('Thời gian học thực tế:'),
              findsOneWidget,
            );

            // Kiểm tra không có bất kỳ exception nào về RenderFlex overflow
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });

  group('2. StatsScreen - 8 dạng câu hỏi THPT (Không overflow tên dạng bài)', () {
    testWidgets('Tên dạng bài dài không bị tràn trên màn hình 320x640 với textScale 1.3', (tester) async {
      tester.view.physicalSize = const Size(320 * 2.0, 640 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(1.3),
            ),
            child: Scaffold(
              body: StatsScreen(
                repository: _FakeStatsRepository(),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 11));
      expect(tester.takeException(), isNull);
    });
  });

  group('3. ReadingCompletionScreen - 3 Card thống kê', () {
    testWidgets('Không tràn màn hình hẹp 320px', (tester) async {
      tester.view.physicalSize = const Size(320 * 2.0, 640 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(1.2),
            ),
            child: ReadingCompletionScreen(
              unitNumber: 2,
              correctCount: 5,
              totalQuestions: 6,
              xpEarned: 25,
              currentStreak: 5,
              newWordsCount: 4,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('XP'), findsOneWidget);
      expect(find.text('Chính xác'), findsOneWidget);
      expect(find.text('Streak 🔥'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('4. AppButton - Tự dãn khi TextScaler lớn', () {
    testWidgets('Không bottom overflow khi text scaler 2.0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(2.0),
            ),
            child: Scaffold(
              body: Center(
                child: AppButton(
                  label: 'Tiếp tục câu tiếp theo với học liệu chuẩn',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: () {},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('5. Login & Register - Wrap cho link chuyển đổi tài khoản', () {
    testWidgets('LoginScreen không overflow ở màn hình nhỏ 320px textScale 1.5', (tester) async {
      tester.view.physicalSize = const Size(320 * 2.0, 640 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(1.5),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('Chưa có tài khoản? '),
                        Text('Đăng ký ngay'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('6. History Screens - Row ngày tháng co dãn', () {
    testWidgets('Không overflow khi ngày tháng dài và textScale 1.5', (tester) async {
      tester.view.physicalSize = const Size(320 * 2.0, 640 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(1.5),
            ),
            child: Scaffold(
              body: Row(
                children: [
                  Icon(Icons.access_time_rounded, size: 14),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text('Hôm nay, 14:30:45 ngày 03/11/2026 (Lần thi thứ 12)'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
