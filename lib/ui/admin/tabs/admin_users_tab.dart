import 'package:flutter/material.dart';

import '../../../data/app_repository.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/rbac_proctor_ai_service.dart';
import '../components/admin_kpi_card.dart';
import '../../common/dialogs/student_progress_sheet.dart';

/// Tab 3: Quản lý Người dùng, Phân quyền RBAC & Duyệt hồ sơ Giáo viên
class AdminUsersTab extends StatefulWidget {
  final AppRepository repository;

  const AdminUsersTab({super.key, required this.repository});

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> {
  final RbacProctorAiService _service = RbacProctorAiService.instance;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _pendingTeachers = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // 'all' | 'student' | 'teacher' | 'locked'

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final users = await _service.getAdminUsers();
      final pending = await _service.getTeacherRequests();

      if (mounted) {
        setState(() {
          _users = users;
          _pendingTeachers = pending;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    final query = _searchController.text.trim().toLowerCase();
    return _users.where((u) {
      final role = (u['role'] ?? 'student').toString().toLowerCase();
      final isLocked = u['is_locked'] == true;

      if (_selectedFilter == 'student' && role != 'student') return false;
      if (_selectedFilter == 'teacher' && role != 'teacher') return false;
      if (_selectedFilter == 'locked' && !isLocked) return false;

      if (query.isNotEmpty) {
        final email = (u['email'] ?? '').toString().toLowerCase();
        final name = (u['display_name'] ?? u['displayName'] ?? '').toString().toLowerCase();
        if (!email.contains(query) && !name.contains(query)) return false;
      }
      return true;
    }).toList();
  }

  Future<void> _approveTeacher(Map<String, dynamic> teacher) async {
    setState(() => _isLoading = true);
    final tName = (teacher['display_name'] ?? teacher['name'] ?? teacher['email'] ?? 'Giáo viên').toString();
    try {
      await _service.decideTeacherRequest(
        request: {
          ...teacher,
          'display_name': tName,
        },
        approve: true,
      );
    } catch (error) {
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
        );
      }
      return;
    }
    await _loadData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã duyệt hồ sơ giáo viên: $tName!'),
          backgroundColor: const Color(0xFF1B5E20),
        ),
      );
    }
  }

  Future<void> _rejectTeacher(Map<String, dynamic> teacher) async {
    setState(() => _isLoading = true);
    final tName = (teacher['display_name'] ?? teacher['name'] ?? teacher['email'] ?? 'Giáo viên').toString();
    await _service.decideTeacherRequest(
      request: teacher,
      approve: false,
    );
    await _loadData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã từ chối yêu cầu của $tName'),
          backgroundColor: Colors.deepOrange,
        ),
      );
    }
  }

  void _showLockUserDialog(Map<String, dynamic> user) {
    final email = (user['email'] ?? '').toString();
    if (UserProfile.isSystemAdmin(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể khóa tài khoản Quản trị viên tối cao!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Khóa tài khoản ${user['display_name'] ?? email}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tài khoản sẽ bị tạm khóa không thể đăng nhập hoặc tham gia làm bài thi.',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Lý do khóa tài khoản',
                hintText: 'Nhập lý do khóa tài khoản...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final lockReason = reasonCtrl.text.trim();
              Navigator.pop(ctx);
              final email = (user['email'] ?? '').toString();
              final uId = user['id'].toString();
              final targetReason = lockReason.isNotEmpty ? lockReason : 'Tạm khóa bởi Quản trị viên';

              final idx = _users.indexWhere((u) =>
                  u['id']?.toString() == uId ||
                  (email.isNotEmpty && u['email']?.toString().toLowerCase() == email.toLowerCase()));
              if (idx >= 0) {
                setState(() {
                  _users[idx]['is_locked'] = true;
                  _users[idx]['locked_reason'] = targetReason;
                });
              }

              final updated = await _service.updateAdminUser(
                userId: uId,
                email: email,
                isLocked: true,
                lockedReason: targetReason,
              );
              if (!updated) {
                if (mounted && idx >= 0) {
                  setState(() {
                    _users[idx]['is_locked'] = false;
                    _users[idx]['locked_reason'] = '';
                  });
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _service.lastAdminUserError ??
                            'Không thể khóa tài khoản trên máy chủ. Vui lòng tải lại danh sách và thử lại.',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                return;
              }
              await _loadData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã khóa tài khoản $email. Tài khoản đã chuyển vào mục "Bị khóa".'),
                    backgroundColor: Colors.red[700],
                  ),
                );
              }
            },
            child: const Text('Xác nhận khóa'),
          ),
        ],
      ),
    );
  }

  void _showUnlockUser(Map<String, dynamic> user) async {
    final email = (user['email'] ?? '').toString();
    final uId = user['id'].toString();

    final idx = _users.indexWhere((u) =>
        u['id']?.toString() == uId ||
        (email.isNotEmpty && u['email']?.toString().toLowerCase() == email.toLowerCase()));
    if (idx >= 0) {
      setState(() {
        _users[idx]['is_locked'] = false;
        _users[idx]['locked_reason'] = '';
      });
    }

    final updated = await _service.updateAdminUser(
      userId: uId,
      email: email,
      isLocked: false,
      lockedReason: '',
    );
    if (!updated) {
      if (mounted && idx >= 0) {
        setState(() {
          _users[idx]['is_locked'] = true;
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể mở khóa tài khoản trên máy chủ. Vui lòng kiểm tra kết nối và thử lại.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã mở khóa tài khoản $email thành công.'),
          backgroundColor: const Color(0xFF1B5E20),
        ),
      );
    }
  }

  void _showChangeRoleDialog(Map<String, dynamic> user) {
    final email = (user['email'] ?? '').toString();
    if (UserProfile.isSystemAdmin(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể thay đổi vai trò Quản trị viên tối cao!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    String selectedRole = (user['role'] ?? 'student').toString();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: Text('Đổi quyền: ${user['display_name'] ?? email}'),
          content: RadioGroup<String>(
            groupValue: selectedRole,
            onChanged: (v) {
              if (v != null) setLocalState(() => selectedRole = v);
            },
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  title: Text('Học viên (Student)'),
                  subtitle: Text('Chỉ được học bài, làm bài tập & thi trực tuyến'),
                  value: 'student',
                ),
                RadioListTile<String>(
                  title: Text('Giáo viên (Teacher)'),
                  subtitle: Text('Soạn bài, tạo đề thi & giám sát phòng thi 10s'),
                  value: 'teacher',
                ),
                RadioListTile<String>(
                  title: Text('Quản trị viên (Admin)'),
                  subtitle: Text('Toàn quyền quản trị hệ thống'),
                  value: 'admin',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final updated = await _service.updateAdminUser(
                  userId: user['id'].toString(),
                  email: (user['email'] ?? '').toString(),
                  role: selectedRole,
                );
                if (!updated) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          _service.lastAdminUserError ??
                              'Không thể cập nhật vai trò trên máy chủ.',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                  return;
                }
                await _loadData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Đã cập nhật vai trò sang $selectedRole')),
                  );
                }
              },
              child: const Text('Lưu thay đổi'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTeacherModal() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final confirmPasswordCtrl = TextEditingController();
    int selectedTab = 0; // 0: Cấp quyền tài khoản có sẵn, 1: Thêm tài khoản mới

    final studentUsers = _users.where((u) {
      final r = (u['role'] ?? 'student').toString().toLowerCase();
      final em = (u['email'] ?? '').toString();
      return r != 'teacher' && !UserProfile.isSystemAdmin(em);
    }).toList();

    String? selectedUserId = studentUsers.isNotEmpty ? studentUsers.first['id']?.toString() : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.person_add_alt_1, color: Color(0xFF1E3A8A)),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Thêm & Phân quyền Giáo viên',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Chọn chế độ: Cấp quyền tài khoản có sẵn vs Tạo mới
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setSheetState(() => selectedTab = 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: selectedTab == 0 ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: selectedTab == 0
                                  ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1))]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Cấp quyền tài khoản có sẵn',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: selectedTab == 0 ? FontWeight.bold : FontWeight.normal,
                                color: selectedTab == 0 ? const Color(0xFF1E3A8A) : Colors.grey[700],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setSheetState(() => selectedTab = 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: selectedTab == 1 ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: selectedTab == 1
                                  ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1))]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Tạo tài khoản mới',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: selectedTab == 1 ? FontWeight.bold : FontWeight.normal,
                                color: selectedTab == 1 ? const Color(0xFF1E3A8A) : Colors.grey[700],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (selectedTab == 0) ...[
                  // TAB 0: Phân quyền từ tài khoản có sẵn
                  if (studentUsers.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: const Center(
                        child: Text(
                          'Tất cả tài khoản hiện tại đều đã là Giáo viên hoặc Admin.\nHãy chuyển sang tab "Tạo tài khoản mới".',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ),
                    )
                  else ...[
                    const Text(
                      'Chọn tài khoản cần cấp quyền Giáo viên:',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: selectedUserId,
                      decoration: const InputDecoration(
                        labelText: 'Tài khoản người dùng',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: studentUsers.map((u) {
                        final name = (u['display_name'] ?? u['displayName'] ?? u['email']?.toString().split('@').first ?? 'User').toString();
                        final email = (u['email'] ?? '').toString();
                        return DropdownMenuItem(
                          value: u['id'].toString(),
                          child: Text(
                            '$name ($email)',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13.5),
                          ),
                        );
                      }).toList(),
                      onChanged: (v) => setSheetState(() => selectedUserId = v),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Quyền được cấp theo vai trò Giáo viên trên máy chủ: soạn bài, tạo đề và giám sát phòng thi.',
                      style: TextStyle(fontSize: 12.5, color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)),
                        onPressed: selectedUserId == null
                            ? null
                            : () async {
                                final targetUser = studentUsers.firstWhere((u) => u['id'].toString() == selectedUserId);
                                final name = (targetUser['display_name'] ?? targetUser['displayName'] ?? targetUser['email'] ?? 'người dùng').toString();
                                final targetEmail = (targetUser['email'] ?? '').toString();
                                Navigator.pop(ctx);
                                final updated = await _service.updateAdminUser(
                                  userId: selectedUserId!,
                                  email: targetEmail,
                                  role: 'teacher',
                                );
                                if (!updated) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          _service.lastAdminUserError ??
                                              'Không thể cấp quyền trên máy chủ.',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                  return;
                                }
                                await _loadData();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Đã cấp quyền Giáo viên thành công cho "$name"!'),
                                      backgroundColor: const Color(0xFF059669),
                                    ),
                                  );
                                }
                              },
                        icon: const Icon(Icons.verified_user_rounded, size: 18),
                        label: const Text('Cấp quyền Giáo viên ngay', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ] else ...[
                  // TAB 1: Tạo tài khoản giáo viên mới
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Họ và tên giáo viên',
                      hintText: 'VD: Cô Thu Hà',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Địa chỉ Email trường / cá nhân',
                      hintText: 'thuha@nguyentrai.edu.vn',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Mật khẩu đăng nhập *',
                      hintText: 'Tối thiểu 6 ký tự',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmPasswordCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Xác nhận mật khẩu *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Quyền được cấp theo vai trò Giáo viên trên máy chủ: soạn bài, tạo đề và giám sát phòng thi.',
                    style: TextStyle(fontSize: 12.5, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
                      onPressed: () async {
                        final email = emailCtrl.text.trim();
                        final name = nameCtrl.text.trim();
                        final password = passwordCtrl.text;
                        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                            .hasMatch(email)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Vui lòng nhập email giáo viên hợp lệ!'), backgroundColor: Colors.orange),
                          );
                          return;
                        }
                        if (password.length < 6) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Mật khẩu phải có ít nhất 6 ký tự!'), backgroundColor: Colors.orange),
                          );
                          return;
                        }
                        if (password != confirmPasswordCtrl.text) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Mật khẩu xác nhận không khớp!'), backgroundColor: Colors.orange),
                          );
                          return;
                        }
                        Navigator.pop(ctx);
                        try {
                          await _service.createAdminUser(
                            email: email,
                            password: password,
                            displayName: name.isNotEmpty ? name : email.split('@').first,
                            role: 'teacher',
                          );
                        } catch (error) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
                            );
                          }
                          return;
                        }
                        await _loadData();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Đã thêm tài khoản Giáo viên "$email" thành công!'),
                              backgroundColor: const Color(0xFF1B5E20),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.person_add_rounded, size: 18),
                      label: const Text('Thêm tài khoản Giáo viên', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRoleMatrixModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.75,
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shield_outlined, color: Color(0xFF1E3A8A)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Bảng ma trận phân quyền (RBAC Matrix)',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    columnSpacing: 16,
                    columns: const [
                      DataColumn(label: Text('Quyền hạn / Chức năng', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Khách')),
                      DataColumn(label: Text('Học sinh')),
                      DataColumn(label: Text('Giáo viên')),
                      DataColumn(label: Text('Admin', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)))),
                    ],
                    rows: const [
                      DataRow(cells: [
                        DataCell(Text('Học theo SGK 12 & làm bài')),
                        DataCell(Icon(Icons.check, size: 18, color: Colors.green)),
                        DataCell(Icon(Icons.check, size: 18, color: Colors.green)),
                        DataCell(Icon(Icons.check, size: 18, color: Colors.green)),
                        DataCell(Icon(Icons.check, size: 18, color: Colors.green)),
                      ]),
                      DataRow(cells: [
                        DataCell(Text('Lưu tiến độ & Sổ tay từ vựng')),
                        DataCell(Icon(Icons.close, size: 18, color: Colors.grey)),
                        DataCell(Icon(Icons.check, size: 18, color: Colors.green)),
                        DataCell(Icon(Icons.check, size: 18, color: Colors.green)),
                        DataCell(Icon(Icons.check, size: 18, color: Colors.green)),
                      ]),
                      DataRow(cells: [
                        DataCell(Text('Dịch thuật 3-in-1 (Voice, Cam, OCR)')),
                        DataCell(Text('Giới hạn')),
                        DataCell(Icon(Icons.check, size: 18, color: Colors.green)),
                        DataCell(Icon(Icons.check, size: 18, color: Colors.green)),
                        DataCell(Icon(Icons.check, size: 18, color: Colors.green)),
                      ]),
                      DataRow(cells: [
                        DataCell(Text('Trợ lý AI Chatbot cá nhân')),
                        DataCell(Text('3 câu')),
                        DataCell(Icon(Icons.check, size: 18, color: Colors.green)),
                        DataCell(Icon(Icons.check, size: 18, color: Colors.green)),
                        DataCell(Icon(Icons.check, size: 18, color: Colors.green)),
                      ]),
                      DataRow(cells: [
                        DataCell(Text('Tham gia phòng thi có giám sát 10s')),
                        DataCell(Icon(Icons.close, size: 18, color: Colors.grey)),
                        DataCell(Icon(Icons.check, size: 18, color: Colors.green)),
                        DataCell(Icon(Icons.close, size: 18, color: Colors.grey)),
                        DataCell(Icon(Icons.check, size: 18, color: Colors.green)),
                      ]),
                      DataRow(cells: [
                        DataCell(Text('Tạo lớp học & Ra đề thi')),
                        DataCell(Icon(Icons.close, size: 18, color: Colors.grey)),
                        DataCell(Icon(Icons.close, size: 18, color: Colors.grey)),
                        DataCell(Icon(Icons.check, size: 18, color: Colors.green)),
                        DataCell(Icon(Icons.check, size: 18, color: Colors.green)),
                      ]),
                      DataRow(cells: [
                        DataCell(Text('Giám sát thí sinh Realtime & Thu bài')),
                        DataCell(Icon(Icons.close, size: 18, color: Colors.grey)),
                        DataCell(Icon(Icons.close, size: 18, color: Colors.grey)),
                        DataCell(Icon(Icons.check, size: 18, color: Colors.green)),
                        DataCell(Icon(Icons.check, size: 18, color: Colors.green)),
                      ]),
                      DataRow(cells: [
                        DataCell(Text('Soạn, nhập sách mới & Xuất bản')),
                        DataCell(Icon(Icons.close, size: 18, color: Colors.grey)),
                        DataCell(Icon(Icons.close, size: 18, color: Colors.grey)),
                        DataCell(Icon(Icons.close, size: 18, color: Colors.grey)),
                        DataCell(Icon(Icons.check, size: 18, color: Colors.green)),
                      ]),
                      DataRow(cells: [
                        DataCell(Text('Quản lý người dùng, khóa TK & Audit')),
                        DataCell(Icon(Icons.close, size: 18, color: Colors.grey)),
                        DataCell(Icon(Icons.close, size: 18, color: Colors.grey)),
                        DataCell(Icon(Icons.close, size: 18, color: Colors.grey)),
                        DataCell(Icon(Icons.check, size: 18, color: Colors.green)),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final studentCount = _users.where((u) => u['role'] == 'student').length;
    final teacherCount = _users.where((u) => u['role'] == 'teacher').length;
    final adminCount = _users.where((u) => u['role'] == 'admin').length;
    final pendingCount = _pendingTeachers.length;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thanh tiêu đề + nút mời giáo viên & xem ma trận quyền
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Người dùng & Phân quyền',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${_users.length} tài khoản trong hệ thống',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _showRoleMatrixModal,
                  icon: const Icon(Icons.table_chart_outlined, size: 16),
                  label: const Text('Bảng quyền'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
                const SizedBox(width: 6),
                FilledButton.icon(
                  onPressed: _showAddTeacherModal,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Thêm GV'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 4 Thẻ KPI: Học sinh, Giáo viên, Chờ duyệt, Admin
            Row(
              children: [
                Expanded(
                  child: AdminKpiCard(
                    title: 'Học sinh',
                    value: '$studentCount',
                    subtitle: 'Đang theo học',
                    icon: Icons.school_outlined,
                    iconColor: const Color(0xFF2563EB),
                    backgroundColor: const Color(0xFFEFF6FF),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AdminKpiCard(
                    title: 'Giáo viên',
                    value: '$teacherCount',
                    subtitle: 'Đang giảng dạy',
                    icon: Icons.person_search_outlined,
                    iconColor: const Color(0xFF059669),
                    backgroundColor: const Color(0xFFECFDF5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: AdminKpiCard(
                    title: 'Chờ duyệt',
                    value: '$pendingCount',
                    subtitle: pendingCount > 0 ? 'Cần xử lý ngay' : 'Đã duyệt hết',
                    icon: Icons.pending_actions_outlined,
                    iconColor: const Color(0xFFD97706),
                    backgroundColor: const Color(0xFFFFFBEB),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AdminKpiCard(
                    title: 'Quản trị viên',
                    value: '$adminCount',
                    subtitle: 'Toàn quyền',
                    icon: Icons.admin_panel_settings_outlined,
                    iconColor: const Color(0xFF7C3AED),
                    backgroundColor: const Color(0xFFF5F3FF),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Khối "Chờ Duyệt Giáo Viên" (theo mockup Claude Ảnh 10)
            if (_pendingTeachers.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.hourglass_top, color: Color(0xFFD97706), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Yêu cầu làm giáo viên chờ duyệt (${_pendingTeachers.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF92400E)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ..._pendingTeachers.map((tch) => _buildPendingTeacherCard(tch)),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],

            // Thanh tìm kiếm + Bộ lọc Tabs
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Tìm theo tên, email...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Chips lọc
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('all', 'Tất cả (${_users.length})'),
                  const SizedBox(width: 6),
                  _buildFilterChip('student', 'Học sinh ($studentCount)'),
                  const SizedBox(width: 6),
                  _buildFilterChip('teacher', 'Giáo viên ($teacherCount)'),
                  const SizedBox(width: 6),
                  _buildFilterChip('locked', 'Bị khóa (${_users.where((u) => u['is_locked'] == true).length})'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Danh sách người dùng
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_filteredUsers.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.person_off_outlined, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text('Không tìm thấy tài khoản nào', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredUsers.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, idx) {
                  final user = _filteredUsers[idx];
                  return _buildUserTile(user);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) setState(() => _selectedFilter = value);
      },
      selectedColor: const Color(0xFF1E3A8A).withValues(alpha: 0.12),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? const Color(0xFF1E3A8A) : Colors.black87,
      ),
      backgroundColor: Colors.grey[100],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isSelected ? const Color(0xFF1E3A8A) : Colors.grey[300]!),
      ),
    );
  }

  Widget _buildPendingTeacherCard(Map<String, dynamic> tch) {
    final isVerified = tch['isVerifiedDomain'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                child: Text(
                  (tch['name'] ?? 'T').toString().substring(0, 1).toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tch['name'].toString(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      '${tch['school']} • ${tch['subject']}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Chờ duyệt',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                isVerified ? Icons.verified : Icons.warning_amber_rounded,
                size: 14,
                color: isVerified ? Colors.green : Colors.deepOrange,
              ),
              const SizedBox(width: 4),
              Text(
                isVerified ? 'Email trường đã xác thực' : 'Email cá nhân, chưa xác thực trường',
                style: TextStyle(
                  fontSize: 11,
                  color: isVerified ? Colors.green[800] : Colors.deepOrange[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red[700],
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(color: Colors.red[200]!),
                ),
                onPressed: () => _rejectTeacher(tch),
                child: const Text('Từ chối'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => _approveTeacher(tch),
                child: const Text('Duyệt giáo viên'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    final role = (user['role'] ?? 'student').toString().toLowerCase();
    final isLocked = user['is_locked'] == true;
    final email = (user['email'] ?? '').toString();
    final displayName = (user['display_name'] ?? user['displayName'] ?? email.split('@').first).toString();
    final isSuperAdmin = UserProfile.isSystemAdmin(email);

    Color roleColor = Colors.blue;
    String roleName = 'Học sinh';
    if (role == 'admin') {
      roleColor = const Color(0xFF7C3AED);
      roleName = 'Admin';
    } else if (role == 'teacher') {
      roleColor = const Color(0xFF059669);
      roleName = 'Giáo viên';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          if (role == 'student') {
            _showStudentProgress(user);
          }
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isLocked ? Colors.red[50]?.withValues(alpha: 0.5) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isLocked ? Colors.red[200]! : Colors.grey[200]!,
            ),
          ),
          child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: roleColor.withValues(alpha: 0.12),
            child: Text(
              displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : 'U',
              style: TextStyle(fontWeight: FontWeight.bold, color: roleColor),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          decoration: isLocked ? TextDecoration.lineThrough : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        roleName,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: roleColor),
                      ),
                    ),
                    if (isLocked) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red[100],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Bị khóa',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (isLocked && (user['locked_reason'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Lý do: ${user['locked_reason']}',
                    style: const TextStyle(fontSize: 11, color: Colors.red, fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.grey),
            onSelected: (action) {
              if (action == 'progress') {
                _showStudentProgress(user);
              } else if (action == 'assign_class') {
                _showAssignStudentToClassDialog(user);
              } else if (action == 'role') {
                _showChangeRoleDialog(user);
              } else if (action == 'lock') {
                _showLockUserDialog(user);
              } else if (action == 'unlock') {
                _showUnlockUser(user);
              } else if (action == 'delete') {
                _confirmDeleteUser(user);
              }
            },
            itemBuilder: (ctx) => [
              if (role == 'student') ...[
                const PopupMenuItem(
                  value: 'progress',
                  child: Row(
                    children: [
                      Icon(Icons.insights_rounded, size: 18, color: Color(0xFF1E3A8A)),
                      SizedBox(width: 8),
                      Text('Tiến độ học tập'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'assign_class',
                  child: Row(
                    children: [
                      Icon(Icons.school_outlined, size: 18, color: Color(0xFF059669)),
                      SizedBox(width: 8),
                      Text('Xếp vào lớp'),
                    ],
                  ),
                ),
              ],
              if (!isSuperAdmin) ...[
                const PopupMenuItem(
                  value: 'role',
                  child: Row(
                    children: [
                      Icon(Icons.manage_accounts, size: 18),
                      SizedBox(width: 8),
                      Text('Đổi vai trò'),
                    ],
                  ),
                ),
                if (!isLocked)
                  const PopupMenuItem(
                    value: 'lock',
                    child: Row(
                      children: [
                        Icon(Icons.lock_outline, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Khóa tài khoản', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  )
                else
                  const PopupMenuItem(
                    value: 'unlock',
                    child: Row(
                      children: [
                        Icon(Icons.lock_open, size: 18, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Mở khóa', style: TextStyle(color: Colors.green)),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                      SizedBox(width: 8),
                      Text('Xóa tài khoản'),
                    ],
                  ),
                ),
              ] else
                const PopupMenuItem(
                  enabled: false,
                  value: 'info',
                  child: Text('Tài khoản Quản trị viên tối cao'),
                ),
            ],
          ),
        ],
      ),
        ),
      ),
    );
  }

  void _confirmDeleteUser(Map<String, dynamic> user) {
    final email = (user['email'] ?? '').toString();
    if (UserProfile.isSystemAdmin(email)) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa tài khoản?'),
        content: Text('Hành động này sẽ xóa vĩnh viễn tài khoản $email khỏi hệ thống.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await _service.deleteAdminUser(user['id'].toString());
              await _loadData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã xóa người dùng thành công')),
                );
              }
            },
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  void _showStudentProgress(Map<String, dynamic> user) {
    StudentProgressSheet.show(
      context,
      student: user,
      onUpdated: _loadData,
    );
  }

  void _showAssignStudentToClassDialog(Map<String, dynamic> user) async {
    final classes = await _service.getClasses();
    if (!mounted) return;

    if (classes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hệ thống chưa có lớp học nào. Hãy tạo lớp trước!')),
      );
      return;
    }

    String selectedClassId = classes.first['id'].toString();
    final studentName = (user['display_name'] ?? user['displayName'] ?? user['email']?.toString().split('@').first ?? 'Học sinh').toString();
    final studentEmail = (user['email'] ?? '').toString();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text('Xếp "$studentName" vào lớp'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Chọn lớp học để thêm học sinh này:', style: TextStyle(fontSize: 13, color: Colors.black54)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: selectedClassId,
                  decoration: const InputDecoration(labelText: 'Lớp học', border: OutlineInputBorder()),
                  items: classes
                      .map((c) => DropdownMenuItem(
                            value: c['id'].toString(),
                            child: Text(
                              '${c['name']} (Mã: ${c['code']})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDlgState(() => selectedClassId = v);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
              onPressed: () async {
                Navigator.pop(ctx);
                await _service.addStudentToClass(
                  classId: selectedClassId,
                  studentName: studentName,
                  studentEmail: studentEmail,
                );
                await _loadData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Đã thêm học sinh "$studentName" vào lớp thành công!'),
                      backgroundColor: Colors.green[800],
                    ),
                  );
                }
              },
              child: const Text('Xác nhận xếp lớp'),
            ),
          ],
        ),
      ),
    );
  }
}
