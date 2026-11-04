import 'package:flutter/material.dart';

class AvatarPickerDialog extends StatefulWidget {
  final String currentAvatarUrl;
  final ValueChanged<String> onSelected;

  const AvatarPickerDialog({
    super.key,
    required this.currentAvatarUrl,
    required this.onSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required String currentAvatarUrl,
    required ValueChanged<String> onSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AvatarPickerDialog(
        currentAvatarUrl: currentAvatarUrl,
        onSelected: onSelected,
      ),
    );
  }

  @override
  State<AvatarPickerDialog> createState() => _AvatarPickerDialogState();
}

class _AvatarPickerDialogState extends State<AvatarPickerDialog> {
  int _selectedTab = 0; // 0: Bộ sưu tập, 1: Nhập link ảnh
  late final TextEditingController _urlCtrl;
  String _previewUrl = '';
  String _selectedPreset = '';

  static const List<Map<String, String>> presets = [
    {
      'name': 'Học bá THPT',
      'url': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&fit=crop&crop=faces',
    },
    {
      'name': 'Phi hành gia',
      'url': 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=200&fit=crop&crop=faces',
    },
    {
      'name': 'Học giả tài năng',
      'url': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&fit=crop&crop=faces',
    },
    {
      'name': 'Năng động sáng tạo',
      'url': 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=200&fit=crop&crop=faces',
    },
    {
      'name': 'Thầy giáo mẫu mực',
      'url': 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=200&fit=crop&crop=faces',
    },
    {
      'name': 'Cô giáo nhiệt huyết',
      'url': 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=200&fit=crop&crop=faces',
    },
    {
      'name': 'Quản trị viên Tối cao',
      'url': 'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?w=200&fit=crop&crop=faces',
    },
    {
      'name': 'Chiến binh IELTS',
      'url': 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=200&fit=crop&crop=faces',
    },
  ];

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(text: widget.currentAvatarUrl);
    _previewUrl = widget.currentAvatarUrl;
    _selectedPreset = widget.currentAvatarUrl;
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2430) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                    color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add_photo_alternate_rounded, color: Color(0xFF2563EB)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Đổi ảnh đại diện (Avatar)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Tab switch: Bộ sưu tập mẫu vs Link ảnh bên ngoài
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2D3748) : Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedTab == 0
                              ? (isDark ? const Color(0xFF1A202C) : Colors.white)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _selectedTab == 0
                              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1))]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Bộ sưu tập EngPass',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: _selectedTab == 0 ? FontWeight.bold : FontWeight.normal,
                            color: _selectedTab == 0 ? const Color(0xFF2563EB) : (isDark ? Colors.grey[300] : Colors.grey[700]),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedTab == 1
                              ? (isDark ? const Color(0xFF1A202C) : Colors.white)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _selectedTab == 1
                              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1))]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Link ảnh từ web',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: _selectedTab == 1 ? FontWeight.bold : FontWeight.normal,
                            color: _selectedTab == 1 ? const Color(0xFF2563EB) : (isDark ? Colors.grey[300] : Colors.grey[700]),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_selectedTab == 0) ...[
              // TAB 0: Grid avatar mẫu
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: presets.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.85,
                ),
                itemBuilder: (ctx, idx) {
                  final p = presets[idx];
                  final isSelected = _selectedPreset == p['url'];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedPreset = p['url']!;
                        _previewUrl = p['url']!;
                        _urlCtrl.text = p['url']!;
                      });
                    },
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 28,
                            backgroundImage: NetworkImage(p['url']!),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          p['name']!,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? const Color(0xFF2563EB) : (isDark ? Colors.grey[300] : Colors.grey[700]),
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                  onPressed: _selectedPreset.isEmpty
                      ? null
                      : () {
                          widget.onSelected(_selectedPreset);
                          Navigator.pop(context);
                        },
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Áp dụng ảnh này', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ] else ...[
              // TAB 1: Nhập link ảnh bên ngoài
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: _previewUrl.isNotEmpty ? NetworkImage(_previewUrl) : null,
                    child: _previewUrl.isEmpty
                        ? const Icon(Icons.person, size: 32, color: Colors.grey)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _urlCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Dán đường dẫn ảnh (URL)',
                            hintText: 'https://example.com/avatar.jpg',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (v) {
                            setState(() => _previewUrl = v.trim());
                          },
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Hỗ trợ link ảnh JPG, PNG từ Imgur, Facebook, Pinterest, v.v.',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  if (widget.currentAvatarUrl.isNotEmpty) ...[
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      onPressed: () {
                        widget.onSelected('');
                        Navigator.pop(context);
                      },
                      child: const Text('Xóa ảnh'),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                      onPressed: () {
                        final trimmed = _urlCtrl.text.trim();
                        widget.onSelected(trimmed);
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.save_rounded, size: 18),
                      label: const Text('Lưu ảnh đại diện', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
