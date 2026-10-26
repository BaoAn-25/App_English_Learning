# Tài — kế hoạch hoàn thiện tiến độ học

> Thực thi inline bằng executing-plans, TDD và Ponytail full; người dùng đã giao quyền quyết định trong dự án.

**Goal:** Hoàn thiện phần Tài thành các màn hình dùng dữ liệu thật.
**Architecture:** Giữ AppRepository và SQLite; state cục bộ cho đọc/lưu. LearningSummary thuần Dart tổng hợp DailyStat dùng chung Home/Stats.
**Tech Stack:** Flutter, Material 3, Provider, sqflite hiện có.
**Spec:** docs/project-audit.md

## Constraints
- Không thêm dependency, không sửa nghiệp vụ của thành viên khác.
- Không đọc bí mật hoặc gửi dữ liệu ngoài dự án; mạng chỉ dùng GitHub theo yêu cầu.
- Nhánh feature/tai từ origin/main; PR vào main do chưa có develop. Không merge.
- Mỗi chức năng có commit riêng sau test toàn bộ và analyze sạch.

## Review focus
- Mục tiêu hỏng/rỗng và lỗi lưu: fallback an toàn, không báo lưu thành công giả.
- Không dữ liệu/không có câu: không chia cho 0 hoặc bịa tỷ lệ.
- Ngày tương lai, qua tháng/năm, gián đoạn chuỗi: tính theo ngày lịch địa phương.
- Dữ liệu cũ sau chuyển tab: Home/Stats đọc lại khi được chọn, có nút làm mới.
- Màn hình nhỏ, chữ lớn, dark mode: không overflow, nội dung có thể cuộn.

## Task 1: Cài đặt mục tiêu
- [x] Viết test tải, validation 1–200, lưu thành công/lỗi và đọc lại từ repository.
- [x] Chạy test đỏ, triển khai SettingsScreen + test/support/fake_repository.dart.
- [x] Chạy flutter test --no-pub và flutter analyze --no-pub; commit riêng.

## Task 2: Thống kê
- [ ] Viết test LearningSummary.fromStats(List<DailyStat>, {required DateTime now}) cho tổng, 7 ngày đủ cả ngày 0, weighted accuracy, streak và ngày tương lai.
- [ ] Viết widget test dữ liệu rỗng, tải/lỗi/thử lại, refresh và responsive.
- [ ] Chạy đỏ, triển khai lib/ui/stats/learning_summary.dart và StatsScreen. Đọc lại khi active false → true.
- [ ] Chạy toàn bộ test/analyze; commit riêng.

## Task 3: Trang chủ
- [ ] Viết test mục tiêu/XP/streak, giới hạn progress, điều hướng, mục tiêu đổi sau trở lại và tải/lỗi.
- [ ] Chạy đỏ, triển khai HomeScreen, nối MainShell; giữ state các tab qua IndexedStack.
- [ ] Chạy toàn bộ test/analyze, kiểm tra ảnh render sáng/tối và chữ lớn; commit riêng.

## Kết thúc
- [ ] Review nhánh bằng reviewer độc lập; sửa và test lại nếu cần.
- [ ] Kiểm tra diff và dữ liệu nhạy cảm trước push; push feature/tai, mở PR với kết quả kiểm thử và giới hạn để leader duyệt.
