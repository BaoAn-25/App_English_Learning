import 'package:flutter/material.dart';
import '../../data/app_repository.dart';
import '../../data/remote/api_client.dart';
import '../auth/auth_controller.dart';
import '../home/streak_calculator.dart';
import '../theme/components/app_button.dart';
import 'speed_quiz_arena_screen.dart';

/// Dữ liệu một đối thủ trên Bảng Xếp Hạng (Dữ liệu thật từ CSDL)
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

  List<LeaderboardUser> _users = [];
  int _currentUserRank = 1;
  int _currentUserXp = 0;
  bool _isLoading = true;

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
    setState(() => _isLoading = true);
    final auth = AuthController.instance;
    final currentUserId = (auth.isAuthenticated && !auth.user.isGuest)
        ? auth.user.id
        : await _repo.getOrCreateGuestSessionId();
    final userName = (auth.isAuthenticated && !auth.user.isGuest)
        ? auth.user.displayName
        : 'Bạn (Học viên)';

    // 1. Nạp số liệu học tập thật của học sinh từ CSDL SQLite
    int realXp = 0;
    int realStreak = 0;
    try {
      final stats = await _repo.getAllDailyStats(ownerId: currentUserId);
      realStreak = StreakCalculator.calculateStreak(stats);
      realXp = stats.fold<int>(0, (sum, s) => sum + s.xp);
    } catch (_) {}

    // 2. Thử truy vấn danh sách học sinh thật từ Backend Server API
    List<LeaderboardUser> realServerUsers = [];
    try {
      final token = await _repo.getAuthToken();
      final client = ApiClient(tokenProvider: () => token);
      final remoteList = await client.fetchLeaderboard();
      if (remoteList != null && remoteList.isNotEmpty) {
        for (int i = 0; i < remoteList.length; i++) {
          final item = remoteList[i];
          final isMe = item['id'] == currentUserId;
          final remoteXp = (item['xp'] as num?)?.toInt() ?? 0;
          final remoteStreak = (item['streak'] as num?)?.toInt() ?? 0;

          realServerUsers.add(LeaderboardUser(
            rank: i + 1,
            name: isMe ? userName : (item['name'] as String? ?? 'Học viên EngPass'),
            school: item['school'] as String? ?? 'Lớp 12 · Mục tiêu THPT',
            xp: isMe && realXp > remoteXp ? realXp : remoteXp,
            streak: isMe && realStreak > remoteStreak ? realStreak : remoteStreak,
            avatarUrl: item['avatarUrl'] as String? ?? '',
            isCurrentUser: isMe,
          ));
        }
      }
    } catch (_) {}

    // 3. Nếu chưa kết nối máy chủ hoặc danh sách rỗng, sử dụng dữ liệu người dùng thật tại thiết bị
    if (realServerUsers.isEmpty) {
      realServerUsers = [
        LeaderboardUser(
          rank: 1,
          name: userName,
          school: 'Lớp 12 · Mục tiêu THPT',
          xp: realXp,
          streak: realStreak,
          isCurrentUser: true,
        ),
      ];
    } else {
      // Đảm bảo người dùng hiện tại luôn có mặt trong bảng xếp hạng theo điểm XP thật
      final exists = realServerUsers.any((u) => u.isCurrentUser);
      if (!exists) {
        realServerUsers.add(LeaderboardUser(
          rank: realServerUsers.length + 1,
          name: userName,
          school: 'Lớp 12 · Mục tiêu THPT',
          xp: realXp,
          streak: realStreak,
          isCurrentUser: true,
        ));
        realServerUsers.sort((a, b) => b.xp.compareTo(a.xp));
        for (int i = 0; i < realServerUsers.length; i++) {
          final u = realServerUsers[i];
          realServerUsers[i] = LeaderboardUser(
            rank: i + 1,
            name: u.name,
            school: u.school,
            xp: u.xp,
            streak: u.streak,
            avatarUrl: u.avatarUrl,
            isCurrentUser: u.isCurrentUser,
          );
        }
      }
    }

    final myIdx = realServerUsers.indexWhere((u) => u.isCurrentUser);
    final myRank = myIdx >= 0 ? realServerUsers[myIdx].rank : 1;

    if (mounted) {
      setState(() {
        _users = realServerUsers;
        _currentUserRank = myRank;
        _currentUserXp = realXp;
        _isLoading = false;
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
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : const Color(0xFF0F172A)),
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
            tooltip: 'Làm mới bảng xếp hạng',
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2563EB)),
            onPressed: _loadUserStats,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2563EB),
          unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          indicatorColor: const Color(0xFF2563EB),
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontFamily: 'BeVietnamPro', fontWeight: FontWeight.bold, fontSize: 13.5),
          tabs: const [
            Tab(text: '🏆 Bảng Xếp Hạng Tuần'),
            Tab(text: '⚡ Đấu Trường Tốc Độ 60s'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLeaderboardTab(isDark),
          _buildArenaIntroTab(context, isDark),
        ],
      ),
      bottomNavigationBar: _buildStickyMyRankBar(isDark),
    );
  }

  Widget _buildLeaderboardTab(bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)));
    }

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
                        'Cập nhật trực tiếp từ hệ thống',
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
                      'Top Thăng Hạng',
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
              if (_users.length >= 3) ...[
                _buildTop3Podium(isDark),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: _users.skip(3).map((u) => _buildUserRankTile(u, isDark)).toList(),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E2430) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.workspace_premium_rounded, size: 48, color: Color(0xFFEAB308)),
                        const SizedBox(height: 8),
                        const Text(
                          'Bảng Xếp Hạng Tuần Hiện Tại',
                          style: TextStyle(fontFamily: 'BeVietnamPro', fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Hiện có ${_users.length} học viên ghi nhận thành tích tuần này. Hãy tiếp tục học bài và tham gia Đấu Trường 60s để gia tăng điểm XP!',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: _users.map((u) => _buildUserRankTile(u, isDark)).toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTop3Podium(bool isDark) {
    if (_users.length < 3) return const SizedBox.shrink();
    final first = _users[0];
    final second = _users[1];
    final third = _users[2];

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
                          fontSize: 13,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (user.isCurrentUser) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('BẠN', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
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
                  'Điểm hiện tại: $_currentUserXp XP',
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
          const SizedBox(height: 6),
          Text(
            'Thử thách phản xạ nhanh 15 câu hỏi THPT ngẫu nhiên trong 60 giây',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), height: 1.4),
          ),
          const SizedBox(height: 24),
          _buildArenaRuleCard(
            icon: Icons.timer_rounded,
            title: 'Thời gian 60 giây đếm ngược',
            desc: 'Đồng hồ đếm ngược liên tục. Phản xạ càng nhanh, điểm tích lũy càng cao.',
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _buildArenaRuleCard(
            icon: Icons.local_fire_department_rounded,
            title: 'Combo nhân đôi XP',
            desc: 'Mỗi câu đúng liên tiếp kích hoạt hệ số nhân Combo x2, x3 để leo tháp bảng xếp hạng.',
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _buildArenaRuleCard(
            icon: Icons.auto_awesome_rounded,
            title: 'Ngân hàng đề thi THPT Quốc gia',
            desc: 'Các câu hỏi được chọn ngẫu nhiên từ kho 405 câu chuẩn kiến thức SGK 12.',
            isDark: isDark,
          ),
          const SizedBox(height: 32),
          AppButton(
            label: 'VÀO ĐẤU TRƯỜNG NGAY',
            icon: Icons.play_arrow_rounded,
            isFullWidth: true,
            height: 52,
            variant: AppButtonVariant.primary,
            onPressed: () => _openSpeedQuizArena(),
          ),
        ],
      ),
    );
  }

  Widget _buildArenaRuleCard({
    required IconData icon,
    required String title,
    required String desc,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2430) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF2563EB), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSpeedQuizArena() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SpeedQuizArenaScreen()),
    );
    await _loadUserStats();
  }
}
