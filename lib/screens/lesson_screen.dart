import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/services/app_services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────────────────────

class _LessonItem {
  const _LessonItem({
    required this.id,
    required this.title,
    required this.icon,
    required this.completed,
    required this.locked,
    this.current = false,
  });
  final int id;
  final String title;
  final String icon;
  final bool completed;
  final bool locked;
  final bool current;
}

class _UnitData {
  const _UnitData({
    required this.id,
    required this.title,
    required this.progress,
    required this.lessons,
  });
  final int id;
  final String title;
  final int progress;
  final List<_LessonItem> lessons;
}

class _VocabData {
  const _VocabData({
    required this.word,
    required this.translation,
    required this.example,
    required this.colorValue,
  });
  final String word;
  final String translation;
  final String example;
  final int colorValue;
}

class _GrammarData {
  const _GrammarData({required this.title, required this.desc});
  final String title;
  final String desc;
}

class _ActivityData {
  const _ActivityData(
      {required this.emoji, required this.title, required this.count});
  final String emoji;
  final String title;
  final int count;
}

// ─────────────────────────────────────────────────────────────────────────────
// COURSE MAP SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class CourseMapScreen extends StatefulWidget {
  const CourseMapScreen({super.key});

  @override
  State<CourseMapScreen> createState() => _CourseMapScreenState();
}

class _CourseMapScreenState extends State<CourseMapScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _overallProgress;

  List<_UnitData> _units = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _overallProgress = Tween<double>(begin: 0, end: 0.0).animate(
      CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0.3, 1.0, curve: Curves.easeOut)),
    );
    _loadData();
  }

  Future<void> _loadData() async {
    final user = await AppServices.userRepository.getActiveUser();
    final repo = AppServices.learningRepository;
    final units = await repo.getUnits();
    final completedIds = user?.id != null
        ? await repo.getCompletedLessonIds(user!.id!)
        : <int>{};

    final List<_UnitData> builtUnits = [];
    bool foundCurrent = false;

    for (final unit in units) {
      final lessons = await repo.getLessonsByUnit(unit.id!);
      final lessonItems = <_LessonItem>[];

      for (final lesson in lessons) {
        final completed = completedIds.contains(lesson.id);
        final locked = !completed && foundCurrent;
        final current = !completed && !foundCurrent;
        if (current) foundCurrent = true;

        lessonItems.add(_LessonItem(
          id: lesson.id!,
          title: lesson.title,
          icon: lesson.icon,
          completed: completed,
          locked: locked,
          current: current,
        ));
      }

      final completedCount = lessonItems.where((l) => l.completed).length;
      final progress = lessonItems.isEmpty
          ? 0
          : ((completedCount / lessonItems.length) * 100).round();

      builtUnits.add(_UnitData(
        id: unit.id!,
        title: 'Đơn Vị ${unit.id}: ${unit.title}',
        progress: progress,
        lessons: lessonItems,
      ));
    }

    if (!mounted) return;

    final totalLessons = builtUnits.fold<int>(0, (s, u) => s + u.lessons.length);
    final totalCompleted = builtUnits.fold<int>(
        0, (s, u) => s + u.lessons.where((l) => l.completed).length);
    final overall = totalLessons == 0 ? 0.0 : totalCompleted / totalLessons;

    _overallProgress = Tween<double>(begin: 0, end: overall).animate(
      CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0.3, 1.0, curve: Curves.easeOut)),
    );

    setState(() {
      _units = builtUnits;
      _loading = false;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
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
          // Sticky header
          _CourseMapHeader(progressAnim: _overallProgress),
          // Scrollable body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Column(
                children: [
                  ..._units.map((unit) => Padding(
                        padding: const EdgeInsets.only(bottom: 32),
                        child: _UnitSection(unit: unit),
                      )),
                  // Coming soon card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x0F000000),
                            blurRadius: 8,
                            offset: Offset(0, 2))
                      ],
                    ),
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEC288).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Center(
                              child:
                                  Text('🚀', style: TextStyle(fontSize: 40))),
                        ),
                        const SizedBox(height: 12),
                        const Text('Sắp Ra Mắt!',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF111827))),
                        const SizedBox(height: 6),
                        const Text(
                          'Hoàn thành các đơn vị hiện tại để mở khóa bài học nâng cao',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 13, color: Color(0xFF9CA3AF)),
                        ),
                      ],
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

