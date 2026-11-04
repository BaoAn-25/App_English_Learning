import 'package:flutter/material.dart';
import '../../data/rbac_proctor_ai_service.dart';
import '../auth/auth_controller.dart';
import '../theme/app_tokens.dart';
import '../theme/components/engpass_mascot.dart';

class AiChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isOfflineNotice;
  final List<Map<String, dynamic>>? generatedQuestions;

  const AiChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isOfflineNotice = false,
    this.generatedQuestions,
  });
}

/// Trợ lý Cá nhân AI Chatbot Đa vai trò (`EngPass AI Copilot`):
/// - Học viên (`student`): Hỏi đáp kiến thức SGK 12 (Socratic), Chấm bài viết / sửa lỗi câu tiếng Anh, Gợi ý lộ trình.
///   * Ràng buộc: Tự động khóa 100% khi đang trong Phòng thi có giám sát (`ExamLockGuard`).
/// - Giáo viên (`teacher`): Trợ lý soạn giảng, tạo câu hỏi trắc nghiệm tự động (lưu 1 chạm vào Ngân hàng đề), nhận xét bài làm học sinh.
/// - Quản trị viên (`admin`): Trợ lý số hóa sách giáo khoa mới, kiểm tra dữ liệu và phân tích hệ thống.
class AiTutorSheet extends StatefulWidget {
  final int? unitNumber;
  final String? unitTitle;
  final String? sectionTitle;
  final String? contextText;
  final String? initialMode;

  const AiTutorSheet({
    super.key,
    this.unitNumber,
    this.unitTitle,
    this.sectionTitle,
    this.contextText,
    this.initialMode,
  });

  static Future<void> show(
    BuildContext context, {
    int? unitNumber,
    String? unitTitle,
    String? sectionTitle,
    String? contextText,
    String? initialMode,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AiTutorSheet(
        unitNumber: unitNumber,
        unitTitle: unitTitle,
        sectionTitle: sectionTitle,
        contextText: contextText,
        initialMode: initialMode,
      ),
    );
  }

  @override
  State<AiTutorSheet> createState() => _AiTutorSheetState();
}

