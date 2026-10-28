# Lưu kết quả bài làm

Gọi `AppRepository.savePracticeResult` một lần khi nộp bài; chỉ hiển thị thành công sau khi `await` hoàn tất. Giao diện giống API trên nhánh Viễn:

```dart
await repository.savePracticeResult(
  attempt: attempt,
  buildAnswers: (attemptId) => [
    for (var i = 0; i < questions.length; i++)
      AttemptAnswer(
        attemptId: attemptId,
        questionId: questions[i].id,
        chosenIndex: selectedAnswers[i] ?? -1,
        isCorrect: selectedAnswers[i] == questions[i].correctIndex,
      ),
  ],
  wrongEntries: wrongEntries,
  dailyStat: dailyStat,
);
```

## Quy tắc dữ liệu
- Lượt làm mới: `id == null`, mode không rỗng, thời gian không âm, `total > 0`, score từ 0 đến total.
- Có đúng một đáp án cho mỗi câu, gắn đúng attemptId được truyền vào callback. `-1` nghĩa là bỏ trống; chỉ số khác phải nằm trong options. Câu hỏi phải tồn tại trong DB, cờ đúng/sai phải khớp đáp án trong DB.
- Sổ sai chứa đúng tập câu trả lời sai/bỏ trống, mỗi câu tăng wrongCount bằng 1; thời điểm ôn lại không trước thời điểm trả lời sai.
- Thống kê dùng ngày địa phương dạng yyyy-MM-dd hợp lệ; questionsDone/ correct khớp total/score, XP và phút không âm. Caller quyết định chính sách thưởng XP và làm tròn phút.
- Một transaction bao gồm cả bốn bảng. `ArgumentError`, lỗi callback hoặc SQLite đều được đưa về caller và hoàn tác dữ liệu mới. Không nuốt lỗi, không tự retry.
- Hai lần gọi thành công được coi là hai lượt làm, kể cả dữ liệu giống nhau. Caller cần chặn nộp lặp. Chưa có khóa idempotency.

## Kiểm chứng
Flutter 3.47.7 / Dart 3.13.5. Dependency được resolve offline từ cache; không thêm package. Lockfile đổi 6 phiên bản theo SDK/cache, gồm sqflite 2.4.4+1 → 2.4.4; cần leader xác nhận tương thích SDK nhóm.

```sh
flutter test --no-pub --reporter expanded
flutter analyze --no-pub
git diff --check
```

16/16 kiểm thử đạt: 15 kiểm thử chức năng lưu và 1 smoke test. Có lưu thành công, câu bỏ trống, thi đúng hết, hai lần nộp đồng thời, ngày khác nhau, dữ liệu sai/trùng/không tồn tại, lỗi callback, lỗi SQL lúc ghi mới và lúc cộng dồn, rollback và thử lại.

Kiểm thử dữ liệu cần `python3` với module chuẩn `sqlite3`. `test/support/sqlite_bridge.dart` thay transport MethodChannel của sqflite, chuyển SQL thật sang SQLite trong bộ nhớ qua `test/support/sqlite_bridge.py`. Schema, transaction và query chạy thật; không mở database của người dùng, không truy cập mạng. Không cần package FFI bổ sung.

## Giới hạn
- Chưa kiểm thử plugin Android/iOS trên thiết bị hoặc build release; Python SQLite không thay thế kiểm thử plugin native.
- UI trên main vẫn là placeholder; PR này hoàn thiện API tầng dữ liệu tương thích với luồng UI của nhánh Viễn.
- Chưa có CI. Reviewer độc lập bị giới hạn sử dụng trước khi review thay đổi dữ liệu; đã tự rà soát nhưng vẫn cần leader review.
