import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Hộp thoại hiển thị thông báo đổi mã lớp trực quan, hiển thị rõ mã cũ -> mã mới
/// cùng các con số/ký tự được định dạng badge nổi bật, hỗ trợ sao chép và đổi mã khác.
class ClassCodeDialog extends StatefulWidget {
  final String className;
  final String oldCode;
  final String initialNewCode;
  final Future<String> Function()? onRegenerateAnother;

  const ClassCodeDialog({
    super.key,
    required this.className,
    required this.oldCode,
    required this.initialNewCode,
    this.onRegenerateAnother,
  });

  /// Hàm tiện ích mở Dialog
  static Future<void> show(
    BuildContext context, {
    required String className,
    required String oldCode,
    required String initialNewCode,
    Future<String> Function()? onRegenerateAnother,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ClassCodeDialog(
        className: className,
        oldCode: oldCode,
        initialNewCode: initialNewCode,
        onRegenerateAnother: onRegenerateAnother,
      ),
    );
  }

  @override
  State<ClassCodeDialog> createState() => _ClassCodeDialogState();
}

class _ClassCodeDialogState extends State<ClassCodeDialog> {
  late String _currentCode;
  bool _isCopied = false;
  bool _isRegenerating = false;

  @override
  void initState() {
    super.initState();
    _currentCode = widget.initialNewCode;
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _currentCode));
    setState(() {
      _isCopied = true;
    });
    HapticFeedback.lightImpact();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isCopied = false;
        });
      }
    });
  }

  Future<void> _regenerate() async {
    if (widget.onRegenerateAnother == null || _isRegenerating) return;
    setState(() {
      _isRegenerating = true;
    });
    try {
      final newCode = await widget.onRegenerateAnother!();
      if (mounted) {
        setState(() {
          _currentCode = newCode;
          _isCopied = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRegenerating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final characters = _currentCode.split('');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 10,
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Icon Header
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.vpn_key_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),

              // 2. Tiêu đề & Tên lớp
              const Text(
                'Đổi Mã Lớp Thành Công',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.className,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 20),

              // 3. Khung so sánh: Mã cũ -> Mã mới
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    // Hàng mã cũ (nếu có)
                    if (widget.oldCode.isNotEmpty && widget.oldCode != _currentCode) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Mã trước đây: ',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              widget.oldCode,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF64748B),
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Icon(
                        Icons.arrow_downward_rounded,
                        size: 18,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Nhãn mã mới
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'MÃ LỚP MỚI ĐƯỢC CẤP',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                            color: Color(0xFF0F766E),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Hiển thị từng con số / ký tự trong các ô Badge PIN đẹp mắt
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: characters.map((char) {
                        final isDash = char == '-';
                        return Container(
                          width: isDash ? 18 : 36,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isDash ? Colors.transparent : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: isDash
                                ? null
                                : Border.all(
                                    color: const Color(0xFF6366F1),
                                    width: 1.5,
                                  ),
                            boxShadow: isDash
                                ? null
                                : [
                                    BoxShadow(
                                      color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                                      blurRadius: 6,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                          ),
                          child: Text(
                            char,
                            style: TextStyle(
                              fontSize: isDash ? 20 : 20,
                              fontWeight: FontWeight.w900,
                              color: isDash
                                  ? const Color(0xFF64748B)
                                  : const Color(0xFF1E1B4B),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Nút bấm sao chép mã
                    InkWell(
                      onTap: _copyToClipboard,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: _isCopied
                              ? const Color(0xFFECFDF5)
                              : const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _isCopied
                                ? const Color(0xFF10B981)
                                : const Color(0xFFC7D2FE),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isCopied ? Icons.check_circle_rounded : Icons.copy_rounded,
                              size: 16,
                              color: _isCopied
                                  ? const Color(0xFF059669)
                                  : const Color(0xFF4338CA),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isCopied ? 'Đã sao chép mã!' : 'Sao chép mã mới',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _isCopied
                                    ? const Color(0xFF059669)
                                    : const Color(0xFF4338CA),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 4. Ghi chú hướng dẫn
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Học sinh nhập mã này để vào lớp. Mã cũ lập tức vô hiệu hóa để bảo mật.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 5. Nút bấm hành động
              Row(
                children: [
                  if (widget.onRegenerateAnother != null)
                    Expanded(
                      flex: 4,
                      child: OutlinedButton.icon(
                        onPressed: _isRegenerating ? null : _regenerate,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        icon: _isRegenerating
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF475569)),
                        label: Text(
                          _isRegenerating ? 'Đang đổi...' : 'Đổi mã khác',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                        ),
                      ),
                    ),
                  if (widget.onRegenerateAnother != null) const SizedBox(width: 10),
                  Expanded(
                    flex: 5,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Hoàn tất',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

