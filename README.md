# App Luyện Thi Tốt Nghiệp THPT Môn Tiếng Anh (thpt_english)

Ứng dụng ôn thi tốt nghiệp THPT môn Tiếng Anh dành riêng cho học sinh lớp 12 tại Việt Nam. Ứng dụng hỗ trợ học sinh tự học 10–20 phút mỗi ngày, luyện tập theo các dạng câu hỏi chuẩn của đề thi tốt nghiệp, thi thử 50 câu trong 60 phút, đồng thời theo dõi tiến độ và các dạng câu hỏi thường làm sai để cải thiện kịp thời.

---

## 🚀 Hướng Dẫn Cài Đặt & Chạy Ứng Dụng

1. **Clone repository:**
   ```bash
   git clone <URL_REPOSITORY>
   cd thpt_english
   ```

2. **Cài đặt các thư viện phụ thuộc:**
   ```bash
   flutter pub get
   ```

3. **Chạy ứng dụng (trên Android hoặc thiết bị giả lập):**
   ```bash
   flutter run
   ```

4. **Chạy kiểm thử:**
   ```bash
   flutter test
   ```

---

## 🌿 Quy Tắc Quản Lý Nhánh Git

Nhóm áp dụng mô hình phân nhánh Git chuẩn để tránh xung đột mã nguồn:

- **`main`**: Nhánh phát hành chính thức, chứa mã nguồn ổn định nhất.
- **`develop`**: Nhánh tích hợp chung của toàn nhóm trong quá trình phát triển 3 tuần.
- **`feature/<tên_thành_viên>-<nhiệm_vụ>`**: Nhánh tính năng riêng của từng thành viên khi làm việc (ví dụ: `feature/tai-sqlite-data`, `feature/luong-vocab-list`, `feature/vien-practice-quiz`, `feature/an-home-stats`).
  - Mỗi thành viên tạo nhánh feature từ `develop`.
  - Hoàn thành tính năng và test pass thì tạo Pull Request gộp vào `develop`.

---

## 👥 Phân Chia Thư Mục & Trách Nhiệm Thành Viên

Tài và An đã đổi vai trò. Phân công dưới đây là phân công hiện tại; các dòng “Phụ trách” còn trong màn hình mẫu chưa phản ánh thay đổi này.

Để tránh sửa chung file và giảm thiểu xung đột Git, mỗi thành viên chịu trách nhiệm trong thư mục riêng:

| Thành viên | Thư mục phụ trách | Trách nhiệm chính |
| :--- | :--- | :--- |
| **Tài** | `lib/data/`<br>`lib/navigation/` | Model, SQLite `AppDatabase`, `AssetSeeder`, `AppRepository`; lưu/đồng bộ dữ liệu, kiểm thử tầng dữ liệu; luồng khởi động `AppStartup` và khung điều hướng `MainShell` |
| **An** | `lib/ui/theme/`<br>`lib/ui/home/`<br>`lib/ui/stats/`<br>`lib/ui/settings/` | Hệ thống giao diện theme Material 3, màn hình Trang chủ (Streak, XP, mục tiêu ngày), màn hình Thống kê tiến độ, màn hình Cá nhân & Cài đặt |
| **Lượng** | `lib/ui/vocab/` | Màn hình Học từ vựng, danh sách từ vựng theo chủ đề (Topic, Word) |
| **Viễn** | `lib/ui/practice/`<br>`lib/ui/mock/` | Màn hình Luyện tập theo dạng câu hỏi (Question), màn hình Thi thử 50 câu 60 phút (Attempt, AttemptAnswer) |
| **Chung** | `assets/data/` | Dữ liệu JSON mẫu (topics, words, questions) |


## Tiến độ phần Tài — cập nhật 28/10/2026

