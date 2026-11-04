import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:thpt_english/data/app_database.dart';
import 'package:thpt_english/data/rbac_proctor_ai_service.dart';

import 'support/sqlite_bridge.dart';

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

  group('Multi-device Class Join & Cloud Sync Acceptance Tests', () {
    late RbacProctorAiService service;

    setUp(() {
      service = RbacProctorAiService.instance;
    });

    test('1. Tạo mã lớp học tự động chuẩn hóa form LOPC-3681', () {
      final code = RbacProctorAiService.generateClassJoinCode('Lớp Chuyên Tin');
      expect(code.contains('-'), isTrue);
      expect(code.startsWith('LOPC'), isTrue);
    });

    test('2. Giáo viên tạo lớp học và lưu vào hệ thống', () async {
      final created = await service.createClass(
        name: 'Lớp 12A1 Chuyên Tin',
        schoolName: 'THPT Chuyên Tin',
        joinCode: 'LPCT-3681',
      );
      expect(created['code'], equals('LPCT-3681'));
      expect(created['name'], equals('Lớp 12A1 Chuyên Tin'));

      final classes = await service.getClasses();
      expect(classes.any((c) => c['code'] == 'LPCT-3681'), isTrue);
    });

    test('3. Học sinh nhập mã lớp LPCT-3681 tham gia thành công', () async {
      final joinRes = await service.joinClassByCode('LPCT-3681');
      expect(joinRes['ok'], isTrue);
      expect(joinRes['status'], isIn(['approved', 'pending']));

      final joinedList = await service.getMyJoinedClasses();
      expect(joinedList.any((c) => c['code'] == 'LPCT-3681'), isTrue);
    });

    test('4. Nhập mã lớp không tồn tại trả về thông báo lỗi rõ ràng', () async {
      final joinRes = await service.joinClassByCode('KHONG-CO-MA-NAY-999');
      expect(joinRes['ok'], isFalse);
      expect(joinRes['message'].toString().contains('Không tìm thấy lớp học'), isTrue);
    });

    test('5. Giải tán lớp học xóa sạch khỏi danh sách và không bị tự hồi sinh', () async {
      final classesBefore = await service.getClasses();
      final target = classesBefore.where((c) => c['code'] == 'LPCT-3681').firstOrNull;
      expect(target, isNotNull);

      final deleteSuccess = await service.deleteClass(target!['id']);
      expect(deleteSuccess, isTrue);

      final classesAfter = await service.getClasses();
      expect(classesAfter.any((c) => c['code'] == 'LPCT-3681'), isFalse);
      expect(classesAfter.any((c) => c['id'] == target['id']), isFalse);

      final joinedAfter = await service.getMyJoinedClasses();
      expect(joinedAfter.any((c) => c['code'] == 'LPCT-3681'), isFalse);
    });
  });
}