class _CourseMapHeader extends StatelessWidget {
  const _CourseMapHeader({required this.progressAnim});
  final Animation<double> progressAnim;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 20,
        left: 20,
        right: 20,
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
                      color: Color(0xFF374151), size: 20),
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bản Đồ Khóa Học',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827))),
                  Text('Theo dõi hành trình học tập của bạn',
                      style:
                          TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFFFA5C5C), Color(0xFFFD8A6B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tiến Độ Tổng Thể',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                    AnimatedBuilder(
                      animation: progressAnim,
                      builder: (context, _) => Text(
                        '${(progressAnim.value * 100).toInt()}%',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                AnimatedBuilder(
                  animation: progressAnim,
                  builder: (context, _) => ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: LinearProgressIndicator(
                      value: progressAnim.value,
                      minHeight: 10,
                      backgroundColor:
                          Colors.white.withValues(alpha: 0.3),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '3 trong 12 bài học đã hoàn thành',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UnitSection extends StatelessWidget {
  const _UnitSection({required this.unit});
  final _UnitData unit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Unit header
        Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFFFEC288), Color(0xFFFBEF76)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x20000000),
                      blurRadius: 8,
                      offset: Offset(0, 3))
                ],
              ),
              child: Center(
                  child: Text('${unit.id}',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(unit.title,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827))),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: unit.progress / 100,
                            minHeight: 6,
                            backgroundColor:
                                const Color(0xFFE5E7EB),
                            valueColor:
                                const AlwaysStoppedAnimation<Color>(
                                    Color(0xFFFA5C5C)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${unit.progress}%',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF9CA3AF))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Lessons with vertical line on the left
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Vertical connecting line
              SizedBox(
                width: 24,
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Expanded(
                      child: Center(
                        child: Container(
                          width: 2,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFFA5C5C),
                                Color(0xFFE5E7EB)
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Lessons
              Expanded(
                child: Column(
                  children: unit.lessons.asMap().entries.map((e) {
                    final isEven = e.key % 2 == 0;
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: 12,
                        left: isEven ? 0 : 16,
                        right: isEven ? 16 : 0,
                      ),
                      child: _LessonCard(lesson: e.value),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({required this.lesson});
  final _LessonItem lesson;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: lesson.locked ? null : () => context.go('/lesson-intro'),
      child: Opacity(
        opacity: lesson.locked ? 0.6 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: lesson.current
                ? Border.all(color: const Color(0xFFFA5C5C), width: 2)
                : null,
            boxShadow: const [
              BoxShadow(
                  color: Color(0x0F000000),
                  blurRadius: 8,
                  offset: Offset(0, 2))
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  // Icon bubble
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: lesson.completed
                                ? const [
                                    Color(0xFFFBEF76),
                                    Color(0xFFFEC288)
                                  ]
                                : lesson.current
                                    ? const [
                                        Color(0xFFFA5C5C),
                                        Color(0xFFFD8A6B)
                                      ]
                                    : lesson.locked
                                        ? const [
                                            Color(0xFFE5E7EB),
                                            Color(0xFFE5E7EB)
                                          ]
                                        : [
                                            const Color(0xFFFEC288)
                                                .withValues(alpha: 0.3),
                                            const Color(0xFFFBEF76)
                                                .withValues(alpha: 0.3),
                                          ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: lesson.locked
                              ? const Icon(Icons.lock_rounded,
                                  color: Color(0xFF9CA3AF), size: 26)
                              : Text(lesson.icon,
                                  style:
                                      const TextStyle(fontSize: 26)),
                        ),
                      ),
                      if (lesson.completed)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              color: Color(0xFF22C55E),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check_rounded,
                                color: Colors.white, size: 13),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(lesson.title,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF111827))),
                            ),
                            if (lesson.current)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFA5C5C),
                                  borderRadius:
                                      BorderRadius.circular(8),
                                ),
                                child: const Text('Hiện Tại',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.white,
                                        fontWeight:
                                            FontWeight.w600)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          lesson.completed
                              ? 'Đã hoàn thành'
                              : lesson.locked
                                  ? 'Đã khóa'
                                  : 'Sẵn sàng bắt đầu',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF9CA3AF)),
                        ),
                      ],
                    ),
                  ),

                  // Action icon
                  if (lesson.completed)
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: const Icon(Icons.star_rounded,
                          color: Color(0xFF22C55E), size: 18),
                    )
                  else if (lesson.current)
                    Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFA5C5C),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 20),
                    )
                  else if (!lesson.locked)
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: const Icon(Icons.play_arrow_rounded,
                          color: Color(0xFF9CA3AF), size: 20),
                    ),
                ],
              ),

              // XP reward row (only for unlocked)
              if (!lesson.locked) ...[
                const SizedBox(height: 10),
                const Divider(height: 1, color: Color(0xFFF3F4F6)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('Phần thưởng bài học',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFF9CA3AF))),
                    Row(
                      children: [
                        Icon(Icons.star_rounded,
                            color: Color(0xFFFBEF76), size: 14),
                        SizedBox(width: 4),
                        Text('+50 XP',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151))),
                      ],
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LESSON INTRO SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class LessonIntroScreen extends StatefulWidget {
  const LessonIntroScreen({super.key});

  @override
  State<LessonIntroScreen> createState() => _LessonIntroScreenState();
}

