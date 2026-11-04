import 'package:flutter/material.dart';
import '../../theme/app_tokens.dart';
import 'student_preview_mode.dart';

/// Thanh thông báo nổi cố định phía trên khi Admin đang bật "Chế độ xem trước Học viên".
/// Cho phép Admin kiểm tra góc nhìn người học và chạm 1 nút là quay lại Admin ngay.
class StudentPreviewBanner extends StatelessWidget {
  const StudentPreviewBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: AppTokens.primary,
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(40),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.visibility_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Chế độ Xem Trước Học Sinh',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  ),
                  Text(
                    'Đang hiển thị toàn bộ giao diện học sinh 12',
                    style: TextStyle(
                      color: Color(0xFFBFDBFE),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTokens.primary,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: () => StudentPreviewMode.instance.exitPreview(),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back_rounded, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Quay lại Admin',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

