import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/services/app_services.dart';
import '../data/services/achievement_service.dart';
import '../data/services/leaderboard_service.dart';

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
  bool _loading = true;

  List<_PodiumUser> _topThree = [];
  List<_RankUser> _otherUsers = [];

  // User's own standing
  int _myRank = 0;
  int _myXp = 0;
  int _myStreak = 0;
  String _myAvatar = '👤';
  String _myName = 'Bạn';

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    final user = await AppServices.userRepository.getActiveUser();
    if (user != null && user.id != null) {
      await AppServices.syncGamificationForUser(user.id!);
    }

    var entries = await AppServices.leaderboardService.fetchTopUsers(limit: 20);

    if (entries.length < 3) {
      final demo = <LeaderboardEntry>[
        LeaderboardEntry(
          userId: -1,
          displayName: 'Emma Wilson',
          avatarEmoji: '👩',
          totalXp: 1450,
          currentStreak: 12,
          achievementsUnlocked: 7,
          updatedAt: DateTime.now(),
        ),
        LeaderboardEntry(
          userId: -2,
          displayName: 'Alex Kim',
          avatarEmoji: '👨',
          totalXp: 1320,
          currentStreak: 8,
          achievementsUnlocked: 6,
          updatedAt: DateTime.now(),
        ),
        LeaderboardEntry(
          userId: -3,
          displayName: 'Maria Garcia',
          avatarEmoji: '👩',
          totalXp: 1050,
          currentStreak: 10,
          achievementsUnlocked: 5,
          updatedAt: DateTime.now(),
        ),
      ];
      entries = [...entries, ...demo];
    }

    // Ensure the current user is always present (may sit outside top-20).
    if (user != null && user.id != null) {
      final alreadyIn = entries.any((e) => e.userId == user.id);
      if (!alreadyIn) {
        final totalXp =
            await AppServices.learningRepository.getTotalXp(user.id!);
        final streak =
            await AppServices.learningRepository.getCurrentStreak(user.id!);
        entries.add(LeaderboardEntry(
          userId: user.id!,
          displayName: user.displayName,
          avatarEmoji: user.avatarEmoji,
          totalXp: totalXp,
          currentStreak: streak,
          achievementsUnlocked: 0,
          updatedAt: DateTime.now(),
        ));
      }
    }

    entries.sort((a, b) => b.totalXp.compareTo(a.totalXp));

    // Calculate user's rank from the full sorted list.
    int myRank = 0;
    int myXp = 0;
    int myStreak = 0;
    final String myAvatar = user?.avatarEmoji ?? '👤';
    final String myName = user?.displayName ?? 'Bạn';
    if (user != null) {
      final myIndex = entries.indexWhere((e) => e.userId == user.id);
      if (myIndex >= 0) {
        myRank = myIndex + 1;
        myXp = entries[myIndex].totalXp;
        myStreak = entries[myIndex].currentStreak;
      }
    }

    // Top 3 for podium (order: 2nd, 1st, 3rd)
    final podium = <_PodiumUser>[];
    if (entries.length >= 3) {
      podium.add(_PodiumUser(rank: 2, name: entries[1].displayName, avatar: entries[1].avatarEmoji, points: entries[1].totalXp, streak: entries[1].currentStreak, isCurrentUser: user?.id == entries[1].userId));
      podium.add(_PodiumUser(rank: 1, name: entries[0].displayName, avatar: entries[0].avatarEmoji, points: entries[0].totalXp, streak: entries[0].currentStreak, isCurrentUser: user?.id == entries[0].userId));
      podium.add(_PodiumUser(rank: 3, name: entries[2].displayName, avatar: entries[2].avatarEmoji, points: entries[2].totalXp, streak: entries[2].currentStreak, isCurrentUser: user?.id == entries[2].userId));
    }

    final others = <_RankUser>[];
    for (int i = 3; i < entries.length; i++) {
      final u = entries[i];
      final isMe = user?.id == u.userId;
      others.add(_RankUser(rank: i + 1, name: isMe ? 'Bạn' : u.displayName, avatar: u.avatarEmoji, points: u.totalXp, streak: u.currentStreak, isCurrentUser: isMe));
    }

    if (!mounted) return;
    setState(() {
      _topThree = podium;
      _otherUsers = others;
      _myRank = myRank;
      _myXp = myXp;
      _myStreak = myStreak;
      _myAvatar = myAvatar;
      _myName = myName;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF3F4F6),
        body: Center(child: CircularProgressIndicator()),
      );
    }
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
                  // My rank banner – always visible, highlighted in red.
                  if (_myRank > 0) ...[  
                    _MyRankBanner(
                      rank: _myRank,
                      xp: _myXp,
                      streak: _myStreak,
                      avatar: _myAvatar,
                      name: _myName,
                    ),
                    const SizedBox(height: 16),
                  ],
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
      height: 360,
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

