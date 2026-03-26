import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/providers/app_providers.dart';
import '../data/repositories/user_repository.dart';
import '../data/services/app_services.dart';

const Set<String> _detailRoutes = {
  '/notifications',
  '/settings',
  '/streak',
  '/achievements',
  '/lesson-intro',
  '/edit-profile',
  '/subscription',
  '/forgot-password',
  '/help',
};

void _openDetailAwareRoute(BuildContext context, String route) {
  if (_detailRoutes.contains(route)) {
    context.push(route);
    return;
  }
  context.go(route);
}

void _popOrGo(BuildContext context, String fallbackRoute) {
  final router = GoRouter.of(context);
  if (router.canPop()) {
    context.pop();
    return;
  }
  context.go(fallbackRoute);
}

class _SlideIn extends StatefulWidget {
  const _SlideIn({
    required this.child,
    this.delay = 0,
    this.dy = 30.0,
    this.dx = 0.0,
  });
  final Widget child;
  final int delay;
  final double dy;
  final double dx;

  @override
  State<_SlideIn> createState() => _SlideInState();
}

class _SlideInState extends State<_SlideIn>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _slide;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slide = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _opacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Opacity(
        opacity: _opacity.value,
        child: Transform.translate(
          offset: Offset(widget.dx * _slide.value, widget.dy * _slide.value),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressCtrl;
  late Animation<double> _levelProgress;
  late Animation<double> _goalProgress;

  int _level = 1;
  double _levelPct = 0.0;
  int _totalXp = 0;
  int _streak = 0;
  static const double _goalPct = 0.75;
  String _profileName = 'Bạn';
  int _savedWordCount = 0;
  int _completedLessonCount = 0;
  int _achievementCount = 0;

  List<_StatData> get _stats => [
    _StatData(
      label: 'Ngày Liên Tiếp',
      value: '$_streak',
      unit: 'ngày',
      icon: Icons.local_fire_department_rounded,
      color: Color(0xFFFA5C5C),
      route: '/streak',
    ),
    _StatData(
      label: 'Từ Đã Học',
      value: '$_savedWordCount',
      unit: 'từ',
      icon: Icons.menu_book_rounded,
      color: Color(0xFFFD8A6B),
      route: '/dictionary',
    ),
    _StatData(
      label: 'Bài Đã Học',
      value: '$_completedLessonCount',
      unit: 'bài',
      icon: Icons.access_time_rounded,
      color: Color(0xFFFEC288),
      route: '/course-map',
    ),
    _StatData(
      label: 'Thành Tích',
      value: '$_achievementCount',
      unit: 'huy hiệu',
      icon: Icons.emoji_events_rounded,
      color: Color(0xFFFBEF76),
      route: '/achievements',
    ),
  ];

  List<_AchievData> _achievements = [];

  @override
  void initState() {
    super.initState();
    _loadProfileSummary();
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _levelProgress = Tween<double>(begin: 0, end: _levelPct).animate(
      CurvedAnimation(
        parent: _progressCtrl,
        curve: const Interval(0.0, 1.0, curve: Curves.easeOut),
      ),
    );
    _goalProgress = Tween<double>(begin: 0, end: _goalPct).animate(
      CurvedAnimation(
        parent: _progressCtrl,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _progressCtrl.forward();
    });
  }

  Future<void> _loadProfileSummary() async {
    try {
      final user = await AppServices.userRepository.getActiveUser();
      final savedWordCount = await AppServices.dictionaryRepository
          .countSavedWords();
      int streak = 0;
      int totalXp = 0;
      int completedLessons = 0;
      int longestStreak = 0;
      if (user != null && user.id != null) {
        streak = await AppServices.learningRepository.getCurrentStreak(
          user.id!,
        );
        totalXp = await AppServices.learningRepository.getTotalXp(user.id!);
        longestStreak = await AppServices.learningRepository.getLongestStreak(user.id!);
        final completedIds = await AppServices.learningRepository.getCompletedLessonIds(user.id!);
        completedLessons = completedIds.length;
      }
      if (!mounted) return;
      final xpPerLevel = 500;
      final level = (totalXp ~/ xpPerLevel) + 1;
      final xpInLevel = totalXp % xpPerLevel;
      final pct = xpInLevel / xpPerLevel;

      // Compute achievements
      final maxStreak = longestStreak > streak ? longestStreak : streak;
      final achievList = <_AchievData>[];
      if (completedLessons >= 1) achievList.add(const _AchievData(title: 'Bước Đầu Tiên', desc: 'Hoàn thành bài học đầu tiên', emoji: '🎯'));
      if (maxStreak >= 7) achievList.add(const _AchievData(title: 'Chiến Binh Tuần', desc: 'Chuỗi 7 ngày', emoji: '🔥'));
      if (savedWordCount >= 10) achievList.add(const _AchievData(title: 'Người Sưu Tầm', desc: 'Lưu 10 từ vào từ điển', emoji: '📚'));
      if (completedLessons >= 5) achievList.add(const _AchievData(title: 'Học Viên Chăm Chỉ', desc: 'Hoàn thành 5 bài học', emoji: '⚡'));
      if (totalXp >= 500) achievList.add(const _AchievData(title: 'Nhà Vô Địch XP', desc: 'Đạt 500 XP', emoji: '⭐'));
      if (completedLessons >= 12) achievList.add(const _AchievData(title: 'Huyền Thoại', desc: 'Hoàn thành tất cả bài học', emoji: '👑'));

      int achCount = 0;
      if (completedLessons >= 1) achCount++;
      if (maxStreak >= 7) achCount++;
      if (savedWordCount >= 10) achCount++;
      if (completedLessons >= 5) achCount++;
      if (savedWordCount >= 50) achCount++;
      if (totalXp >= 500) achCount++;
      if (maxStreak >= 30) achCount++;
      if (completedLessons >= 10) achCount++;
      if (totalXp >= 1000) achCount++;
      if (completedLessons >= 6) achCount++;
      if (completedLessons >= 12) achCount++;
      if (maxStreak >= 14) achCount++;

      setState(() {
        if (user != null) {
          _profileName = user.displayName;
        }
        _savedWordCount = savedWordCount;
        _streak = streak;
        _totalXp = totalXp;
        _level = level;
        _levelPct = pct;
        _completedLessonCount = completedLessons;
        _achievementCount = achCount;
        _achievements = achievList.length > 3 ? achievList.sublist(0, 3) : achievList;
      });
      // Re-animate progress bars with real values
      _levelProgress = Tween<double>(begin: 0, end: _levelPct).animate(
        CurvedAnimation(
          parent: _progressCtrl,
          curve: const Interval(0.0, 1.0, curve: Curves.easeOut),
        ),
      );
      _progressCtrl.forward(from: 0);
    } catch (_) {
      // Keep default values if loading fails.
    }
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Hero header ──
            _SlideIn(
              delay: 0,
              dy: -20,
              child: _ProfileHeader(
                level: _level,
                progressAnim: _levelProgress,
                progressCtrl: _progressCtrl,
                displayName: _profileName,
                totalXp: _totalXp,
              ),
            ),

            // ── Streak banner ──
            _SlideIn(
              delay: 200,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Transform.translate(
                  offset: const Offset(0, -36),
                  child: GestureDetector(
                    onTap: () => context.push('/streak'),
                    child: _StreakBanner(streak: _streak),
                  ),
                ),
              ),
            ),

            // ── Stats ──
            _SlideIn(
              delay: 300,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Thống Kê Học Tập',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.05,
                      children: _stats.map((s) => _StatCard(stat: s)).toList(),
                    ),
                  ],
                ),
              ),
            ),

            // ── Daily goal ──
            _SlideIn(
              delay: 500,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0F000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Mục Tiêu Hàng Ngày',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                          Text(
                            '${(_goalPct * 100).toInt()}%',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFFA5C5C),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      AnimatedBuilder(
                        animation: _goalProgress,
                        builder: (context, _) => ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: _goalProgress.value,
                            minHeight: 12,
                            backgroundColor: const Color(0xFFF3F4F6),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFFFA5C5C),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '15 trong 20 phút đã hoàn thành hôm nay',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Achievements ──
            _SlideIn(
              delay: 600,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Thành Tích Gần Đây',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => context.push('/achievements'),
                          child: Row(
                            children: const [
                              Text(
                                'Xem Tất Cả',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFFFA5C5C),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: 2),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 16,
                                color: Color(0xFFFA5C5C),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ..._achievements.asMap().entries.map(
                      (e) => _SlideIn(
                        delay: 700 + e.key * 100,
                        dx: -20,
                        dy: 0,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _AchievCard(data: e.value),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Bottom buttons ──
            _SlideIn(
              delay: 800,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: Column(
                  children: [
                    _OutlineBtn(
                      label: 'Chỉnh Sửa Hồ Sơ',
                      onTap: () => context.push('/edit-profile'),
                    ),
                    const SizedBox(height: 10),
                    _GradientBtn(
                      label: '👑  Nâng Cấp Premium',
                      onTap: () => context.push('/subscription'),
                    ),
                    const SizedBox(height: 10),
                    _SolidBtn(
                      label: 'Đi Tới Cài Đặt',
                      onTap: () => context.push('/settings'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Profile header widget ──
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.level,
    required this.progressAnim,
    required this.progressCtrl,
    required this.displayName,
    required this.totalXp,
  });
  final int level;
  final Animation<double> progressAnim;
  final AnimationController progressCtrl;
  final String displayName;
  final int totalXp;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFA5C5C), Color(0xFFFD8A6B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 72,
        left: 24,
        right: 24,
      ),
      child: Stack(
        children: [
          // Deco circles
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: -10,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            children: [
              // Top bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Hồ Sơ Của Tôi',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.push('/settings'),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.settings_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Avatar + info
              Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      GestureDetector(
                        onTap: () => context.push('/edit-profile'),
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x30000000),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text('👤', style: TextStyle(fontSize: 44)),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -4,
                        right: -4,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFBEF76),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x30000000),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.edit_rounded,
                            size: 14,
                            color: Color(0xFF374151),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Học viên Trung Cấp',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFFBEF76),
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Cấp độ $level',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Level progress
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Tiến độ đến Cấp độ ${level + 1}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        AnimatedBuilder(
                          animation: progressAnim,
                          builder: (context, _) => Text(
                            '${(progressAnim.value * 100).toInt()}%',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    AnimatedBuilder(
                      animation: progressAnim,
                      builder: (context, _) => ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progressAnim.value,
                          minHeight: 10,
                          backgroundColor: Colors.white.withValues(alpha: 0.3),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${totalXp % 500} / 500 XP',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Streak banner ──
class _StreakBanner extends StatelessWidget {
  const _StreakBanner({required this.streak});
  final int streak;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFBEF76), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFA5C5C), Color(0xFFFD8A6B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.local_fire_department_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chuỗi $streak Ngày!',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Cố lên! Đừng phá vỡ chuỗi 🔥',
                  style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          Text(
            '$streak',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFA5C5C),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stat data model ──
class _StatData {
  const _StatData({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    required this.route,
  });
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final String? route;
}

// ── Stat card ──
class _StatCard extends StatelessWidget {
  const _StatCard({required this.stat});
  final _StatData stat;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (stat.route != null) _openDetailAwareRoute(context, stat.route!);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: stat.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(stat.icon, color: stat.color, size: 20),
            ),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                stat.value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              stat.unit,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),  
      ),
    );
  }
}

// ── Achievement data model ──
class _AchievData {
  const _AchievData({
    required this.title,
    required this.desc,
    required this.emoji,
  });
  final String title;
  final String desc;
  final String emoji;
}

// ── Achievement card ──
class _AchievCard extends StatelessWidget {
  const _AchievCard({required this.data});
  final _AchievData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFBEF76), Color(0xFFFEC288)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(data.emoji, style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.desc,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 20),
        ],
      ),
    );
  }
}

