import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:thpt_english/data/app_repository.dart';
import 'support/fake_repository.dart';
import 'package:thpt_english/navigation/main_shell.dart';

void main() {
  testWidgets('Smoke test: kiem tra MainShell va chuyen doi 4 tab', (
    WidgetTester tester,
  ) async {
    // Khoi dong MainShell trong MaterialApp khong phu thuoc SQLite
    await tester.pumpWidget(
      Provider<AppRepository>.value(
        value: FakeRepository(),
        child: const MaterialApp(home: MainShell()),
      ),
    );

    await tester.pumpAndSettle();

    // Kiem tra hien thi 4 muc tren NavigationBar
    expect(find.text('Học'), findsWidgets);
    expect(find.text('Luyện đề'), findsWidgets);
    expect(find.text('Thống kê'), findsWidgets);
    expect(find.text('Cá nhân'), findsWidgets);

    // Ban dau tab 'Học' dang duoc chon
    expect(find.text('Học Từ Vựng & Chuyên Đề'), findsOneWidget);

    // Chuyen sang tab 'Luyện đề'
    await tester.tap(find.text('Luyện đề').first);
    await tester.pumpAndSettle();

    // Kiem tra man hinh Luyen de xuat hien
    expect(find.text('Luyện Theo Dạng Bài'), findsOneWidget);
  });
}
