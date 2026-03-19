import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LEADERBOARD SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  bool _isFriends = true;

  static const _topThree = [
    _PodiumUser(rank: 2, name: 'Emma Wilson',  avatar: '👩', points: 1450, streak: 12, isCurrentUser: false),
    _PodiumUser(rank: 1, name: 'Sarah Chen',   avatar: '👤', points: 1850, streak: 25, isCurrentUser: true),
    _PodiumUser(rank: 3, name: 'Alex Kim',     avatar: '👨', points: 1320, streak: 8,  isCurrentUser: false),
  ];

  static const _otherUsers = [
    _RankUser(rank: 4,  name: 'John Davis',   avatar: '👨', points: 1180, streak: 15, isCurrentUser: false),
    _RankUser(rank: 5,  name: 'Maria Garcia', avatar: '👩', points: 1050, streak: 10, isCurrentUser: false),
    _RankUser(rank: 6,  name: 'Bạn',          avatar: '👤', points: 980,  streak: 7,  isCurrentUser: true),
    _RankUser(rank: 7,  name: 'Lisa Brown',   avatar: '👩', points: 890,  streak: 5,  isCurrentUser: false),
    _RankUser(rank: 8,  name: 'Mike Johnson', avatar: '👨', points: 750,  streak: 12, isCurrentUser: false),
    _RankUser(rank: 9,  name: 'Anna Lee',     avatar: '👩', points: 680,  streak: 3,  isCurrentUser: false),
    _RankUser(rank: 10, name: 'Tom White',    avatar: '👨', points: 590,  streak: 6,  isCurrentUser: false),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Column(
        children: [
          // ── Header ──
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              bottom: 18,
              left: 24,
              right: 24,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.go('/home'),
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.arrow_back_rounded,
                            size: 20, color: Color(0xFF374151)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Bảng Xếp Hạng',
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF111827))),
                          Text('Xếp hạng tuần này',
                              style: TextStyle(
                                  fontSize: 13, color: Color(0xFF6B7280))),
                        ],
                      ),
                    ),
                    const Text('👑', style: TextStyle(fontSize: 28)),
                  ],
                ),
                const SizedBox(height: 16),
                // Tabs
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      _TabBtn(
                        label: 'Bạn Bè',
                        icon: Icons.people_rounded,
                        selected: _isFriends,
                        onTap: () => setState(() => _isFriends = true),
                      ),
                      _TabBtn(
                        label: 'Toàn Cầu',
                        icon: Icons.trending_up_rounded,
                        selected: !_isFriends,
                        onTap: () => setState(() => _isFriends = false),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Body ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  _PodiumSection(users: _topThree),
                  const SizedBox(height: 16),
                  const Text('Tất Cả Xếp Hạng',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827))),
                  const SizedBox(height: 12),
                  ..._otherUsers.map(
                    (u) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _RankCard(user: u),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _LeaderboardCTA(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Models ──
class _PodiumUser {
  const _PodiumUser({
    required this.rank,
    required this.name,
    required this.avatar,
    required this.points,
    required this.streak,
    required this.isCurrentUser,
  });
  final int rank, points, streak;
  final String name, avatar;
  final bool isCurrentUser;
}

class _RankUser {
  const _RankUser({
    required this.rank,
    required this.name,
    required this.avatar,
    required this.points,
    required this.streak,
    required this.isCurrentUser,
  });
  final int rank, points, streak;
  final String name, avatar;
  final bool isCurrentUser;
}

// ── Tab button ──
class _TabBtn extends StatelessWidget {
  const _TabBtn({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(50),
            boxShadow: selected
                ? const [
                    BoxShadow(
                        color: Color(0x1A000000),
                        blurRadius: 4,
                        offset: Offset(0, 1))
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: selected
                      ? const Color(0xFF111827)
                      : const Color(0xFF6B7280)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? const Color(0xFF111827)
                        : const Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Podium section ──
class _PodiumSection extends StatelessWidget {
  const _PodiumSection({required this.users});
  final List<_PodiumUser> users; // order: [2nd, 1st, 3rd]

  static const _podiumHeights = [180.0, 220.0, 150.0];

  static List<Color> _gradient(int rank) {
    if (rank == 1) return [const Color(0xFFFBEF76), const Color(0xFFFEC288)];
    if (rank == 2) return [const Color(0xFFD1D5DB), const Color(0xFF9CA3AF)];
    return [const Color(0xFFFD8A6B), const Color(0xFFFA5C5C)];
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 340,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: users.asMap().entries.map((e) {
          final user = e.value;
          final height = _podiumHeights[e.key];
          final grad = _gradient(user.rank);
          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Avatar + crown + rank badge
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    if (user.rank == 1)
                      const Positioned(
                        top: -30,
                        child: Text('👑', style: TextStyle(fontSize: 26)),
                      ),
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: grad,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                        shape: BoxShape.circle,
                        border: user.isCurrentUser
                            ? Border.all(
                                color: const Color(0xFFFA5C5C), width: 3)
                            : null,
                        boxShadow: [
                          BoxShadow(
                              color: grad.last.withValues(alpha: 0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4))
                        ],
                      ),
                      child: Center(
                          child: Text(user.avatar,
                              style: const TextStyle(fontSize: 30))),
                    ),
                    Positioned(
                      bottom: -8,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: grad),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Center(
                          child: Text('${user.rank}',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: user.rank == 1
                                      ? const Color(0xFF374151)
                                      : Colors.white)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  user.name.split(' ').first,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827)),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('⭐', style: TextStyle(fontSize: 12)),
                    Text('${user.points}',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827))),
                  ],
                ),
                const SizedBox(height: 6),
                // Podium block
                Container(
                  width: double.infinity,
                  height: height,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: grad,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12)),
                    boxShadow: [
                      BoxShadow(
                          color: grad.last.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, -2))
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('🔥 ${user.streak}d',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Rank card ──
class _RankCard extends StatelessWidget {
  const _RankCard({required this.user});
  final _RankUser user;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: user.isCurrentUser
            ? Border.all(color: const Color(0xFFFA5C5C), width: 2)
            : null,
        boxShadow: const [
          BoxShadow(
              color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2))
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text('${user.rank}',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6B7280))),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [Color(0xFFFEC288), Color(0xFFFBEF76)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              shape: BoxShape.circle,
            ),
            child: Center(
                child: Text(user.avatar,
                    style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(user.name,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111827)),
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (user.isCurrentUser) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFA5C5C),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('Bạn',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text('🔥 ${user.streak} ngày',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF9CA3AF))),
              ],
            ),
          ),
          Row(
            children: [
              const Text('⭐', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 2),
              Text('${user.points}',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827))),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Bottom CTA ──
