# Bộ audio Global Success 12

51 MP3 đã được đưa vào assets/audio/global_success_12: 27 Listening, 10 Vocabulary và 14 Reading. Bảng ánh xạ: assets/data/audio_manifest.json.

Các file output gốc giữ nguyên. Không nhập bộ output/listening/listening vì chưa xác minh phù hợp hoạt động SGK.

## Lưu ý tích hợp

- Dùng assetPath và activityNumbers trong manifest; không suy Unit từ tên file nguồn.
- Unit 7 Listening dùng chung một track cho Activity 2 và 3; loại track nguồn 53 (Communication and Culture trang 97).
- Unit 6 Listening gồm hai phần hội thoại khác nhau, cần phát đúng hoạt động.
- Reading nguồn 004, 007, 011, 014 là Review 1–4.
- lessonKey là khóa catalog audio, không mặc định bằng ID curriculum; liên kết với textbook.json và schema hiện tại khi tích hợp.
- printedPage null: chưa khai báo trang chính xác, không suy đoán.
- Có audio không đồng nghĩa bài tập, transcript và đáp án đã hoàn thiện. Không đổi toàn bộ audioAvailable thành true.
- Chưa có trọn bộ Getting Started/Pronunciation/Communication audio; đánh giá sẵn sàng theo từng hoạt động.
- Nguồn Listening: Lời Giải Hay. Nguồn Vocabulary/Reading: thư mục Drive dẫn từ https://sach6789.com/tai-lieu-bo-tro-tieng-anh-12-global-success/. Chưa chứng nhận nhà phát hành chính thức.
- Đã kiểm tra SHA-256, giải mã toàn bộ file và phần giới thiệu/chủ đề. Chưa kiểm chứng từng chữ xuyên suốt mọi bản thu.
- Chưa tích hợp player hoặc thay đổi dữ liệu tiến độ.
