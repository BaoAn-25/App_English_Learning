# App Luyện Thi Tốt Nghiệp THPT Môn Tiếng Anh (thpt_english)

> **EngPass Global Success 12 — v2.5.0**  
> Ứng dụng ôn thi tốt nghiệp THPT môn Tiếng Anh và học tập bám sát chương trình **SGK Tiếng Anh 12 (Global Success)**, tích hợp Phòng thi Giám sát chống gian lận AI (Live Proctoring), phân quyền RBAC (Học sinh - Giáo viên - Quản trị viên), quản lý lớp học đa thiết bị qua Cloud Render và hệ thống thông báo nhắc hẹn thông minh.

---

## 🌟 Các Tính Năng Nổi Bật

### 1. 📚 Học Tập Toàn Diện 10 Unit SGK Tiếng Anh 12 (Global Success)
- Đầy đủ 8 phân khu cốt lõi cho mỗi Unit:
  1. **Getting Started:** Giới thiệu ngữ cảnh và chủ đề bài học.
  2. **Language:** Phát âm, Từ vựng trọng tâm và Ngữ pháp chuyên sâu.
  3. **Reading:** Đọc hiểu tương tác, giải thích từ mới và bài tập củng cố.
  4. **Speaking:** Luyện phản xạ và diễn đạt tình huống.
  5. **Listening:** Luyện nghe âm thanh bản xứ với transcript chi tiết.
  6. **Writing:** Hướng dẫn viết luận và bài viết ngắn theo chuẩn đề thi.
  7. **Communication & Culture / CLIL:** Mở rộng văn hóa và kiến thức liên môn.
  8. **Looking Back & Project:** Ôn tập tổng hợp và dự án thực hành.
- **Theo dõi tiến độ học tập tự động:** Ghi nhận % hoàn thành từng section, chuỗi ngày học liên tục (Streak), điểm tích lũy (XP) và tự động đồng bộ lên máy chủ Cloud Render.

### 2. 🛡️ Phòng Thi Giám Sát Chống Gian Lận (10s Live Proctoring)
- **Cơ chế giám sát thông minh:** Phát hiện học sinh rời khỏi ứng dụng trong khi làm bài thi.
- **Thời gian ân hạn linh hoạt (Grace Period):** Hỗ trợ các mốc 5s, 10s, 15s, 20s. Nếu học sinh quay lại trong thời gian cho phép, hiển thị Dialog cảnh báo đỏ và chỉ tính 1 lần vi phạm. Nếu quá thời gian cho phép $\rightarrow$ tự động thu bài và tính điểm tại thời điểm vi phạm.
- **Chặn làm lại bài:** Học sinh sau khi hoàn thành hoặc bị thu bài vi phạm sẽ chuyển sang chế độ "Xem Kết Quả & Chi Tiết", không thể làm lại để đảm bảo tính công bằng.
- **Chặn khách vãng lai:** Yêu cầu đăng nhập tài khoản học sinh chính thức trước khi tham gia bài thi có giám sát.
- **Bảng điều khiển Giám thị Trực tiếp:** Giáo viên và Admin có thể theo dõi trực tiếp trạng thái làm bài, số lần vi phạm và có quyền can thiệp (Reset vi phạm / Thu bài cưỡng chế).

### 3. 👥 Quản Lý Lớp Học Đa Thiết Bị (Multi-Device Class Sync)
- **Tạo lớp học:** Giáo viên / Admin tạo lớp với mã lớp tự sinh chuẩn hóa (VD: `ENG-988B`, `LPCT-3681`).
- **Gia nhập lớp học tức thì:** Học sinh trên bất kỳ điện thoại nào chỉ cần nhập mã lớp là hệ thống tự động tra cứu từ Cloud Render (`/api/classes/lookup/:code`) và tham gia lớp thành công.
- **Đồng bộ 2 chiều (Offline-First + Cloud):** Hỗ trợ lưu trữ offline SQLite cục bộ và đồng bộ tự động hàng loạt lên Cloud PostgreSQL (Render).
- **Giải tán lớp học an toàn (Tombstone Pattern):** Giải tán vĩnh viễn lớp học cả trên SQLite và PostgreSQL, có cơ chế danh sách đen chống việc lớp học tự động bị kéo về lại.

### 4. 🔔 Nhắc Hẹn Lớp Học & Thông Báo Cục Bộ (Push-to-Local Notifications)
- Giáo viên lên lịch nhắc hẹn học bài cho lớp học (chọn ngày giờ và nội dung nhắc nhở).
- Học sinh trong lớp tự động đồng bộ lịch hẹn vào hệ thống thông báo của điện thoại (`flutter_local_notifications`), chuông báo sẽ reo đúng thời điểm đã hẹn kể cả khi đóng ứng dụng.

