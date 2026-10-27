# Khởi động và nạp dữ liệu an toàn

Ứng dụng hiển thị giao diện ngay, sau đó `AppStartup` mở SQLite và nạp dữ liệu. Chỉ khi thành công mới vào MainShell. Lỗi được hiển thị bằng thông báo chung, không đưa đường dẫn/nội dung lỗi nội bộ lên màn hình; nút Thử lại khởi tạo lại và chặn gọi song song.

`AssetSeeder.seedIfEmpty` giữ giao diện cũ, thêm `AssetBundle? bundle` tùy chọn. Kiểm tra bảng rỗng và nạp topics/words/questions nằm trong cùng transaction. JSON hỏng, root không phải list, bản ghi không đúng kiểu, trùng ID hoặc lỗi SQL đều throw và rollback; không thay thế bảng đã có dữ liệu. Transaction ngăn hai lần seed đồng thời cùng ghi vào bảng rỗng.

Không tự xóa database khi lỗi. Nếu tài nguyên bị hỏng hoặc nền tảng không hỗ trợ plugin SQLite, thử lại có thể vẫn thất bại; cần sửa tài nguyên/môi trường chạy, không xóa tiến độ để che lỗi.

## Kiểm chứng ngày 27/10/2026

- 30/30 kiểm thử đạt: 15 lưu kết quả, 7 seed SQLite, 7 startup widget và 1 smoke test.
- Seed test dùng SQLite thật trong bộ nhớ qua transport Python có sẵn, gồm lỗi file/SQL, rollback, giữ dữ liệu cũ, chạy lặp/đồng thời và thử lại.
- Startup test gồm loading/success, lỗi đồng bộ/bất đồng bộ, retry nhiều lần, chặn hai callback cùng frame, rebuild không khởi tạo lại, dispose khi đang chờ và màn hình 320×568 với chữ 2×.
- `flutter analyze --no-pub` và `git diff --check` sạch.
- Review độc lập phần seed/startup không phát hiện lỗi quan trọng mới.

Chưa build release hoặc kiểm thử plugin native Android/iOS trên thiết bị. Các test dùng initializer giả cho widget; kết nối SQLite và assets được kiểm tra riêng trong seed test.
