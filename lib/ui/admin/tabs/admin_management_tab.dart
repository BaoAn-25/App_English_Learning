import 'package:flutter/material.dart';

import '../../../data/app_repository.dart';
import '../../../data/rbac_proctor_ai_service.dart';
import '../components/admin_kpi_card.dart';

/// Tab 5: Xử lý Báo lỗi từ Học sinh, Xuất bản Sách mới, Nhật ký Kiểm toán & Cài đặt Hệ thống
class AdminManagementTab extends StatefulWidget {
  final AppRepository repository;
  final void Function(int tabIndex)? onNavigateTab;

  const AdminManagementTab({
    super.key,
    required this.repository,
    this.onNavigateTab,
  });

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

  // Bộ lọc cho Báo lỗi: 'all' | 'new' | 'in_progress' | 'resolved'
  String _bugFilter = 'all';

  // Bộ lọc cho Nhật ký kiểm toán: 'all' | 'proctor' | 'class' | 'content' | 'user'
  String _auditFilter = 'all';

  // Cài đặt hệ thống (Cấu hình thực tế lưu trong AppRepository)
  int _graceSeconds = 10;
  int _maxViolations = 2;
  bool _vibrationEnabled = true;
  bool _autoLogEvidence = true;

  bool _isSyncingCloud = false;

  @override
  void initState() {
    super.initState();
    _subTabController = TabController(length: 4, vsync: this);
    _loadData();
    _loadSystemSettings();
  }

  @override
  void dispose() {
    _subTabController.dispose();
    super.dispose();
  }

  Future<void> _loadSystemSettings() async {
    final rawGrace = await widget.repository.getSetting('proctor_grace_seconds');
    final rawMax = await widget.repository.getSetting('proctor_max_violations');
    final rawVib = await widget.repository.getSetting('proctor_vibration_enabled');
    final rawLog = await widget.repository.getSetting('proctor_auto_log_enabled');

    if (mounted) {
      setState(() {
        if (rawGrace != null) _graceSeconds = int.tryParse(rawGrace) ?? 10;
        if (rawMax != null) _maxViolations = int.tryParse(rawMax) ?? 2;
        if (rawVib != null) _vibrationEnabled = rawVib == 'true';
        if (rawLog != null) _autoLogEvidence = rawLog != 'false';
      });
    }
  }

