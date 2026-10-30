import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/textbook_repository.dart';
import '../vocab/vocab_screen.dart';

class TextbookScreen extends StatefulWidget {
  const TextbookScreen({super.key});
  @override
  State<TextbookScreen> createState() => _TextbookScreenState();
}

class _TextbookScreenState extends State<TextbookScreen> {
  final repo = TextbookRepository();
  late Future<Textbook> book;
  Set<int> completed = {};
  String query = '';
  @override
  void initState() {
    super.initState();
    book = repo.load();
    _progress();
  }

  Future<void> _progress() async {
    try {
      final value = await repo.completedPages();
      if (mounted) setState(() => completed = value);
    } catch (_) {
      /* Reading remains available if progress cannot be loaded. */
    }
  }

  Future<void> _open(Textbook b, int page, int start, int end) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            TextbookReader(book: b, initialPage: page, start: start, end: end),
      ),
    );
    await _progress();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Global Success 12'),
      actions: [
        IconButton(
          tooltip: 'Dữ liệu trước khi chuyển sách',
          icon: const Icon(Icons.inventory_2_outlined),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LegacyArchiveScreen()),
          ),
        ),
      ],
    ),
    body: FutureBuilder<Textbook>(
      future: book,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: FilledButton(
              onPressed: () => setState(() => book = repo.load()),
              child: const Text('Tải lại sách'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final b = snapshot.data!;
        final results = b.search(query);
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Học theo sách giáo khoa',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  '10 Unit · 4 Review · Phụ lục · Glossary\nĐọc trọn bộ sách, làm bài trong vở và theo dõi các trang đã học.',
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      icon: const Icon(Icons.style_outlined),
                      label: const Text('Từ vựng & flashcard'),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const VocabScreen()),
                      ),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.menu_book),
                      label: const Text('Đọc toàn bộ sách'),
                      onPressed: () => _open(b, -1, -1, 157),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Tìm từ hoặc nội dung trong sách',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() => query = value),
                ),
                if (query.trim().isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Kết quả tìm kiếm từ nhận dạng chữ; đối chiếu nội dung trên ảnh sách.',
                    ),
                  ),
                  if (results.isEmpty)
                    const ListTile(
                      title: Text('Không tìm thấy trang phù hợp.'),
                    ),
                  for (final p in results)
                    ListTile(
                      leading: const Icon(Icons.find_in_page_outlined),
                      title: Text(Textbook.pageLabel(p)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _open(b, p, -1, 157),
                    ),
                ] else ...[
                  for (final group in ['unit', 'review', 'reference']) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 24, bottom: 8),
                      child: Text(
                        {
                          'unit': 'Các Unit',
                          'review': 'Ôn tập',
                          'reference': 'Tra cứu',
                        }[group]!,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    for (final u in b.collections.where((u) => u.kind == group))
                      Card(
                        child: ExpansionTile(
                          title: Text(u.title),
                          subtitle: Text(
                            '${Textbook.pageLabel(u.start)} – ${Textbook.pageLabel(u.end)} · '
                            '${completed.where((p) => p >= u.start && p <= u.end).length}/${u.end - u.start + 1} trang đã học',
                          ),
                          children: [
                            ListTile(
                              leading: const Icon(Icons.auto_stories_outlined),
                              title: const Text('Mở phần này'),
                              onTap: () => _open(b, u.start, u.start, u.end),
                            ),
                            for (final s in u.sections)
                              ListTile(
                                title: Text(s['title']),
                                trailing: Text('tr. ${s['page']}'),
                                onTap: () =>
                                    _open(b, s['page'], u.start, u.end),
                              ),
                          ],
                        ),
                      ),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    ),
  );
}

class TextbookReader extends StatefulWidget {
  final Textbook book;
  final int initialPage, start, end;
  const TextbookReader({
    super.key,
    required this.book,
    required this.initialPage,
    required this.start,
    required this.end,
  });
  @override
  State<TextbookReader> createState() => _TextbookReaderState();
}

class _TextbookReaderState extends State<TextbookReader> {
  late int page;
  final repo = TextbookRepository();
  final transform = TransformationController();
  Set<int> completed = {};
  bool saving = false;
  @override
  void initState() {
    super.initState();
    page = widget.initialPage;
    _refresh();
  }

