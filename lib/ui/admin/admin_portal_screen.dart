import 'package:flutter/material.dart';

import '../../data/rbac_proctor_ai_service.dart';
import '../ai/ai_tutor_sheet.dart';
import '../teacher/teacher_portal_screen.dart';
import '../theme/app_tokens.dart';
import '../theme/components/engpass_mascot.dart';

/// Trung Tâm Quản Trị Hệ Thống (`AdminPortalScreen`) — Toàn quyền CRUD + Thay Sách Mới + Giám Sát Audit + Cấu Hình AI:
/// 1. CRUD Người dùng, Phân quyền (`student` <-> `teacher` <-> `admin`), Khóa / Mở khóa tài khoản (`is_locked`).
/// 2. CRUD Học liệu & Công cụ Thay thế Bộ Sách Giáo Khoa Mới (kèm AI Số hóa tự động không cần nhập tay).
/// 3. Giám sát Vận hành & Nhật ký Hệ thống (`System Audit Logs`).
/// 4. Cấu hình API Key cho Trợ lý Cá nhân AI Chatbot (`GEMINI_API_KEY` & Model).
class AdminPortalScreen extends StatefulWidget {
  final int initialTabIndex;

  const AdminPortalScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<AdminPortalScreen> createState() => _AdminPortalScreenState();
}

