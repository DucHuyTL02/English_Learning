import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/services/app_services.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _Header(),
            _StatsBanner(),
            _NextLessonCard(),
            _LearningPathMap(),
            _QuickActions(),
            // Padding để nội dung không bị che bởi bottom navigation overlay
            const SizedBox(height: 88),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------------------
// Header
// ------------------------------------------------------------------------------
class _Header extends StatefulWidget {
  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  int _notificationCount = 0;
  String _displayName = 'Bạn';

  @override
  void initState() {
    super.initState();
    _loadActiveUser();
  }

  Future<void> _loadActiveUser() async {
    final user = await AppServices.userRepository.getActiveUser();
    if (!mounted || user == null) return;
    await AppServices.notificationService.maybeSendDailyStudyReminder(
      user: user,
    );
    final unread = user.id == null
        ? 0
        : await AppServices.notificationService.getUnreadCount(user.id!);
    if (!mounted) return;
    setState(() {
      _displayName = user.displayName;
      _notificationCount = unread;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 16,
        left: 16,
        right: 16,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Xin chào, $_displayName! 👋',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Sẵn sàng học hôm nay chưa?',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () async {
                  await context.push('/notifications');
                  if (!mounted) return;
                  await _loadActiveUser();
                },
                child: _NotificationIconBtn(count: _notificationCount),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => context.go('/profile'),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFA5C5C), Color(0xFFFD8A6B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(21),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33FA5C5C),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('👤', style: TextStyle(fontSize: 20)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => context.push('/settings'),
                child: _IconBtn(
                  child: const Icon(
                    Icons.settings_outlined,
                    size: 22,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(21),
      ),
      child: Center(child: child),
    );
  }
}

class _NotificationIconBtn extends StatelessWidget {
  const _NotificationIconBtn({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final badgeText = count > 9 ? '9+' : '$count';
    final showBadge = count > 0;

    return SizedBox(
      width: 48,
      height: 48,
      child: Center(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const _IconBtn(
              child: Icon(
                Icons.notifications_outlined,
                size: 22,
                color: Color(0xFF6B7280),
              ),
            ),
            if (showBadge)
              Positioned(
                top: -3,
                right: -3,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  height: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFA5C5C),
                    borderRadius: BorderRadius.all(Radius.circular(9)),
                  ),
                  child: Center(
                    child: Text(
                      badgeText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------------------
// Stats Banner
// ------------------------------------------------------------------------------
class _StatsBanner extends StatefulWidget {
  @override
  State<_StatsBanner> createState() => _StatsBannerState();
}

class _StatsBannerState extends State<_StatsBanner> {
  String _streak = '0';
  String _totalXp = '0';

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final user = await AppServices.userRepository.getActiveUser();
    if (!mounted || user?.id == null) return;
    final repo = AppServices.learningRepository;
    final streak = await repo.getCurrentStreak(user!.id!);
    final xp = await repo.getTotalXp(user.id!);
    if (!mounted) return;
    setState(() {
      _streak = '$streak';
      _totalXp = '$xp';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
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
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            GestureDetector(
              onTap: () => context.push('/streak'),
              child: _StatItem(
                icon: Icons.local_fire_department,
                gradientColors: const [Color(0xFFFA5C5C), Color(0xFFFD8A6B)],
                value: _streak,
                label: 'Ngày Liên Tiếp',
              ),
            ),
            Container(width: 1, height: 40, color: const Color(0xFFE5E7EB)),
            GestureDetector(
              onTap: () => context.push('/achievements'),
              child: _StatItem(
                icon: Icons.star_rounded,
                gradientColors: const [Color(0xFFFEC288), Color(0xFFFBEF76)],
                value: _totalXp,
                label: 'Tăng XP',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.gradientColors,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final List<Color> gradientColors;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------------------
// Next Lesson Card
// ------------------------------------------------------------------------------
class _NextLessonCard extends StatefulWidget {
  @override
  State<_NextLessonCard> createState() => _NextLessonCardState();
}

class _NextLessonCardState extends State<_NextLessonCard> {
  String _unitLabel = '';
  String _lessonTitle = '';
  String _lessonIcon = '📘';
  int _lessonId = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNextLesson();
  }

  Future<void> _loadNextLesson() async {
    final user = await AppServices.userRepository.getActiveUser();
    if (!mounted || user?.id == null) return;
    final repo = AppServices.learningRepository;
    final completedIds = await repo.getCompletedLessonIds(user!.id!);
    final units = await repo.getUnits();
    for (final unit in units) {
      final lessons = await repo.getLessonsByUnit(unit.id!);
      for (final lesson in lessons) {
        if (!completedIds.contains(lesson.id)) {
          if (!mounted) return;
          setState(() {
            _unitLabel = 'Đơn Vị ${unit.id} - Bài ${lesson.sortOrder}';
            _lessonTitle = lesson.title;
            _lessonIcon = lesson.icon;
            _lessonId = lesson.id!;
            _loading = false;
          });
          return;
        }
      }
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(24, 16, 24, 0),
        child: SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (_lessonId == 0) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.all(24),
          child: const Center(
            child: Text(
              '🎉 Bạn đã hoàn thành tất cả bài học!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFA5C5C), Color(0xFFFD8A6B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40FA5C5C),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            // Background decoration circles
            Positioned(
              top: -20,
              right: -20,
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
              bottom: -30,
              left: -20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _unitLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$_lessonTitle $_lessonIcon',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Thành thạo các màu cơ bản trong tiếng Anh\nvới bài tập thú vị',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Progress
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tiến Độ Bài Học',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      Text(
                        '0%',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: 0,
                      minHeight: 8,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Start Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          context.push('/lesson-intro?lessonId=$_lessonId'),
                      icon: const Icon(Icons.play_arrow_rounded, size: 26),
                      label: const Text(
                        'Bắt Đầu Bài Học',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFFFA5C5C),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: const StadiumBorder(),
                        elevation: 4,
                        shadowColor: Colors.black26,
                      ),
                    ),
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

// ------------------------------------------------------------------------------
// Learning Path Map
// ------------------------------------------------------------------------------

class _PathNode {
  const _PathNode({
    required this.id,
    required this.title,
    required this.emoji,
    required this.completed,
    required this.locked,
    this.current = false,
    required this.xPercent,
    required this.yPercent,
  });
  final int id;
  final String title;
  final String emoji;
  final bool completed;
  final bool locked;
  final bool current;
  final double xPercent;
  final double yPercent;
}

const _pathNodes = [
  _PathNode(
    id: 1,
    title: 'Greetings',
    emoji: '👋',
    completed: true,
    locked: false,
    xPercent: 0.30,
    yPercent: 0.08,
  ),
  _PathNode(
    id: 2,
    title: 'Family',
    emoji: '👨‍👩‍👧',
    completed: true,
    locked: false,
    xPercent: 0.72,
    yPercent: 0.22,
  ),
  _PathNode(
    id: 3,
    title: 'Food',
    emoji: '🍕',
    completed: true,
    locked: false,
    xPercent: 0.38,
    yPercent: 0.38,
  ),
  _PathNode(
    id: 4,
    title: 'Colors',
    emoji: '🎨',
    completed: false,
    locked: false,
    current: true,
    xPercent: 0.65,
    yPercent: 0.55,
  ),
  _PathNode(
    id: 5,
    title: 'Animals',
    emoji: '🐶',
    completed: false,
    locked: true,
    xPercent: 0.30,
    yPercent: 0.72,
  ),
  _PathNode(
    id: 6,
    title: 'Weather',
    emoji: '🌤️',
    completed: false,
    locked: true,
    xPercent: 0.68,
    yPercent: 0.88,
  ),
];

class _LearningPathMap extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Lộ Trình Học Tập',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              GestureDetector(
                onTap: () => context.go('/course-map'),
                child: const Text(
                  'Xem Tất Cả',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFFFA5C5C),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 480,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0F000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final h = constraints.maxHeight;
                  return Stack(
                    children: [
                      // Path lines
                      CustomPaint(
                        size: Size(w, h),
                        painter: _PathLinePainter(w, h),
                      ),
                      // Nodes
                      ..._pathNodes.map((node) {
                        return Positioned(
                          left: node.xPercent * w - 40,
                          top: node.yPercent * h - 40,
                          child: GestureDetector(
                            onTap: node.locked
                                ? null
                                : () => context.go(
                                    node.current
                                        ? '/lesson-intro?lessonId=${node.id}'
                                        : '/course-map',
                                  ),
                            child: _NodeWidget(node: node),
                          ),
                        );
                      }),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PathLinePainter extends CustomPainter {
  const _PathLinePainter(this.w, this.h);
  final double w;
  final double h;

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < _pathNodes.length - 1; i++) {
      final a = _pathNodes[i];
      final b = _pathNodes[i + 1];
      final isDashed = !(a.completed && b.completed);

      final paint = Paint()
        ..color = const Color(0xFFFA5C5C).withValues(alpha: 0.3)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final p1 = Offset(a.xPercent * w, a.yPercent * h);
      final p2 = Offset(b.xPercent * w, b.yPercent * h);

      if (isDashed) {
        _drawDashed(canvas, p1, p2, paint);
      } else {
        canvas.drawLine(p1, p2, paint);
      }
    }
  }

  void _drawDashed(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    final dist = (p2 - p1).distance;
    final dir = (p2 - p1) / dist;
    double drawn = 0;
    bool on = true;
    while (drawn < dist) {
      final seg = on ? 8.0 : 4.0;
      final next = drawn + seg;
      if (on) {
        canvas.drawLine(
          p1 + dir * drawn,
          p1 + dir * (next > dist ? dist : next),
          paint,
        );
      }
      drawn = next;
      on = !on;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NodeWidget extends StatelessWidget {
  const _NodeWidget({required this.node});
  final _PathNode node;

  @override
  Widget build(BuildContext context) {
    final Color bgStart;
    final Color bgEnd;
    final Widget nodeIcon;

    if (node.completed) {
      bgStart = const Color(0xFFFBEF76);
      bgEnd = const Color(0xFFFEC288);
      nodeIcon = const Icon(
        Icons.check_circle_rounded,
        color: Colors.white,
        size: 28,
      );
    } else if (node.current) {
      bgStart = const Color(0xFFFA5C5C);
      bgEnd = const Color(0xFFFD8A6B);
      nodeIcon = Text(node.emoji, style: const TextStyle(fontSize: 26));
    } else if (node.locked) {
      bgStart = const Color(0xFFE5E7EB);
      bgEnd = const Color(0xFFE5E7EB);
      nodeIcon = const Icon(
        Icons.lock_rounded,
        color: Color(0xFF9CA3AF),
        size: 24,
      );
    } else {
      bgStart = Colors.white;
      bgEnd = Colors.white;
      nodeIcon = Text(node.emoji, style: const TextStyle(fontSize: 22));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [bgStart, bgEnd],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: (!node.completed && !node.current && !node.locked)
                    ? Border.all(color: const Color(0xFFFA5C5C), width: 3)
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: node.current
                        ? const Color(0x40FA5C5C)
                        : Colors.black.withValues(alpha: 0.08),
                    blurRadius: node.current ? 12 : 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(child: nodeIcon),
            ),
            if (node.completed)
              Positioned(
                top: -6,
                right: -6,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x1A000000),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Color(0xFF22C55E),
                    size: 18,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: node.current ? const Color(0xFFFA5C5C) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: node.current
                ? null
                : Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F000000),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            node.title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: node.current ? Colors.white : const Color(0xFF374151),
            ),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------------------
// Quick Actions
// ------------------------------------------------------------------------------
class _QuickActions extends StatelessWidget {
  final _actions = const [
    _Action(
      emoji: '📚',
      title: 'Từ Vựng',
      subtitle: 'Luyện từ',
      gradientColors: [Color(0xFFFA5C5C), Color(0xFFFD8A6B)],
      route: '/practice/vocabulary',
    ),
    _Action(
      emoji: '🗣️',
      title: 'Phát Âm',
      subtitle: 'Cải thiện khả năng nói',
      gradientColors: [Color(0xFFFEC288), Color(0xFFFBEF76)],
      route: '/practice/speaking',
    ),
    _Action(
      emoji: '📖',
      title: 'Từ Điển',
      subtitle: 'Từ đã lưu',
      gradientColors: [Color(0xFFFD8A6B), Color(0xFFFEC288)],
      route: '/dictionary',
    ),
    _Action(
      emoji: '🏆',
      title: 'Bảng Xếp Hạng',
      subtitle: 'Thứ hạng của bạn',
      gradientColors: [Color(0xFFFBEF76), Color(0xFFFEC288)],
      route: '/leaderboard',
    ),
  ];

  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Luyện Tập Nhanh',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
            children: _actions.map((a) => _ActionCard(action: a)).toList(),
          ),
        ],
      ),
    );
  }
}

class _Action {
  const _Action({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.route,
  });
  final String emoji;
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final String route;
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.action});
  final _Action action;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go(action.route),
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
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: action.gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(action.emoji, style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              action.title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              action.subtitle,
              style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ),
    );
  }
}