class _LeaderboardCTA extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFFFA5C5C), Color(0xFFFD8A6B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
              color: Color(0x40FA5C5C),
              blurRadius: 16,
              offset: Offset(0, 6))
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Row(
            children: [
              Text('🏆', style: TextStyle(fontSize: 40)),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Leo Lên Cao Hơn!',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    SizedBox(height: 2),
                    Text('Hoàn thành bài học để kiếm thêm XP',
                        style: TextStyle(
                            fontSize: 13, color: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.go('/home'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFFA5C5C),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const StadiumBorder(),
                elevation: 0,
              ),
              child: const Text('Bắt Đầu Học',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACHIEVEMENTS SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  int? _selectedId;

  static const _achievements = [
    _AchievItem(
        id: 1, title: 'Bước Đầu Tiên', desc: 'Hoàn thành bài học đầu tiên',
        icon: '🎯', unlocked: true,
        gradStart: Color(0xFFFBEF76), gradEnd: Color(0xFFFEC288),
        date: '2 ngày trước', rarity: 'Thường'),
    _AchievItem(
        id: 2, title: 'Chiến Binh Tuần', desc: 'Duy trì chuỗi 7 ngày',
        icon: '🔥', unlocked: true,
        gradStart: Color(0xFFFA5C5C), gradEnd: Color(0xFFFD8A6B),
        date: '1 ngày trước', rarity: 'Hiếm'),
    _AchievItem(
        id: 3, title: 'Điểm Tuyệt Đối', desc: 'Đạt 100% trong bất kỳ bài học',
        icon: '⭐', unlocked: true,
        gradStart: Color(0xFFFEC288), gradEnd: Color(0xFFFBEF76),
        date: '3 ngày trước', rarity: 'Thường'),
    _AchievItem(
        id: 4, title: 'Học Viên Nhanh', desc: 'Hoàn thành 5 bài học trong ngày',
        icon: '⚡', unlocked: true,
        gradStart: Color(0xFFFD8A6B), gradEnd: Color(0xFFFA5C5C),
        date: '5 ngày trước', rarity: 'Hiếm'),
    _AchievItem(
        id: 5, title: 'Bậc Thầy Từ Vựng', desc: 'Học 100 từ mới',
        icon: '📚', unlocked: false,
        gradStart: Color(0xFFD1D5DB), gradEnd: Color(0xFF9CA3AF),
        progress: 65, rarity: 'Sử Thi'),
    _AchievItem(
        id: 6, title: 'Cánh Bướm Xã Hội', desc: 'Thêm 5 bạn bè',
        icon: '👥', unlocked: false,
        gradStart: Color(0xFFD1D5DB), gradEnd: Color(0xFF9CA3AF),
        progress: 3, total: 5, rarity: 'Thường'),
    _AchievItem(
        id: 7, title: 'Người Chạy Marathon', desc: 'Chuỗi 30 ngày',
        icon: '🏃', unlocked: false,
        gradStart: Color(0xFFD1D5DB), gradEnd: Color(0xFF9CA3AF),
        progress: 15, total: 30, rarity: 'Sử Thi'),
    _AchievItem(
        id: 8, title: 'Nhà Vô Địch Quiz', desc: 'Vượt qua 20 bài kiểm tra',
        icon: '🎓', unlocked: false,
        gradStart: Color(0xFFD1D5DB), gradEnd: Color(0xFF9CA3AF),
        progress: 12, total: 20, rarity: 'Hiếm'),
    _AchievItem(
        id: 9, title: 'Chim Sớm', desc: 'Học trước 8 giờ sáng',
        icon: '🌅', unlocked: false,
        gradStart: Color(0xFFD1D5DB), gradEnd: Color(0xFF9CA3AF),
        rarity: 'Hiếm'),
    _AchievItem(
        id: 10, title: 'Cú Đêm', desc: 'Học sau 10 giờ tối',
        icon: '🦉', unlocked: false,
        gradStart: Color(0xFFD1D5DB), gradEnd: Color(0xFF9CA3AF),
        rarity: 'Hiếm'),
    _AchievItem(
        id: 11, title: 'Huyền Thoại', desc: 'Hoàn thành tất cả đơn vị',
        icon: '👑', unlocked: false,
        gradStart: Color(0xFFD1D5DB), gradEnd: Color(0xFF9CA3AF),
        progress: 1, total: 10, rarity: 'Huyền Thoại'),
    _AchievItem(
        id: 12, title: 'Chuyên Gia Phát Âm', desc: '90%+ trong 10 bài nói',
        icon: '🎤', unlocked: false,
        gradStart: Color(0xFFD1D5DB), gradEnd: Color(0xFF9CA3AF),
        progress: 4, total: 10, rarity: 'Sử Thi'),
  ];

  int get _unlockedCount =>
      _achievements.where((a) => a.unlocked).length;

  @override
  Widget build(BuildContext context) {
    final pct = _unlockedCount / _achievements.length;
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Stack(
        children: [
          Column(
            children: [
              // ── Header ──
              Container(
                color: Colors.white,
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 12,
                  bottom: 20,
                  left: 24,
                  right: 24,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => context.go('/home'),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(Icons.arrow_back_rounded,
                                size: 20, color: Color(0xFF374151)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Thành Tích',
                                  style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF111827))),
                              Text('Các cột mốc học tập của bạn',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF6B7280))),
                            ],
                          ),
                        ),
                        const Text('🏆', style: TextStyle(fontSize: 28)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Progress card
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFFFA5C5C), Color(0xFFFD8A6B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x40FA5C5C),
                              blurRadius: 16,
                              offset: Offset(0, 6))
                        ],
                      ),
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Tiến Độ Tổng',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white)),
                              Text(
                                '${(_unlockedCount / _achievements.length * 100).round()}%',
                                style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0, end: pct),
                            duration: const Duration(milliseconds: 1000),
                            curve: Curves.easeOut,
                            builder: (context, value, _) => ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: value,
                                minHeight: 10,
                                backgroundColor: Colors.white30,
                                valueColor:
                                    const AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '$_unlockedCount trong ${_achievements.length} thành tích đã mở khóa',
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Grid ──
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.72,
                        ),
                        itemCount: _achievements.length,
                        itemBuilder: (context, index) {
                          final a = _achievements[index];
                          return _AchievCard(
                            achievement: a,
                            onTap: a.unlocked
                                ? () => setState(() => _selectedId = a.id)
                                : null,
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      // Motivational CTA
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                              color: const Color(0xFFE5E7EB), width: 2),
                          boxShadow: const [
                            BoxShadow(
                                color: Color(0x0F000000), blurRadius: 8)
                          ],
                        ),
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            const Text('🎯',
                                style: TextStyle(fontSize: 44)),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const Text('Tiếp Tục Cố Gắng!',
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF111827))),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_achievements.length - _unlockedCount} thành tích nữa cần mở khóa',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF6B7280)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── Modal overlay ──
          if (_selectedId != null)
            _AchievModal(
              achievement: _achievements
                  .firstWhere((a) => a.id == _selectedId),
              onClose: () => setState(() => _selectedId = null),
            ),
        ],
      ),
    );
  }
}

