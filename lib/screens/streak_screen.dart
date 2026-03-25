import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/services/app_services.dart';

// ─────────────────────────────────────────────
// Streak Screen
// ─────────────────────────────────────────────
class StreakCalendarScreen extends StatefulWidget {
  const StreakCalendarScreen({super.key});

  @override
  State<StreakCalendarScreen> createState() => _StreakCalendarScreenState();
}

class _StreakCalendarScreenState extends State<StreakCalendarScreen>
    with TickerProviderStateMixin {
  late AnimationController _headerCtrl;
  late Animation<Offset> _headerSlide;
  late Animation<double> _headerFade;

  late AnimationController _heroCtrl;
  late Animation<double> _heroScale;
  late Animation<double> _heroFade;

  late AnimationController _calendarCtrl;
  late Animation<Offset> _calendarSlide;
  late Animation<double> _calendarFade;

  late AnimationController _tipsCtrl;
  late Animation<Offset> _tipsSlide;
  late Animation<double> _tipsFade;

  late AnimationController _footerCtrl;
  late Animation<Offset> _footerSlide;
  late Animation<double> _footerFade;

  // Flame pulse animation
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseScale;

  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);

  Map<String, int> _streakData = {
    'current': 0,
    'longest': 0,
    'total': 0,
    'thisMonth': 0,
  };

  List<int> _activeDays = [];

  @override
  void initState() {
    super.initState();
    _loadStreakData();

    _headerCtrl = _makeCtrl(400);
    _headerSlide = _slideAnim(_headerCtrl, const Offset(0, -0.3));
    _headerFade = CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut);

    _heroCtrl = _makeCtrl(500);
    _heroScale = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _heroCtrl, curve: Curves.elasticOut));
    _heroFade = CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOut);

    _calendarCtrl = _makeCtrl(450);
    _calendarSlide = _slideAnim(_calendarCtrl, const Offset(0, 0.4));
    _calendarFade = CurvedAnimation(
      parent: _calendarCtrl,
      curve: Curves.easeOut,
    );

    _tipsCtrl = _makeCtrl(400);
    _tipsSlide = _slideAnim(_tipsCtrl, const Offset(0, 0.3));
    _tipsFade = CurvedAnimation(parent: _tipsCtrl, curve: Curves.easeOut);

    _footerCtrl = _makeCtrl(400);
    _footerSlide = _slideAnim(_footerCtrl, const Offset(0, 1));
    _footerFade = CurvedAnimation(parent: _footerCtrl, curve: Curves.easeOut);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseScale = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    // Stagger animations
    _headerCtrl.forward();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _heroCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _calendarCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _tipsCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _footerCtrl.forward();
    });
  }

  Future<void> _loadStreakData() async {
    final user = await AppServices.userRepository.getActiveUser();
    if (!mounted || user?.id == null) return;
    final repo = AppServices.learningRepository;
    final current = await repo.getCurrentStreak(user!.id!);
    final longest = await repo.getLongestStreak(user.id!);
    final total = await repo.getTotalActivityDays(user.id!);
    final thisMonth = await repo.getMonthActivityCount(
      user.id!,
      _currentMonth.year,
      _currentMonth.month,
    );
    await _loadMonthActivities(user.id!);
    if (!mounted) return;
    setState(() {
      _streakData = {
        'current': current,
        'longest': longest,
        'total': total,
        'thisMonth': thisMonth,
      };
    });
  }

  Future<void> _loadMonthActivities(int userId) async {
    final activities = await AppServices.learningRepository
        .getActivitiesForMonth(userId, _currentMonth.year, _currentMonth.month);
    final days = activities.map((a) {
      final date = DateTime.parse(a.date);
      return date.day;
    }).toList();
    if (!mounted) return;
    setState(() => _activeDays = days);
  }

  AnimationController _makeCtrl(int ms) => AnimationController(
    vsync: this,
    duration: Duration(milliseconds: ms),
  );

  Animation<Offset> _slideAnim(AnimationController ctrl, Offset begin) =>
      Tween<Offset>(
        begin: begin,
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: ctrl, curve: Curves.easeOut));

  @override
  void dispose() {
    _headerCtrl.dispose();
    _heroCtrl.dispose();
    _calendarCtrl.dispose();
    _tipsCtrl.dispose();
    _footerCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // Calendar helpers
  List<int?> _getDaysInMonth(DateTime date) {
    final firstWeekday = DateTime(date.year, date.month, 1).weekday % 7;
    final daysInMonth = DateTime(date.year, date.month + 1, 0).day;
    return [
      ...List<int?>.filled(firstWeekday, null),
      ...List<int?>.generate(daysInMonth, (i) => i + 1),
    ];
  }

  bool _hasActivity(int? day) => day != null && _activeDays.contains(day);

  bool _isToday(int? day) {
    if (day == null) return false;
    final now = DateTime.now();
    return day == now.day &&
        _currentMonth.month == now.month &&
        _currentMonth.year == now.year;
  }

  String get _monthName {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[_currentMonth.month - 1]} ${_currentMonth.year}';
  }

  void _previousMonth() {
    setState(
      () =>
          _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1),
    );
    _reloadMonthActivities();
  }

  void _nextMonth() {
    setState(
      () =>
          _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1),
    );
    _reloadMonthActivities();
  }

  Future<void> _reloadMonthActivities() async {
    final user = await AppServices.userRepository.getActiveUser();
    if (user?.id == null) return;
    await _loadMonthActivities(user!.id!);
  }

  @override
  Widget build(BuildContext context) {
    final days = _getDaysInMonth(_currentMonth);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // ── Header ─────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: SlideTransition(
                  position: _headerSlide,
                  child: FadeTransition(
                    opacity: _headerFade,
                    child: _StreakHeader(),
                  ),
                ),
              ),

              // ── Hero Streak Card ────────────────────────────────────────
              SliverToBoxAdapter(
                child: ScaleTransition(
                  scale: _heroScale,
                  child: FadeTransition(
                    opacity: _heroFade,
                    child: _HeroCard(
                      streakData: _streakData,
                      pulseScale: _pulseScale,
                    ),
                  ),
                ),
              ),

              // ── Calendar ────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: SlideTransition(
                  position: _calendarSlide,
                  child: FadeTransition(
                    opacity: _calendarFade,
                    child: _CalendarCard(
                      days: days,
                      monthName: _monthName,
                      hasActivity: _hasActivity,
                      isToday: _isToday,
                      onPreviousMonth: _previousMonth,
                      onNextMonth: _nextMonth,
                    ),
                  ),
                ),
              ),

              // ── Tips ────────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: SlideTransition(
                  position: _tipsSlide,
                  child: FadeTransition(
                    opacity: _tipsFade,
                    child: const _StreakTips(),
                  ),
                ),
              ),

              // Bottom padding for CTA bar
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),

          // ── Sticky CTA Button ──────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SlideTransition(
              position: _footerSlide,
              child: FadeTransition(opacity: _footerFade, child: _CtaBar()),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────
