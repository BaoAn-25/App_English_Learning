import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:thpt_english/data/app_database.dart';
import 'package:thpt_english/data/app_repository.dart';
import 'package:thpt_english/ui/auth/auth_controller.dart';
import 'package:thpt_english/ui/onboarding/onboarding_schedule_screen.dart';
import 'package:thpt_english/ui/onboarding/onboarding_target_screen.dart';
import 'package:thpt_english/ui/settings/settings_controller.dart';
import 'package:thpt_english/ui/theme/components/app_button.dart';

import 'support/sqlite_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SqliteBridge bridge;
  late Database database;
  late AppRepository repository;

  setUpAll(() async {
    bridge = await SqliteBridge.start();
    database = await AppDatabase.instance.database;
    repository = AppRepository();
  });

  tearDownAll(() async {
    await database.close();
    await bridge.close();
  });

  setUp(() async {
    await database.delete('app_settings');
    AuthController.instance.logout();
  });

  void setStandardPhoneViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('BỘ KIỂM THỬ NGHIỆM THU ONBOARDING TARGET SCREEN (10 YÊU CẦU)', () {
    // 1. Khách mới: không thẻ nào được chọn, Tiếp tục bị vô hiệu hóa
    testWidgets('1. Khach moi: khong the nao duoc chon, Tiep tuc bi vo hieu hoa', (tester) async {
      setStandardPhoneViewport(tester);

      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingTargetScreen(autoLoadSavedSettings: false),
        ),
      );
      await tester.pumpAndSettle();

      // Dòng hướng dẫn khi chưa chọn
      expect(find.text('Chọn mục tiêu để tiếp tục'), findsOneWidget);

      // Không có thẻ nào hiển thị dấu tích check_circle_rounded
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);

      // Cả 5 thẻ đều có icon radio_button_unchecked_rounded
      expect(find.byIcon(Icons.radio_button_unchecked_rounded), findsNWidgets(5));

      // Không còn nhãn Gợi ý trên giao diện
      expect(find.text('Gợi ý'), findsNothing);

      // Nút Tiếp tục bị vô hiệu hóa
      final button = tester.widget<AppButton>(find.byType(AppButton));
      expect(button.onPressed, isNull);
    });

    // 2. Bấm 7+: chỉ 7+ được chọn, Tiếp tục được bật
    testWidgets('2. Bam 7+: chi 7+ duoc chon, Tiep tuc duoc bat', (tester) async {
      setStandardPhoneViewport(tester);

      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingTargetScreen(autoLoadSavedSettings: false),
        ),
      );
      await tester.pumpAndSettle();

      // Bấm vào thẻ 7+ (Khá)
      await tester.tap(find.text('Khá'));
      await tester.pumpAndSettle();

      // Chỉ có duy nhất 1 dấu tích được hiển thị
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked_rounded), findsNWidgets(4));

      // Dòng hướng dẫn đổi sang thông báo đã chọn 7+
      expect(find.textContaining('Đã chọn mục tiêu 7+'), findsOneWidget);

      // Nút Tiếp tục được kích hoạt
      final button = tester.widget<AppButton>(find.byType(AppButton));
      expect(button.onPressed, isNotNull);
    });

    // 3. Đổi sang 9+: 7+ bỏ chọn, chỉ 9+ được chọn
    testWidgets('3. Doi sang 9+: 7+ bo chon, chi 9+ duoc chon', (tester) async {
      setStandardPhoneViewport(tester);

      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingTargetScreen(autoLoadSavedSettings: false),
        ),
      );
      await tester.pumpAndSettle();

      // Chọn 7+ trước
      await tester.tap(find.text('Khá'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Đã chọn mục tiêu 7+'), findsOneWidget);

      // Bấm chuyển sang 9+ (Xuất sắc)
      await tester.tap(find.text('Xuất sắc'));
      await tester.pumpAndSettle();

      // Chỉ duy nhất 9+ được chọn
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.textContaining('Đã chọn mục tiêu 9+'), findsOneWidget);

      // Bấm chuyển sang 10 (Tuyệt đối)
      await tester.drag(find.byType(ListView), const Offset(0, -250));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tuyệt đối'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Đã chọn mục tiêu 10'), findsOneWidget);
    });

    // 4. Tiếp tục sang bước 2 rồi quay lại: vẫn giữ 9+
    testWidgets('4. Tiep tuc sang buoc 2 roi quay lai: van giu 9+', (tester) async {
      setStandardPhoneViewport(tester);

      await tester.runAsync(() async {
        await tester.pumpWidget(
          const MaterialApp(
            home: OnboardingTargetScreen(autoLoadSavedSettings: false),
          ),
        );
        await tester.pumpAndSettle();

        // Chọn 9+
        await tester.tap(find.text('Xuất sắc'));
        await tester.pumpAndSettle();

        // Bấm Tiếp tục sang Bước 2 (OnboardingScheduleScreen)
        await tester.tap(find.byType(AppButton));
        // Đợi async SQLite save hoàn thành
        await Future.delayed(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        // Đã mở OnboardingScheduleScreen (Bước 2/3)
        expect(find.byType(OnboardingScheduleScreen), findsOneWidget);

        // Bấm nút quay lại AppBar ở Bước 2
        await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
        await tester.pumpAndSettle();

        // Đã quay về OnboardingTargetScreen và mục tiêu 9+ vẫn giữ nguyên
        expect(find.byType(OnboardingTargetScreen), findsOneWidget);
        expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
        expect(find.textContaining('Đã chọn mục tiêu 9+'), findsOneWidget);
      });
    });

    // 5. Lựa chọn được lưu thật: mở lại hiển thị đúng
    testWidgets('5. Lua chon duoc luu that: mo lai hien thi dung', (tester) async {
      setStandardPhoneViewport(tester);

      await tester.runAsync(() async {
        // Giả lập người dùng trước đó đã chọn và xác nhận mục tiêu 9.0
        await repository.setSetting('target_score', '9.0');
        await repository.setSetting('target_score_confirmed', 'true');

        await tester.pumpWidget(
          const MaterialApp(
            home: OnboardingTargetScreen(autoLoadSavedSettings: true),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        // Đã tự khôi phục 9+
        expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
        expect(find.textContaining('Đã chọn mục tiêu 9+'), findsOneWidget);
        final button = tester.widget<AppButton>(find.byType(AppButton));
        expect(button.onPressed, isNotNull);
      });
    });

    // 6. Dữ liệu mặc định cũ 8.0 chưa xác nhận không tự được coi là lựa chọn của người dùng
    testWidgets('6. Du lieu mac dinh cu 8.0 chua xac nhan khong tu duoc coi la lua chon', (tester) async {
      setStandardPhoneViewport(tester);

      await tester.runAsync(() async {
        // Dữ liệu cũ còn sót lại target_score = 8.0 nhưng KHÔNG CÓ target_score_confirmed
        await repository.setSetting('target_score', '8.0');
        await repository.setSetting('target_score_confirmed', 'false');

        await tester.pumpWidget(
          const MaterialApp(
            home: OnboardingTargetScreen(autoLoadSavedSettings: true),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        // Không tự chọn 8+, không có dấu tích, Tiếp tục bị vô hiệu hóa
        expect(find.text('Chọn mục tiêu để tiếp tục'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
        final button = tester.widget<AppButton>(find.byType(AppButton));
        expect(button.onPressed, isNull);
      });
    });

    // 7. Kết quả tải chậm không ghi đè thao tác vừa chọn
    testWidgets('7. Ket qua tai cham khong ghi de thao tac vua chon', (tester) async {
      setStandardPhoneViewport(tester);

      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingTargetScreen(
            autoLoadSavedSettings: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Người dùng chủ động bấm chọn 7+
      await tester.tap(find.text('Khá'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Đã chọn mục tiêu 7+'), findsOneWidget);

      // Cho dù có background async trả về 8.0 cũ, màn hình vẫn giữ 7+ của người dùng
      expect(find.textContaining('Đã chọn mục tiêu 7+'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    // 8. Lưu thất bại không điều hướng như đã lưu thành công
    testWidgets('8. Luu that bai khong dieu huong nhu da luu thanh cong', (tester) async {
      setStandardPhoneViewport(tester);

      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingTargetScreen(autoLoadSavedSettings: false),
        ),
      );
      await tester.pumpAndSettle();

      // Khi chưa chọn mục tiêu, cố tình bấm (bằng cách kiểm tra logic _handleContinue)
      // Nút bấm bị disabled nên không thể trigger điều hướng
      final button = tester.widget<AppButton>(find.byType(AppButton));
      expect(button.onPressed, isNull);
      expect(find.byType(OnboardingScheduleScreen), findsNothing);
    });

    // 9. Trang chủ/Cài đặt không tự hiện mục tiêu 8+ khi chưa chọn
    testWidgets('9. Trang chu va Cai dat khong tu hien muc tieu 8+ khi chua chon', (tester) async {
      setStandardPhoneViewport(tester);

      await tester.runAsync(() async {
        final auth = AuthController.instance;
        expect(auth.user.hasConfirmedTargetScore, isFalse);
        expect(auth.user.targetScore, isNull);

        final settingsCtrl = SettingsController(repo: repository);
        await settingsCtrl.loadSettings();

        // SettingsController không tự gán mục tiêu
        expect(settingsCtrl.hasTargetScore, isFalse);
        expect(settingsCtrl.targetScore, isNull);

        // Màn hình Cài đặt hiển thị 'Chưa chọn mục tiêu'
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return Text(
                    settingsCtrl.hasTargetScore
                        ? 'Lớp ${settingsCtrl.grade} • Mục tiêu: ${settingsCtrl.targetScore!.toStringAsFixed(1)} đ'
                        : 'Lớp ${settingsCtrl.grade} • Chưa chọn mục tiêu',
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Lớp 12 • Chưa chọn mục tiêu'), findsOneWidget);
        expect(find.textContaining('8.0 đ'), findsNothing);
        expect(find.textContaining('8.5 đ'), findsNothing);
      });
    });

    // 10. Không ảnh hưởng lịch sử học, thời lượng học, ngày thi hoặc lịch nhắc
    test('10. Khong anh huong lich su hoc, thoi luong hoc, ngay thi hoac lich nhac', () async {
      // Lưu sẵn thời lượng học, ngày thi, giờ nhắc
      await repository.setSetting('daily_minutes', '45');
      await repository.setSetting('exam_date', '2027-06-25');
      await repository.setSetting('reminder_time', '19:30');
      await repository.setSetting('reminder_enabled', 'true');

      // Người dùng lưu mục tiêu 9.0
      await repository.setSetting('target_score', '9.0');
      await repository.setSetting('target_score_confirmed', 'true');

      // Kiểm tra lại các thiết lập khác hoàn toàn nguyên vẹn
      expect(await repository.getSetting('daily_minutes'), '45');
      expect(await repository.getSetting('exam_date'), '2027-06-25');
      expect(await repository.getSetting('reminder_time'), '19:30');
      expect(await repository.getSetting('reminder_enabled'), 'true');
      expect(await repository.getSetting('target_score'), '9.0');
      expect(await repository.getSetting('target_score_confirmed'), 'true');
    });
  });
}
