# Backend Dịch Vụ Máy Chủ Cloud Render — EngPass Global Success 12

> **Máy chủ RESTful API & Dịch vụ Trí tuệ Nhân tạo (RBAC, Live Proctoring, Multi-device Sync, Gemini AI)**  
> Host trực tuyến tại: `https://english12-backend.onrender.com/api`

---

## 📋 Mục Lục
- [Tổng quan Kiến trúc](#-tổng-quan-kiến-trúc)
- [Hệ thống Bảng Dữ liệu (Neon PostgreSQL)](#-hệ-thống-bảng-dữ-liệu-neon-postgresql)
- [Tài liệu Chi tiết RESTful APIs](#-tài-liệu-chi-tiết-restful-apis)
  - [1. Kiểm tra Sức khỏe & Cấu hình](#1-kiểm-tra-sức-khỏe--cấu-hình)
  - [2. Quản lý Lớp học Đa thiết bị (Multi-Device Classes)](#2-quản-lý-lớp-học-đa-thiết-bị-multi-device-classes)
  - [3. Đồng bộ Tiến độ Học tập SGK (Textbook Progress)](#3-đồng-bộ-tiến-độ-học-tập-sgk-textbook-progress)
  - [4. Phòng thi Giám sát AI (Live Proctoring & Anti-Cheat)](#4-phòng-thi-giám-sát-ai-live-proctoring--anti-cheat)
  - [5. Tích hợp Trí tuệ Nhân tạo Gemini (AI Engine)](#5-tích-hợp-trí-tuệ-nhân-tạo-gemini-ai-engine)
- [Hướng dẫn Cài đặt & Khởi chạy Local](#-hướng-dẫn-cài-đặt--khởi-chạy-local)
- [Triển khai lên Cloud Render & Neon Database](#-triển-khai-lên-cloud-render--neon-database)

---

## 🏛️ Tổng quan Kiến trúc

```
[ Flutter Mobile Clients ]
        │
        │ HTTPS (JSON + Bearer Token)
        ▼
[ Node.js + Express.js API Gateway ]
   ├── Authentication & RBAC Middleware (Student / Teacher / Admin)
   ├── Proctoring & Anti-Cheat Session State Engine
   ├── Multi-device Class Code & Sync Controller
   └── AI Service Adapter (Google Gemini Generative AI)
        │
        │ pg-pool Connection
        ▼
[ Neon Cloud PostgreSQL Database ]
```

---

## 🗄️ Hệ thống Bảng Dữ liệu (Neon PostgreSQL)

1. **`users`**: Quản lý tài khoản, mật khẩu băm (bcrypt), vai trò (`student`, `teacher`, `admin`).
2. **`user_profiles`**: Thông tin cá nhân, mục tiêu điểm số, chuỗi ngày học (`current_streak`), điểm XP.
3. **`classes`**: Danh sách lớp học, tên trường, niên khóa, mã tham gia (`join_code` UNIQUE), giáo viên phụ trách, cờ mở/khóa lớp (`allow_join`).
4. **`class_members`**: Thành viên lớp học, trạng thái phê duyệt (`active`, `pending`), lịch sử tham gia.
5. **`class_assignments`**: Bài tập / đề thi giao cho lớp, thời hạn nộp (`deadline_at`), quy chế thi.
6. **`assignment_submissions`**: Bài làm của học sinh, điểm số, số câu đúng, phân tích kỹ năng.
7. **`textbook_progress`**: Tiến độ học 10 Unit SGK 12 (Getting Started, Language, Reading, Listening, Speaking...), trạng thái (`completed`, `in_progress`).
8. **`exam_live_sessions`**: Phiên thi giám sát trực tiếp, thời gian bắt đầu, số lần vi phạm rời ứng dụng, trạng thái (`in_progress`, `warning_out_of_app`, `force_submitted`, `completed`).
9. **`exam_proctor_violations`**: Chi tiết từng lần vi phạm (thời điểm rời app, thời lượng out, bằng chứng vi phạm).
10. **`audit_logs`**: Nhật ký kiểm toán các thao tác quan trọng (tạo/xóa lớp, can thiệp thi, duyệt giáo viên).

---

## 📡 Tài liệu Chi tiết RESTful APIs

### 1. Kiểm tra Sức khỏe & Cấu hình
- **`GET /api/health`**
  - Kiểm tra trạng thái máy chủ và kết nối cơ sở dữ liệu.
  - Phản hồi: `{ "status": "ok", "db": "connected", "time": "..." }`

---

### 2. Quản lý Lớp học Đa thiết bị (Multi-Device Classes)

| Phương thức | Đường dẫn API | Mô tả chức năng | Quyền hạn |
| :--- | :--- | :--- | :--- |
| **`GET`** | `/api/classes` | Lấy danh sách lớp học (tự động lọc theo vai trò người dùng) | Đã xác thực |
| **`GET`** | `/api/classes/lookup/:code` | **Tra cứu công khai:** Tìm kiếm lớp học theo mã lớp (`join_code`) mà không cần đăng nhập trước | Công khai |
| **`POST`** | `/api/classes` | Tạo lớp học mới và tự động sinh mã hoặc cấp mã tùy chỉnh | Teacher, Admin |
| **`POST`** | `/api/classes/join` | Tham gia lớp học bằng mã (tự động liên kết học sinh vào lớp) | Student |
| **`POST`** | `/api/classes/batch-sync` | **Đồng bộ hàng loạt:** Đẩy toàn bộ danh sách lớp từ thiết bị lên Cloud PostgreSQL | Teacher, Admin |
| **`PUT`** | `/api/classes/:id` | Cập nhật thông tin, đổi mã lớp, khóa tiếp nhận thành viên | Teacher, Admin |
| **`DELETE`**| `/api/classes/:id` | **Giải tán vĩnh viễn:** Xóa lớp và các bản ghi phụ thuộc (members, assignments) | Teacher, Admin |
| **`GET`** | `/api/classes/:classId/members` | Danh sách học sinh trong lớp kèm tiến độ và điểm số | Teacher, Admin |

---

### 3. Đồng bộ Tiến độ Học tập SGK (Textbook Progress)

- **`POST /api/students/progress/sync`**
  - **Mô tả:** Đẩy tiến độ một phần bài học (Unit X - Section Y) lên Cloud khi học sinh hoàn thành trên điện thoại.
  - **Body JSON:**
    ```json
    {
      "userId": "usr_12345",
      "userEmail": "hocsinh@gmail.com",
      "unitNumber": 1,
      "sectionName": "reading",
      "status": "completed",
      "score": 100
    }
    ```

- **`GET /api/students/:identifier/progress`**
  - **Mô tả:** Giáo viên/Admin tra cứu tiến độ học tập chi tiết của học sinh (theo ID hoặc Email).
  - **Phản hồi:** Trả về danh sách tất cả các bài học đã hoàn thành, chuỗi Streak, điểm TB bài tập đã nộp.

---

### 4. Phòng thi Giám sát AI (Live Proctoring & Anti-Cheat)

- **`POST /api/proctor/exams`**: Tạo bài thi giám sát với quy chế (thời gian làm bài, ân hạn rời app 5s/10s/15s/20s, giới hạn số lần vi phạm).
- **`POST /api/proctor/sessions/start`**: Học sinh bắt đầu vào làm bài thi có giám sát (chặn làm lại nếu đã thi).
- **`POST /api/proctor/sessions/event`**: Ghi nhận sự kiện học sinh rời ứng dụng hoặc quay lại ứng dụng.
- **`POST /api/proctor/sessions/submit`**: Nộp bài thi có giám sát và tự động chấm điểm.
- **`GET /api/proctor/exams/:examId/live`**: Bảng theo dõi trực tiếp trạng thái của tất cả thí sinh đang trong phòng thi.
- **`POST /api/proctor/sessions/:sessionId/override`**: Giám thị can thiệp: Bỏ qua vi phạm (`reset_violation`) hoặc Thu bài cưỡng chế (`force_submit`).

---

### 5. Tích hợp Trí tuệ Nhân tạo Gemini (AI Engine)
- **`POST /api/ai/generate-questions`**: Trích xuất và sinh câu hỏi trắc nghiệm tự động theo chủ đề hoặc Unit SGK 12.
- **`POST /api/ai/explain-answer`**: Phân tích giải thích chi tiết đáp án câu sai cho học sinh.
- **`POST /api/ai/digitize-curriculum`**: Số hóa văn bản giáo trình SGK Tiếng Anh 12.

---

## 💻 Hướng Dẫn Cài Đặt & Khởi Chạy Local

### 1. Cài đặt thư viện
```bash
cd backend
npm install
```

### 2. Cấu hình biến môi trường
Tạo file `.env` dựa theo mẫu `.env.example`:
```env
PORT=3000
DATABASE_URL=postgresql://neondb_owner:xxxx@ep-xxxx.ap-southeast-1.aws.neon.tech/neondb?sslmode=require
JWT_SECRET=your_super_secret_jwt_key_here
GEMINI_API_KEY=your_gemini_api_key_here
```

### 3. Kiểm tra cú pháp & Khởi chạy máy chủ
```bash
# Kiểm tra cú pháp (đảm bảo không có lỗi)
node --check server.js
node --check routes_rbac_proctor_ai.js

# Khởi chạy server
npm start
# hoặc chạy chế độ phát triển tự reload
npm run dev
```

---

## ☁️ Triển Khai Lên Cloud Render

1. Đẩy code lên nhánh chính (`main` hoặc `feature/BaoAn`).
2. Trên **Render Dashboard**:
   - Chọn Web Service kết nối tới Repository.
   - **Root Directory:** `backend`
   - **Build Command:** `npm install`
   - **Start Command:** `npm start`
   - Cấu hình các **Environment Variables**: `DATABASE_URL`, `JWT_SECRET`, `GEMINI_API_KEY`.
3. Kiểm tra sức khỏe máy chủ tại: `https://english12-backend.onrender.com/api/health`