// ── My rank banner ──
class _MyRankBanner extends StatelessWidget {
  const _MyRankBanner({
    required this.rank,
    required this.xp,
    required this.streak,
    required this.avatar,
    required this.name,
  });
  final int rank, xp, streak;
  final String avatar, name;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFA5C5C), Color(0xFFFD8A6B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
              color: Color(0x40FA5C5C), blurRadius: 12, offset: Offset(0, 4))
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          // Rank badge
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
                color: Colors.white24, shape: BoxShape.circle),
            child: Center(
                child: Text(avatar, style: const TextStyle(fontSize: 24))),
          ),
          const SizedBox(width: 10),
          // Name + streak
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('🔥 $streak ngày',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.white70)),
              ],
            ),
          ),
          // XP
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  const Text('⭐', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 2),
                  Text('$xp',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ],
              ),
              const Text('XP của bạn',
                  style: TextStyle(fontSize: 11, color: Colors.white70)),
            ],
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
  List<_AchievItem> _achievements = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAchievements();
  }

  Future<void> _loadAchievements() async {
    final user = await AppServices.userRepository.getActiveUser();
    final items = <_AchievItem>[];
    if (user != null && user.id != null) {
      final repo = AppServices.learningRepository;
      final completedIds = await repo.getCompletedLessonIds(user.id!);
      final streak = await repo.getCurrentStreak(user.id!);
      final longestStreak = await repo.getLongestStreak(user.id!);
      final totalXp = await repo.getTotalXp(user.id!);
      final savedWords = await AppServices.dictionaryRepository.countSavedWords();

      final sync = await AppServices.achievementService.syncAchievements(
        userId: user.id!,
        stats: UserLearningStats(
          completedLessons: completedIds.length,
          currentStreak: streak,
          longestStreak: longestStreak,
          savedWords: savedWords,
          totalXp: totalXp,
        ),
      );

      for (final progress in sync.allProgress) {
        items.add(
          _AchievItem(
            id: progress.definition.id,
            title: progress.definition.title,
            desc: progress.definition.description,
            icon: progress.definition.icon,
            unlocked: progress.unlocked,
            gradStart: const Color(0xFFD1D5DB),
            gradEnd: const Color(0xFF9CA3AF),
            rarity: _rarityFor(progress.definition.target),
            date: progress.unlocked ? 'Vừa mở khóa' : null,
            progress: progress.progress,
            total: progress.definition.target,
          ),
        );
      }
    }

    // Set colors for unlocked items
    for (int i = 0; i < items.length; i++) {
      if (items[i].unlocked) {
        final colors = [
          [const Color(0xFFFBEF76), const Color(0xFFFEC288)],
          [const Color(0xFFFA5C5C), const Color(0xFFFD8A6B)],
          [const Color(0xFFFEC288), const Color(0xFFFBEF76)],
          [const Color(0xFFFD8A6B), const Color(0xFFFA5C5C)],
        ];
        final c = colors[i % colors.length];
        items[i] = _AchievItem(
          id: items[i].id, title: items[i].title, desc: items[i].desc,
          icon: items[i].icon, unlocked: true,
          gradStart: c[0], gradEnd: c[1],
          rarity: items[i].rarity, progress: items[i].progress, total: items[i].total,
        );
      }
    }

    if (!mounted) return;
    setState(() {
      _achievements = items;
      _loading = false;
    });
  }

  String _rarityFor(int target) {
    if (target >= 30 || target >= 1000) return 'Sử Thi';
    if (target >= 10) return 'Hiếm';
    return 'Thường';
  }

  int get _unlockedCount =>
      _achievements.where((a) => a.unlocked).length;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF3F4F6),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final pct = _achievements.isEmpty ? 0.0 : _unlockedCount / _achievements.length;
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
