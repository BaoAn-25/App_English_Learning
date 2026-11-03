import 'package:flutter/material.dart';
import '../../data/app_repository.dart';
import '../auth/auth_controller.dart';
import '../home/streak_calculator.dart';
import '../theme/components/app_button.dart';
import 'speed_quiz_arena_screen.dart';

/// Dữ liệu một đối thủ trên Bảng Xếp Hạng
class LeaderboardUser {
  final int rank;
  final String name;
  final String school;
  final int xp;
  final int streak;
  final String avatarUrl;
  final bool isCurrentUser;

  const LeaderboardUser({
    required this.rank,
    required this.name,
    required this.school,
    required this.xp,
    required this.streak,
    this.avatarUrl = '',
    this.isCurrentUser = false,
  });
}

/// Màn hình Bảng Xếp Hạng Liên Đoàn & Đua Top Học Sinh THPT
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final int _currentLeagueIndex = 2; // 0: Đồng, 1: Bạc, 2: Vàng, 3: Lam Ngọc, 4: Kim Cương
  final AppRepository _repo = AppRepository();

  final List<String> _leagues = const [
    'Hạng Đồng',
    'Hạng Bạc',
    'Hạng Vàng',
    'Lam Ngọc',
    'Kim Cương',
  ];

  final List<Color> _leagueColors = const [
    Color(0xFFCD7F32), // Đồng
    Color(0xFF94A3B8), // Bạc
    Color(0xFFEAB308), // Vàng
    Color(0xFF0284C7), // Lam Ngọc
    Color(0xFF8B5CF6), // Kim Cương
  ];

  List<LeaderboardUser> _mockUsers = [];
  final int _currentUserRank = 6;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserStats() async {
    final auth = AuthController.instance;
    final userName = auth.isAuthenticated ? auth.user.displayName : 'Bạn (Học thử)';
    int xp = 0;
    int streak = 0;
    try {
      final stats = await _repo.getAllDailyStats();
      streak = StreakCalculator.calculateStreak(stats);
      xp = stats.fold<int>(0, (sum, s) => sum + s.xp);
    } catch (_) {}

    if (mounted) {
      setState(() {
        _mockUsers = [
          const LeaderboardUser(
            rank: 1,
            name: 'Trần Minh Anh',
            school: 'THPT Chuyên Lê Hồng Phong',
            xp: 840,
            streak: 15,
          ),
          const LeaderboardUser(
            rank: 2,
            name: 'Nguyễn Quốc Bảo',
            school: 'THPT Chuyên Hà Nội - Amsterdam',
            xp: 790,
            streak: 12,
          ),
          const LeaderboardUser(
            rank: 3,
            name: 'Lê Hoàng Yến Nhi',
            school: 'THPT Chu Văn An',
            xp: 710,
            streak: 9,
          ),
          const LeaderboardUser(
            rank: 4,
            name: 'Phạm Đức Huy',
            school: 'THPT Bùi Thị Xuân',
            xp: 640,
            streak: 8,
          ),
          const LeaderboardUser(
            rank: 5,
            name: 'Võ Thị Mai Phương',
            school: 'THPT Nguyễn Thượng Hiền',
            xp: 590,
            streak: 7,
          ),
          LeaderboardUser(
            rank: 6,
            name: userName,
            school: 'Lớp 12 · Mục tiêu THPT',
            xp: xp > 0 ? xp : 120,
            streak: streak > 0 ? streak : 1,
            isCurrentUser: true,
          ),
          const LeaderboardUser(
            rank: 7,
            name: 'Đặng Tuấn Kiệt',
            school: 'THPT Gia Định',
            xp: 490,
            streak: 5,
          ),
          const LeaderboardUser(
            rank: 8,
            name: 'Bùi Thanh Trúc',
            school: 'THPT Marie Curie',
            xp: 430,
            streak: 4,
          ),
          const LeaderboardUser(
            rank: 9,
            name: 'Hoàng Văn Nam',
            school: 'THPT Chuyên Thái Bình',
            xp: 380,
            streak: 3,
          ),
          const LeaderboardUser(
            rank: 10,
            name: 'Phan Thùy Linh',
            school: 'THPT Chuyên Lam Sơn',
            xp: 310,
            streak: 2,
          ),
        ];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121620) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E2430) : Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Đấu Trường & Xếp Hạng',
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Thể lệ thăng hạng',
            icon: const Icon(Icons.info_outline_rounded, color: Color(0xFF64748B)),
            onPressed: () => _showRulesDialog(context, isDark),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2563EB),
          unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          labelStyle: const TextStyle(fontFamily: 'BeVietnamPro', fontWeight: FontWeight.w800, fontSize: 13.5),
          indicatorColor: const Color(0xFF2563EB),
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.emoji_events_rounded, size: 20), text: 'Liên Đoàn Tuần'),
            Tab(icon: Icon(Icons.flash_on_rounded, size: 20), text: 'Đấu Trường 60s'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLeagueRankingTab(context, isDark),
          _buildArenaIntroTab(context, isDark),
        ],
      ),
      bottomNavigationBar: _tabController.index == 0 ? _buildStickyMyRankBar(isDark) : null,
    );
  }

  Widget _buildLeagueRankingTab(BuildContext context, bool isDark) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: isDark ? const Color(0xFF1E2430) : Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _leagueColors[_currentLeagueIndex].withAlpha(35),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(Icons.shield_rounded, color: _leagueColors[_currentLeagueIndex], size: 20),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _leagues[_currentLeagueIndex].toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: _leagueColors[_currentLeagueIndex],
                        ),
                      ),
                      Text(
                        'Kết thúc sau 2 ngày 14 giờ',
                        style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_upward_rounded, size: 14, color: Color(0xFF16A34A)),
                    SizedBox(width: 3),
                    Text(
                      'Top 5 Thăng Hạng',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 90),
            children: [
              _buildTop3Podium(isDark),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: _mockUsers.skip(3).map((u) => _buildUserRankTile(u, isDark)).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTop3Podium(bool isDark) {
    if (_mockUsers.length < 3) return const SizedBox.shrink();
    final first = _mockUsers[0];
    final second = _mockUsers[1];
    final third = _mockUsers[2];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2430) : Colors.white,
        border: Border(
          bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildPodiumColumn(second, rank: 2, height: 110, color: const Color(0xFF94A3B8), medal: '🥈', isDark: isDark),
          _buildPodiumColumn(first, rank: 1, height: 140, color: const Color(0xFFEAB308), medal: '👑', isDark: isDark),
          _buildPodiumColumn(third, rank: 3, height: 90, color: const Color(0xFFCD7F32), medal: '🥉', isDark: isDark),
        ],
      ),
    );
  }

  Widget _buildPodiumColumn(
    LeaderboardUser user, {
    required int rank,
    required double height,
    required Color color,
    required String medal,
    required bool isDark,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(medal, style: TextStyle(fontSize: rank == 1 ? 26 : 20)),
        const SizedBox(height: 2),
        CircleAvatar(
          radius: rank == 1 ? 28 : 22,
          backgroundColor: color.withAlpha(50),
          child: Text(
            user.name.trim().isNotEmpty ? user.name.trim()[0].toUpperCase() : 'U',
            style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: rank == 1 ? 20 : 16),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 85,
          child: Text(
            user.name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ),
        Text(
          '⚡ ${user.xp} XP',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: color),
        ),
        const SizedBox(height: 6),
        Container(
          width: 80,
          height: height,
          decoration: BoxDecoration(
            color: color.withAlpha(isDark ? 40 : 25),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border.all(color: color.withAlpha(80)),
          ),
          child: Center(
            child: Text(
              '#$rank',
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontWeight: FontWeight.w900,
                fontSize: 22,
                color: color,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserRankTile(LeaderboardUser user, bool isDark) {
    final bool isTop5 = user.rank <= 5;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: user.isCurrentUser
            ? (isDark ? const Color(0xFF1E3A8A).withAlpha(80) : const Color(0xFFEFF6FF))
            : (isDark ? const Color(0xFF1E2430) : Colors.white),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: user.isCurrentUser
              ? const Color(0xFF2563EB)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: user.isCurrentUser ? 1.8 : 1.0,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '#${user.rank}',
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontWeight: FontWeight.w900,
                fontSize: 14,
                color: isTop5 ? const Color(0xFF16A34A) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 18,
            backgroundColor: user.isCurrentUser ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
            child: Text(
              user.name.isNotEmpty ? user.name.trim()[0].toUpperCase() : 'H',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: user.isCurrentUser ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.name,
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (user.isCurrentUser) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('BẠN', style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                Text(
                  user.school,
                  style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${user.xp} XP',
                style: const TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                  color: Color(0xFFD97706),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 10)),
                  const SizedBox(width: 2),
                  Text(
                    '${user.streak}d',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStickyMyRankBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2430) : Colors.white,
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            offset: Offset(0, -3),
            blurRadius: 8,
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Vị trí của bạn: ', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    Text('#$_currentUserRank', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF2563EB), fontSize: 14)),
                  ],
                ),
                Text(
                  'Cần thêm 100 XP để lọt Top 5 thăng hạng!',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D)),
                ),
              ],
            ),
            const Spacer(),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.flash_on_rounded, size: 16, color: Colors.white),
              label: const Text('Đấu 60s kiếm XP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              onPressed: () => _openSpeedQuizArena(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArenaIntroTab(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.bolt_rounded, size: 48, color: Color(0xFFD97706)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Đấu Trường Tốc Độ 60s',
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontWeight: FontWeight.w900,
              fontSize: 22,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Thử thách phản xạ nhanh 10 câu trắc nghiệm THPT trong 60 giây. Trả lời đúng liên tiếp để kích hoạt Combo x2 XP!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), height: 1.4),
          ),
          const SizedBox(height: 24),
          _buildArenaRuleRow(Icons.timer_outlined, 'Thời gian 60 giây', 'Đồng hồ đếm ngược, làm nhanh và chính xác nhất có thể.', isDark),
          const SizedBox(height: 12),
          _buildArenaRuleRow(Icons.stars_rounded, 'Cộng điểm Bảng Xếp Hạng', 'Mỗi câu đúng +10 XP, Combo đúng liên tục nhận tới +30 XP.', isDark),
          const SizedBox(height: 12),
          _buildArenaRuleRow(Icons.menu_book_rounded, 'Câu hỏi trích từ đề THPT', 'Ngữ pháp, từ vựng, phát âm chuẩn ma trận kỳ thi tốt nghiệp.', isDark),
          const SizedBox(height: 36),
          AppButton(
            label: 'BẮT ĐẦU VÀO ĐẤU TRƯỜNG (60S)',
            isFullWidth: true,
            height: 52,
            variant: AppButtonVariant.primary,
            icon: Icons.play_arrow_rounded,
            onPressed: () => _openSpeedQuizArena(),
          ),
        ],
      ),
    );
  }

  Widget _buildArenaRuleRow(IconData icon, String title, String desc, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2430) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF2563EB), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
                Text(
                  desc,
                  style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openSpeedQuizArena() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SpeedQuizArenaScreen()),
    ).then((_) => _loadUserStats());
  }

  void _showRulesDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Thể lệ Liên Đoàn Tuần'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• Bảng xếp hạng cập nhật lúc 00:00 Thứ Hai hàng tuần.'),
            SizedBox(height: 6),
            Text('• Top 5 học sinh có điểm XP cao nhất sẽ được thăng lên hạng đấu tiếp theo.'),
            SizedBox(height: 6),
            Text('• 5 học sinh cuối bảng sẽ rớt hạng đấu để thi đấu vừa sức hơn.'),
            SizedBox(height: 6),
            Text('• Điểm XP kiếm được từ việc giải bài SGK, học từ vựng và tham gia Đấu trường tốc độ 60s.'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đã hiểu')),
        ],
      ),
    );
  }
}
