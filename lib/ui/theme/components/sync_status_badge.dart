import 'package:flutter/material.dart';
import '../../strings.dart';
import '../app_tokens.dart';

enum SyncState { syncing, synced, offline, error }

/// Huy hiệu hiển thị trạng thái đồng bộ dữ liệu (Offline-first).
/// Hỗ trợ 4 trạng thái: Đang đồng bộ, Đã đồng bộ, Đang offline, Lỗi đồng bộ (kèm nút Thử lại).
///
/// Cách dùng:
/// ```dart
/// SyncStatusBadge(
///   state: SyncState.synced,
///   onRetry: () {},
/// )
/// ```
class SyncStatusBadge extends StatelessWidget {
  final SyncState state;
  final VoidCallback? onRetry;
  final bool compact;

  const SyncStatusBadge({
    super.key,
    required this.state,
    this.onRetry,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    IconData icon;
    String text;

    switch (state) {
      case SyncState.syncing:
        bg = const Color(0xFFE8F2FF);
        fg = AppTokens.primary;
        icon = Icons.sync_rounded;
        text = AppStrings.syncStatusSyncing;
        break;
      case SyncState.synced:
        bg = const Color(0xFFE6F7F0);
        fg = AppTokens.successGreen;
        icon = Icons.cloud_done_rounded;
        text = AppStrings.syncStatusSynced;
        break;
      case SyncState.offline:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
        icon = Icons.save_alt_rounded;
        text = AppStrings.syncStatusOffline;
        break;
      case SyncState.error:
        bg = const Color(0xFFFFECEC);
        fg = AppTokens.errorRed;
        icon = Icons.error_outline_rounded;
        text = AppStrings.syncStatusError;
        break;
    }

    if (compact) {
      return Tooltip(
        message: text,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: state == SyncState.syncing
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                )
              : Icon(icon, size: 14, color: fg),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state == SyncState.syncing)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: fg),
            )
          else
            Icon(icon, size: 16, color: fg),
          const SizedBox(width: AppTokens.space4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
          if (state == SyncState.error && onRetry != null) ...[
            const SizedBox(width: AppTokens.space8),
            InkWell(
              onTap: onRetry,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  AppStrings.retry,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: fg,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
