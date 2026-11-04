import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_repository.dart';
import 'topic_list_screen.dart';
import 'vocab_provider.dart';

/// Entry point của module Vocab – cung cấp VocabProvider và điều hướng đến TopicListScreen
class VocabScreen extends StatelessWidget {
  final bool showAppBar;
  const VocabScreen({super.key, this.showAppBar = false});

  @override
  Widget build(BuildContext context) {
    AppRepository repo;
    try {
      repo = context.read<AppRepository>();
    } catch (_) {
      repo = AppRepository();
    }

    return ChangeNotifierProvider(
      create: (ctx) => VocabProvider(repo),
      child: TopicListScreen(showAppBar: showAppBar),
    );
  }
}
