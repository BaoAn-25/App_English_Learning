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
- **`feature/<tên_thành_viên>-<nhiệm_vụ>`**: Nhánh tính năng riêng của từng thành viên khi làm việc (ví dụ: `feature/an-sqlite-data`, `feature/luong-vocab-list`, `feature/vien-practice-quiz`, `feature/tai-home-stats`).
  - Mỗi thành viên tạo nhánh feature từ `develop`.
  - Hoàn thành tính năng và test pass thì tạo Pull Request gộp vào `develop`.

---

## 👥 Phân Chia Thư Mục & Trách Nhiệm Thành Viên

Để tránh sửa chung file và giảm thiểu xung đột Git, mỗi thành viên chịu trách nhiệm trong thư mục riêng:

| Thành viên | Thư mục phụ trách | Trách nhiệm chính |
| :--- | :--- | :--- |
| **An** | `lib/data/`<br>`lib/navigation/` | Cấu trúc dữ liệu (Model, SQLite `AppDatabase`, `AssetSeeder`, `AppRepository`), khung điều hướng chính `MainShell` |
| **Tài** | `lib/ui/theme/`<br>`lib/ui/home/`<br>`lib/ui/stats/`<br>`lib/ui/settings/` | Hệ thống giao diện theme Material 3, màn hình Trang chủ (Streak, XP, mục tiêu ngày), màn hình Thống kê tiến độ, màn hình Cá nhân & Cài đặt |
| **Lượng** | `lib/ui/vocab/` | Màn hình Học từ vựng, danh sách từ vựng theo chủ đề (Topic, Word) |
| **Viễn** | `lib/ui/practice/`<br>`lib/ui/mock/` | Màn hình Luyện tập theo dạng câu hỏi (Question), màn hình Thi thử 50 câu 60 phút (Attempt, AttemptAnswer) |
| **Chung** | `assets/data/` | Dữ liệu JSON mẫu (topics, words, questions) |
