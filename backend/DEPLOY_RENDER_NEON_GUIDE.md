# HƯỚNG DẪN TRIỂN KHAI BACKEND ENGLISH 12 TRÊN NEON DATABASE & RENDER.COM

Tài liệu này hướng dẫn bạn cấu hình hoàn chỉnh hệ thống Backend Serverless cho ứng dụng **English 12 - Luyện Thi THPT** bằng cách kết nối **Neon PostgreSQL** và **Render Web Service** (hoàn toàn miễn phí, nhanh chóng và bảo mật cao).

---

## 📌 Tổng Quan Kiến Trúc

```
+-------------------+        HTTPS / JSON        +--------------------------+
|  Flutter Mobile   |  ----------------------->  |     Render Web API       |
|   (English 12 App)|  <-----------------------  |   (Node.js + Express)    |
+-------------------+                            +--------------------------+
                                                               |
                                                               | SSL Connection
                                                               v
                                                 +--------------------------+
                                                 |      Neon Database       |
                                                 |  (Serverless Postgres)   |
                                                 +--------------------------+
```

---

## BƯỚC 1: TẠO CƠ SỞ DỮ LIỆU POSTGRESQL TRÊN NEON (2 PHÚT)

1. Truy cập [https://neon.tech](https://neon.tech) và chọn **Sign in** bằng tài khoản GitHub hoặc Google.
2. Tại trang tổng quan, nhấn nút **"Create Project"**:
   - **Project name**: `english12-database`
   - **Postgres version**: `16` (mặc định)
   - **Region**: Chọn `Asia Pacific (Singapore) - ap-southeast-1` để có tốc độ kết nối nhanh nhất từ Việt Nam.
3. Sau khi tạo xong, Neon sẽ hiển thị hộp thoại chứa **Connection Details**:
   - Chọn định dạng: **Connection string**
   - Đảm bảo có checkbox **Pooled connection** hoặc chuỗi kết thúc bằng `?sslmode=require`.
   - Bấm nút **Copy** (chuỗi kết nối có dạng):
     ```text
     postgresql://alex_owner:abc123xyz@ep-weathered-wind-a123.ap-southeast-1.aws.neon.tech/neondb?sslmode=require
     ```
   *(Hãy lưu lại chuỗi này vào Notepad để dùng ở Bước 2)*.

4. **(Tùy chọn) Chạy Schema SQL khởi tạo bảng:**
   - Trên thanh menu bên trái của Neon, bấm vào **SQL Editor**.
   - Mở file `backend/schema.sql` trong dự án của bạn, copy toàn bộ nội dung và dán vào ô soạn thảo.
   - Bấm nút **Run** (Ctrl + Enter) để tạo sẵn 6 bảng: `users`, `user_profiles`, `daily_stats`, `textbook_progress`, `exam_attempts`, `wrong_book`.
   *(Lưu ý: Nếu không chạy thủ công, server Node.js khi khởi động cũng sẽ tự động tạo bảng nếu chưa có).*

---

## BƯỚC 2: TRIỂN KHAI WEB API LÊN RENDER.COM (3 PHÚT)

1. Đẩy mã nguồn dự án của bạn lên GitHub repository cá nhân (nhánh `main` hoặc `feature/BaoAn`).
2. Truy cập [https://render.com](https://render.com) và đăng nhập bằng tài khoản GitHub.
3. Trên thanh điều hướng Dashboard, bấm **"New +"** -> Chọn **"Web Service"**.
4. Chọn repository GitHub chứa dự án của bạn.
5. Điền các trường thông số cấu hình:
   - **Name**: `english12-backend` (hoặc tên tùy chọn)
   - **Region**: `Singapore (Southeast Asia)`
   - **Branch**: `main` (hoặc nhánh chứa code của bạn)
   - **Root Directory**: `backend` *(Rất quan trọng: vì code backend nằm trong thư mục `backend/`)*
   - **Runtime**: `Node`
   - **Build Command**: `npm install`
   - **Start Command**: `node server.js`
   - **Instance Type**: `Free` (0$/tháng)
6. Kéo xuống mục **Environment Variables** (Biến môi trường) -> Bấm **"Add Environment Variable"**:
   - **Key**: `DATABASE_URL`
   - **Value**: Dán chuỗi kết nối Neon vừa copy ở Bước 1 vào đây.
7. Bấm nút **"Create Web Service"**.
8. Render sẽ tiến hành build và khởi chạy server trong khoảng 1 - 2 phút. Khi thấy dòng:
   ```text
   ==> Your service is live 🎉
   🚀 English 12 Backend API đang chạy tại cổng http://localhost:3000
   ✅ Đã kết nối thành công tới Neon PostgreSQL Database!
   ```
   Bạn copy đường link dịch vụ do Render cấp ở trên cùng bên trái, có dạng:
   `https://english12-backend-xxxx.onrender.com`

---

## BƯỚC 3: KIỂM TRA API HOẠT ĐỘNG

Mở trình duyệt hoặc Postman, truy cập:
`https://english12-backend-xxxx.onrender.com/`

Kết quả trả về JSON thành công:
```json
{
  "status": "online",
  "app": "English 12 - Luyện Thi THPT",
  "version": "1.0.0",
  "database": "Neon Postgres Connected",
  "timestamp": "2026-10-30T16:40:00.000Z"
}
```

---

## BƯỚC 4: KẾT NỐI FLUTTER APP VỚI BACKEND VỪA TRIỂN KHAI

Mở file `lib/data/remote/api_client.dart` trong Flutter app và cấu hình `baseUrl`:

```dart
class ApiClient {
  final String baseUrl;
  final String? Function()? tokenProvider;

  const ApiClient({
    // Thay đường link bên dưới bằng URL Render của bạn:
    this.baseUrl = 'https://english12-backend-xxxx.onrender.com/api',
    this.tokenProvider,
  });
}
```

Từ thời điểm này:
- Mọi tài khoản đăng ký hoặc đăng nhập bằng Google trên app sẽ tự động lưu vào Neon Database.
- Mục tiêu điểm thi THPT, thời gian học, nhắc nhở sẽ đồng bộ đám mây và khôi phục khi đăng nhập ở thiết bị khác.
- Lịch sử thi thử 40 câu 50 phút và chuỗi streak học tập được bảo toàn trọn vẹn.

