# Số đếm từ vựng theo dữ liệu thật — 30/10/2026

Màn danh sách chủ đề trước đây ghi cố định 10 chủ đề, 200 từ và 20 từ/chủ đề; tiến độ chủ đề suy ra từ tiền tố ID. Khi dữ liệu có ID cũ, chủ đề tự đặt hoặc số từ khác mẫu, màn hình báo sai.

Provider nay lấy danh sách từ của từng chủ đề qua AppRepository, sử dụng ánh xạ chủ đề cũ/mới sẵn có. Tổng số từ đếm ID duy nhất trong các chủ đề đang hiển thị; tiến độ chỉ tính những ID còn thuộc danh sách. Thanh tiến độ chủ đề rỗng bằng 0, không chia cho 0. Các bản ghi học tập vẫn được giữ nguyên.

Không đổi schema, thêm thư viện hoặc Kotlin. Chỉ sửa provider và nội dung số đếm trên giao diện hiện có. Các từ giống nội dung nhưng khác ID vẫn được xem là những bản ghi riêng.

Kiểm thử: widget test với ID không theo mẫu, từ thuộc chủ đề cũ do repository trả về, tiến độ của từ đã xóa, chủ đề rỗng, dữ liệu rỗng và cập nhật sau khi học. Test tương thích chủ đề hiện có kiểm tra ánh xạ ở tầng SQLite. Chạy `flutter test --no-pub` và `flutter analyze --no-pub`. Chưa kiểm thử thiết bị thật.

Nhánh `feature/tai-vocab-counts` xuất phát từ `main`, độc lập PR #5/#6; chỉ leader merge.
