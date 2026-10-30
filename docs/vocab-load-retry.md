# Tải lại dữ liệu từ vựng — 30/10/2026

Ba luồng chủ đề, danh sách từ và ôn đến hạn trước đây nuốt lỗi đọc dữ liệu, khiến người dùng nhìn thấy trạng thái rỗng hoặc dữ liệu của chủ đề trước.

Bản sửa tách trạng thái tải/lỗi từng luồng. Màn hình báo lỗi chung và có nút Thử lại, không hiện thông tin DB nội bộ. Danh sách từ cũ được bỏ khỏi giao diện khi đổi chủ đề; kết quả cũ hoàn tất muộn không ghi đè yêu cầu mới. Các caller tải từ đến hạn đồng thời chờ cùng một Future.

Không thay đổi hoặc xóa dữ liệu lưu trữ, không thêm dependency/Kotlin. Danh sách thực sự rỗng có thông báo riêng.

Kiểm chứng: 238/238 test đạt, flutter analyze --no-pub sạch, git diff --check đạt. Năm test mới gồm retry ở ba màn, phản hồi chủ đề sai thứ tự và tải từ đến hạn đồng thời. Reviewer độc lập không phát hiện lỗi cần sửa. Chưa kiểm thử điện thoại thật/build APK cho bản sửa này.

Nhánh feature/tai-vocab-load-retry kế thừa PR #8; cần leader duyệt/merge #7 rồi #8 trước khi kiểm tra diff cuối của PR này. Chỉ leader merge.