Các phần sau đã có trên `feature/tai`, được đẩy lên [PR #3](https://github.com/BaoAn-25/App_English_Learning/pull/3) để leader duyệt:

| Phần đã hoàn thành | Kết quả |
| :--- | :--- |
| Lưu kết quả bài làm | Ghi lượt làm, đáp án, sổ câu sai và thống kê trong một giao dịch; kiểm tra tính nhất quán và rollback toàn bộ lần lưu khi lỗi. |
| Nạp dữ liệu mẫu | Seed topics/words/questions trong cùng giao dịch; không ghi đè bảng đã có dữ liệu và không để dữ liệu nạp dở. |
| Đồng bộ từ vựng khi nâng cấp | Bổ sung chủ đề/từ vựng thiếu theo ID trong một giao dịch; giữ nội dung đã có và tiến độ ôn tập, chạy lặp không tạo trùng ID. |
| Khởi động và thử lại | Hiển thị loading/lỗi/Thử lại; chạy seed, đồng bộ chủ đề/từ vựng rồi đồng bộ câu hỏi trước khi vào MainShell; chặn retry song song và không hiện lỗi nội bộ. |
| Cập nhật đồng thời | Ngăn mất số đếm khi cộng thống kê ngày và số lần trả lời sai từ nhiều lời gọi đồng thời. |
| Tương thích chủ đề cũ/mới | Hiển thị chung ba cặp ID chủ đề mẫu đã biết khi thông tin khớp; mở chung từ vựng/câu hỏi của hai ID và giữ nguyên dữ liệu gốc. Chủ đề đã sửa thông tin vẫn tách riêng. |
| Kiểm tra tên bảng | Chỉ cho phép truy vấn kiểm tra bảng rỗng với 9 bảng ứng dụng hợp lệ, gồm word_progress. |
| Tích hợp với nhóm | Giải quyết xung đột với main, giữ chức năng luyện thi của Viễn, từ vựng của Lượng và schema SQLite v2/migration tiến độ từ vựng. |
| Sửa lỗi phát hiện khi tích hợp | Khóa chọn đáp án trong lúc lưu bài luyện tập để đáp án không lệch với điểm và sổ câu sai. |

**Kiểm chứng sau sửa chủ đề trùng:** 208/208 test đạt, `flutter analyze --no-pub` không báo vấn đề; đã review phần gộp code và sửa phát hiện từ review. Đã build debug và kiểm tra khởi động/nâng cấp SQLite trên Android 17 tại commit `fde5130`; chưa kiểm thử đầy đủ các luồng trên thiết bị, TTS hoặc bản release. Bản sửa gộp chủ đề sau đó mới được kiểm thử tự động.

**Phần còn lại:** kiểm thử nâng cấp và plugin trên thiết bị thật. Giữ nguyên ID từ vựng và tiến độ; chưa hợp nhất các từ trùng nội dung nhưng khác ID. Màn hình Trang chủ, Thống kê và Cá nhân/Cài đặt thuộc phần An, không tính là chức năng Tài đã hoàn thành trong PR này.


## Lưu kết quả bài làm

`AppRepository.savePracticeResult` lưu lượt làm, đáp án, sổ câu sai và thống kê ngày trong một giao dịch, kiểm tra dữ liệu trước khi ghi và rollback khi lỗi. Xem [hướng dẫn tích hợp và kiểm chứng](docs/save-practice-result.md).

Bộ test dữ liệu dùng SQLite trong bộ nhớ qua Python 3 có sẵn (`sqlite3` trong thư viện chuẩn); không tải dependency khi chạy `flutter test --no-pub`. Xem [hiện trạng và ưu tiên tiếp theo](docs/project-audit.md).


## Khởi động có thể thử lại

Ứng dụng hiển thị trạng thái nạp dữ liệu trước khi mở các tab. Khi lỗi có nút **Thử lại**, không tự xóa database. Dữ liệu mẫu được nạp trong một transaction để tránh nạp dở dang. Xem [luồng khởi động và kiểm chứng](docs/startup.md).
