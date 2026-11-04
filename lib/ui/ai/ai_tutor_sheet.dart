import 'package:flutter/material.dart';
import '../../data/app_repository.dart';
import '../../data/remote/api_client.dart';
import '../../data/trial_lesson_repository.dart';
import '../theme/components/engpass_mascot.dart';

class AiChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isOfflineNotice;

  const AiChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isOfflineNotice = false,
  });
}

/// Bottom Sheet Trợ lý Gia sư AI dành cho học sinh Tiếng Anh 12.
/// - Kết nối trực tiếp API Backend (`/api/ai/ask`).
/// - Nếu máy chủ chưa cấu hình API Key: Báo trung thực, không tạo phản hồi giả,
///   đồng thời kích hoạt chế độ hỗ trợ tri thức SGK 12 ngoại tuyến.
class AiTutorSheet extends StatefulWidget {
  final int? unitNumber;
  final String? unitTitle;
  final String? sectionTitle;
  final String? contextText;

  const AiTutorSheet({
    super.key,
    this.unitNumber,
    this.unitTitle,
    this.sectionTitle,
    this.contextText,
  });

  static Future<void> show(
    BuildContext context, {
    int? unitNumber,
    String? unitTitle,
    String? sectionTitle,
    String? contextText,
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

  @override
  void initState() {
    super.initState();
    _initWelcomeMessage();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initWelcomeMessage() {
    final unitInfo = widget.unitNumber != null
        ? 'Unit ${widget.unitNumber}: ${widget.unitTitle ?? ""}'
        : 'SGK Tiếng Anh 12 Global Success';
    final sectionInfo = widget.sectionTitle != null ? ' (${widget.sectionTitle})' : '';

    _messages.add(
      AiChatMessage(
        text: 'Xin chào! Mình là Gia sư AI đồng hành cùng bạn ôn luyện $unitInfo$sectionInfo.\n\n'
            'Bạn có thể hỏi về cách dùng ngữ pháp, mẹo làm bài đọc hiểu, dịch cụm từ hoặc cấu trúc câu nhé!',
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> _sendMessage([String? presetText]) async {
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
      final repo = AppRepository();
      final token = await repo.getAuthToken();
      final client = ApiClient(tokenProvider: () => token);

      final response = await client.askAiTutor(
        question: query,
        unitNumber: widget.unitNumber,
        section: widget.sectionTitle,
        contextText: widget.contextText,
      );

      if (!mounted) return;

      if (response.isSuccess && response.data != null) {
        final answer = response.data!['answer'] as String? ?? 'Chưa có câu trả lời.';
        setState(() {
          _messages.add(
            AiChatMessage(
              text: answer,
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
        });
      } else {
        // Xử lý khi máy chủ chưa cấu hình API Key hoặc lỗi mạng
        final errorMsg = response.errorMessage ?? 'Không thể kết nối máy chủ AI.';
        final offlineAnswer = _getOfflineFallbackAnswer(query);

        setState(() {
          _messages.add(
            AiChatMessage(
              text: '⚠️ $errorMsg\n\n'
                  '💡 [Giải đáp ngoại tuyến SGK 12]:\n$offlineAnswer',
              isUser: false,
              timestamp: DateTime.now(),
              isOfflineNotice: true,
            ),
          );
        });
      }
    } catch (e) {
      if (!mounted) return;
      final offlineAnswer = _getOfflineFallbackAnswer(query);
      setState(() {
        _messages.add(
          AiChatMessage(
            text: '⚠️ Không có kết nối mạng tới máy chủ AI ($e).\n\n'
                '💡 [Giải đáp ngoại tuyến SGK 12]:\n$offlineAnswer',
            isUser: false,
            timestamp: DateTime.now(),
            isOfflineNotice: true,
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  /// Tra cứu tri thức có sẵn trong từ điển ngoại tuyến SGK 12 khi cloud AI chưa sẵn sàng
  String _getOfflineFallbackAnswer(String query) {
    final lower = query.toLowerCase();

    // 1. Kiểm tra từ vựng
    final lookup = TrialLessonRepository.instance.lookupWordOrPhrase(query: query);
    if (lookup.isFoundInDictionary) {
      final phonetic = lookup.phonetic != null ? ' [${lookup.phonetic}]' : '';
      final pos = lookup.partOfSpeech != null ? ' (${lookup.partOfSpeech})' : '';
      return 'Mục từ: "${lookup.displayWord}"$phonetic$pos\n'
          'Nghĩa: ${lookup.meaning}\n'
          'Nguồn: ${lookup.source}';
    }

    // 2. Kiến thức ngữ pháp Unit 1 & 2
    if (lower.contains('quá khứ') || lower.contains('past') || widget.unitNumber == 1) {
      return 'Trọng tâm ngữ pháp Unit 1 (Past Simple vs. Past Continuous):\n'
          '• Quá khứ đơn (Past Simple): Diễn tả hành động đã xảy ra và kết thúc hoàn toàn trong quá khứ (S + V2/ed).\n'
          '• Quá khứ tiếp diễn (Past Continuous): Diễn tả hành động đang diễn ra tại một thời điểm xác định trong quá khứ (S + was/were + V-ing).\n'
          '• Kết hợp với When/While: Hành động đang xảy ra (quá khứ tiếp diễn) thì hành động khác cắt ngang (quá khứ đơn).\n'
          'Ví dụ: "She was working in a hospital when she wrote her diary."';
    }

    if (lower.contains('cleft') || lower.contains('nhấn mạnh') || widget.unitNumber == 2) {
      return 'Trọng tâm ngữ pháp Unit 2 (Cleft Sentences - Câu chẻ):\n'
          '• Cấu trúc: It is / It was + [Thành phần cần nhấn mạnh] + that / who + S + V...\n'
          '• Dùng để tập trung sự chú ý vào một thông tin cụ thể (chủ ngữ, tân ngữ, hoặc trạng ngữ).\n'
          'Ví dụ: "It is the rich cultural diversity that makes our country unique."';
    }

    // 3. Mẹo làm bài đọc hiểu chung
    if (lower.contains('đọc hiểu') || lower.contains('reading') || lower.contains('tiêu đề')) {
      return 'Mẹo làm bài Đọc hiểu SGK & thi tốt nghiệp THPT:\n'
          '1. Đọc lướt (Skimming): Đọc câu đầu và câu cuối mỗi đoạn văn để nắm ý chính.\n'
          '2. Quét thông tin (Scanning): Tìm các từ khóa (tên riêng, số liệu, năm tháng, thuật ngữ) trong câu hỏi trước khi quay lại bài đọc.\n'
          '3. Ghép tiêu đề đoạn văn: Chú ý từ đồng nghĩa hoặc cách diễn đạt lại (paraphrase) giữa tiêu đề và ý chính của đoạn.';
    }

    return 'Bạn có thể chạm trực tiếp vào bất kỳ từ vựng nào trong bài đọc để tra cứu nghĩa tức thì, '
        'hoặc bôi đen cụm từ để xem bản dịch đối chiếu chuẩn SGK 12 nhé!';
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

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
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
                bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
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
                      Text(
                        'Gia sư AI EngPass',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        widget.unitNumber != null
                            ? 'Đang hỗ trợ Unit ${widget.unitNumber}: ${widget.unitTitle ?? ""}'
                            : 'Hỗ trợ giải đáp kiến thức SGK 12 Global Success',
                        style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
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
                    'Gia sư AI đang soạn câu trả lời...',
                    style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),

          // Gợi ý nhanh
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                _buildQuickChip('Trọng tâm ngữ pháp Unit', isDark),
                _buildQuickChip('Mẹo làm bài đọc hiểu', isDark),
                _buildQuickChip('Cấu trúc câu hỏi hay gặp', isDark),
              ],
            ),
          ),

          // Input bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    style: TextStyle(fontSize: 14, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      hintText: 'Nhập câu hỏi bài học hoặc từ cần tra...',
                      hintStyle: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF0F172A), width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.send_rounded, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF0F172A)),
                  onPressed: _sendMessage,
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
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
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
        child: Text(
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
      ),
    );
  }
}
