import 'package:flutter/material.dart';

import '../../../data/app_repository.dart';
import '../../../data/rbac_proctor_ai_service.dart';
import '../components/admin_kpi_card.dart';
import '../components/student_preview_mode.dart';

/// Tab 5: Xử lý Báo lỗi từ Học sinh, Xuất bản Sách mới, Nhật ký Kiểm toán & Cài đặt Hệ thống
class AdminManagementTab extends StatefulWidget {
  final AppRepository repository;

  const AdminManagementTab({super.key, required this.repository});

  @override
  State<AdminManagementTab> createState() => _AdminManagementTabState();
}

class _AdminManagementTabState extends State<AdminManagementTab> with SingleTickerProviderStateMixin {
  final RbacProctorAiService _service = RbacProctorAiService.instance;
  late TabController _subTabController;

  List<Map<String, dynamic>> _bugReports = [];
  List<Map<String, dynamic>> _curriculumVersions = [];
  List<Map<String, dynamic>> _auditLogs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _subTabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _subTabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Tải danh sách báo lỗi học viên thật
      final reports = await _service.getBugReports();

      // 2. Tải danh sách các phiên bản giáo trình SGK
      final versions = await _service.getCurriculumVersions();

      // 3. Tải nhật ký kiểm toán hệ thống thật
      final logs = await _service.getAuditLogs();

