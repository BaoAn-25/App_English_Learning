# Khởi động và nạp dữ liệu an toàn

Ứng dụng hiển thị giao diện ngay, sau đó `AppStartup` mở/nâng cấp SQLite, seed các bảng rỗng, bổ sung chủ đề/từ vựng thiếu rồi đồng bộ câu hỏi qua QuestionSyncService. Chỉ khi thành công mới vào MainShell. Lỗi được hiển thị bằng thông báo chung, không đưa đường dẫn/nội dung lỗi nội bộ lên màn hình; nút Thử lại khởi tạo lại và chặn gọi song song.

`AssetSeeder.seedIfEmpty` giữ giao diện cũ, thêm `AssetBundle? bundle` tùy chọn. Kiểm tra bảng rỗng và nạp topics/words/questions nằm trong cùng transaction. JSON hỏng, root không phải list, bản ghi không đúng kiểu, trùng ID hoặc lỗi SQL đều throw và rollback; không thay thế bảng đã có dữ liệu. Transaction ngăn hai lần seed đồng thời cùng ghi vào bảng rỗng.

Không tự xóa database khi lỗi. Nếu tài nguyên bị hỏng hoặc nền tảng không hỗ trợ plugin SQLite, thử lại có thể vẫn thất bại; cần sửa tài nguyên/môi trường chạy, không xóa tiến độ để che lỗi.

## Kiểm chứng ngày 27/10/2026

- 30/30 kiểm thử đạt: 15 lưu kết quả, 7 seed SQLite, 7 startup widget và 1 smoke test.
- Seed test dùng SQLite thật trong bộ nhớ qua transport Python có sẵn, gồm lỗi file/SQL, rollback, giữ dữ liệu cũ, chạy lặp/đồng thời và thử lại.
- Startup test gồm loading/success, lỗi đồng bộ/bất đồng bộ, retry nhiều lần, chặn hai callback cùng frame, rebuild không khởi tạo lại, dispose khi đang chờ và màn hình 320×568 với chữ 2×.
- `flutter analyze --no-pub` và `git diff --check` sạch.
- Review độc lập phần seed/startup không phát hiện lỗi quan trọng mới.

Chưa build release hoặc kiểm thử plugin native Android/iOS trên thiết bị. Ngoài test widget với initializer giả, startup_data_test chạy luồng khởi động mặc định với SQLite thật trong bộ nhớ: bổ sung câu hỏi trên bản cài đã có dữ liệu, rollback khi đồng bộ lỗi và retry thành công. TTS được giả lập ở kênh nền tảng.

## Kiểm chứng sau tích hợp main

- 195/195 test đạt trên bộ mã đã gộp luyện thi và từ vựng; analyzer không báo lỗi.
- Giữ schema v2/migration và API từ main; whitelist bao gồm bảng word_progress.
- Luồng seed → sync → MainShell được kiểm thử với SQLite thật trong bộ nhớ, gồm lỗi đồng bộ và retry.
- Khóa chọn đáp án khi đang lưu bài luyện tập; test trì hoãn ghi xác nhận điểm và đáp án không lệch nhau.

## Bổ sung chủ đề và từ vựng khi nâng cấp

`AssetSeeder.syncVocabulary` đọc topics/words từ assets và chỉ thêm ID chưa tồn tại. Hai bảng được xử lý trong cùng transaction; lỗi JSON/SQL, ID trống/trùng hoặc từ mới tham chiếu chủ đề không tồn tại làm rollback đợt đồng bộ. Bản ghi có sẵn và word_progress không bị ghi đè; chạy lặp/đồng thời không thêm trùng ID.

AppStartup gọi sau seed và trước đồng bộ câu hỏi. Lỗi đồng bộ từ vựng được đưa vào màn hình lỗi/Thử lại; chỉ mở MainShell khi mọi bước hoàn tất. Mỗi bước có transaction riêng, không rollback bước đã hoàn tất trước đó.

Không tự suy đoán các ID khác nhau là cùng một mục: bản cài có 3 chủ đề cũ với ID khác 10 chủ đề mới sẽ giữ cả 13 mục. Muốn hợp nhất phải có quy tắc ánh xạ ID được thống nhất, để bảo toàn liên kết và tiến độ.

Kiểm chứng sau bổ sung: 202/202 test đạt, analyzer sạch; gồm giữ dữ liệu/tiến độ cũ, đồng bộ lặp/đồng thời, rollback và retry sau lỗi đồng bộ từ vựng. Review độc lập không có phát hiện cần sửa.
