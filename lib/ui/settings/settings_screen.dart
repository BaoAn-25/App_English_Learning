import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_repository.dart';
import 'daily_goal.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _goalController = TextEditingController();
  bool _initialized = false;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  String? _saveError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final stored = await context.read<AppRepository>().getSetting(
        'daily_goal',
      );
      if (!mounted) return;
      _goalController.text = '${validDailyGoal(stored) ?? defaultDailyGoal}';
    } catch (_) {
      if (!mounted) return;
      _loadError = 'Không tải được cài đặt.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final goal = validDailyGoal(_goalController.text)!;
      await context.read<AppRepository>().setSetting('daily_goal', '$goal');
      if (!mounted) return;
      _goalController.text = '$goal';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã lưu mục tiêu.')));
    } catch (_) {
      if (!mounted) return;
      setState(() => _saveError = 'Chưa lưu được mục tiêu. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _goalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cá nhân & cài đặt')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: _loadError != null
                          ? Column(
                              children: [
                                Text(_loadError!),
                                TextButton(
                                  onPressed: _load,
                                  child: const Text('Thử lại'),
                                ),
                              ],
                            )
                          : Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'Mục tiêu mỗi ngày',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.headlineSmall,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Chọn số câu bạn muốn luyện mỗi ngày. Bạn có thể thay đổi bất cứ lúc nào.',
                                  ),
                                  const SizedBox(height: 24),
                                  TextFormField(
                                    controller: _goalController,
                                    enabled: !_saving,
                                    keyboardType: TextInputType.number,
                                    textInputAction: TextInputAction.done,
                                    decoration: const InputDecoration(
                                      labelText: 'Số câu mỗi ngày',
                                      helperText: 'Từ 1 đến 200 câu',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (value) =>
                                        validDailyGoal(value) == null
                                        ? 'Nhập số nguyên từ 1 đến 200.'
                                        : null,
                                    onFieldSubmitted: (_) => _save(),
                                  ),
                                  if (_saveError != null) ...[
                                    const SizedBox(height: 16),
                                    Semantics(
                                      liveRegion: true,
                                      child: Text(
                                        _saveError!,
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.error,
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 24),
                                  FilledButton(
                                    onPressed: _saving ? null : _save,
                                    child: Text(
                                      _saving ? 'Đang lưu…' : 'Lưu mục tiêu',
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                  const Text(
                                    'Dữ liệu học được lưu trên thiết bị này. Xóa dữ liệu ứng dụng hoặc gỡ ứng dụng có thể làm mất tiến độ.',
                                  ),
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
}
