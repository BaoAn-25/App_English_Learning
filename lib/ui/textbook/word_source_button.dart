import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/textbook_repository.dart';
import 'textbook_screen.dart';

class WordSourceButton extends StatelessWidget {
  final String wordId;
  final String? english;
  const WordSourceButton({super.key, required this.wordId, this.english});
  @override
  Widget build(BuildContext context) => TextButton.icon(
    icon: const Icon(Icons.menu_book_outlined),
    label: const Text('Phiên âm, từ loại & nghĩa trong sách'),
    onPressed: () async {
      try {
        final sources =
            jsonDecode(
                  await rootBundle.loadString('assets/data/word_sources.json'),
                )
                as Map<String, dynamic>;
        final source = sources[wordId] ??
            (english != null ? sources[english!.toLowerCase().trim()] : null);
        if (source == null) return;
        final book = await TextbookRepository().load();
        if (!context.mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TextbookReader(
              book: book,
              initialPage: source['page'] as int,
              start: 147,
              end: 155,
            ),
          ),
        );
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không mở được trang nguồn. Vui lòng thử lại.'),
            ),
          );
        }
      }
    },
  );
}
