import 'package:flutter/material.dart';
import '../../../data/rbac_proctor_ai_service.dart';
import '../../theme/app_tokens.dart';
import '../components/admin_kpi_card.dart';

/// TAB 1: Tổng quan Hệ thống (Admin Dashboard Overview)
/// Hiển thị KPI thực tế, danh sách việc cần làm, phím tắt nhanh và dòng hoạt động gần nhất.
class AdminDashboardTab extends StatefulWidget {
  final void Function(int tabIndex)? onNavigateTab;

  const AdminDashboardTab({super.key, this.onNavigateTab});

  @override
  State<AdminDashboardTab> createState() => _AdminDashboardTabState();
}

class _AdminDashboardTabState extends State<AdminDashboardTab> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];
  List<SupervisedExamModel> _exams = [];
  List<Map<String, dynamic>> _auditLogs = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    final users = await RbacProctorAiService.instance.getAdminUsers();
    final exams = await RbacProctorAiService.instance.getSupervisedExams();
    final logs = await RbacProctorAiService.instance.getAuditLogs();

    if (!mounted) return;
    setState(() {
      _users = users;
      _exams = exams;
      _auditLogs = logs;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF162032) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final textMain = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSub = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final totalUsers = _users.length;
    final studentCount = _users.where((u) => u['role'] == 'student').length;
    final teacherCount = _users.where((u) => u['role'] == 'teacher').length;
    final lockedCount = _users.where((u) => u['is_locked'] == true).length;
    final activeExams = _exams.where((e) => e.isActive).length;

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Header chào mừng Quản trị viên
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppTokens.primary,
                child: const Text('A', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Admin: số liệu hệ thống',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSub),
                    ),
                    Text(
                      'Tổng quan Hệ Thống',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textMain),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _loadDashboardData,
                tooltip: 'Làm mới dữ liệu',
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Lưới 4 thẻ KPI Dữ liệu thật
          Row(
            children: [
              Expanded(
                child: AdminKpiCard(
                  title: 'Người dùng',
                  value: totalUsers > 0 ? '$totalUsers' : '1',
                  subtitle: '$studentCount học sinh • $teacherCount GV',
                  icon: Icons.people_alt_rounded,
                  iconColor: AppTokens.primary,
                  onTap: () => widget.onNavigateTab?.call(2), // Sang Tab Người dùng
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AdminKpiCard(
                  title: 'Đề thi & Giám sát',
                  value: '$activeExams',
                  subtitle: 'Đang mở trên lớp',
                  icon: Icons.shield_rounded,
                  iconColor: const Color(0xFFEA580C),
                  onTap: () => widget.onNavigateTab?.call(3), // Sang Tab Lớp & Thi
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AdminKpiCard(
                  title: 'Tài khoản bị khóa',
                  value: '$lockedCount',
                  subtitle: lockedCount > 0 ? 'Vi phạm quy định' : 'Hệ thống an toàn',
                  icon: Icons.lock_person_rounded,
                  iconColor: lockedCount > 0 ? AppTokens.danger : AppTokens.success,
                  onTap: () => widget.onNavigateTab?.call(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AdminKpiCard(
                  title: 'Nhật ký kiểm toán',
                  value: '${_auditLogs.length}',
                  subtitle: 'Sự kiện hệ thống',
                  icon: Icons.history_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  onTap: () => widget.onNavigateTab?.call(4), // Sang Tab Quản trị
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Khối "Việc Cần Làm" (Actionable Tasks)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Việc cần làm',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textMain),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTokens.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Ưu tiên cao',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTokens.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Mục 1: Duyệt giáo viên
                _buildActionItem(
                  icon: Icons.verified_user_rounded,
                  iconColor: const Color(0xFFD97706),
                  title: 'Quản lý & Duyệt phân quyền Giáo viên',
                  subtitle: 'Kiểm tra và cấp quyền ra đề, tạo phòng thi có giám sát 10s',
                  onTap: () => widget.onNavigateTab?.call(2),
                  textMain: textMain,
                  textSub: textSub,
                ),
                const Divider(height: 16),

                // Mục 2: Kiểm tra kỳ thi đang thi trực tiếp
                _buildActionItem(
                  icon: Icons.videocam_rounded,
                  iconColor: const Color(0xFFDC2626),
                  title: 'Theo dõi Phòng thi Trực tiếp (10s Live Proctoring)',
                  subtitle: 'Bắt các ca học sinh thoát app sang ChatGPT quá 10 giây',
                  onTap: () => widget.onNavigateTab?.call(3),
                  textMain: textMain,
                  textSub: textSub,
                ),
                const Divider(height: 16),

                // Mục 3: Quản lý học liệu SGK 12
                _buildActionItem(
                  icon: Icons.auto_stories_rounded,
                  iconColor: AppTokens.primary,
                  title: 'Rà soát 10 Unit Sách Giáo Khoa Global Success 12',
                  subtitle: 'Chỉnh sửa bài đọc, từ vựng IPA hoặc nhập sách mới bằng AI',
                  onTap: () => widget.onNavigateTab?.call(1),
                  textMain: textMain,
                  textSub: textSub,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Lối tắt tác vụ
          Text(
            'Lối tắt tác vụ',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: textMain),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => widget.onNavigateTab?.call(1),
                  icon: const Icon(Icons.post_add_rounded, size: 18),
                  label: const Text('Soạn câu hỏi', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => widget.onNavigateTab?.call(1),
                  icon: const Icon(Icons.document_scanner_rounded, size: 18),
                  label: const Text('Nhập sách AI', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => widget.onNavigateTab?.call(3),
                  icon: const Icon(Icons.shield_outlined, size: 18),
                  label: const Text('Tạo thi 10s', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => widget.onNavigateTab?.call(2),
                  icon: const Icon(Icons.verified_user_outlined, size: 18),
                  label: const Text('Duyệt giáo viên', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Dòng hoạt động gần nhất (Recent Audit Feed)
          Text(
            'Nhật ký hoạt động gần nhất',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: textMain),
          ),
          const SizedBox(height: 10),
          if (_auditLogs.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Center(
                child: Text('Chưa có hoạt động quản trị nào phát sinh.', style: TextStyle(color: textSub)),
              ),
            )
          else
            ..._auditLogs.take(3).map((log) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTokens.primary.withAlpha(20),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.history_rounded, size: 16, color: AppTokens.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (log['action'] ?? 'THAO TÁC HỆ THỐNG').toString(),
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: textMain),
                          ),
                          Text(
                            (log['details'] ?? '').toString(),
                            style: TextStyle(fontSize: 11.5, color: textSub),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color textMain,
    required Color textSub,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: textMain)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 11.5, color: textSub)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: textSub, size: 18),
          ],
        ),
      ),
    );
  }
}