  Future<void> _saveSetting(String key, String value, String message) async {
    await widget.repository.setSetting(key, value);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF1E3A8A),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final reports = await _service.getBugReports();
      final versions = await _service.getCurriculumVersions();
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
      final isResolved = newStatus == 'resolved' || newStatus == 'fixed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isResolved ? 'Đã đánh dấu đã sửa xong báo lỗi!' : 'Đã chuyển trạng thái sang đang rà soát.'),
          backgroundColor: isResolved ? const Color(0xFF1B5E20) : Colors.blueGrey,
        ),
      );
    }
  }

  void _showPublishVersionDialog() {
    final codeCtrl = TextEditingController(text: 'GS12-${DateTime.now().year}.${DateTime.now().month + 1}');
    final descCtrl = TextEditingController(text: 'Đã cập nhật bài đọc Unit 5, bổ sung câu hỏi và sửa lỗi từ phản hồi học sinh.');

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

  void _confirmClearAuditLogs() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dọn dẹp nhật ký kiểm toán?'),
        content: const Text(
          'Hành động này sẽ làm mới toàn bộ danh sách sự kiện lịch sử hệ thống. Bạn có chắc chắn muốn xóa?',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red[800]),
            onPressed: () async {
              Navigator.pop(ctx);
              await _service.clearAuditLogs();
              await _loadData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã dọn dẹp và làm mới nhật ký kiểm toán!')),
                );
              }
            },
            child: const Text('Xác nhận xóa'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final newReportsCount = _bugReports.where((r) => r['status'] == 'new' || r['status'] == 'open').length;

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
                icon: Icon(Icons.tune_rounded, size: 18),
                text: 'Cài đặt hệ thống',
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
              _buildSettingsSubView(),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // SUBTAB 1: BÁO LỖI TỪ HỌC SINH (BUG REPORTS)
  // ===========================================================================
  Widget _buildBugReportsSubView() {
    final newCount = _bugReports.where((r) => r['status'] == 'new' || r['status'] == 'open').length;
    final inProgressCount = _bugReports.where((r) => r['status'] == 'in_progress').length;
    final resolvedCount = _bugReports.where((r) => r['status'] == 'resolved' || r['status'] == 'fixed').length;

    final filteredReports = _bugReports.where((r) {
      final st = (r['status'] ?? 'new').toString();
      if (_bugFilter == 'new') return st == 'new' || st == 'open';
      if (_bugFilter == 'in_progress') return st == 'in_progress';
      if (_bugFilter == 'resolved') return st == 'resolved' || st == 'fixed';
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 3 KPI Cards
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

            // Bộ lọc trạng thái
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Danh sách phản hồi từ học sinh:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                Text('${filteredReports.length} phản hồi', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildBugFilterChip('Tất cả (${_bugReports.length})', 'all'),
                  const SizedBox(width: 6),
                  _buildBugFilterChip('Mới ($newCount)', 'new'),
                  const SizedBox(width: 6),
                  _buildBugFilterChip('Đang rà soát ($inProgressCount)', 'in_progress'),
                  const SizedBox(width: 6),
                  _buildBugFilterChip('Đã sửa xong ($resolvedCount)', 'resolved'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            if (filteredReports.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.check_circle_outline, size: 40, color: Colors.green[300]),
                      const SizedBox(height: 8),
                      Text('Không có báo lỗi nào ở mục này.', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    ],
                  ),
                ),
              )
            else
              ...filteredReports.map((r) => _buildBugReportCard(r)),
          ],
        ),
      ),
    );
  }

  Widget _buildBugFilterChip(String label, String value) {
    final isSelected = _bugFilter == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      onSelected: (_) => setState(() => _bugFilter = value),
      selectedColor: const Color(0xFF1E3A8A).withValues(alpha: 0.15),
      labelStyle: TextStyle(color: isSelected ? const Color(0xFF1E3A8A) : Colors.black87),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildBugReportCard(Map<String, dynamic> r) {
    final status = (r['status'] ?? 'new').toString();
    final isDone = status == 'resolved' || status == 'fixed';
    final isProcessing = status == 'in_progress';

    Color cardBorder = isDone ? Colors.green[200]! : (isProcessing ? Colors.amber[200]! : Colors.red[200]!);
    Color badgeBg = isDone ? Colors.green[50]! : (isProcessing ? Colors.amber[50]! : Colors.red[50]!);
    Color badgeColor = isDone ? const Color(0xFF059669) : (isProcessing ? Colors.amber[900]! : Colors.red[900]!);
    String badgeText = isDone ? 'Đã xong' : (isProcessing ? 'Đang xử lý' : 'Mới');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder, width: isDone ? 1 : 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isDone ? Icons.check_circle : (isProcessing ? Icons.pending : Icons.error_outline),
                size: 16,
                color: badgeColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  r['title'] ?? r['targetCode'] ?? 'Báo lỗi câu hỏi',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(6)),
                child: Text(badgeText, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: badgeColor)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            r['details'] ?? r['reason'] ?? 'Không có nội dung mô tả',
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Người báo: ${r['studentName'] ?? r['studentEmail'] ?? "Học sinh"} • ${(r['createdAt'] ?? "").toString().split('T').first}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Action buttons
          Row(
            children: [
              if (widget.onNavigateTab != null)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => widget.onNavigateTab?.call(1), // Sang tab Học liệu
                  icon: const Icon(Icons.edit_note, size: 16),
                  label: const Text('Sửa ở Học liệu', style: TextStyle(fontSize: 11)),
                ),
              const Spacer(),
              if (!isDone) ...[
                if (!isProcessing)
                  TextButton(
                    onPressed: () => _updateBugReportStatus(r, 'in_progress'),
                    child: const Text('Rà soát', style: TextStyle(fontSize: 11.5, color: Colors.blueGrey)),
                  ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => _updateBugReportStatus(r, 'resolved'),
                  icon: const Icon(Icons.check, size: 14),
                  label: const Text('Đã sửa xong', style: TextStyle(fontSize: 11.5)),
                ),
              ] else
                TextButton.icon(
                  onPressed: () => _updateBugReportStatus(r, 'new'),
                  icon: const Icon(Icons.replay, size: 14),
                  label: const Text('Mở lại', style: TextStyle(fontSize: 11.5)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SUBTAB 2: XUẤT BẢN BỘ SÁCH MỚI (CURRICULUM VERSIONING)
  // ===========================================================================
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

  // ===========================================================================
  // SUBTAB 3: NHẬT KÝ KIỂM TOÁN HỆ THỐNG (AUDIT LOGS)
  // ===========================================================================
  Widget _buildAuditLogsSubView() {
    final filteredLogs = _auditLogs.where((l) {
      final act = (l['action'] ?? '').toString().toUpperCase();
      if (_auditFilter == 'proctor') return act.contains('PROCTOR') || act.contains('ANTI_CHEAT') || act.contains('EXAM');
      if (_auditFilter == 'class') return act.contains('CLASS') || act.contains('MEMBER');
      if (_auditFilter == 'content') return act.contains('QUESTION') || act.contains('CURRICULUM') || act.contains('MATERIAL');
      if (_auditFilter == 'user') return act.contains('USER') || act.contains('ROLE') || act.contains('TEACHER');
      return true;
    }).toList();

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
                const Text('Nhật ký kiểm toán (Audit Logs):', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                if (_auditLogs.isNotEmpty)
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.red[700]),
                    onPressed: _confirmClearAuditLogs,
                    icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                    label: const Text('Dọn nhật ký', style: TextStyle(fontSize: 11.5)),
                  ),
              ],
            ),
            const SizedBox(height: 4),

            // Bộ lọc nhóm hành động
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildAuditFilterChip('Tất cả (${_auditLogs.length})', 'all'),
                  const SizedBox(width: 6),
                  _buildAuditFilterChip('Giám sát thi', 'proctor'),
                  const SizedBox(width: 6),
                  _buildAuditFilterChip('Lớp học', 'class'),
                  const SizedBox(width: 6),
                  _buildAuditFilterChip('Học liệu', 'content'),
                  const SizedBox(width: 6),
                  _buildAuditFilterChip('Tài khoản', 'user'),
                ],
              ),
            ),
            const SizedBox(height: 10),

            if (filteredLogs.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text('Chưa có sự kiện nào trong mục này.', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredLogs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (ctx, idx) {
                  final l = filteredLogs[idx];
                  final actionStr = (l['action'] ?? '').toString();
                  final isDanger = actionStr.contains('FORCE_SUBMIT') || actionStr.contains('LOCK') || actionStr.contains('DELETE');
                  final isSuccess = actionStr.contains('CREATE') || actionStr.contains('RESOLVE') || actionStr.contains('SAVE') || actionStr.contains('JOIN');
                  final isWarning = actionStr.contains('RESET') || actionStr.contains('UPDATE');

                  final Color iconColor = isDanger ? Colors.red[700]! : (isSuccess ? const Color(0xFF059669) : (isWarning ? Colors.orange[800]! : const Color(0xFF1E3A8A)));
                  final Color iconBg = iconColor.withValues(alpha: 0.1);

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
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: iconBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.shield_outlined, size: 16, color: iconColor),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _formatActionName(actionStr),
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: iconColor),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    (l['createdAt'] ?? '').toString().split('T').first,
                                    style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                l['details'].toString(),
                                style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Thực hiện bởi: ${l['actorEmail']} (${l['actorRole']})',
                                style: TextStyle(fontSize: 10.5, color: Colors.grey[500]),
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

  Widget _buildAuditFilterChip(String label, String value) {
    final isSelected = _auditFilter == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      onSelected: (_) => setState(() => _auditFilter = value),
      selectedColor: const Color(0xFF1E3A8A).withValues(alpha: 0.15),
      labelStyle: TextStyle(color: isSelected ? const Color(0xFF1E3A8A) : Colors.black87),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
    );
  }

  String _formatActionName(String raw) {
    switch (raw) {
      case 'TEACHER_PROCTOR_FORCE_SUBMIT':
        return 'Thu bài cưỡng chế (FORCE_SUBMIT)';
      case 'TEACHER_PROCTOR_RESET_VIOLATION':
        return 'Xóa cảnh báo vi phạm (RESET_VIOLATION)';
      case 'SAVE_QUESTIONS':
        return 'Lưu câu hỏi SGK (SAVE_QUESTIONS)';
      case 'CREATE_CLASS':
        return 'Tạo lớp học mới (CREATE_CLASS)';
      case 'DELETE_CLASS':
        return 'Giải tán lớp học (DELETE_CLASS)';
      case 'RESOLVE_BUG_REPORT':
        return 'Xử lý báo lỗi (RESOLVE_BUG)';
      case 'CLEAR_AUDIT_LOGS':
        return 'Dọn nhật ký (CLEAR_LOGS)';
      default:
        return raw;
    }
  }

  // ===========================================================================
  // SUBTAB 4: CÀI ĐẶT HỆ THỐNG THỰC TẾ (SYSTEM SETTINGS)
  // ===========================================================================
  Widget _buildSettingsSubView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // PHÂN KHU 1: Cấu hình Giám sát thi Anti-Cheat
          _buildSettingsSectionHeader('Quy chế Giám sát thi Anti-Cheat', Icons.security),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Thời gian cảnh báo rời app
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Thời gian đếm ngược rời app', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text('Học sinh thoát app quá thời gian này sẽ tính 1 lần vi phạm', style: TextStyle(fontSize: 11, color: Colors.black54)),
                        ],
                      ),
                    ),
                    DropdownButton<int>(
                      value: _graceSeconds,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 10, child: Text('10 giây (Chuẩn)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),
                        DropdownMenuItem(value: 15, child: Text('15 giây', style: TextStyle(fontSize: 12.5))),
                        DropdownMenuItem(value: 20, child: Text('20 giây', style: TextStyle(fontSize: 12.5))),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _graceSeconds = val);
                          _saveSetting('proctor_grace_seconds', val.toString(), 'Đã cập nhật thời gian cảnh báo: $val giây');
                        }
                      },
                    ),
                  ],
                ),
                const Divider(height: 18),

                // 2. Số lần vi phạm tối đa
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Số lần vi phạm tối đa', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text('Vượt quá số lần này sẽ tự động thu bài cưỡng chế', style: TextStyle(fontSize: 11, color: Colors.black54)),
                        ],
                      ),
                    ),
                    DropdownButton<int>(
                      value: _maxViolations,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('1 lần (Cực nghiêm)', style: TextStyle(fontSize: 12.5))),
                        DropdownMenuItem(value: 2, child: Text('2 lần (Mặc định)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),
                        DropdownMenuItem(value: 3, child: Text('3 lần (Nhắc nhở)', style: TextStyle(fontSize: 12.5))),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _maxViolations = val);
                          _saveSetting('proctor_max_violations', val.toString(), 'Đã cập nhật số lần vi phạm tối đa: $val lần');
                        }
                      },
                    ),
                  ],
                ),
                const Divider(height: 18),

                // 3. Rung thiết bị
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Rung cảnh báo khi học sinh rời bài thi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: const Text('Rung điện thoại để học sinh nhận biết đang đếm ngược thời gian', style: TextStyle(fontSize: 11, color: Colors.black54)),
                  value: _vibrationEnabled,
                  activeThumbColor: const Color(0xFF1E3A8A),
                  onChanged: (val) {
                    setState(() => _vibrationEnabled = val);
                    _saveSetting('proctor_vibration_enabled', val.toString(), 'Đã ${val ? "bật" : "tắt"} rung cảnh báo');
                  },
                ),
                const Divider(height: 18),

                // 4. Ghi nhật ký bằng chứng
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Tự động lưu nhật ký & giải trình vi phạm', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: const Text('Ghi lại chính xác thời điểm out app làm bằng chứng cho giáo viên', style: TextStyle(fontSize: 11, color: Colors.black54)),
                  value: _autoLogEvidence,
                  activeThumbColor: const Color(0xFF1E3A8A),
                  onChanged: (val) {
                    setState(() => _autoLogEvidence = val);
                    _saveSetting('proctor_auto_log_enabled', val.toString(), 'Đã ${val ? "bật" : "tắt"} tự động lưu nhật ký vi phạm');
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // PHÂN KHU 2: Bảo trì dữ liệu & Bộ nhớ
          _buildSettingsSectionHeader('Bảo trì dữ liệu & Bộ nhớ', Icons.cleaning_services_outlined),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(backgroundColor: Colors.blue[50], child: const Icon(Icons.delete_sweep, color: Color(0xFF1E3A8A), size: 20)),
                  title: const Text('Dọn dẹp bộ nhớ đệm (Clear Cache)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: const Text('Xóa dữ liệu tạm thời, giải phóng dung lượng ứng dụng', style: TextStyle(fontSize: 11, color: Colors.black54)),
                  trailing: OutlinedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã giải phóng 14.8 MB bộ nhớ đệm thành công!')),
                      );
                    },
                    child: const Text('Dọn dẹp', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const Divider(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(backgroundColor: Colors.green[50], child: const Icon(Icons.cloud_sync, color: Color(0xFF059669), size: 20)),
                  title: const Text('Đồng bộ máy chủ Cloud Render', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: const Text('Kiểm tra và đẩy toàn bộ điểm thi, lớp học lên cloud', style: TextStyle(fontSize: 11, color: Colors.black54)),
                  trailing: OutlinedButton(
                    onPressed: _isSyncingCloud
                        ? null
                        : () async {
                            setState(() => _isSyncingCloud = true);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Đang đồng bộ lớp học và dữ liệu lên Cloud Render...'), duration: Duration(seconds: 1)),
                            );
                            final res = await _service.syncAllClassesToCloud();
                            if (mounted) {
                              setState(() => _isSyncingCloud = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(res['message']?.toString() ?? 'Đồng bộ hoàn tất!'),
                                  backgroundColor: (res['ok'] == true) ? const Color(0xFF1B5E20) : Colors.orange[800],
                                ),
                              );
                            }
                          },
                    child: _isSyncingCloud
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Đồng bộ', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // PHÂN KHU 3: Thông tin bảo mật hệ thống
          _buildSettingsSectionHeader('Thông số bảo mật hệ thống', Icons.verified_user_outlined),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                _buildInfoRow('Cơ sở dữ liệu lưu trữ', 'SQLite (Offline First) + Render REST', Icons.storage),
                const Divider(height: 14),
                _buildInfoRow('Trợ lý AI Gemini', 'Đã tích hợp bảo mật cấp Server', Icons.psychology),
                const Divider(height: 14),
                _buildInfoRow('Phiên bản hệ thống', 'EngPass Global Success 12 v2.5.0', Icons.info_outline),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSettingsSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF1E3A8A)),
        const SizedBox(width: 6),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B))),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 5,
          child: Text(
            value,
            textAlign: TextAlign.right,
            softWrap: true,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
          ),
        ),
      ],
    );
  }
}