class _LessonIntroScreenState extends State<LessonIntroScreen> {

  static const _vocab = [
    _VocabData(
        word: 'Red',
        translation: 'Đỏ',
        example: 'Quả táo màu đỏ',
        colorValue: 0xFFFA5C5C),
    _VocabData(
        word: 'Blue',
        translation: 'Xanh dương',
        example: 'Bầu trời màu xanh dương',
        colorValue: 0xFF4A90E2),
    _VocabData(
        word: 'Green',
        translation: 'Xanh lá',
        example: 'Cỏ màu xanh lá',
        colorValue: 0xFF4CAF50),
    _VocabData(
        word: 'Yellow',
        translation: 'Vàng',
        example: 'Mặt trời màu vàng',
        colorValue: 0xFFFBEF76),
    _VocabData(
        word: 'Orange',
        translation: 'Cam',
        example: 'Quả cam màu cam',
        colorValue: 0xFFFD8A6B),
    _VocabData(
        word: 'Purple',
        translation: 'Tím',
        example: 'Bông hoa màu tím',
        colorValue: 0xFF9C27B0),
  ];

  static const _grammar = [
    _GrammarData(
        title: "Sử dụng 'is' với màu sắc",
        desc: 'Học cách mô tả đồ vật'),
    _GrammarData(
        title: 'Vị trí tính từ',
        desc: 'Màu sắc đứng ở đâu trong câu'),
  ];