  @override
  void dispose() {
    transform.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final value = await repo.completedPages();
      if (mounted) setState(() => completed = value);
    } catch (_) {
      if (mounted) _error();
    }
  }

  void _error() => ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Không lưu/đọc được tiến độ. Vui lòng thử lại.'),
    ),
  );
  void _go(int target) {
    setState(() {
      page = target;
      transform.value = Matrix4.identity();
    });
  }

  Future<void> _complete() async {
    if (saving) return;
    setState(() => saving = true);
    try {
      final targetPage = page;
      final state = await repo.study(targetPage);
      await repo.saveStudy(
        targetPage,
        (state['answers'] as List).cast<Map<String, dynamic>>(),
        !completed.contains(targetPage),
      );
      await _refresh();
    } catch (_) {
      if (mounted) _error();
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(Textbook.pageLabel(page)),
      actions: [
        IconButton(
          tooltip: 'Đến trang',
          icon: const Icon(Icons.pin_outlined),
          onPressed: () async {
            final selected = await showDialog<int>(context: context,
              builder: (_) => _PageJumpDialog(page: page, start: widget.start, end: widget.end));
            if (selected != null && mounted) _go(selected);
          },
        ),
        IconButton(
          tooltip: 'Khôi phục thu phóng',
          icon: const Icon(Icons.fit_screen),
          onPressed: () => transform.value = Matrix4.identity(),
        ),
      ],
    ),
    body: Column(
      children: [
        Expanded(
          child: ColoredBox(
            color: Colors.grey.shade200,
            child: SizedBox.expand(
              child: InteractiveViewer(
                transformationController: transform,
                minScale: 1,
                maxScale: 6,
                child: Image.asset(
                  widget.book.asset(page),
                  key: ValueKey(page),
                  fit: BoxFit.contain,
                  semanticLabel:
                      'Trang sách gốc ${Textbook.pageLabel(page)}. Phóng to để đọc.',
                  errorBuilder: (_, error, stack) => const Center(
                    child: Text('Không tải được ảnh trang sách.'),
                  ),
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: [
                    FilledButton.icon(
                      icon: const Icon(Icons.edit_note),
                      label: const Text('Vở bài làm'),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BookWorksheet(page: page),
                          ),
                        );
                        await _refresh();
                      },
                    ),
                    FilterChip(
                      label: const Text('Đã học trang này'),
                      selected: completed.contains(page),
                      onSelected: saving ? null : (_) => _complete(),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      tooltip: 'Trang trước',
                      onPressed: page > widget.start
                          ? () => _go(page - 1)
                          : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text(
                      '${Textbook.pageLabel(page)} · ${page - widget.start + 1}/${widget.end - widget.start + 1}',
                    ),
                    IconButton(
                      tooltip: 'Trang sau',
                      onPressed: page < widget.end ? () => _go(page + 1) : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class BookWorksheet extends StatefulWidget {
  final int page;
  final TextbookRepository? repository;
  const BookWorksheet({super.key, required this.page, this.repository});
  @override
  State<BookWorksheet> createState() => _BookWorksheetState();
}

class _BookWorksheetState extends State<BookWorksheet> {
  late final repo = widget.repository ?? TextbookRepository();
  final List<Map<String, dynamic>> answers = [];
  bool loading = true,
      failed = false,
      saving = false,
      dirty = false,
      completed = false,
      canPop = false;
  static const kinds = [
    'Trả lời ngắn / điền từ',
    'Trắc nghiệm / đúng sai',
    'Nối cặp / sắp xếp',
    'Writing',
    'Speaking',
    'Listening',
    'Project',
    'Ghi chú',
  ];
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final state = await repo.study(widget.page);
      if (!mounted) return;
      setState(() {
        answers.clear();
        answers.addAll((state['answers'] as List).cast<Map<String, dynamic>>());
        completed = state['completed'] == true;
        loading = false;
        failed = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          failed = true;
        });
      }
    }
  }

  Future<bool> _save() async {
    if (saving || loading || failed) return false;
    setState(() => saving = true);
    try {
      await repo.saveStudy(widget.page, answers, completed);
      if (mounted) setState(() => dirty = false);
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Chưa lưu được bài. Nội dung vẫn ở đây; hãy thử lại.',
            ),
          ),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _leave() async {
    if (saving) return;
    if (!dirty || await _save()) {
      if (!mounted) return;
      setState(() => canPop = true);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: canPop,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _leave();
    },
    child: Scaffold(
      appBar: AppBar(title: Text('Vở bài làm · tr. ${widget.page}')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : failed
          ? Center(
              child: FilledButton(
                onPressed: _load,
                child: const Text('Thử tải lại bài đã lưu'),
              ),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(
                      'Ghi số bài/câu đúng như trên trang sách rồi nhập câu trả lời. '
                      'Bài được lưu trên máy khi bấm Lưu hoặc quay lại.',
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Vở bài làm chưa tự chấm điểm. Với Speaking/Project, ghi dàn ý hoặc nội dung thực hiện. '
                      'Bài Listening cần bản ghi âm của sách; hiện chưa có audio kèm theo.',
                    ),
                    for (int i = 0; i < answers.length; i++)
                      Card(
                        key: ValueKey(answers[i]['id']),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              TextFormField(
                                initialValue: answers[i]['label'] as String,
                                enabled: !saving,
                                decoration: const InputDecoration(
                                  labelText:
                                      'Bài / câu (ví dụ: Language 2, câu 1)',
                                ),
                                onChanged: (v) {
                                  answers[i]['label'] = v;
                                  dirty = true;
                                },
                              ),
                              DropdownButtonFormField<String>(
                                initialValue: answers[i]['kind'] as String,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Dạng bài',
                                ),
                                items: kinds
                                    .map(
                                      (k) => DropdownMenuItem(
                                        value: k,
                                        child: Text(k),
                                      ),
                                    )
                                    .toList(),
                                onChanged: saving
                                    ? null
                                    : (v) => setState(() {
                                        answers[i]['kind'] = v;
                                        dirty = true;
                                      }),
                              ),
                              TextFormField(
                                initialValue: answers[i]['response'] as String,
                                enabled: !saving,
                                minLines: 3,
                                maxLines: null,
                                decoration: const InputDecoration(
                                  labelText: 'Bài làm / câu trả lời',
                                  hintText:
                                      'Điền từ: 1. … 2. …\nNối cặp: 1–b, 2–a\nTrắc nghiệm: 1. B\nViết: nhập toàn bộ bài viết',
                                ),
                                onChanged: (v) {
                                  answers[i]['response'] = v;
                                  dirty = true;
                                },
                              ),
                              DropdownButtonFormField<String>(
                                initialValue: answers[i]['review'] as String,
                                decoration: const InputDecoration(
                                  labelText: 'Tự đánh giá',
                                ),
                                isExpanded: true,
                                items:
                                    [
                                          'Chưa đối chiếu',
                                          'Cần ôn lại',
                                          'Đã đối chiếu với giáo viên',
                                        ]
                                        .map(
                                          (s) => DropdownMenuItem(
                                            value: s,
                                            child: Text(s),
                                          ),
                                        )
                                        .toList(),
                                onChanged: saving
                                    ? null
                                    : (v) => setState(() {
                                        answers[i]['review'] = v;
                                        dirty = true;
                                      }),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: saving
                          ? null
                          : () => setState(() {
                              answers.add({
                                'id': DateTime.now().microsecondsSinceEpoch
                                    .toString(),
                                'label': '',
                                'kind': kinds.first,
                                'response': '',
                                'review': 'Chưa đối chiếu',
                              });
                              dirty = true;
                            }),
                      icon: const Icon(Icons.add),
                      label: const Text('Thêm bài / câu trả lời'),
                    ),
                    CheckboxListTile(
                      title: const Text('Đánh dấu đã học trang này'),
                      value: completed,
                      onChanged: saving
                          ? null
                          : (v) => setState(() {
                              completed = v!;
                              dirty = true;
                            }),
                    ),
                    FilledButton.icon(
                      onPressed: saving
                          ? null
                          : () async {
                              if (await _save() && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Đã lưu bài làm.'),
                                  ),
                                );
                              }
                            },
                      icon: const Icon(Icons.save_outlined),
                      label: Text(saving ? 'Đang lưu…' : 'Lưu bài làm'),
                    ),
                  ],
                ),
              ),
            ),
    ),
  );
}

class LegacyArchiveScreen extends StatelessWidget {
  const LegacyArchiveScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Dữ liệu đã lưu trữ')),
    body: FutureBuilder<String?>(
      future: TextbookRepository().database.getSetting(
        TextbookRepository.archiveKey,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Không đọc được bản lưu trữ.'));
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data == null) {
          return const Center(
            child: Text('Cài mới: không có dữ liệu cũ cần lưu trữ.'),
          );
        }
        final archive = jsonDecode(snapshot.data!) as Map<String, dynamic>;
        final tables = archive['tables'] as Map<String, dynamic>;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Nội dung và tiến độ trước khi chuyển sang Global Success 12 được giữ ở đây. '
              'Chúng không cộng vào kết quả học của bộ sách mới.',
            ),
            const SizedBox(height: 12),
            for (final e in tables.entries)
              ListTile(
                title: Text(e.key),
                trailing: Text('${(e.value as List).length} bản ghi'),
              ),
            FilledButton.icon(
              icon: const Icon(Icons.copy),
              label: const Text('Sao chép bản sao lưu JSON'),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: snapshot.data!));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã sao chép bản sao lưu.')),
                  );
                }
              },
            ),
          ],
        );
      },
    ),
  );
}

class _PageJumpDialog extends StatefulWidget {
  final int page, start, end;
  const _PageJumpDialog({required this.page, required this.start, required this.end});
  @override
  State<_PageJumpDialog> createState() => _PageJumpDialogState();
}
class _PageJumpDialogState extends State<_PageJumpDialog> {
  late String value = widget.page.toString();
  String? error;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Đến trang sách'),
    content: TextFormField(initialValue: value,
      keyboardType: const TextInputType.numberWithOptions(signed: true),
      decoration: InputDecoration(labelText: 'Trang ${widget.start} đến ${widget.end}', errorText: error),
      onChanged: (s) => value = s),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
      FilledButton(onPressed: () {
        final p = int.tryParse(value);
        if (p == null || p < widget.start || p > widget.end) {
          setState(() => error = 'Nhập số trang trong phạm vi trên.');
        } else { Navigator.pop(context, p); }
      }, child: const Text('Mở'))]);
}
