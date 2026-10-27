import 'package:flutter/material.dart';

import '../data/asset_seeder.dart';
import 'main_shell.dart';

class AppStartup extends StatefulWidget {
  final Future<void> Function()? initialize;

  const AppStartup({super.key, this.initialize});

  @override
  State<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<AppStartup> {
  late Future<void> _initialization;
  bool _initializing = false;

  @override
  void initState() {
    super.initState();
    _initialization = _initialize();
  }

  Future<void> _initialize() async {
    _initializing = true;
    try {
      await (widget.initialize ?? () => AssetSeeder.seedIfEmpty())();
    } finally {
      _initializing = false;
    }
  }

  void _retry() {
    if (_initializing) return;
    setState(() {
      _initialization = _initialize();
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _initialization,
    builder: (context, snapshot) {
      final loading = snapshot.connectionState != ConnectionState.done;
      if (!loading && !snapshot.hasError) return const MainShell();
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (loading) ...[
                      const CircularProgressIndicator(),
                      const SizedBox(height: 24),
                      Semantics(
                        liveRegion: true,
                        child: const Text('Đang chuẩn bị dữ liệu học…'),
                      ),
                    ] else ...[
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          'Không tải được dữ liệu.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Vui lòng thử lại.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _retry,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