class _StreakHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  final router = GoRouter.of(context);
                  if (router.canPop()) {
                    context.pop();
                    return;
                  }
                  context.go('/home');
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    size: 20,
                    color: Color(0xFF374151),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Your Streak',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                  Text(
                    'Keep the fire burning! 🔥',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Hero Card
// ─────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  final Map<String, int> streakData;
  final Animation<double> pulseScale;

  const _HeroCard({required this.streakData, required this.pulseScale});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFA5C5C), Color(0xFFFD8A6B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFA5C5C).withOpacity(0.4),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            // Glow circles background
            Positioned(
              top: -40,
              right: -40,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -30,
              left: -30,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  // Main streak display
                  Column(
                    children: [
                      ScaleTransition(
                        scale: pulseScale,
                        child: const Icon(
                          Icons.local_fire_department,
                          size: 80,
                          color: Color(0xFFFBEF76),
                          shadows: [
                            Shadow(color: Color(0x66FBEF76), blurRadius: 20),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${streakData['current']}',
                        style: const TextStyle(
                          fontSize: 72,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Day Streak',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Don't break the chain! Come back tomorrow.",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.75),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Stats row
                  Row(
                    children: [
                      _StatChip(
                        icon: Icons.emoji_events,
                        value: '${streakData['longest']}',
                        label: 'Longest',
                      ),
                      const SizedBox(width: 10),
                      _StatChip(
                        icon: Icons.trending_up,
                        value: '${streakData['total']}',
                        label: 'Total Days',
                      ),
                      const SizedBox(width: 10),
                      _StatChip(
                        icon: Icons.local_fire_department,
                        value: '${streakData['thisMonth']}',
                        label: 'This Month',
                      ),
                    ],
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

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: Colors.white),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Calendar Card
// ─────────────────────────────────────────────
class _CalendarCard extends StatelessWidget {
  final List<int?> days;
  final String monthName;
  final bool Function(int?) hasActivity;
  final bool Function(int?) isToday;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  const _CalendarCard({
    required this.days,
    required this.monthName,
    required this.hasActivity,
    required this.isToday,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Month navigation
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: onPreviousMonth,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.chevron_left,
                      size: 20,
                      color: Color(0xFF374151),
                    ),
                  ),
                ),
                Text(
                  monthName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                GestureDetector(
                  onTap: onNextMonth,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: Color(0xFF374151),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Weekday labels
            Row(
              children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                  .map(
                    (d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 10),

            // Calendar grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
                childAspectRatio: 1,
              ),
              itemCount: days.length,
              itemBuilder: (context, i) {
                final day = days[i];
                final active = hasActivity(day);
                final today = isToday(day);

                if (day == null) return const SizedBox();

                return _CalendarDay(day: day, active: active, today: today);
              },
            ),
            const SizedBox(height: 16),

            // Legend
            const Divider(color: Color(0xFFF3F4F6)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Legend(
                  color: const Color(0xFFFA5C5C),
                  label: 'Active day',
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFA5C5C), Color(0xFFFD8A6B)],
                  ),
                ),
                const SizedBox(width: 24),
                _Legend(color: const Color(0xFFF3F4F6), label: 'Inactive'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarDay extends StatelessWidget {
  final int day;
  final bool active;
  final bool today;

  const _CalendarDay({
    required this.day,
    required this.active,
    required this.today,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(
                    colors: [Color(0xFFFA5C5C), Color(0xFFFD8A6B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: active ? null : const Color(0xFFF9F9F9),
            borderRadius: BorderRadius.circular(10),
            border: today
                ? Border.all(color: const Color(0xFFFBEF76), width: 2)
                : null,
            boxShadow: active
                ? [
                    BoxShadow(
                      color: const Color(0xFFFA5C5C).withOpacity(0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              '$day',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : const Color(0xFF9CA3AF),
              ),
            ),
          ),
        ),

        // Flame icon on active days
        if (active)
          Positioned(
            top: -4,
            right: -4,
            child: Icon(
              Icons.local_fire_department,
              size: 12,
              color: const Color(0xFFFBEF76),
              shadows: const [Shadow(color: Color(0x66FBEF76), blurRadius: 6)],
            ),
          ),

        // Today dot indicator
        if (today)
          Positioned(
            bottom: 2,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: Color(0xFFFBEF76),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  final Gradient? gradient;

  const _Legend({required this.color, required this.label, this.gradient});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: gradient == null ? color : null,
            gradient: gradient,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Streak Tips
// ─────────────────────────────────────────────
class _StreakTips extends StatelessWidget {
  const _StreakTips();

  @override
  Widget build(BuildContext context) {
    final tips = [
      _Tip(
        emoji: '⏰',
        title: 'Set a Daily Goal',
        body: 'Study at the same time each day to build a habit',
      ),
      _Tip(
        emoji: '🔔',
        title: 'Enable Notifications',
        body: 'Get reminders so you never miss a day',
      ),
      _Tip(
        emoji: '🎯',
        title: 'Start Small',
        body: 'Even 5 minutes counts toward your streak!',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Streak Tips',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
          ...tips.map((t) => _TipCard(tip: t)),
        ],
      ),
    );
  }
}

class _Tip {
  final String emoji, title, body;
  const _Tip({required this.emoji, required this.title, required this.body});
}

class _TipCard extends StatelessWidget {
  final _Tip tip;
  const _TipCard({required this.tip});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tip.emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tip.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tip.body,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Sticky CTA
// ─────────────────────────────────────────────
class _CtaBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
          child: SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: () => context.go('/home'),
              child: Container(
                height: 58,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFA5C5C), Color(0xFFFD8A6B)],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFA5C5C).withOpacity(0.4),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'Continue Learning',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