class _AiTutorSheetState extends State<AiTutorSheet> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<AiChatMessage> _messages = [];
  bool _isLoading = false;
  late String _activeMode;

  String get _currentRole => AuthController.instance.user.role;

  @override
  void initState() {
    super.initState();
    _activeMode = widget.initialMode ??
        (_currentRole == 'teacher'
            ? 'teacher_assist'
            : (_currentRole == 'admin' ? 'admin_assist' : 'general'));
    _initWelcomeMessage();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initWelcomeMessage() {
    if (ExamLockGuard.instance.isLocked && _currentRole == 'student') {
      _messages.add(
        AiChatMessage(
          text: '🔒 **Chế độ Chống Gian Lận Phòng Thi đang bật!**\n\n'
              'Bạn đang làm bài thi có giám sát: "${ExamLockGuard.instance.activeExamTitle ?? "Kiểm tra"}".\n'
              'Gia sư AI tạm thời bị khóa cho đến khi bạn hoàn thành và nộp bài.',
          isUser: false,
          timestamp: DateTime.now(),
          isOfflineNotice: true,
        ),
      );
      return;
    }

    if (_currentRole == 'admin') {
      _messages.add(
        AiChatMessage(
          text: 'Xin chào Quản trị viên! Mình là **Admin AI Copilot**.\n\n'
              '• Hỗ trợ chuẩn hóa & số hóa nội dung Sách giáo khoa mới tự động.\n'
              '• Hỗ trợ tạo nhanh bộ câu hỏi hệ thống không cần nhập tay.\n'
              '• Ràng buộc an toàn: Mọi dữ liệu AI sinh ra đều ở trạng thái Bản nháp để Admin kiểm duyệt trước khi lưu.',
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
      return;
    }

    if (_currentRole == 'teacher') {
      _messages.add(
        AiChatMessage(
          text: 'Xin chào Giáo viên! Mình là **Trợ lý AI Soạn Giảng & Chấm Bài**.\n\n'
              '• Bấm **"⚡ Sinh 3 câu trắc nghiệm mẫu"** bên dưới để tự động tạo câu hỏi và lưu 1 chạm vào Ngân hàng đề mà không cần gõ tay.\n'
              '• Hoặc nhập yêu cầu soạn bài đọc, giải thích ngữ pháp, nhận xét học sinh.',
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
      return;
    }

    final unitInfo = widget.unitNumber != null
        ? 'Unit ${widget.unitNumber}: ${widget.unitTitle ?? ""}'
        : 'SGK Tiếng Anh 12 Global Success';
    final sectionInfo = widget.sectionTitle != null ? ' (${widget.sectionTitle})' : '';

    _messages.add(
      AiChatMessage(
        text: 'Xin chào! Mình là **Gia sư AI Cá nhân** đồng hành cùng bạn ôn luyện $unitInfo$sectionInfo.\n\n'
            '• **💬 Hỏi bài & Ngữ pháp:** Giải thích từ vựng, ngữ pháp và hướng dẫn cách loại trừ đáp án.\n'
            '• **✍️ Chấm bài viết:** Chấm điểm câu/đoạn văn tiếng Anh (thang 10) và sửa lỗi chi tiết.',
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> _sendMessage([String? presetText]) async {
    if (ExamLockGuard.instance.isLocked && _currentRole == 'student') return;

    final query = (presetText ?? _inputController.text).trim();
    if (query.isEmpty || _isLoading) return;

    if (presetText == null) {
      _inputController.clear();
    }

    setState(() {
      _messages.add(
        AiChatMessage(
          text: query,
          isUser: true,
          timestamp: DateTime.now(),
        ),
      );
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      // Nếu Giáo viên / Admin bấm tạo câu hỏi tự động nhanh
      if ((_currentRole == 'teacher' || _currentRole == 'admin') &&
          (query.toLowerCase().contains('sinh') || query.toLowerCase().contains('tạo câu hỏi'))) {
        final generated = await RbacProctorAiService.instance.generateQuestionsWithAi(
          unitNumber: widget.unitNumber ?? 1,
          skill: 'grammar',
          difficulty: 2,
          count: 3,
          topicPrompt: query,
        );
        if (!mounted) return;
        final previewBuffer = StringBuffer(
          '✅ **Đã tạo tự động ${generated.length} câu hỏi trắc nghiệm (Bản nháp kiểm duyệt):**\n\n',
        );
        for (int i = 0; i < generated.length; i++) {
          final q = generated[i];
          previewBuffer.writeln('**Câu ${i + 1}:** ${q['stem']}');
          final opts = (q['options'] as List?) ?? [];
          for (final o in opts) {
            previewBuffer.writeln('  • $o');
          }
          previewBuffer.writeln('  👉 *Giải thích:* ${q['explanation']}\n');
        }
        setState(() {
          _messages.add(
            AiChatMessage(
              text: previewBuffer.toString().trim(),
              isUser: false,
              timestamp: DateTime.now(),
              generatedQuestions: generated,
            ),
          );
        });
        return;
      }

      final res = await RbacProctorAiService.instance.askRoleCopilot(
        role: _currentRole,
        mode: _activeMode,
        message: query,
        unitNumber: widget.unitNumber,
        contextText: widget.contextText,
      );

      if (!mounted) return;
      final answer = (res['answer'] ?? 'Chưa có câu trả lời.').toString();
      setState(() {
        _messages.add(
          AiChatMessage(
            text: answer,
            isUser: false,
            timestamp: DateTime.now(),
            isOfflineNotice: res['isLocked'] == true,
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _scrollToBottom();
      }
    }
  }

  Future<void> _saveGeneratedQuestionsToBank(List<Map<String, dynamic>> questions) async {
    await RbacProctorAiService.instance.saveTeacherQuestions(questions);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã lưu ${questions.length} câu hỏi vào Ngân hàng câu hỏi thành công!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locked = ExamLockGuard.instance.isLocked && _currentRole == 'student';

    final quickChips = _currentRole == 'admin'
        ? [
            'Tạo câu hỏi tự động Unit 1',
            'Kiểm tra chất lượng học liệu',
            'Hướng dẫn số hóa sách mới',
          ]
        : (_currentRole == 'teacher'
            ? [
                '⚡ Sinh 3 câu hỏi trắc nghiệm Unit ${widget.unitNumber ?? 1}',
                'Gợi ý nhận xét bài kiểm tra học sinh',
                'Soạn tóm tắt ngữ pháp trọng tâm',
              ]
            : (_activeMode == 'writing_check'
                ? [
                    'Although urbanization brings many benefits, it also causes pollution.',
                    'It is cultural diversity that makes our world more interesting.',
                  ]
                : [
                    'Trọng tâm ngữ pháp Unit ${widget.unitNumber ?? 1}',
                    'Mẹo làm bài đọc hiểu THPT',
                    'Phân biệt câu chẻ và mệnh đề quan hệ',
                  ]));

    return Container(
      height: MediaQuery.of(context).size.height * 0.86,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Row(
              children: [
                const EngPassMascot(
                  mood: MascotMood.study,
                  size: 40,
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
                              _currentRole == 'admin'
                                  ? 'Trợ lý AI Quản trị (Admin Copilot)'
                                  : (_currentRole == 'teacher'
                                      ? 'Trợ lý AI Giáo viên (Teacher Copilot)'
                                      : 'Gia sư AI Cá nhân EngPass'),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        locked
                            ? '🔒 Đang khóa chống gian lận trong Phòng thi giám sát'
                            : (widget.unitNumber != null
                                ? 'Đang hỗ trợ Unit ${widget.unitNumber}: ${widget.unitTitle ?? ""}'
                                : 'Ràng buộc thông minh theo vai trò ${_currentRole.toUpperCase()}'),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: locked
                              ? AppTokens.danger
                              : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Chuyển chế độ cho Học viên (Hỏi bài Socratic vs Chấm bài viết)
          if (_currentRole == 'student' && !locked)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'general',
                    icon: Icon(Icons.school_rounded, size: 16),
                    label: Text('Hỏi bài & Ngữ pháp', style: TextStyle(fontSize: 12)),
                  ),
                  ButtonSegment(
                    value: 'writing_check',
                    icon: Icon(Icons.rate_review_rounded, size: 16),
                    label: Text('Chấm câu / Bài viết', style: TextStyle(fontSize: 12)),
                  ),
                ],
                selected: {_activeMode == 'writing_check' ? 'writing_check' : 'general'},
                onSelectionChanged: (sel) {
                  setState(() => _activeMode = sel.first);
                },
              ),
            ),

          // Danh sách tin nhắn
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildMessageBubble(msg, isDark);
              },
            ),
          ),

          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Trợ lý AI đang xử lý yêu cầu...',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

          if (!locked)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: quickChips.map((c) => _buildQuickChip(c, isDark)).toList(),
              ),
            ),

          // Input bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: Border(
                top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    enabled: !locked,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      hintText: locked
                          ? 'Đã khóa AI khi đang trong Phòng thi giám sát...'
                          : (_activeMode == 'writing_check'
                              ? 'Nhập câu hoặc đoạn văn tiếng Anh để AI chấm điểm...'
                              : 'Nhập câu hỏi bài học hoặc yêu cầu cho AI...'),
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    Icons.send_rounded,
                    color: locked
                        ? Colors.grey
                        : (isDark ? const Color(0xFF60A5FA) : const Color(0xFF0F172A)),
                  ),
                  onPressed: locked ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip(String label, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () => _sendMessage(label),
      ),
    );
  }

  Widget _buildMessageBubble(AiChatMessage msg, bool isDark) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.84),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: msg.isUser
              ? (isDark ? const Color(0xFF2563EB) : const Color(0xFF0F172A))
              : (msg.isOfflineNotice
                  ? (isDark ? const Color(0xFF2E1E0F) : const Color(0xFFFFFBEB))
                  : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC))),
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: msg.isUser ? const Radius.circular(4) : const Radius.circular(16),
            bottomLeft: !msg.isUser ? const Radius.circular(4) : const Radius.circular(16),
          ),
          border: Border.all(
            color: msg.isUser
                ? Colors.transparent
                : (msg.isOfflineNotice
                    ? (isDark ? const Color(0xFF92400E) : const Color(0xFFFDE68A))
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              msg.text,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: msg.isUser
                    ? Colors.white
                    : (msg.isOfflineNotice
                        ? (isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E))
                        : (isDark ? Colors.white : const Color(0xFF1E293B))),
              ),
            ),
            if (msg.generatedQuestions != null && msg.generatedQuestions!.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _saveGeneratedQuestionsToBank(msg.generatedQuestions!),
                  icon: const Icon(Icons.playlist_add_check_rounded, size: 18),
                  label: Text(
                    '+ Duyệt & Lưu ${msg.generatedQuestions!.length} câu vào Ngân hàng đề',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