### 5. 📝 Luyện Thi & Thi Thử Tốt Nghiệp THPT
- Luyện tập theo từng chuyên đề ngữ pháp và dạng câu hỏi thi tốt nghiệp THPT.
- Thi thử chuẩn cấu trúc đề thi tốt nghiệp THPT môn Tiếng Anh (50 câu / 60 phút).
- **Sổ tay câu sai (Wrong Book):** Tự động lưu lại các câu hỏi trả lời sai để học sinh ôn luyện lại có trọng tâm.

---

## 🏗️ Kiến Trúc Hệ Thống & Công Nghệ

```
[ Flutter Mobile App (Android/iOS) ]
       │              │
       │ (SQLite)     │ (RESTful APIs + Bearer JWT)
       ▼              ▼
[ Local Offline DB ] [ Node.js Express Backend on Render ]
                            │
                            │ (PostgreSQL Connection Pool)
                            ▼
                     [ Neon Cloud PostgreSQL DB ]
                            │
                            │ (Google Gemini SDK)
                            ▼
                     [ Google Gemini AI 1.5/2.0 ]
```

| Thành phần | Công nghệ sử dụng |
| :--- | :--- |
| **Frontend Framework** | Flutter 3.x (Dart 3.x), Material 3 Theme |
| **Cơ sở dữ liệu cục bộ** | SQLite (`sqflite`), Offline-First Architecture |
| **Quản lý Thông báo** | `flutter_local_notifications`, `timezone` |
| **Backend Runtime** | Node.js, Express.js |
| **Cơ sở dữ liệu đám mây** | PostgreSQL (Neon Cloud Database) |
| **Nền tảng Cloud Host** | Render (`https://english12-backend.onrender.com/api`) |
| **Trí tuệ Nhân tạo** | Google Gemini API (AI Proctoring, Question Generator, Grammar Analyzer) |

---

## 📁 Cấu Trúc Thư Mục Frontend

```
lib/
├── data/                               # Quản lý CSDL SQLite & Dịch vụ Mạng
│   ├── app_database.dart               # Cấu hình SQLite, Schema Migration v1 -> v2
│   ├── app_repository.dart             # Kho dữ liệu trung tâm (Sessions, Progress, Stats)
│   ├── rbac_proctor_ai_service.dart    # Service chính: RBAC, Proctoring, Lớp học, Cloud Sync
│   └── models/                         # Data Models (ClassReminder, Question, WordProgress...)
├── navigation/                         # Điều hướng ứng dụng (MainShell, Route Config)
├── ui/                                 # Giao diện người dùng
│   ├── admin/                          # Trung tâm quản trị Admin (5 Tabs quản lý, Proctoring, KPI)
│   ├── teacher/                        # Bảng điều khiển Giáo viên (Lớp học, Bài tập, Giám thị Live)
│   ├── classes/                        # Màn hình Lớp học của tôi dành cho Học sinh
│   ├── textbook/                       # Giao diện học 10 Unit SGK 12 Global Success
│   ├── practice/                       # Màn hình Luyện tập & Phòng thi Giám sát (Supervised Exam)
│   ├── common/dialogs/                 # Các Dialog & BottomSheet (StudentProgressSheet, v.v.)
│   └── settings/                       # Cài đặt, Thông báo (NotificationService)
```

---

## 🚀 Hướng Dẫn Cài Đặt & Chạy Ứng Dụng

### 1. Yêu cầu môi trường
- Flutter SDK $\ge$ 3.24.0
- Dart SDK $\ge$ 3.5.0
- Android Studio / VS Code có cài Flutter & Dart Extensions

### 2. Các bước cài đặt
```bash
# 1. Clone repository
git clone https://github.com/BaoAn-25/App_English_Learning.git
cd App_Learning_English

# 2. Cài đặt các package phụ thuộc
flutter pub get

# 3. Kiểm tra tính toàn vẹn mã nguồn (bắt buộc 0 issues)
flutter analyze

# 4. Chạy kiểm thử chấp nhận (Acceptance Tests)
flutter test test/class_join_multi_device_acceptance_test.dart test/class_reminder_notification_acceptance_test.dart

# 5. Khởi chạy ứng dụng trên thiết bị Android / Giả lập
flutter run
```

---

## 🌿 Quy Tắc Quản Lý Nhánh Git
- **`main`**: Nhánh phát hành chính thức, mã nguồn production ổn định nhất.
- **`develop`**: Nhánh tích hợp chung của toàn bộ nhóm.
- **`feature/BaoAn`**: Nhánh phát triển tính năng chính (UI/UX, RBAC, Proctoring, Đồng bộ Đa thiết bị).

---

## 📄 Bản Quyền
Dự án được xây dựng phục vụ môn Lập trình Di động & Học sinh Lớp 12 ôn thi tốt nghiệp THPT môn Tiếng Anh.