// ── Button helpers ──
class _OutlineBtn extends StatelessWidget {
  const _OutlineBtn({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: const StadiumBorder(),
          side: const BorderSide(color: Color(0xFFE5E7EB), width: 2),
          backgroundColor: Colors.white,
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
      ),
    );
  }
}

class _GradientBtn extends StatelessWidget {
  const _GradientBtn({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFBEF76), Color(0xFFFEC288)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(50),
          boxShadow: const [
            BoxShadow(
              color: Color(0x30FEC288),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFF111827),
          ),
        ),
      ),
    );
  }
}

class _SolidBtn extends StatelessWidget {
  const _SolidBtn({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: const StadiumBorder(),
          backgroundColor: const Color(0xFFFA5C5C),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EDIT PROFILE SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameCtrl = TextEditingController(text: 'Sarah Chen');
  final _emailCtrl = TextEditingController(text: 'sarah.chen@example.com');
  final _bioCtrl = TextEditingController(text: 'Passionate English learner 📚');
  final _locationCtrl = TextEditingController(text: 'San Francisco, CA');
  String _birthdate = '1995-03-15';
  int? _activeUserId;
  bool _isSaving = false;
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _loadActiveUser();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _bioCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadActiveUser() async {
    try {
      final user = await AppServices.userRepository.getActiveUser();
      if (!mounted || user == null) return;
      setState(() {
        _activeUserId = user.id;
        _nameCtrl.text = user.fullName;
        _emailCtrl.text = user.email;
        _bioCtrl.text = user.bio;
        _locationCtrl.text = user.location;
        _birthdate = user.birthDate.isEmpty ? _birthdate : user.birthDate;
      });
    } catch (_) {
      // Keep fallback values if loading fails.
    } finally {
      if (mounted) {
        setState(() => _isLoadingUser = false);
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_birthdate) ?? DateTime(1995, 3, 15),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFFFA5C5C),
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _birthdate =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_activeUserId == null) {
      _showSnackBar('Không tìm thấy tài khoản đang đăng nhập.');
      return;
    }
    if (_nameCtrl.text.trim().isEmpty || _emailCtrl.text.trim().isEmpty) {
      _showSnackBar('Họ tên và email không được để trống.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await AppServices.userRepository.updateProfile(
        userId: _activeUserId!,
        fullName: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        bio: _bioCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
        birthDate: _birthdate.trim(),
      );
      if (!mounted) return;
      _popOrGo(context, '/profile');
    } on UserRepositoryException catch (e) {
      if (!mounted) return;
      _showSnackBar(e.message);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Không thể lưu hồ sơ, vui lòng thử lại.');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _deleteAccount() async {
    // Bước 1: Hỏi xác nhận.
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa tài khoản'),
        content: const Text(
          'Tài khoản và toàn bộ dữ liệu sẽ bị xóa vĩnh viễn. '
          'Hành động này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Xóa vĩnh viễn',
              style: TextStyle(color: Color(0xFFDC2626)),
            ),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !mounted) return;

    // Bước 2: Yêu cầu nhập mật khẩu để xác thực lại.
    final password = await _askPasswordForReauth();
    if (password == null || password.isEmpty || !mounted) return;

    try {
      // Xác thực lại với Firebase trước khi xóa.
      await AppServices.userRepository.reauthenticate(password);

      if (_activeUserId != null) {
        await AppServices.userRepository.deleteUser(_activeUserId!);
      }
      await AppServices.routeStateService.clear();
      if (!mounted) return;
      context.go('/login');
    } on UserRepositoryException catch (e) {
      if (!mounted) return;
      _showSnackBar(e.message);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Không thể xóa tài khoản lúc này.');
    }
  }

  Future<String?> _askPasswordForReauth() {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác thực lại'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Nhập mật khẩu hiện tại để tiếp tục xóa tài khoản.'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'Mật khẩu',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
            child: const Text(
              'Xác nhận',
              style: TextStyle(color: Color(0xFFDC2626)),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFFA5C5C),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          // ── Sticky header ──
          _SlideIn(
            dy: -20,
            child: Container(
              color: Colors.white,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                bottom: 12,
                left: 16,
                right: 16,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => _popOrGo(context, '/profile'),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Color(0xFF374151),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Chỉnh Sửa Hồ Sơ',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),

          // ── Scrollable content ──
          Expanded(
            child: _isLoadingUser
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // Avatar
                        _SlideIn(
                          delay: 100,
                          child: Column(
                            children: [
                              Stack(
                                children: [
                                  Container(
                                    width: 110,
                                    height: 110,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFFA5C5C),
                                          Color(0xFFFD8A6B),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      shape: BoxShape.circle,
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x40FA5C5C),
                                          blurRadius: 16,
                                          offset: Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: Text(
                                        '👤',
                                        style: TextStyle(fontSize: 54),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFBEF76),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 3,
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x20000000),
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt_rounded,
                                        size: 18,
                                        color: Color(0xFF374151),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Nhấn để đổi ảnh',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF9CA3AF),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Form fields
                        _SlideIn(
                          delay: 200,
                          child: Column(
                            children: [
                              _EditField(
                                label: 'Họ Tên',
                                icon: Icons.person_outline_rounded,
                                controller: _nameCtrl,
                              ),
                              const SizedBox(height: 16),
                              _EditField(
                                label: 'Email',
                                icon: Icons.mail_outline_rounded,
                                controller: _emailCtrl,
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 16),
                              _EditMultilineField(
                                label: 'Bio',
                                controller: _bioCtrl,
                              ),
                              const SizedBox(height: 16),
                              _EditField(
                                label: 'Địa Điểm',
                                icon: Icons.location_on_outlined,
                                controller: _locationCtrl,
                              ),
                              const SizedBox(height: 16),
                              _DateField(
                                label: 'Ngày Sinh',
                                value: _birthdate,
                                onTap: _pickDate,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Action buttons
                        _SlideIn(
                          delay: 300,
                          child: Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isSaving ? null : _saveProfile,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: const StadiumBorder(),
                                    backgroundColor: const Color(0xFFFA5C5C),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                  ),
                                  child: _isSaving
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        )
                                      : const Text(
                                          'Lưu Thay Đổi',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: () =>
                                      _popOrGo(context, '/profile'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: const StadiumBorder(),
                                    side: const BorderSide(
                                      color: Color(0xFFE5E7EB),
                                      width: 2,
                                    ),
                                  ),
                                  child: const Text(
                                    'Hủy',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF374151),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),
                        const Divider(color: Color(0xFFE5E7EB)),
                        const SizedBox(height: 20),

                        // Account actions
                        _SlideIn(
                          delay: 400,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Tùy Chọn Tài Khoản',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _AccountActionBtn(
                                label: 'Đổi Mật Khẩu',
                                danger: false,
                                onTap: () {},
                              ),
                              const SizedBox(height: 10),
                              _AccountActionBtn(
                                label: 'Xóa Tài Khoản',
                                danger: true,
                                onTap: _deleteAccount,
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
    );
  }
}

class _EditField extends StatelessWidget {
  const _EditField({
    required this.label,
    required this.icon,
    required this.controller,
    this.keyboardType,
  });
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFF9CA3AF), size: 20),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFFA5C5C), width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _EditMultilineField extends StatelessWidget {
  const _EditMultilineField({required this.label, required this.controller});
  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Giới thiệu bản thân...',
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.all(16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFFA5C5C), width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_month_outlined,
                  color: Color(0xFF9CA3AF),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AccountActionBtn extends StatelessWidget {
  const _AccountActionBtn({
    required this.label,
    required this.danger,
    required this.onTap,
  });
  final String label;
  final bool danger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: danger ? const Color(0xFFFECACA) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: danger ? const Color(0xFFDC2626) : const Color(0xFF374151),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SETTINGS SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notifications = true;
  bool _sound = true;
  bool _darkMode = false;
  bool _isLoading = true;
  int? _activeUserId;
  String _displayName = 'Sarah Chen';
  String _displayEmail = 'sarah.chen@example.com';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final user = await AppServices.userRepository.getActiveUser();
      if (!mounted || user == null) return;
      setState(() {
        _activeUserId = user.id;
        _displayName = user.fullName;
        _displayEmail = user.email;
        _notifications = user.notificationsEnabled;
        _sound = user.soundEnabled;
        _darkMode = user.darkModeEnabled;
      });
    } catch (_) {
      // Keep defaults if loading fails.
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _persistSettings() async {
    if (_activeUserId == null) return;
    try {
      await AppServices.userRepository.updatePreferences(
        userId: _activeUserId!,
        notificationsEnabled: _notifications,
        soundEnabled: _sound,
        darkModeEnabled: _darkMode,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể lưu cài đặt, vui lòng thử lại.'),
          backgroundColor: Color(0xFFFA5C5C),
        ),
      );
    }
  }

  void _showLanguageDialog() {
    final currentLocale = ref.read(localeNotifierProvider);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chọn ngôn ngữ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LangOption(
              label: 'Tiếng Việt',
              selected: currentLocale.languageCode == 'vi',
              onTap: () {
                ref
                    .read(localeNotifierProvider.notifier)
                    .setLocale(const Locale('vi'));
                Navigator.of(ctx).pop();
              },
            ),
            _LangOption(
              label: 'English',
              selected: currentLocale.languageCode == 'en',
              onTap: () {
                ref
                    .read(localeNotifierProvider.notifier)
                    .setLocale(const Locale('en'));
                Navigator.of(ctx).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = [
      _SettingsGroup(
        title: 'Tài Khoản',
        items: [
          _SettingsItem(
            icon: Icons.person_outline_rounded,
            label: 'Chỉnh Sửa Hồ Sơ',
            desc: 'Cập nhật thông tin cá nhân',
            type: _ItemType.navigate,
            onTap: () => context.push('/edit-profile'),
          ),
          _SettingsItem(
            icon: Icons.smartphone_rounded,
            label: 'Gói Premium',
            desc: 'Nâng cấp để mở khóa tất cả tính năng',
            type: _ItemType.navigate,
            onTap: () => context.push('/subscription'),
          ),
          _SettingsItem(
            icon: Icons.lock_outline_rounded,
            label: 'Đổi Mật Khẩu',
            desc: 'Cập nhật thông tin bảo mật',
            type: _ItemType.navigate,
            onTap: () => context.push('/forgot-password'),
          ),
          _SettingsItem(
            icon: Icons.shield_outlined,
            label: 'Quyền Riêng Tư',
            desc: 'Quản lý cài đặt quyền riêng tư',
            type: _ItemType.navigate,
            onTap: () {},
          ),
        ],
      ),
      _SettingsGroup(
        title: 'Tùy Chọn',
        items: [
          _SettingsItem(
            icon: Icons.language_rounded,
            label: 'Ngôn Ngữ',
            desc: ref.watch(localeNotifierProvider).languageCode == 'vi'
                ? 'Tiếng Việt'
                : 'English',
            type: _ItemType.navigate,
            onTap: _showLanguageDialog,
          ),
          _SettingsItem(
            icon: Icons.volume_up_rounded,
            label: 'Âm Thanh',
            desc: 'Hiệu ứng âm thanh và giọng nói',
            type: _ItemType.toggle,
            toggleValue: _sound,
            onTap: () {
              setState(() => _sound = !_sound);
              _persistSettings();
            },
          ),
          _SettingsItem(
            icon: Icons.notifications_outlined,
            label: 'Thông Báo',
            desc: 'Nhắc nhở hàng ngày và cập nhật',
            type: _ItemType.toggle,
            toggleValue: _notifications,
            onTap: () {
              setState(() => _notifications = !_notifications);
              _persistSettings();
            },
          ),
          _SettingsItem(
            icon: Icons.dark_mode_outlined,
            label: 'Chế Độ Tối',
            desc: 'Chuyển sang giao diện tối',
            type: _ItemType.toggle,
            toggleValue: _darkMode,
            onTap: () {
              final newDark = !_darkMode;
              setState(() => _darkMode = newDark);
              ref.read(themeNotifierProvider.notifier).setDark(newDark);
              _persistSettings();
            },
          ),
        ],
      ),
      _SettingsGroup(
        title: 'Hỗ Trợ',
        items: [
          _SettingsItem(
            icon: Icons.help_outline_rounded,
            label: 'Trợ Giúp & Hỗ Trợ',
            desc: 'Câu hỏi thường gặp và liên hệ',
            type: _ItemType.navigate,
            onTap: () => context.push('/help'),
          ),
          _SettingsItem(
            icon: Icons.info_outline_rounded,
            label: 'Giới Thiệu',
            desc: 'Phiên bản ứng dụng và thông tin',
            type: _ItemType.navigate,
            onTap: () {},
          ),
        ],
      ),
    ];

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // ── Header ──
          _SlideIn(
            dy: -20,
            child: Container(
              color: cs.surface,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                bottom: 12,
                left: 8,
                right: 16,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => _popOrGo(context, '/profile'),
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: cs.onSurface,
                    ),
                  ),
                  Text(
                    'Cài Đặt',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),

                        // ── Profile summary ──
                        _SlideIn(
                          delay: 100,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFA5C5C), Color(0xFFFD8A6B)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x30FA5C5C),
                                  blurRadius: 16,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x20000000),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Text(
                                      '👤',
                                      style: TextStyle(fontSize: 30),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _displayName,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _displayEmail,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.white.withValues(
                                          alpha: 0.8,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ── Groups ──
                        ...groups.asMap().entries.map(
                          (e) => _SlideIn(
                            delay: 200 + e.key * 100,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 24),
                              child: _SettingsGroupWidget(group: e.value),
                            ),
                          ),
                        ),

                        // ── Logout ──
                        _SlideIn(
                          delay: 500,
                          child: GestureDetector(
                            onTap: () async {
                              try {
                                await AppServices.userRepository
                                    .logoutActiveUser();
                                await AppServices.routeStateService.clear();
                              } catch (_) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Đăng xuất thất bại.'),
                                    backgroundColor: Color(0xFFFA5C5C),
                                  ),
                                );
                                return;
                              }
                              if (!context.mounted) return;
                              context.go('/login');
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: cs.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFFECACA),
                                  width: 2,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x0F000000),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(
                                    Icons.logout_rounded,
                                    color: Color(0xFFDC2626),
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Đăng Xuất',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFDC2626),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // ── Version ──
                        _SlideIn(
                          delay: 600,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Column(
                              children: [
                                Text(
                                  'LinguaJoy v1.0.0',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: cs.onSurface.withValues(alpha: 0.4),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '© 2026 All rights reserved',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurface.withValues(alpha: 0.25),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Settings models ──
enum _ItemType { navigate, toggle }

// Simple language option tile used inside the language picker dialog.
class _LangOption extends StatelessWidget {
  const _LangOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      trailing: selected
          ? const Icon(Icons.check_rounded, color: Color(0xFFFA5C5C))
          : null,
      onTap: onTap,
    );
  }
}

class _SettingsItem {
  const _SettingsItem({
    required this.icon,
    required this.label,
    required this.desc,
    required this.type,
    required this.onTap,
    this.toggleValue,
  });
  final IconData icon;
  final String label;
  final String desc;
  final _ItemType type;
  final VoidCallback onTap;
  final bool? toggleValue;
}

class _SettingsGroup {
  const _SettingsGroup({required this.title, required this.items});
  final String title;
  final List<_SettingsItem> items;
}

class _SettingsGroupWidget extends StatelessWidget {
  const _SettingsGroupWidget({required this.group});
  final _SettingsGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            group.title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: cs.onSurface.withValues(alpha: 0.4),
              letterSpacing: 1.0,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: cs.shadow.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: group.items.asMap().entries.map((e) {
              final item = e.value;
              final isFirst = e.key == 0;
              final isLast = e.key == group.items.length - 1;
              return Column(
                children: [
                  if (!isFirst)
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: cs.outlineVariant.withValues(alpha: 0.3),
                      indent: 56,
                    ),
                  ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: isFirst
                          ? const Radius.circular(16)
                          : Radius.zero,
                      topRight: isFirst
                          ? const Radius.circular(16)
                          : Radius.zero,
                      bottomLeft: isLast
                          ? const Radius.circular(16)
                          : Radius.zero,
                      bottomRight: isLast
                          ? const Radius.circular(16)
                          : Radius.zero,
                    ),
                    child: InkWell(
                      onTap: item.onTap,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: cs.onSurface.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                item.icon,
                                color: cs.onSurface.withValues(alpha: 0.5),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.label,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    item.desc,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: cs.onSurface.withValues(alpha: 0.4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (item.type == _ItemType.toggle)
                              _Toggle(value: item.toggleValue ?? false)
                            else
                              Icon(
                                Icons.chevron_right_rounded,
                                color: cs.onSurface.withValues(alpha: 0.25),
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.value});
  final bool value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 46,
      height: 26,
      decoration: BoxDecoration(
        color: value ? const Color(0xFFFA5C5C) : cs.onSurface.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(13),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 20,
          height: 20,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x30000000),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
