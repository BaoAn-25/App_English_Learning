# Kiểm tra dự án — 26/10/2026

## Phân công đã cập nhật
Tài và An đổi vai trò: Tài phụ trách `lib/data/` và `lib/navigation/`; An phụ trách theme/home/stats/settings. Phần UI đã làm trước khi nhận thông tin đổi vai trò được giữ tại nhánh local `codex/tai-ui-handoff`, không có trong diff cuối của `feature/tai`.

## Hiện trạng
- Main đã tích hợp luyện thi và từ vựng; dùng Flutter/Material 3, Provider, SQLite phiên bản 2 với 9 bảng, gồm word_progress. Chưa có backend máy chủ.
- Assets sau tích hợp có 10 chủ đề, 200 từ và 405 câu hỏi.
- Main đã nhận PR luyện thi của Viễn, từ vựng của Lượng và giao diện của An. feature/tai gộp main, giữ các API mới, migration và phần kiểm tra/lưu dữ liệu an toàn.
- Remote chưa có develop; PR vào main để leader duyệt, không tự merge.

## Đã hoàn thiện trong PR này
API `AppRepository.savePracticeResult` giữ đúng interface đang được nhánh Viễn dùng. Lưu lượt làm, đáp án, câu sai và thống kê ngày trong một transaction; kiểm tra dữ liệu nhất quán và chấm đáp án theo câu hỏi có trong DB. SQL lỗi hoặc callback lỗi đều rollback, không để kết quả dở dang. Giữ nguyên các API cũ.

## Việc tiếp theo
- Kiểm thử luồng nộp bài đã tích hợp trên thiết bị thật.
- Theo dõi phản hồi leader và kiểm thử khởi động trên Android/iOS thật.
- Rà soát mở DB đồng thời, ràng buộc/di trú dữ liệu (whitelist tên bảng đã hoàn tất, gồm word_progress).
- Thống nhất khóa chống gửi trùng nếu cần hỗ trợ retry tự động; hiện caller phải chặn nộp lặp.
- Bổ sung dữ liệu đã được rà soát, CI và kiểm thử plugin theo nền tảng hỗ trợ.

Chưa thêm server; chỉ cập nhật feature/tai từ main theo yêu cầu, không tự merge PR vào main.


## Bổ sung ngày 27/10/2026
- Seed ba bảng trong cùng transaction, bảo toàn bảng có dữ liệu và rollback khi lỗi.
- AppStartup có loading/lỗi/thử lại, không hiển thị lỗi nội bộ và chặn retry song song.
- Chi tiết kiểm chứng: [khởi động](startup.md).

- Đã tích hợp đồng bộ câu hỏi vào AppStartup sau seed; lỗi đồng bộ giữ màn hình lỗi và cho phép thử lại.

- Bổ sung đồng bộ chủ đề/từ vựng còn thiếu theo ID trên bản cài cũ, giữ dữ liệu/tiến độ và rollback khi lỗi; AppStartup hỗ trợ thử lại bước này.

- 28/10: sửa hiển thị chủ đề cũ/mới trùng bằng ánh xạ ba cặp ID mẫu tại tầng đọc; mở chung nội dung của hai ID khi metadata khớp, bảo toàn toàn bộ bản ghi và tiến độ. Còn số đếm cố định và các từ cùng nội dung khác ID trong UI từ vựng.

- 28/10: tích hợp main `0f03eae`, bỏ dấu xung đột còn sót trong mã/lockfile/registrant, giữ cả ThemeController và AppStartup. Sửa lỗi notify sau dispose của controller Thống kê/Cài đặt; bốn test tái hiện lỗi trước bản sửa. Đồng bộ máy chủ trong giao diện An vẫn là mô phỏng, chưa có backend thật.
