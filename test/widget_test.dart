import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:thpt_english/data/app_repository.dart';
import 'package:thpt_english/data/models/topic.dart';
import 'package:thpt_english/data/models/word_progress.dart';
import 'package:thpt_english/navigation/main_shell.dart';

class FakeAppRepository extends Fake implements AppRepository {
  @override
  Future<List<Topic>> getTopicsByGrade(int grade) async => [];

  @override
  Future<List<WordProgress>> getAllWordProgress() async => [];
}

void main() {
  testWidgets('Smoke test: kiem tra MainShell va chuyen doi 4 tab', (WidgetTester tester) async {
    // Khoi dong MainShell trong MaterialApp voi FakeAppRepository khong phu thuoc SQLite
    await tester.pumpWidget(
      Provider<AppRepository>.value(
        value: FakeAppRepository(),
        child: const MaterialApp(
          home: MainShell(),
        ),
      ),
    );

    // Kiem tra hien thi 4 muc tren NavigationBar
    expect(find.text('Học'), findsWidgets);
    expect(find.text('Luyện đề'), findsWidgets);
    expect(find.text('Thống kê'), findsWidgets);
    expect(find.text('Cá nhân'), findsWidgets);

    // Ban dau tab 'Học' dang duoc chon (man hinh Tu Vung)
    expect(find.text('Từ Vựng'), findsWidgets);

    // Chuyen sang tab 'Luyện đề'
    await tester.tap(find.text('Luyện đề').first);
    await tester.pumpAndSettle();

    // Kiem tra man hinh Luyen de xuat hien
    expect(find.text('Luyện Theo Dạng Bài'), findsOneWidget);
  });
}
