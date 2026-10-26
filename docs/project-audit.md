# Kiểm tra dự án — 26/10/2026

## Phân công đã cập nhật
Tài và An đổi vai trò: Tài phụ trách `lib/data/` và `lib/navigation/`; An phụ trách theme/home/stats/settings. Phần UI đã làm trước khi nhận thông tin đổi vai trò được giữ tại nhánh local `codex/tai-ui-handoff`, không có trong diff cuối của `feature/tai`.

## Hiện trạng
- Main có Flutter/Material 3, Provider, SQLite, 8 bảng dữ liệu và 4 tab placeholder. Chưa có backend máy chủ.
- Assets trên main có 3 chủ đề, 3 từ, 3 câu hỏi; chưa đủ cho thi thử hoàn chỉnh.
- Nhánh `feature/Vien` có luồng luyện/thi thử và chữ ký `savePracticeResult`; nhánh `feature/Luong` có phần từ vựng. Đây là công việc chưa có trên main, không nên triển khai lại.
- Remote chưa có develop; PR vào main để leader duyệt, không tự merge.

## Đã hoàn thiện trong PR này
API `AppRepository.savePracticeResult` giữ đúng interface đang được nhánh Viễn dùng. Lưu lượt làm, đáp án, câu sai và thống kê ngày trong một transaction; kiểm tra dữ liệu nhất quán và chấm đáp án theo câu hỏi có trong DB. SQL lỗi hoặc callback lỗi đều rollback, không để kết quả dở dang. Giữ nguyên các API cũ.

## Việc tiếp theo
- Tích hợp API với nhánh Viễn, kiểm thử luồng nộp bài trên thiết bị thật.
- Đảm bảo seed dữ liệu đồng bộ và có xử lý lỗi khởi động để app không dừng trước runApp.
- Rà soát mở DB đồng thời, ràng buộc/di trú dữ liệu và whitelist tên bảng trong helper isTableEmpty.
- Thống nhất khóa chống gửi trùng nếu cần hỗ trợ retry tự động; hiện caller phải chặn nộp lặp.
- Bổ sung dữ liệu đã được rà soát, CI và kiểm thử plugin theo nền tảng hỗ trợ.

Chưa thêm server hoặc tự gộp các nhánh của thành viên khác.