      if (mounted) {
        setState(() {
          _bugReports = reports;
          _curriculumVersions = versions;
          _auditLogs = logs;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateBugReportStatus(Map<String, dynamic> report, String newStatus) async {
    await _service.updateBugReportStatus(
      reportId: report['id'].toString(),
      status: newStatus,
    );
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newStatus == 'resolved' || newStatus == 'fixed' ? 'Đã đánh dấu đã xử lý xong!' : 'Đã chuyển trạng thái'),
          backgroundColor: newStatus == 'resolved' || newStatus == 'fixed' ? const Color(0xFF1B5E20) : Colors.blueGrey,
        ),
      );
    }
  }

  void _showPublishVersionDialog() {
    final codeCtrl = TextEditingController(text: 'GS12-${DateTime.now().year}.${DateTime.now().month + 1}');
    final descCtrl = TextEditingController(text: 'Đã cập nhật bài đọc Unit 5, bổ sung câu hỏi và sửa 4 lỗi từ báo cáo.');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xuất bản phiên bản sách mới'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Phiên bản mới sẽ lập tức áp dụng cho toàn bộ học sinh và giáo viên trong hệ thống.',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeCtrl,
              decoration: const InputDecoration(labelText: 'Mã phiên bản (Version Code)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Ghi chú thay đổi (Changelog)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
            onPressed: () async {
              Navigator.pop(ctx);
              await _service.saveAndOptionallyActivateCurriculum(
                versionCode: codeCtrl.text.trim(),
                title: 'SGK Tiếng Anh 12 Global Success (${codeCtrl.text.trim()})',
                description: descCtrl.text.trim(),
                payload: {
                  'unitCount': 10,
                  'publishedAt': DateTime.now().toIso8601String(),
                },
                activateImmediately: true,
              );
              _loadData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã xuất bản và kích hoạt thành công phiên bản ${codeCtrl.text.trim()}!'),
                    backgroundColor: const Color(0xFF1B5E20),
                  ),
                );
              }
            },
            child: const Text('Xuất bản ngay'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final newReportsCount = _bugReports.where((r) => r['status'] == 'new').length;

    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _subTabController,
            isScrollable: true,
            labelColor: const Color(0xFF1E3A8A),
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: const Color(0xFF1E3A8A),
            indicatorWeight: 3,
            tabs: [
              Tab(
                icon: const Icon(Icons.bug_report_outlined, size: 18),
                text: 'Báo lỗi ($newReportsCount mới)',
              ),
              Tab(
                icon: const Icon(Icons.publish_outlined, size: 18),
                text: 'Xuất bản sách (${_curriculumVersions.length})',
              ),
              Tab(
                icon: const Icon(Icons.history_edu_outlined, size: 18),
                text: 'Nhật ký (${_auditLogs.length})',
              ),
              const Tab(
                icon: Icon(Icons.settings_outlined, size: 18),
                text: 'Cài đặt & Xem trước',
              ),
            ],
          ),
        ),
        if (_isLoading) const LinearProgressIndicator(minHeight: 2),

        Expanded(
          child: TabBarView(
            controller: _subTabController,
            children: [
              _buildBugReportsSubView(),
              _buildCurriculumPublishSubView(),
              _buildAuditLogsSubView(),
              _buildSettingsAndPreviewSubView(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBugReportsSubView() {
    final newCount = _bugReports.where((r) => r['status'] == 'new' || r['status'] == 'open').length;
    final inProgressCount = _bugReports.where((r) => r['status'] == 'in_progress').length;
    final resolvedCount = _bugReports.where((r) => r['status'] == 'resolved' || r['status'] == 'fixed').length;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: AdminKpiCard(
                    title: 'Mới gửi',
                    value: '$newCount',
                    subtitle: 'Cần xử lý',
                    icon: Icons.mark_email_unread_outlined,
                    iconColor: Colors.red,
                    backgroundColor: Colors.red[50]!,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AdminKpiCard(
                    title: 'Đang xử lý',
                    value: '$inProgressCount',
                    subtitle: 'Đang rà soát',
                    icon: Icons.pending_actions_outlined,
                    iconColor: Colors.amber[800]!,
                    backgroundColor: Colors.amber[50]!,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AdminKpiCard(
                    title: 'Đã xong',
                    value: '$resolvedCount',
                    subtitle: 'Đã sửa chữa',
                    icon: Icons.check_circle_outline,
                    iconColor: Colors.green,
                    backgroundColor: Colors.green[50]!,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Danh sách phản hồi từ học sinh:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (_bugReports.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: const Text(
                  'Chưa có báo lỗi câu hỏi/bài đọc nào từ học sinh.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _bugReports.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (ctx, idx) {
                  final r = _bugReports[idx];
                  final isNew = r['status'] == 'new' || r['status'] == 'open';
                  final isResolved = r['status'] == 'resolved' || r['status'] == 'fixed';
                  final title = (r['title'] ?? r['targetCode'] ?? 'Báo lỗi câu hỏi').toString();
                  final details = (r['details'] ?? r['reason'] ?? '').toString();
                  final reporter = (r['reportedBy'] ?? r['reporter'] ?? 'Học sinh').toString();
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isResolved ? Colors.grey[50] : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isNew ? Colors.red[200]! : Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isResolved ? Icons.check_circle : (isNew ? Icons.error_outline : Icons.pending),
                              color: isResolved ? Colors.green : (isNew ? Colors.red : Colors.amber),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  decoration: isResolved ? TextDecoration.lineThrough : null,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isResolved
                                    ? Colors.green[100]
                                    : (isNew ? Colors.red[100] : Colors.amber[100]),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isResolved ? 'Đã xong' : (isNew ? 'Mới' : 'Đang xử lý'),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isResolved ? Colors.green[900] : (isNew ? Colors.red[900] : Colors.amber[900]),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(details, style: TextStyle(fontSize: 13, color: Colors.grey[800])),
                        const SizedBox(height: 6),
                        Text(
                          'Người báo: $reporter • ${(r['createdAt'] ?? '').toString().split('T').first}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                        if (!isResolved) ...[
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                onPressed: () => _updateBugReportStatus(r, 'ignored'),
                                child: const Text('Bỏ qua'),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF1B5E20),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () => _updateBugReportStatus(r, 'fixed'),
                                child: const Text('Đã sửa xong'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurriculumPublishSubView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.rocket_launch, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Trung tâm Xuất bản Bộ sách mới',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Cho phép kích hoạt toàn bộ dữ liệu sách mới vào SQLite đồng bộ mà không xóa dữ liệu học viên.',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1E3A8A),
                  ),
                  onPressed: _showPublishVersionDialog,
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: const Text('Xuất bản & Kích hoạt phiên bản mới'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('Các phiên bản giáo trình trong hệ thống:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _curriculumVersions.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (ctx, idx) {
              final v = _curriculumVersions[idx];
              final isActive = v['isActive'] == true;
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isActive ? const Color(0xFF1E3A8A) : Colors.grey[200]!,
                    width: isActive ? 1.5 : 1.0,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          v['versionCode'].toString(),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(width: 8),
                        if (isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Đang sử dụng',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(v['title'].toString(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(v['description'].toString(), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    const SizedBox(height: 10),
                    if (!isActive)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF1E3A8A),
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () async {
                              await _service.activateCurriculumVersion(v['id'].toString());
                              _loadData();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Đã kích hoạt phiên bản ${v['versionCode']}')),
                                );
                              }
                            },
                            child: const Text('Kích hoạt bản này'),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAuditLogsSubView() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Nhật ký kiểm toán (Audit Logs):', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('${_auditLogs.length} sự kiện', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
            const SizedBox(height: 10),
            if (_auditLogs.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text('Chưa có nhật ký hoạt động nào.', style: TextStyle(color: Colors.grey[600])),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _auditLogs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (ctx, idx) {
                  final l = _auditLogs[idx];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.shield_outlined, size: 16, color: Colors.blueGrey),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    l['action'].toString(),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const Spacer(),
                                  Text(
                                    (l['createdAt'] ?? '').toString().split('T').first,
                                    style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                l['details'].toString(),
                                style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Thực hiện bởi: ${l['actorEmail']} (${l['actorRole']})',
                                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsAndPreviewSubView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thẻ Xem Trước Giao Diện Học Sinh (Preview Mode)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.remove_red_eye_outlined, color: Color(0xFF15803D)),
                    SizedBox(width: 8),
                    Text(
                      'Chế độ Xem trước Giao diện Học sinh',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF15803D)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Cho phép Quản trị viên trải nghiệm toàn bộ giao diện học bài, streak, ôn tập từ vựng chuẩn như một học sinh thông thường. Phía trên màn hình sẽ có thanh thông báo "Đang xem trước" để bạn có thể quay lại Trung tâm Admin bất kỳ lúc nào.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF166534)),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF15803D)),
                  onPressed: () {
                    StudentPreviewMode.instance.enterPreview();
                  },
                  icon: const Icon(Icons.school),
                  label: const Text('Bật Chế Độ Xem Trước Học Sinh'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const Text('Cài đặt chung hệ thống:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.security, color: Color(0xFF1E3A8A)),
                  title: const Text('Quy chế giám sát thi 10 giây (Anti-Cheat)'),
                  subtitle: const Text('Bắt buộc out app >10s cảnh báo, quá 2 lần cưỡng chế nộp bài'),
                  trailing: const Icon(Icons.check, color: Colors.green),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.cloud_done, color: Color(0xFF1E3A8A)),
                  title: const Text('Cấu hình API Gemini trên Render'),
                  subtitle: const Text('Bảo mật biến môi trường GEMINI_API_KEY ở cấp Server'),
                  trailing: const Icon(Icons.verified, color: Colors.green),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.storage, color: Color(0xFF1E3A8A)),
                  title: const Text('Dữ liệu lưu trữ SQLite + Render REST'),
                  subtitle: const Text('Đảm bảo 100% dữ liệu thật, không mock tĩnh'),
                  trailing: const Icon(Icons.check, color: Colors.green),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
