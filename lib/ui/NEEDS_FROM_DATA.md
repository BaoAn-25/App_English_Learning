# DANH SÁCH YÊU CẦU DÀNH CHO BỘ PHẬN DATA (AppRepository & Backend Sync)

Tài liệu này tổng hợp các hàm và giao thức đồng bộ dữ liệu mà các màn hình **Home, Stats, Settings** cần kết nối khi `AppRepository` được tích hợp hoàn chỉnh với backend API.

---

## 1. Đồng bộ Hồ sơ & Cài đặt (Profile & Settings)
- **Hàm mong muốn trong `AppRepository`**:
  ```dart
  Future<UserProfile> getUserProfile();
  Future<void> saveUserProfile(UserProfile profile);
  Future<SyncResult> syncPendingChanges();
  ```
- **Endpoint backend đề xuất**:
  - `GET /api/v1/user/profile`: Lấy thông tin cá nhân (name, grade, targetScore, dailyGoal).
  - `PUT /api/v1/user/profile`: Cập nhật thông tin cá nhân.
  - Hỗ trợ timestamp cập nhật (`updatedAt`) để giải quyết xung đột (conflict resolution: bản mới hơn sẽ ghi đè).

---

## 2. Đồng bộ Thống kê Tiến độ (Stats)
- **Hàm mong muốn trong `AppRepository`**:
  ```dart
  Future<List<DailyStat>> getDailyStatsInRange(String startDate, String endDate);
  Future<Map<String, TypeStatSummary>> getAccuracyByQuestionType();
  ```
- **Endpoint backend đề xuất**:
  - `GET /api/v1/stats/daily?from=yyyy-MM-dd&to=yyyy-MM-dd`: Trả về mảng `DailyStat` gồm `{date, xp, questionsDone, correct, minutes}`.
  - `GET /api/v1/stats/by-type`: Thống kê tỷ lệ đúng theo 8 dạng câu hỏi THPT:
    `vocab`, `grammar`, `synonym_antonym`, `communication`, `signs`, `arrange`, `cloze`, `reading`.

---

## 3. Lộ trình học & Mở khóa chủ đề (Home Roadmap)
- **Hàm mong muốn trong `AppRepository`**:
  ```dart
  Future<List<TopicProgress>> getTopicsWithProgress({required int grade});
  ```
- Hiện tại bảng `topics` đã có sẵn trong SQLite; phía UI đang đọc qua `AppRepository.getTopicsByGrade(12)`. Cần hỗ trợ thêm cờ trạng thái hoàn thành / mở khóa của từng Topic từ lịch sử `attempts`.