  static const _activities = [
    _ActivityData(emoji: '👂', title: 'Nghe', count: 5),
    _ActivityData(emoji: '💬', title: 'Nói', count: 3),
    _ActivityData(emoji: '✍️', title: 'Viết', count: 4),
    _ActivityData(emoji: '🎯', title: 'Kiểm Tra', count: 1),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Column(
        children: [
          // Header
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              bottom: 16,
              left: 16,
              right: 24,
            ),
            child: Row(
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
                        color: Color(0xFF374151), size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Đơn Vị 1 - Bài 4',
                        style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFFFA5C5C),
                            fontWeight: FontWeight.w600)),
                    Text('Học Màu Sắc',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827))),
                  ],
                ),
              ],
            ),
          ),

          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Mascot card
                  _MascotCard(),
                  const SizedBox(height: 24),

                  // Activities grid
                  const Text('Bạn Sẽ Luyện Tập',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827))),
                  const SizedBox(height: 12),
                  Row(
                    children: _activities
                        .map((a) => Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.only(right: 8),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius:
                                        BorderRadius.circular(16),
                                    boxShadow: const [
                                      BoxShadow(
                                          color: Color(0x0F000000),
                                          blurRadius: 6,
                                          offset: Offset(0, 2))
                                    ],
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  child: Column(
                                    children: [
                                      Text(a.emoji,
                                          style: const TextStyle(
                                              fontSize: 26)),
                                      const SizedBox(height: 5),
                                      Text(a.title,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight:
                                                  FontWeight.w600,
                                              color:
                                                  Color(0xFF111827))),
                                      Text('${a.count} nhiệm vụ',
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color:
                                                  Color(0xFF9CA3AF))),
                                    ],
                                  ),
                                ),
                              ),
                            ))
                        .toList(),
                  ),

                  const SizedBox(height: 24),

                  // Vocabulary
                  Row(
                    children: const [
                      Text('📚 ', style: TextStyle(fontSize: 16)),
                      Text('Từ Vựng Mới (6 từ)',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF111827))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x0F000000),
                            blurRadius: 6,
                            offset: Offset(0, 2))
                      ],
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: _vocab
                          .asMap()
                          .entries
                          .map((e) => Column(
                                children: [
                                  if (e.key > 0)
                                    const Divider(
                                        height: 1,
                                        color: Color(0xFFF3F4F6)),
                                  _VocabRow(item: e.value),
                                ],
                              ))
                          .toList(),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Grammar
                  Row(
                    children: const [
                      Text('📝 ', style: TextStyle(fontSize: 16)),
                      Text('Điểm Ngữ Pháp',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF111827))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._grammar.asMap().entries.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(
                                  color: Color(0x0F000000),
                                  blurRadius: 6,
                                  offset: Offset(0, 2))
                            ],
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFFEC288),
                                        Color(0xFFFBEF76)
                                      ],
                                      begin: Alignment.topLeft,
                                      end:
                                          Alignment.bottomRight),
                                  borderRadius:
                                      BorderRadius.circular(14),
                                ),
                                child: Center(
                                    child: Text('${e.key + 1}',
                                        style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight:
                                                FontWeight.bold,
                                            color: Colors.white))),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(e.value.title,
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight:
                                                FontWeight.w600,
                                            color:
                                                Color(0xFF111827))),
                                    const SizedBox(height: 2),
                                    Text(e.value.desc,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color:
                                                Color(0xFF9CA3AF))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),

      // Sticky bottom start button
      bottomNavigationBar: Container(
        color: Colors.white,
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: MediaQuery.of(context).padding.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  // Load exercises for lesson 4 (Màu Sắc) into session
                  final exercises = await AppServices.learningRepository
                      .getExercisesByLesson(4);
                  AppServices.exerciseSession.load(4, exercises);
                  if (!mounted) return;
                  if (exercises.isNotEmpty) {
                    final firstType = exercises.first.type;
                    final route = switch (firstType) {
                      'listening' => '/exercise/listening',
                      'speaking' => '/exercise/speaking',
                      _ => '/exercise/multiple-choice',
                    };
                    context.go(route);
                  } else {
                    context.go('/exercise/multiple-choice');
                  }
                },
                icon: const Icon(Icons.play_arrow_rounded, size: 24),
                label: const Text('Bắt Đầu Bài Học',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFA5C5C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: const StadiumBorder(),
                  elevation: 4,
                  shadowColor: const Color(0x40FA5C5C),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Thời gian ước tính: 10 phút · Nhận 50 XP',
              style:
                  TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _MascotCard extends StatelessWidget {
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
              blurRadius: 20,
              offset: Offset(0, 8))
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: CustomPaint(painter: _OwlPainter()),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x20000000),
                          blurRadius: 8,
                          offset: Offset(0, 2))
                    ],
                  ),
                  padding: const EdgeInsets.all(14),
                  child: const Text(
                    '"Cùng học màu sắc nào! 🎨 Bạn sẽ có thể mô tả mọi thứ ngay thôi!"',
                    style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF374151),
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _LessonStat(
                  icon: Icons.access_time_rounded, label: '10 phút'),
              const SizedBox(width: 10),
              _LessonStat(icon: Icons.star_rounded, label: '+50 XP'),
              const SizedBox(width: 10),
              _LessonStat(
                  icon: Icons.track_changes_rounded,
                  label: '13 Nhiệm vụ'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LessonStat extends StatelessWidget {
  const _LessonStat({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _VocabRow extends StatelessWidget {
  const _VocabRow({required this.item});
  final _VocabData item;

  @override
  Widget build(BuildContext context) {
    final color = Color(item.colorValue);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                    color: color, shape: BoxShape.circle),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(item.word,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827))),
                    const SizedBox(width: 8),
                    Text(item.translation,
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF9CA3AF))),
                  ],
                ),
                Text('"${item.example}"',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                        fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Owl CustomPainter
class _OwlPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 + 4;

    // Body
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, cy + 4), width: 68, height: 62),
      Paint()..color = Colors.white,
    );

    // Wings
    final wingPaint = Paint()..color = const Color(0xFFFBEF76);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx - 36, cy + 8), width: 22, height: 34),
        wingPaint);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx + 36, cy + 8), width: 22, height: 34),
        wingPaint);

    // Eye circles
    canvas.drawCircle(Offset(cx - 13, cy - 2), 11,
        Paint()..color = const Color(0xFFFA5C5C));
    canvas.drawCircle(Offset(cx + 13, cy - 2), 11,
        Paint()..color = const Color(0xFFFA5C5C));

    // Eye highlights
    canvas.drawCircle(Offset(cx - 11, cy - 4), 4,
        Paint()..color = Colors.white);
    canvas.drawCircle(Offset(cx + 15, cy - 4), 4,
        Paint()..color = Colors.white);

    // Beak
    final beakPath = Path()
      ..moveTo(cx, cy + 7)
      ..lineTo(cx - 7, cy + 15)
      ..lineTo(cx + 7, cy + 15)
      ..close();
    canvas.drawPath(beakPath, Paint()..color = const Color(0xFFFEC288));

    // Feet
    final feetPaint = Paint()
      ..color = const Color(0xFFFD8A6B)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(cx - 13, cy + 32),
        Offset(cx - 19, cy + 40), feetPaint);
    canvas.drawLine(Offset(cx - 13, cy + 32),
        Offset(cx - 7, cy + 40), feetPaint);
    canvas.drawLine(Offset(cx + 13, cy + 32),
        Offset(cx + 7, cy + 40), feetPaint);
    canvas.drawLine(Offset(cx + 13, cy + 32),
        Offset(cx + 19, cy + 40), feetPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
