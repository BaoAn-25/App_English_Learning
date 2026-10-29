# Lưu tiến độ từ vựng an toàn — 30/10/2026

Trước bản sửa, provider cập nhật tiến độ trong bộ nhớ trước khi SQLite ghi xong. Lưu thất bại vẫn để lại tiến độ mới; đánh dấu đã xem thất bại còn khiến lần thử lại bị bỏ qua. Hai màn Flashcard/SRS không khóa thao tác trong khi lưu, dễ ghi nhiều lần hoặc chuyển thẻ sai khi bấm nhanh.

Bản sửa chỉ công bố tiến độ sau khi ghi thành công. Flashcard khóa lật, trả lời và bỏ qua trong lúc ghi/chuyển thẻ; SRS khóa trả lời trong lúc ghi. Khi lỗi, giữ thẻ, thông báo ngắn và cho bấm lại. Khi màn hình/provider đã đóng, tác vụ hoàn tất không thông báo hoặc chạy animation vào đối tượng đã hủy. Thẻ cuối đã trả lời không được ghi thêm lần nữa.

SRS nạp dữ liệu sau khung hình đầu tiên để tránh notify trong build; tiêu đề kết quả co giãn trên màn hình hẹp. Không thay đổi schema, lịch ôn hoặc thêm thư viện/Kotlin.

Kiểm thử hồi quy: lỗi lưu đúng/sai/đã xem, thử lại không cộng thừa, provider bị hủy trong lúc lưu, bấm lặp và đóng cả hai màn trong lúc lưu. Chạy toàn bộ `flutter test --no-pub` và `flutter analyze --no-pub`. Không có kiểm thử thiết bị thật.

Nhánh `feature/tai-vocab-save` kế thừa PR #7. PR vào main, chỉ leader merge.
