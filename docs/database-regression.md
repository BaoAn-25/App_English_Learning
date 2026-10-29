# Kiểm thử vòng đời SQLite — 29/10/2026

Phạm vi phần Tài: xác minh mở database, thử lại sau lỗi và bảo toàn dữ liệu khi nâng cấp v1 → v2. Không thay đổi mã sản phẩm, schema hay thêm dependency.

## Các tình huống đã bổ sung

- `test/database_open_test.dart`: lỗi tại lần mở nền tảng đầu tiên được trả về; 20 lời gọi tiếp theo chồng lấn trong lúc đang mở nhận cùng một kết nối. Database có schema/cài đặt mặc định hợp lệ; đọc/ghi và truy cập tiếp theo không mở lại.
- `test/database_migration_test.dart`: tạo một tệp SQLite v1 trong thư mục tạm, điền dữ liệu ở cả 8 bảng cũ, đóng rồi mở bằng `AppDatabase.instance.database` để chạy migration sản phẩm. Kiểm tra nguyên vẹn dữ liệu, phiên bản 2, bảng `word_progress` có thể ghi với giá trị mặc định đúng, ID bài làm tiếp tục tăng và dữ liệu còn sau khi đóng/mở lại.
- `test/fixtures/database_v1.sql`: schema v1 lấy từ lịch sử `e465e6c^`, độc lập với hàm tạo schema hiện tại. Không lấy schema hiện tại rồi hạ số phiên bản để giả lập v1.

Bộ hỗ trợ test giữ sqflite phía Dart và SQL thật, chỉ thay kênh nền tảng bằng tiến trình Python SQLite. Mặc định vẫn chạy trong bộ nhớ; chế độ thư mục tạm phục vụ kiểm tra lưu bền. Hook `beforeCall` cho phép tạo lỗi và giữ thao tác mở để kiểm tra đồng thời một cách xác định. Mỗi file kiểm thử có vòng đời riêng vì singleton sản phẩm không có API reset dành cho test.

## Cách chạy

```sh
flutter test --no-pub test/database_open_test.dart test/database_migration_test.dart
flutter test --no-pub
flutter analyze --no-pub
git diff --check
```

Đã kiểm tra độ nhạy bằng hai thay đổi lỗi tạm thời: bỏ `onUpgrade` làm bài migration thất bại vì thiếu `word_progress`; tắt `singleInstance` làm bài mở đồng thời thất bại vì các kết nối khác nhau. Đã khôi phục toàn bộ mã sản phẩm sau kiểm tra.

## Giới hạn

Đây là kiểm thử hồi quy trên máy, không phải kiểm thử Android/iOS thật. SQLite dùng thư viện chuẩn Python; không xác minh toàn bộ hành vi driver native, TTS, thông báo hay sự cố mất điện. Chưa phát hiện lỗi cần sửa trong mã sản phẩm ở các tình huống được kiểm tra. Nhánh công việc từ `main`, PR vào `main` theo quyết định của người dùng cho nhiệm vụ này; không tạo `develop`.
