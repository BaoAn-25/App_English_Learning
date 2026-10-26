# Hoàn thiện lưu kết quả bài làm

Người dùng đã đổi vai trò với An: Tài phụ trách data/navigation; yêu cầu hoàn thiện một chức năng ngay, tự quyết định trong dự án. Phần UI đã giữ riêng tại nhánh local codex/tai-ui-handoff, không nằm trong diff cuối của feature/tai.

## Phạm vi
Giữ chữ ký savePracticeResult đã được Viễn sử dụng ở origin/feature/Vien. Một transaction lưu attempts, attempt_answers, cộng wrong_book và daily_stats. Không merge giao diện của nhánh khác. Đây là API hoàn chỉnh của tầng dữ liệu; màn hình main hiện vẫn là placeholder.

## Quy tắc
- Attempt mới không có id, mode không rỗng, thời gian không âm, total > 0 và score trong khoảng.
- Mỗi câu có đúng một câu trả lời thuộc attempt vừa tạo; -1 là bỏ trống. Đối chiếu câu hỏi thật để kiểm tra lựa chọn và isCorrect.
- Tổng số câu/đúng phải khớp attempt và dailyStat; ngày yyyy-MM-dd hợp lệ, XP/phút không âm. Chính sách thưởng XP vẫn do luồng làm bài quyết định.
- Sổ câu sai phải khớp đúng tập câu sai/bỏ trống, mỗi câu tăng một lần và lịch ôn không trước lần sai.
- Lỗi callback, dữ liệu hoặc SQL bất kỳ phải rollback cả transaction. Các lần nộp khác nhau cộng dồn; API không có khóa chống gửi trùng khi caller gọi hai lần.

## Thực thi
- [x] Viết test đỏ qua AppRepository.
- [x] Thêm API và validation trong AppDatabase/AppRepository.
- [x] Chạy schema/SQL/transaction thật bằng sqflite qua transport kiểm thử Python sqlite3 (chỉ database trong bộ nhớ).
- [x] Kiểm thử lưu thành công, nộp đồng thời, callback lỗi, SQLite lỗi ở bước cuối, giữ dữ liệu cũ và thử lại.
- [x] Tự rà soát; 16/16 test và analyze/diff-check đạt. Reviewer độc lập bị giới hạn sử dụng, cần leader review.
- [ ] Đẩy feature/tai, mở PR tiếng Việt vào main (remote chưa có develop), không merge.