class _AdminPortalScreenState extends State<AdminPortalScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];
  String _roleFilter = 'all';
  final TextEditingController _userSearchCtrl = TextEditingController();

  List<Map<String, dynamic>> _curriculums = [];
  List<Map<String, dynamic>> _auditLogs = [];

  // AI Config
  final TextEditingController _apiKeyCtrl = TextEditingController();
  String _selectedModel = 'gemini-2.5-flash';
  Map<String, dynamic> _aiConfigInfo = {};
  bool _isSavingAiConfig = false;
  String? _aiTestResultMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 3),
    );
    _loadAllAdminData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _userSearchCtrl.dispose();
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAllAdminData() async {
    setState(() => _isLoading = true);
    final users = await RbacProctorAiService.instance.getAdminUsers(
      roleFilter: _roleFilter,
      search: _userSearchCtrl.text,
    );
    final curriculums = await RbacProctorAiService.instance.getCurriculumVersions();
    final logs = await RbacProctorAiService.instance.getAuditLogs();
    final aiCfg = await RbacProctorAiService.instance.getAiConfig();

    if (!mounted) return;
    setState(() {
      _users = users;
      _curriculums = curriculums;
      _auditLogs = logs;
      _aiConfigInfo = aiCfg;
      _selectedModel = (aiCfg['model'] ?? 'gemini-2.5-flash').toString();
      _isLoading = false;
    });
  }

  // Hộp thoại Tạo mới Người dùng (Users Create)
  Future<void> _showCreateUserDialog() async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController(text: 'EngPass123@');
    String selectedRole = 'student';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Tạo Tài Khoản Người Dùng Mới'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Tên hiển thị *'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Địa chỉ Email *'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: passCtrl,
                      decoration: const InputDecoration(labelText: 'Mật khẩu khởi tạo *'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRole,
                      decoration: const InputDecoration(labelText: 'Phân quyền Vai trò (Role)'),
                      items: const [
                        DropdownMenuItem(value: 'student', child: Text('🎓 Học viên (Student)')),
                        DropdownMenuItem(value: 'teacher', child: Text('👩‍🏫 Giáo viên (Teacher)')),
                        DropdownMenuItem(value: 'admin', child: Text('🛡️ Quản trị viên (Admin)')),
                      ],
                      onChanged: (v) {
                        if (v != null) setDialogState(() => selectedRole = v);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  onPressed: () {
                    if (emailCtrl.text.trim().isEmpty || passCtrl.text.length < 6) return;
                    Navigator.pop(ctx, true);
                  },
                  child: const Text('Tạo Tài Khoản'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true) {
      await RbacProctorAiService.instance.createAdminUser(
        email: emailCtrl.text.trim(),
        password: passCtrl.text,
        displayName: nameCtrl.text.trim(),
        role: selectedRole,
      );
      await _loadAllAdminData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã tạo tài khoản ${emailCtrl.text.trim()} (${selectedRole.toUpperCase()})!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Hộp thoại Khóa / Mở khóa tài khoản người dùng
  Future<void> _toggleLockUser(Map<String, dynamic> user) async {
    final userId = user['id'].toString();
    final currentlyLocked = user['is_locked'] == true;
    if (currentlyLocked) {
      await RbacProctorAiService.instance.updateAdminUser(
        userId: userId,
        isLocked: false,
        lockedReason: '',
      );
      await _loadAllAdminData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã mở khóa tài khoản người dùng thành công!')),
      );
      return;
    }

    final reasonCtrl = TextEditingController(
      text: 'Vi phạm quy chế phòng thi / quy định sử dụng hệ thống.',
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🔒 Khóa Tài Khoản Người Dùng'),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Lý do khóa tài khoản (hiển thị cho người dùng)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTokens.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác nhận Khóa'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await RbacProctorAiService.instance.updateAdminUser(
        userId: userId,
        isLocked: true,
        lockedReason: reasonCtrl.text.trim(),
      );
      await _loadAllAdminData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã khóa tài khoản người dùng!')),
      );
    }
  }

  // Hộp thoại AI Tự động Số hóa & Thay thế Sách Giáo Khoa Mới (Không cần nhập tay)
  Future<void> _showAiCurriculumReplacerDialog() async {
    final versionCtrl = TextEditingController(
      text: 'SGK12-NEW-${DateTime.now().year}',
    );
    final titleCtrl = TextEditingController(
      text: 'Bộ Sách Giáo Khoa Tiếng Anh 12 Mới Cập Nhật',
    );
    final rawTextCtrl = TextEditingController(
      text: 'Artificial Intelligence and Smart Education in the 21st Century. '
          'Modern schools are adopting virtual reality classrooms and personalized digital textbooks to help students master global communication skills effectively.',
    );
    int selectedUnit = 1;
    bool activateImmediately = true;
    Map<String, dynamic>? digitizedPreview;
    bool isDigitizing = false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('📖 AI Số Hóa & Thay Thế Dữ Liệu Sách Mới'),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Chỉ cần dán đoạn văn bản từ sách giáo khoa mới, AI sẽ tự động bóc tách thành Bài đọc + Từ vựng IPA + Câu hỏi trắc nghiệm chuẩn để cập nhật/thay thế cho hệ thống.',
                        style: TextStyle(fontSize: 12.5, height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: versionCtrl,
                              decoration: const InputDecoration(labelText: 'Mã phiên bản *'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: selectedUnit,
                              decoration: const InputDecoration(labelText: 'Áp dụng từ Unit'),
                              items: List.generate(
                                10,
                                (i) => DropdownMenuItem(value: i + 1, child: Text('Unit ${i + 1}')),
                              ),
                              onChanged: (v) {
                                if (v != null) setDialogState(() => selectedUnit = v);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(labelText: 'Tên bộ sách giáo khoa mới *'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: rawTextCtrl,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Dán nội dung bài học / văn bản từ Sách Mới *',
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: isDigitizing
                              ? null
                              : () async {
                                  setDialogState(() => isDigitizing = true);
                                  final res = await RbacProctorAiService.instance
                                      .digitizeCurriculumWithAi(
                                        unitNumber: selectedUnit,
                                        title: titleCtrl.text.trim(),
                                        rawText: rawTextCtrl.text.trim(),
                                      );
                                  setDialogState(() {
                                    digitizedPreview = res;
                                    isDigitizing = false;
                                  });
                                },
                          icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                          label: Text(
                            isDigitizing
                                ? 'AI đang bóc tách dữ liệu sách mới...'
                                : '1. Nhờ AI Bóc Tách Từ Vựng & Câu Hỏi (Xem trước)',
                          ),
                        ),
                      ),
                      if (digitizedPreview != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTokens.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTokens.success),
                          ),
                          child: Text(
                            '✅ Bản xem trước đã sẵn sàng:\n'
                            '• Từ vựng rút trích: ${(digitizedPreview!['vocabulary'] as List?)?.length ?? 0} từ kèm IPA\n'
                            '• Câu hỏi tương tác: ${(digitizedPreview!['questions'] as List?)?.length ?? 0} câu trắc nghiệm',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Kích hoạt thay thế làm Bộ sách chính thức ngay',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        subtitle: const Text(
                          'Lưu trữ bộ sách cũ an toàn, không làm mất điểm số học viên.',
                          style: TextStyle(fontSize: 11.5),
                        ),
                        value: activateImmediately,
                        onChanged: (v) => setDialogState(() => activateImmediately = v),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Hủy'),
                ),
                FilledButton.icon(
                  onPressed: () async {
                    digitizedPreview ??= await RbacProctorAiService.instance
                        .digitizeCurriculumWithAi(
                          unitNumber: selectedUnit,
                          title: titleCtrl.text.trim(),
                          rawText: rawTextCtrl.text.trim(),
                        );
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx, true);
                  },
                  icon: const Icon(Icons.published_with_changes_rounded, size: 18),
                  label: const Text('2. Xác nhận Lưu & Thay Sách'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == true && digitizedPreview != null) {
      await RbacProctorAiService.instance.saveAndOptionallyActivateCurriculum(
        versionCode: versionCtrl.text.trim(),
        title: titleCtrl.text.trim(),
        description: 'Số hóa & cập nhật tự động bởi Admin AI Copilot (Unit $selectedUnit).',
        payload: {
          'units': [digitizedPreview],
        },
        activateImmediately: activateImmediately,
      );
      await _loadAllAdminData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            activateImmediately
                ? 'Đã thay thế và kích hoạt bộ sách "${titleCtrl.text.trim()}" cho toàn hệ thống!'
                : 'Đã lưu phiên bản bộ sách "${titleCtrl.text.trim()}"!',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppTokens.darkBackground : AppTokens.background;
    final cardColor = isDark ? AppTokens.darkSurface : AppTokens.surface;
    final textMain = isDark ? AppTokens.darkTextMain : AppTokens.textMain;
    final textSub = isDark ? AppTokens.darkTextSub : AppTokens.textSub;
    final borderColor = isDark ? AppTokens.darkBorder : AppTokens.border;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        title: Row(
          children: [
            const EngPassMascot(mood: MascotMood.celebrate, size: 32),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Trung Tâm Quản Trị Admin',
                style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: textMain),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Trợ lý AI Admin (Copilot)',
            icon: const Icon(Icons.auto_awesome_rounded, color: AppTokens.primary),
            onPressed: () => AiTutorSheet.show(context, initialMode: 'admin_assist'),
          ),
          IconButton(
            tooltip: 'Mở Cổng Giáo Viên & Giám sát Thi',
            icon: const Icon(Icons.radar_rounded, color: AppTokens.success),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TeacherPortalScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Làm mới',
            icon: Icon(Icons.refresh_rounded, color: textMain),
            onPressed: _loadAllAdminData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: AppTokens.primary,
          unselectedLabelColor: textSub,
          indicatorColor: AppTokens.primary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.manage_accounts_rounded, size: 18), text: '1. Người dùng & Phân quyền'),
            Tab(icon: Icon(Icons.library_books_rounded, size: 18), text: '2. Học liệu & Thay sách mới'),
            Tab(icon: Icon(Icons.security_rounded, size: 18), text: '3. Giám sát Audit Logs'),
            Tab(icon: Icon(Icons.settings_suggest_rounded, size: 18), text: '4. Cấu hình API AI'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildUsersRbacTab(cardColor, textMain, textSub, borderColor),
                _buildCurriculumReplacerTab(cardColor, textMain, textSub, borderColor),
                _buildAuditLogsTab(cardColor, textMain, textSub, borderColor),
                _buildAiConfigTab(cardColor, textMain, textSub, borderColor),
              ],
            ),
    );
  }

  // TAB 1: CRUD Người dùng, Khóa/Mở khóa & Phân quyền RBAC
  Widget _buildUsersRbacTab(
    Color cardColor,
    Color textMain,
    Color textSub,
    Color borderColor,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _showCreateUserDialog,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('+ Tạo Tài Khoản (Học viên / Giáo viên / Admin)'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Tìm kiếm & Lọc theo vai trò
        TextField(
          controller: _userSearchCtrl,
          onSubmitted: (_) => _loadAllAdminData(),
          decoration: InputDecoration(
            hintText: 'Tìm theo tên hoặc email người dùng...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: IconButton(
              icon: const Icon(Icons.arrow_forward_rounded),
              onPressed: _loadAllAdminData,
            ),
            filled: true,
            fillColor: cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: borderColor),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final item in const [
                ('all', 'Tất cả'),
                ('student', '🎓 Học viên'),
                ('teacher', '👩‍🏫 Giáo viên'),
                ('admin', '🛡️ Admin'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(item.$2),
                    selected: _roleFilter == item.$1,
                    onSelected: (_) {
                      setState(() => _roleFilter = item.$1);
                      _loadAllAdminData();
                    },
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        ..._users.map((u) {
          final userId = u['id'].toString();
          final name = (u['display_name'] ?? u['displayName'] ?? 'Người dùng').toString();
          final email = (u['email'] ?? '').toString();
          final role = (u['role'] ?? 'student').toString();
          final isLocked = u['is_locked'] == true;
          final lockedReason = (u['locked_reason'] ?? '').toString();

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isLocked ? AppTokens.danger : borderColor,
                width: isLocked ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: isLocked
                          ? AppTokens.danger.withValues(alpha: 0.16)
                          : AppTokens.primary.withValues(alpha: 0.16),
                      child: Icon(
                        isLocked
                            ? Icons.lock_rounded
                            : (role == 'admin'
                                ? Icons.admin_panel_settings_rounded
                                : (role == 'teacher' ? Icons.school_rounded : Icons.person_rounded)),
                        color: isLocked ? AppTokens.danger : AppTokens.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textMain),
                          ),
                          Text(
                            email,
                            style: TextStyle(fontSize: 12.5, color: textSub),
                          ),
                        ],
                      ),
                    ),
                    // Đổi vai trò trực tiếp (Phân quyền)
                    DropdownButton<String>(
                      value: ['student', 'teacher', 'admin'].contains(role) ? role : 'student',
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(value: 'student', child: Text('Student')),
                        DropdownMenuItem(value: 'teacher', child: Text('Teacher')),
                        DropdownMenuItem(value: 'admin', child: Text('Admin')),
                      ],
                      onChanged: (newRole) async {
                        if (newRole == null || newRole == role) return;
                        await RbacProctorAiService.instance.updateAdminUser(
                          userId: userId,
                          role: newRole,
                        );
                        await _loadAllAdminData();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Đã phân quyền "$name" thành ${newRole.toUpperCase()}!'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                if (isLocked && lockedReason.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '🔒 Đang bị khóa: $lockedReason',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTokens.danger,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _toggleLockUser(u),
                      icon: Icon(
                        isLocked ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                        size: 16,
                        color: isLocked ? AppTokens.success : AppTokens.warning,
                      ),
                      label: Text(isLocked ? 'Mở khóa' : 'Khóa tài khoản'),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Xóa người dùng',
                      icon: const Icon(Icons.delete_outline_rounded, color: AppTokens.danger),
                      onPressed: () async {
                        await RbacProctorAiService.instance.deleteAdminUser(userId);
                        await _loadAllAdminData();
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // TAB 2: Quản lý Học liệu & Thay thế Bộ Sách Giáo Khoa Mới
  Widget _buildCurriculumReplacerTab(
    Color cardColor,
    Color textMain,
    Color textSub,
    Color borderColor,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTokens.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTokens.primary.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '📚 Quản lý Phiên bản Sách Giáo Khoa & Thay Sách Mới',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textMain),
              ),
              const SizedBox(height: 6),
              Text(
                'Cho phép Admin cập nhật tài liệu mới hoặc thay thế toàn bộ dữ liệu từ sách cũ sang bộ sách mới mà không làm mất lịch sử XP, Streak và điểm số của học viên.',
                style: TextStyle(fontSize: 12.5, color: textSub, height: 1.4),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _showAiCurriculumReplacerDialog,
                      icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                      label: const Text('⚡ AI Số Hóa & Thay Sách Mới'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Text(
          'Các phiên bản Bộ Sách Giáo Khoa trong hệ thống:',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: textMain),
        ),
        const SizedBox(height: 10),

        ..._curriculums.map((cur) {
          final isActive = cur['isActive'] == true || cur['is_active'] == true;
          final id = cur['id'].toString();
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isActive ? AppTokens.success : borderColor,
                width: isActive ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isActive ? AppTokens.success : AppTokens.primary)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        isActive ? 'ĐANG ÁP DỤNG TOÀN HỆ THỐNG' : 'BẢN LƯU TRỮ (ARCHIVE)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isActive ? AppTokens.success : AppTokens.primary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      (cur['versionCode'] ?? cur['version_code'] ?? '').toString(),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textSub),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  (cur['title'] ?? '').toString(),
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: textMain),
                ),
                const SizedBox(height: 4),
                Text(
                  (cur['description'] ?? '').toString(),
                  style: TextStyle(fontSize: 13, color: textSub),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (!isActive)
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: () async {
                            await RbacProctorAiService.instance.activateCurriculumVersion(id);
                            await _loadAllAdminData();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Đã kích hoạt bộ sách "${cur['title']}" làm mặc định!'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                          label: const Text('Kích hoạt thay thế bộ sách này'),
                        ),
                      ),
                    if (!isActive) const SizedBox(width: 8),
                    if (!isActive)
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: AppTokens.danger),
                        onPressed: () async {
                          await RbacProctorAiService.instance.deleteCurriculumVersion(id);
                          await _loadAllAdminData();
                        },
                      ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // TAB 3: Giám sát Vận hành & Nhật ký Hệ thống (System Audit Logs)
  Widget _buildAuditLogsTab(
    Color cardColor,
    Color textMain,
    Color textSub,
    Color borderColor,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              const Icon(Icons.policy_rounded, color: AppTokens.primary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Giám sát Toàn Hệ Thống (System Audit Logs): Ghi nhận mọi thao tác phân quyền, khóa tài khoản, thay sách giáo khoa và cảnh báo gian lận phòng thi.',
                  style: TextStyle(fontSize: 12.5, color: textSub, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_auditLogs.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text('Chưa có bản ghi nhật ký nào.', style: TextStyle(color: textSub)),
            ),
          ),
        ..._auditLogs.map((log) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      (log['action'] ?? '').toString(),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppTokens.primary,
                      ),
                    ),
                    Text(
                      '${log['actorRole']?.toString().toUpperCase() ?? "ADMIN"} • ${(log['createdAt'] ?? '').toString().split('T').first}',
                      style: TextStyle(fontSize: 11.5, color: textSub),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  (log['details'] ?? '').toString(),
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: textMain),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // TAB 4: Cấu hình API Key cho Trợ lý Cá nhân AI Chatbot
  Widget _buildAiConfigTab(
    Color cardColor,
    Color textMain,
    Color textSub,
    Color borderColor,
  ) {
    final hasKey = _aiConfigInfo['hasApiKey'] == true;
    final maskedKey = (_aiConfigInfo['maskedApiKey'] ?? '').toString();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
                children: [
                  Icon(
                    hasKey ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                    color: hasKey ? AppTokens.success : AppTokens.warning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hasKey
                          ? 'Đã cấu hình khóa API AI (${_aiConfigInfo['model']})'
                          : 'Chưa nhập khóa API trực tuyến (Đang chạy Bộ xử lý Học thuật Nội bộ)',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: textMain),
                    ),
                  ),
                ],
              ),
              if (maskedKey.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Khóa hiện tại: $maskedKey',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: textSub),
                ),
              ],
              const Divider(height: 24),
              Text(
                '🔑 Hướng dẫn lấy khóa API Google Gemini miễn phí:',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: textMain),
              ),
              const SizedBox(height: 6),
              Text(
                '1. Truy cập https://aistudio.google.com/apikey và đăng nhập Google.\n'
                '2. Bấm "Create API key" và sao chép mã khóa bắt đầu bằng "AIzaSy...".\n'
                '3. Dán mã khóa vào ô bên dưới và bấm "Kiểm tra & Lưu Cấu Hình".',
                style: TextStyle(fontSize: 12.5, color: textSub, height: 1.45),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: ['gemini-2.5-flash', 'gemini-2.0-flash', 'gemini-1.5-flash']
                        .contains(_selectedModel)
                    ? _selectedModel
                    : 'gemini-2.5-flash',
                decoration: const InputDecoration(
                  labelText: 'Chọn Mô hình AI (Model)',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'gemini-2.5-flash',
                    child: Text('Gemini 2.5 Flash (Khuyến nghị - Nhanh & Thông minh nhất)'),
                  ),
                  DropdownMenuItem(
                    value: 'gemini-2.0-flash',
                    child: Text('Gemini 2.0 Flash (Tốc độ cao, hỗ trợ Vision OCR)'),
                  ),
                  DropdownMenuItem(
                    value: 'gemini-1.5-flash',
                    child: Text('Gemini 1.5 Flash (Ổn định, tương thích rộng)'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _selectedModel = v);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _apiKeyCtrl,
                decoration: const InputDecoration(
                  labelText: 'Dán GEMINI_API_KEY vào đây (AIzaSy...)',
                  hintText: 'Để trống nếu muốn giữ khóa hiện tại',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSavingAiConfig
                      ? null
                      : () async {
                          setState(() => _isSavingAiConfig = true);
                          final res = await RbacProctorAiService.instance.saveAndTestAiConfig(
                            apiKey: _apiKeyCtrl.text,
                            model: _selectedModel,
                          );
                          _apiKeyCtrl.clear();
                          await _loadAllAdminData();
                          if (!mounted) return;
                          setState(() {
                            _isSavingAiConfig = false;
                            _aiTestResultMessage = res['testReply']?.toString();
                          });
                        },
                  icon: const Icon(Icons.save_rounded),
                  label: Text(
                    _isSavingAiConfig ? 'Đang kiểm tra kết nối AI...' : 'Kiểm Tra Kết Nối & Lưu Cấu Hình AI',
                  ),
                ),
              ),
              if (_aiTestResultMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTokens.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '🤖 Phản hồi hệ thống: $_aiTestResultMessage',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textMain),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

