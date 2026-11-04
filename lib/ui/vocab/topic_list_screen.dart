import '../textbook/textbook_hub_screen.dart';
import '../textbook/textbook_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/topic.dart';
import 'srs_review_screen.dart';
import 'vocab_provider.dart';
import 'match_game_screen.dart';
import 'word_list_screen.dart';

/// Màn hình danh sách 10 chủ đề từ vựng & Ghép Thẻ
class TopicListScreen extends StatefulWidget {
  final bool showAppBar;
  const TopicListScreen({super.key, this.showAppBar = true});

  @override
  State<TopicListScreen> createState() => _TopicListScreenState();
}

class _TopicListScreenState extends State<TopicListScreen> {
  int _selectedSegment = 0; // 0: Flashcards, 1: Match Game

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<VocabProvider>().loadTopics();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isDark = theme.brightness == Brightness.dark;

    final segmentedControl = Container(
      color: isDark ? const Color(0xFF1E2430) : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() => _selectedSegment = 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _selectedSegment == 0 ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: _selectedSegment == 0
                        ? [const BoxShadow(color: Color(0x10000000), blurRadius: 4, offset: Offset(0, 1))]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      'Thẻ Lật 3D (Flashcards)',
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                        color: _selectedSegment == 0 ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() => _selectedSegment = 1),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _selectedSegment == 1 ? const Color(0xFF2563EB) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: _selectedSegment == 1
                        ? [const BoxShadow(color: Color(0x182563EB), blurRadius: 4, offset: Offset(0, 1))]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      'Ghép Thẻ (Match Game)',
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                        color: _selectedSegment == 1 ? Colors.white : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (_selectedSegment == 1) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: widget.showAppBar
            ? AppBar(
                backgroundColor: Colors.white,
                elevation: 0.5,
                title: const Text(
                  'Ghép Thẻ Từ Vựng',
                  style: TextStyle(fontFamily: 'BeVietnamPro', fontWeight: FontWeight.bold, fontSize: 18),
                ),
              )
            : null,
        body: Column(
          children: [
            segmentedControl,
            const Expanded(
              child: MatchGameScreen(isEmbedded: true),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Consumer<VocabProvider>(
        builder: (context, provider, _) {
          return CustomScrollView(
            slivers: [
              // ── App Bar (Ẩn khi nhúng trong TabBar của ReviewScreen) ──
              if (widget.showAppBar)
                SliverAppBar(
                  expandedHeight: 160,
                  floating: false,
                  pinned: true,
                  backgroundColor: colorScheme.surface,
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding: const EdgeInsets.fromLTRB(20, 0, 16, 14),
                    title: Text(
                      'Từ Vựng',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    background: _HeaderBackground(colorScheme: colorScheme),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.menu_book_rounded),
                      tooltip: 'Đọc Sách Giáo Khoa 12',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TextbookScreen()),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.dashboard_customize_rounded),
                      tooltip: 'Trò chơi Ghép Thẻ Từ Vựng',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MatchGameScreen()),
                      ),
                    ),
                    _SrsReviewButton(provider: provider),
                    const SizedBox(width: 8),
                  ],
                )
              else
                // Banner header gọn gàng khi hiển thị bên trong Tab
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primaryContainer.withAlpha(200),
                          colorScheme.secondaryContainer.withAlpha(120),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.school_rounded, size: 36, color: colorScheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Luyện Thi THPT',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '200 Từ Vựng Tiếng Anh 12',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.menu_book_rounded),
                          tooltip: 'Sách GK 12',
                          color: colorScheme.primary,
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const TextbookScreen()),
                          ),
                        ),
                        _SrsReviewButton(provider: provider),
                      ],
                    ),
                  ),
                ),

              // ── Thống kê tổng quan ────────────────────────────────────
              SliverToBoxAdapter(
                child: _StatsRow(provider: provider),
              ),
              // ── Banner mở Sách Giáo Khoa 12 ─────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: colorScheme.primary.withAlpha(80),
                        width: 1.2,
                      ),
                    ),
                    color: colorScheme.primaryContainer.withAlpha(60),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.auto_stories_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      title: const Text(
                        'Sách Giáo Khoa Tiếng Anh 12',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text(
                        'Đọc trọn bộ 159 trang Global Success, vở ghi bài & tra cứu OCR',
                        style: TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TextbookHubScreen(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),


              // ── Tiêu đề section ───────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child: Text(
                    'Glossary · 10 Unit Global Success 12',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ),

              // ── Loading ───────────────────────────────────────────────
              if (provider.isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (provider.topics.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Text(
                      'Không có chủ đề nào.',
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                )
              else
                // ── Danh sách chủ đề ─────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final topic = provider.topics[index];
                        return _TopicCard(
                          topic: topic,
                          index: index,
                          progressMap: provider.progressMap,
                        );
                      },
                      childCount: provider.topics.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ── Header với gradient ────────────────────────────────────────────────────
class _HeaderBackground extends StatelessWidget {
  final ColorScheme colorScheme;
  const _HeaderBackground({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer.withAlpha(200),
            colorScheme.secondaryContainer.withAlpha(120),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
        child: Row(
          children: [
            Icon(Icons.school_rounded, size: 36, color: colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Luyện Thi THPT',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '200 Từ Vựng Tiếng Anh',
                    style: TextStyle(
                      fontSize: 16,
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Nút ôn luyện SRS ──────────────────────────────────────────────────────
class _SrsReviewButton extends StatelessWidget {
  final VocabProvider provider;
  const _SrsReviewButton({required this.provider});

  @override
  Widget build(BuildContext context) {
    final dueCount = provider.progressMap.values
        .where((p) => p.isDue && p.isLearned)
        .length;

    return Badge(
      isLabelVisible: dueCount > 0,
      label: Text('$dueCount'),
      child: IconButton(
        icon: const Icon(Icons.repeat_rounded),
        tooltip: 'Ôn luyện ngắt quãng',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider.value(
              value: provider,
              child: const SrsReviewScreen(),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Row thống kê ──────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final VocabProvider provider;
  const _StatsRow({required this.provider});

  @override
  Widget build(BuildContext context) {
    const total = 200;
    final learned = provider.totalLearnedCount();
    final mastered = provider.masteredCount();
    final dueCount = provider.progressMap.values
        .where((p) => p.isDue && p.isLearned)
        .length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          _StatChip(
            icon: Icons.book_outlined,
            label: '$learned/$total',
            sublabel: 'Đã học',
            color: Colors.blue,
          ),
          const SizedBox(width: 8),
          _StatChip(
            icon: Icons.star_rounded,
            label: '$mastered',
            sublabel: 'Thành thạo',
            color: Colors.amber,
          ),
          const SizedBox(width: 8),
          _StatChip(
            icon: Icons.repeat_rounded,
            label: '$dueCount',
            sublabel: 'Cần ôn',
            color: Colors.orange,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(
                  value: provider,
                  child: const SrsReviewScreen(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback? onTap;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withAlpha(60)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: color,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      sublabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurface.withAlpha(140),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Card chủ đề ───────────────────────────────────────────────────────────
class _TopicCard extends StatelessWidget {
  final Topic topic;
  final int index;
  final Map<String, dynamic> progressMap;

  static const List<Color> _colors = [
    Color(0xFF5C6BC0),
    Color(0xFF26A69A),
    Color(0xFF66BB6A),
    Color(0xFFEF5350),
    Color(0xFFAB47BC),
    Color(0xFF29B6F6),
    Color(0xFFFF7043),
    Color(0xFF26C6DA),
    Color(0xFF9CCC65),
    Color(0xFFFFCA28),
  ];

  static const List<IconData> _icons = [
    Icons.emoji_events_rounded,
    Icons.location_city_rounded,
    Icons.eco_rounded,
    Icons.computer_rounded,
    Icons.thermostat_rounded,
    Icons.school_rounded,
    Icons.local_hospital_rounded,
    Icons.people_rounded,
    Icons.business_center_rounded,
    Icons.flight_rounded,
  ];

  const _TopicCard({
    required this.topic,
    required this.index,
    required this.progressMap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _colors[index % _colors.length];
    final icon = _icons[index % _icons.length];

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChangeNotifierProvider.value(
                value: context.read<VocabProvider>(),
                child: WordListScreen(topic: topic),
              ),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withAlpha(18),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withAlpha(50)),
            ),
            child: Row(
              children: [
                // Icon chủ đề
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withAlpha(40),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(width: 14),
                // Tên & progress
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chủ đề ${topic.order}',
                        style: TextStyle(
                          fontSize: 11,
                          color: color,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        topic.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      _TopicProgressBar(topicId: topic.id, color: color),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded,
                    color: color.withAlpha(180), size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Progress bar cho từng chủ đề ──────────────────────────────────────────
class _TopicProgressBar extends StatelessWidget {
  final String topicId;
  final Color color;
  const _TopicProgressBar({required this.topicId, required this.color});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VocabProvider>();
    const wordsPerTopic = 20;

    // Đếm đã học trong chủ đề này
    int learned = 0;
    final unit = topicId.split('_').last; // ví dụ: "u1", "u2", "u10"
    for (final entry in provider.progressMap.values) {
      if (entry.isLearned && entry.wordId.startsWith('w_${unit}_')) {
        learned++;
      }
    }
    final progress = (learned / wordsPerTopic).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: color.withAlpha(30),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '$learned/$wordsPerTopic từ đã học',
          style: TextStyle(
            fontSize: 11,
            color: color.withAlpha(200),
          ),
        ),
      ],
    );
  }
}