// ── Achievement model ──
class _AchievItem {
  const _AchievItem({
    required this.id,
    required this.title,
    required this.desc,
    required this.icon,
    required this.unlocked,
    required this.gradStart,
    required this.gradEnd,
    required this.rarity,
    this.date,
    this.progress,
    this.total,
  });
  final int id;
  final String title, desc, icon, rarity;
  final bool unlocked;
  final Color gradStart, gradEnd;
  final String? date;
  final int? progress, total;
}

// ── Achievement card ──
class _AchievCard extends StatelessWidget {
  const _AchievCard({required this.achievement, this.onTap});
  final _AchievItem achievement;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final a = achievement;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: a.unlocked
              ? LinearGradient(
                  colors: [a.gradStart, a.gradEnd],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight)
              : null,
          color: a.unlocked ? null : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: a.unlocked
                    ? a.gradEnd.withValues(alpha: 0.3)
                    : const Color(0x0F000000),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Rarity badge
            Align(
              alignment: Alignment.topRight,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: a.unlocked
                      ? Colors.white24
                      : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  a.rarity,
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: a.unlocked
                          ? Colors.white
                          : const Color(0xFF6B7280)),
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Icon with lock overlay
            Stack(
              children: [
                Text(a.icon,
                    style: TextStyle(
                        fontSize: 42,
                        color: a.unlocked ? null : const Color(0x40000000))),
                if (!a.unlocked)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: const Color(0xFF9CA3AF).withValues(alpha: 0.85),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lock_rounded,
                          size: 13, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              a.title,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: a.unlocked ? Colors.white : const Color(0xFF6B7280)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              a.desc,
              style: TextStyle(
                  fontSize: 11,
                  color: a.unlocked
                      ? Colors.white70
                      : const Color(0xFF9CA3AF)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            // Progress bar (locked only)
            if (!a.unlocked && a.progress != null) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tiến độ',
                      style: TextStyle(
                          fontSize: 10, color: Color(0xFF9CA3AF))),
                  Text(
                    a.total != null
                        ? '${a.progress}/${a.total}'
                        : '${a.progress}%',
                    style: const TextStyle(
                        fontSize: 10, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: a.total != null
                      ? a.progress! / a.total!
                      : a.progress! / 100.0,
                  minHeight: 6,
                  backgroundColor: const Color(0xFFD1D5DB),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF9CA3AF)),
                ),
              ),
            ],
            // Unlock date
            if (a.unlocked && a.date != null) ...[
              const SizedBox(height: 8),
              Text(a.date!,
                  style: const TextStyle(
                      fontSize: 10, color: Colors.white60)),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Achievement detail modal ──
class _AchievModal extends StatelessWidget {
  const _AchievModal({required this.achievement, required this.onClose});
  final _AchievItem achievement;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final a = achievement;
    return GestureDetector(
      onTap: onClose,
      child: Container(
        color: Colors.black54,
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 32)
                ],
              ),
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [a.gradStart, a.gradEnd],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                            color: a.gradEnd.withValues(alpha: 0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8))
                      ],
                    ),
                    child: Center(
                        child: Text(a.icon,
                            style: const TextStyle(fontSize: 54))),
                  ),
                  const SizedBox(height: 16),
                  // Rarity badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(a.rarity,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6B7280))),
                  ),
                  const SizedBox(height: 12),
                  Text(a.title,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827)),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  Text(a.desc,
                      style: const TextStyle(
                          fontSize: 14, color: Color(0xFF6B7280)),
                      textAlign: TextAlign.center),
                  if (a.date != null) ...[
                    const SizedBox(height: 6),
                    Text('Mở khóa ${a.date}',
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF9CA3AF))),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onClose,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFA5C5C),
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: const StadiumBorder(),
                        elevation: 0,
                      ),
                      child: const Text('Đóng',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
