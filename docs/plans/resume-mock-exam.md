# Tiếp tục bài thi thử — phạm vi được duyệt 29/10/2026

Một bản nháp thi thử cục bộ; giữ đề, hoán vị đáp án, đáp án gốc, cờ, vị trí và thời hạn tuyệt đối. Đóng ứng dụng không dừng thời gian. Hết hạn thì khóa đáp án và hoàn tất khi mở lại. Chưa áp dụng cho bài luyện tập thường.

SQLite v3 thêm bảng bản nháp và biên nhận hoàn tất. Ghi kết quả, thống kê, biên nhận và xóa bản nháp trong cùng transaction; gọi lại trả về lượt làm đã lưu. Chặn ghi cũ bằng revision và chặn tạo lại ID đã hoàn tất. Không thay đổi API lưu bài cũ.

Lưu từng thay đổi trước khi xác nhận lên giao diện; khóa chỉnh sửa trong lúc ghi. Nếu ghi lỗi, giữ trạng thái đã lưu trước đó, thông báo thử lại. Bắt đầu bài mới chỉ khi bản nháp cũ được bỏ bằng xác nhận. Không tự xóa bản nháp bị lỗi hoặc có đề không còn tương thích.

Quyết định: lưu snapshot câu hỏi để so sánh nội dung; khóa cập nhật câu hỏi trong bản nháp khi đồng bộ assets. Nếu dữ liệu bị thay đổi/xóa bằng đường khác, chặn khôi phục/nộp và cho người dùng bỏ bài có xác nhận, không chấm theo đề khác. Đồng hồ offline không bảo đảm chống chỉnh giờ thiết bị.

Thứ tự: test dữ liệu → model/migration/API → test UI → tích hợp màn thi → kiểm thử toàn bộ/review → commit tiếng Việt và PR vào main. Không merge. Kiểm tra main mới và xung đột trước push. Không có thiết bị, không tuyên bố kiểm thử native.

## Phục hồi và kiểm chứng

Bản nháp không đọc được không chặn khởi động: tạm bỏ qua đồng bộ câu hỏi và không đánh dấu phiên bản mới. Màn thi thử cho thử đọc lại hoặc bỏ bản nháp lỗi sau xác nhận. Lệnh bỏ so sánh chính xác payload cũ, nên không xóa nhầm bài mới được tạo trong lúc hộp thoại đang mở. Các lỗi đọc SQLite khác vẫn chỉ cho thử lại.

Kiểm thử dữ liệu dùng SQLite thật qua cầu nối Python: mở lại tệp, migration v1/v2 lên v3, ghi đồng thời, rollback rồi thử lại, chống nộp trùng, khóa nội dung đề đang thi và phục hồi bản nháp hỏng. Widget test kiểm tra khôi phục giao diện, lỗi lưu và thử lại, hết hạn, hủy/xác nhận bỏ bài. Chạy `flutter test --no-pub` và `flutter analyze --no-pub`.

Chỉ lưu một bài thi thử trên thiết bị, chưa đồng bộ đa thiết bị hoặc lưu bài luyện tập thường. Không tuyên bố đã kiểm thử thiết bị thật.

Kết quả 29/10/2026: 241/241 test đạt; analyze sạch; APK debug build thành công. Có cảnh báo tương thích Kotlin tương lai từ flutter_tts. Review độc lập hoàn tất, chưa kiểm thử trên điện thoại.
