import 'package:flutter/material.dart';

class VocabLoadError extends StatelessWidget {
  final VoidCallback onRetry;
  const VocabLoadError({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            liveRegion: true,
            child: const Text(
              'Không thể tải dữ liệu từ vựng. Vui lòng thử lại.',
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    ),
  );
}
