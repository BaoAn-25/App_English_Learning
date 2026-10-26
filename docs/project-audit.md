# Kiểm tra dự án — 26/10/2026

## Hiện trạng
- Flutter, Material 3 sáng/tối, Provider, SQLite. Chưa có backend máy chủ.
- Có model/repository cho chủ đề, từ vựng, câu hỏi, lượt làm bài, câu sai, thống kê ngày và cài đặt.
- Có 4 tab nhưng nội dung đều là placeholder. Home chưa được đưa vào điều hướng.
- Có 3 chủ đề, 3 từ, 3 câu hỏi mẫu; chưa đủ cho thi thử trong README.
- Có 1 smoke test chuyển tab, chưa có kiểm thử nghiệp vụ.
- README quy định PR vào develop nhưng remote chưa có develop; dùng main làm base cho feature/tai.

## Phạm vi đợt này (Tài)
1. Cài đặt mục tiêu số câu mỗi ngày, lưu qua AppRepository. Mặc định 20; nhập số nguyên 1–200. Đây là quyết định triển khai để làm rõ đơn vị daily_goal.
2. Thống kê tổng XP, số câu, độ chính xác có trọng số và 7 ngày gần nhất từ daily_stats.
3. Trang chủ với tiến độ mục tiêu, XP, chuỗi ngày có trả lời câu hỏi và nút đi học; đưa vào điều hướng bằng một tab mới, giữ các tab cũ.

Dữ liệu hiển thị là dữ liệu thật. Không tạo số liệu học giả. Một ngày được tính vào chuỗi khi questionsDone > 0; hôm nay chưa học thì giữ chuỗi kết thúc hôm qua. Không áp dụng streak_freeze vì chưa có nghiệp vụ tiêu thụ lượt đóng băng.

## Ưu tiên tiếp theo của nhóm
- Lượng: học từ theo chủ đề, tìm kiếm/flashcard và tiến độ từ vựng.
- Viễn: trả lời/chấm điểm/giải thích, ghi lượt làm và daily_stats; sổ câu sai và thi thử có đồng hồ.
- An: ghi kết quả trong transaction, kiểm tra ràng buộc dữ liệu, seed atomic, xử lý lỗi khởi động; xác định nền tảng hỗ trợ SQLite.
- Nội dung: bổ sung ngân hàng câu hỏi đã được rà soát và xác nhận cấu trúc đề thi trước phát hành.
- Chung: CI, kiểm thử SQLite trên thiết bị và kiểm thử luồng học đầy đủ. Chưa cần thêm server khi chưa có yêu cầu đồng bộ tài khoản.

## Giới hạn kiểm chứng
Widget tests dùng repository bộ nhớ để kiểm tra hành vi UI, không chứng minh plugin SQLite chạy trên thiết bị. Không tuyên bố toàn bộ ứng dụng không còn lỗi. Không tải SDK, package hay tài nguyên ngoài mạng; dependency được giải từ cache cục bộ.

## Môi trường kiểm thử
Flutter 3.47.7 / Dart 3.13.5 có sẵn. `flutter pub get --offline` giải lại 6 phiên bản trong pubspec.lock để dùng SDK/cache hiện có (bao gồm sqflite 2.4.4 thay cho 2.4.4+1). Không thay pubspec.yaml, không thêm package. SDK tự thêm exclude thư mục generated/platform vào analysis_options.yaml. Leader cần xác nhận lockfile này phù hợp SDK của nhóm.
