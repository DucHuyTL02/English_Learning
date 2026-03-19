import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Dot-row indicator.  [activeIndex] is the active dot (0-based, out of 3).
class _PageDots extends StatelessWidget {
  const _PageDots({required this.activeIndex, required this.activeColor});
  final int activeIndex;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final isActive = i == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? activeColor : const Color(0xFFD1D5DB),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

/// Shared scaffold for every onboarding page.
class _OnboardingScaffold extends StatefulWidget {
  const _OnboardingScaffold({
    required this.illustration,
    required this.title,
    required this.subtitle,
    required this.activeIndex,
    required this.activeColor,
    required this.onNext,
    this.isLast = false,
  });

  final Widget illustration;
  final String title;
  final String subtitle;
  final int activeIndex;
  final Color activeColor;
  final VoidCallback onNext;

  final bool isLast;

  @override
  State<_OnboardingScaffold> createState() => _OnboardingScaffoldState();
}

class _OnboardingScaffoldState extends State<_OnboardingScaffold>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _imgScale;
  late Animation<double> _imgOpacity;
  late Animation<double> _textSlide;
  late Animation<double> _textOpacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _imgScale = Tween<double>(begin: 0.8, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _imgOpacity = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _textSlide = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0.3, 1.0, curve: Curves.easeOut)),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0.3, 1.0, curve: Curves.easeOut)),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Column(
            children: [
              // Skip
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => context.go('/login'),
                  child: const Text(
                    'Bỏ qua',
                    style: TextStyle(
                        fontSize: 15, color: Color(0xFF9CA3AF)),
                  ),
                ),
              ),

              // Illustration
              Expanded(
                child: AnimatedBuilder(
                  animation: _ctrl,
                  builder: (context, _) => Opacity(
                    opacity: _imgOpacity.value,
                    child: Transform.scale(
                      scale: _imgScale.value,
                      child: widget.illustration,
                    ),
                  ),
                ),
              ),

              // Text block
              AnimatedBuilder(
                animation: _ctrl,
                builder: (context, _) => Transform.translate(
                  offset: Offset(0, _textSlide.value),
                  child: Opacity(
                    opacity: _textOpacity.value,
                    child: Column(
                      children: [
                        Text(
                          widget.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.subtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.6,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        if (widget.isLast) ...[
                          const SizedBox(height: 28),
                          _GetStartedButton(onTap: widget.onNext),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Bottom row: dots + next button (or only dots on last page)
              Row(
                mainAxisAlignment: widget.isLast
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.spaceBetween,
                children: [
                  _PageDots(
                      activeIndex: widget.activeIndex,
                      activeColor: widget.activeColor),
                  if (!widget.isLast)
                    _NextButton(
                        color: widget.activeColor,
                        onTap: widget.onNext),
                ],
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextButton extends StatelessWidget {
  const _NextButton({required this.color, required this.onTap});
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(Icons.chevron_right_rounded,
            color: Colors.white, size: 30),
      ),
    );
  }
}

class _GetStartedButton extends StatelessWidget {
  const _GetStartedButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFA5C5C), Color(0xFFFD8A6B)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(50),
          boxShadow: const [
            BoxShadow(
                color: Color(0x40FA5C5C),
                blurRadius: 20,
                offset: Offset(0, 8)),
          ],
        ),
        child: const Text(
          'Bắt Đầu Ngay',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Onboarding 1 – Khám Phá Từ Mới
// ─────────────────────────────────────────────────────────────────────────────
class OnboardingScreen1 extends StatelessWidget {
  const OnboardingScreen1({super.key});

  @override
  Widget build(BuildContext context) {
    return _OnboardingScaffold(
      activeIndex: 0,
      activeColor: const Color(0xFFFA5C5C),
      title: 'Khám Phá Từ Mới',
      subtitle:
          'Xây dựng vốn từ vựng với các bài học hấp dẫn và bài tập tương tác được thiết kế riêng cho bạn',
      onNext: () => context.go('/onboarding-2'),
      illustration: const _Illustration1(),
    );
  }
}

class _Illustration1 extends StatelessWidget {
  const _Illustration1();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CustomPaint(
        size: const Size(280, 280),
        painter: _Illus1Painter(),
      ),
    );
  }
}

class _Illus1Painter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2); // 140,140

    // Background circle
    canvas.drawCircle(c, 120,
        Paint()..color = const Color(0xFFFEC288).withValues(alpha: 0.2));

    // Book body
    _rrect(canvas, 90, 150, 100, 80, 8, const Color(0xFFFA5C5C));
    // Book divider
    canvas.drawLine(const Offset(140, 150), const Offset(140, 230),
        Paint()
          ..color = Colors.white
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round);
    canvas.drawCircle(
        const Offset(115, 180), 4, Paint()..color = const Color(0xFFFBEF76));
    canvas.drawCircle(
        const Offset(165, 180), 4, Paint()..color = const Color(0xFFFEC288));

    // Head
    canvas.drawCircle(
        const Offset(140, 80), 30, Paint()..color = const Color(0xFFFD8A6B));

    // Hair
    final hairPath = Path()
      ..moveTo(110, 75)
      ..quadraticBezierTo(125, 45, 140, 50)
      ..quadraticBezierTo(155, 45, 170, 75)
      ..close();
    canvas.drawPath(hairPath, Paint()..color = const Color(0xFFFA5C5C));

    // Eyes
    canvas.drawCircle(
        const Offset(130, 80), 3, Paint()..color = Colors.white);
    canvas.drawCircle(
        const Offset(150, 80), 3, Paint()..color = Colors.white);

    // Smile
    final smilePath = Path()
      ..moveTo(125, 90)
      ..quadraticBezierTo(140, 98, 155, 90);
    canvas.drawPath(
        smilePath,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke);

    // Body
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(140, 130), width: 70, height: 90),
        Paint()..color = const Color(0xFFFD8A6B));

    // Left arm
    final la = Path()
      ..moveTo(105, 120)
      ..cubicTo(95, 130, 85, 142, 90, 155);
    canvas.drawPath(
        la,
        Paint()
          ..color = const Color(0xFFFD8A6B)
          ..strokeWidth = 12
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke);

    // Right arm
    final ra = Path()
      ..moveTo(175, 120)
      ..cubicTo(185, 130, 195, 142, 190, 155);
    canvas.drawPath(
        ra,
        Paint()
          ..color = const Color(0xFFFD8A6B)
          ..strokeWidth = 12
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke);

    // Sparkles
    final sp = Paint()..color = const Color(0xFFFBEF76).withValues(alpha: 0.8);
    canvas.drawCircle(const Offset(60, 60), 4, sp);
    canvas.drawCircle(const Offset(220, 80), 3, sp);
    final sp2 = Paint()
      ..color = const Color(0xFFFEC288).withValues(alpha: 0.8);
    canvas.drawCircle(const Offset(50, 180), 3, sp2);
    canvas.drawCircle(const Offset(230, 200), 4, sp2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Onboarding 2 – Đạt Được Mục Tiêu
// ─────────────────────────────────────────────────────────────────────────────
class OnboardingScreen2 extends StatelessWidget {
  const OnboardingScreen2({super.key});

  @override
  Widget build(BuildContext context) {
    return _OnboardingScaffold(
      activeIndex: 1,
      activeColor: const Color(0xFFFD8A6B),
      title: 'Đạt Được Mục Tiêu',
      subtitle:
          'Theo dõi tiến độ và ăn mừng mọi cột mốc quan trọng trên hành trình học tập của bạn',
      onNext: () => context.go('/onboarding-3'),
      illustration: const _Illustration2(),
    );
  }
}

class _Illustration2 extends StatelessWidget {
  const _Illustration2();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CustomPaint(
        size: const Size(280, 280),
        painter: _Illus2Painter(),
      ),
    );
  }
}

class _Illus2Painter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Background circle
    canvas.drawCircle(const Offset(140, 140), 120,
        Paint()..color = const Color(0xFFFBEF76).withValues(alpha: 0.3));

    // Trophy base
    _rrect(canvas, 110, 200, 60, 15, 4, const Color(0xFFFA5C5C));
    final stemRect = Rect.fromLTWH(125, 185, 30, 20);
    canvas.drawRect(stemRect, Paint()..color = const Color(0xFFFD8A6B));

    // Trophy cup
    final cupPath = Path()
      ..moveTo(95, 120)
      ..lineTo(95, 140)
      ..quadraticBezierTo(95, 175, 110, 175)
      ..lineTo(170, 175)
      ..quadraticBezierTo(185, 175, 185, 140)
      ..lineTo(185, 120)
      ..quadraticBezierTo(185, 110, 175, 110)
      ..lineTo(105, 110)
      ..quadraticBezierTo(95, 110, 95, 120)
      ..close();
    canvas.drawPath(cupPath, Paint()..color = const Color(0xFFFBEF76));

    // Handles
    final lh = Path()
      ..moveTo(95, 125)
      ..cubicTo(85, 125, 72, 130, 75, 140)
      ..cubicTo(75, 148, 80, 152, 85, 150);
    canvas.drawPath(
        lh,
        Paint()
          ..color = const Color(0xFFFEC288)
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke);

    final rh = Path()
      ..moveTo(185, 125)
      ..cubicTo(195, 125, 208, 130, 205, 140)
      ..cubicTo(205, 148, 200, 152, 195, 150);
    canvas.drawPath(
        rh,
        Paint()
          ..color = const Color(0xFFFEC288)
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke);

    // Star
    _drawStar(canvas, const Offset(140, 149), 14, const Color(0xFFFA5C5C));

    // Head
    canvas.drawCircle(
        const Offset(140, 60), 28, Paint()..color = const Color(0xFFFD8A6B));

    // Hair
    final hair = Path()
      ..moveTo(115, 55)
      ..quadraticBezierTo(125, 28, 140, 32)
      ..quadraticBezierTo(155, 28, 165, 55)
      ..close();
    canvas.drawPath(hair, Paint()..color = const Color(0xFFFA5C5C));

    // Eyes
    canvas.drawCircle(
        const Offset(130, 58), 3, Paint()..color = Colors.white);
    canvas.drawCircle(
        const Offset(150, 58), 3, Paint()..color = Colors.white);
    canvas.drawCircle(
        const Offset(131, 57), 1.5, Paint()..color = const Color(0xFF333333));
    canvas.drawCircle(
        const Offset(151, 57), 1.5, Paint()..color = const Color(0xFF333333));

    // Smile
    final smile = Path()
      ..moveTo(125, 68)
      ..quadraticBezierTo(140, 78, 155, 68);
    canvas.drawPath(
        smile,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke);

    // Body
    canvas.drawOval(Rect.fromCenter(center: Offset(140, 95), width: 60, height: 70),
        Paint()..color = const Color(0xFFFD8A6B));

    // Arms raised
    final la = Path()
      ..moveTo(110, 95)
      ..cubicTo(105, 83, 96, 74, 85, 70);
    canvas.drawPath(
        la,
        Paint()
          ..color = const Color(0xFFFD8A6B)
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke);

    final ra = Path()
      ..moveTo(170, 95)
      ..cubicTo(175, 83, 184, 74, 195, 70);
    canvas.drawPath(
        ra,
        Paint()
          ..color = const Color(0xFFFD8A6B)
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke);

    // Confetti
    final confPaints = [
      Paint()..color = const Color(0xFFFA5C5C).withValues(alpha: 0.8),
      Paint()..color = const Color(0xFFFBEF76).withValues(alpha: 0.8),
      Paint()..color = const Color(0xFFFEC288).withValues(alpha: 0.8),
      Paint()..color = const Color(0xFFFD8A6B).withValues(alpha: 0.8),
    ];
    canvas.drawCircle(const Offset(50, 90), 4, confPaints[0]);
    canvas.drawCircle(const Offset(230, 100), 3, confPaints[1]);
    canvas.drawRect(
        const Rect.fromLTWH(40, 150, 6, 6),
        confPaints[2]..style = PaintingStyle.fill);
    canvas.drawRect(
        const Rect.fromLTWH(220, 160, 8, 8),
        confPaints[3]..style = PaintingStyle.fill);
    canvas.drawCircle(const Offset(60, 200), 3, confPaints[0]);
    canvas.drawCircle(const Offset(210, 210), 4, confPaints[1]);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Onboarding 3 – Sẵn Sàng Khởi Động?
// ─────────────────────────────────────────────────────────────────────────────
class OnboardingScreen3 extends StatelessWidget {
  const OnboardingScreen3({super.key});

  @override
  Widget build(BuildContext context) {
    return _OnboardingScaffold(
      activeIndex: 2,
      activeColor: const Color(0xFFFA5C5C),
      isLast: true,
      title: 'Sẵn Sàng Khởi Động?',
      subtitle:
          'Bắt đầu cuộc phiêu lưu học tiếng Anh của bạn ngay hôm nay và vươn tới những vì sao!',
      onNext: () => context.go('/login'),
      illustration: const _Illustration3(),
    );
  }
}

class _Illustration3 extends StatefulWidget {
  const _Illustration3();

  @override
  State<_Illustration3> createState() => _Illustration3State();
}

class _Illustration3State extends State<_Illustration3>
    with TickerProviderStateMixin {
  late AnimationController _flameCtrl;
  late AnimationController _smokeCtrl;
  late Animation<double> _flameScale;
  late Animation<double> _flameOpacity;
  late Animation<double> _smokeOpacity;

  @override
  void initState() {
    super.initState();
    _flameCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500))
      ..repeat(reverse: true);
    _smokeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat(reverse: true);

    _flameScale = Tween<double>(begin: 1.0, end: 1.2)
        .animate(CurvedAnimation(parent: _flameCtrl, curve: Curves.easeInOut));
    _flameOpacity = Tween<double>(begin: 0.9, end: 1.0)
        .animate(CurvedAnimation(parent: _flameCtrl, curve: Curves.easeInOut));
    _smokeOpacity = Tween<double>(begin: 0.3, end: 0.5)
        .animate(CurvedAnimation(parent: _smokeCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _flameCtrl.dispose();
    _smokeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: Listenable.merge([_flameCtrl, _smokeCtrl]),
        builder: (context, _) {
          return CustomPaint(
            size: const Size(280, 280),
            painter: _Illus3Painter(
              flameScale: _flameScale.value,
              flameOpacity: _flameOpacity.value,
              smokeOpacity: _smokeOpacity.value,
            ),
          );
        },
      ),
    );
  }
}

class _Illus3Painter extends CustomPainter {
  const _Illus3Painter({
    required this.flameScale,
    required this.flameOpacity,
    required this.smokeOpacity,
  });
  final double flameScale;
  final double flameOpacity;
  final double smokeOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    // Background circle
    canvas.drawCircle(const Offset(140, 120), 100,
        Paint()..color = const Color(0xFFFA5C5C).withValues(alpha: 0.15));

    // Clouds
    canvas.drawOval(Rect.fromCenter(center: Offset(60, 200), width: 50, height: 30),
        Paint()..color = const Color(0xFFFEC288).withValues(alpha: 0.3));
    canvas.drawOval(Rect.fromCenter(center: Offset(220, 190), width: 60, height: 36),
        Paint()..color = const Color(0xFFFEC288).withValues(alpha: 0.3));
    canvas.drawOval(Rect.fromCenter(center: Offset(45, 150), width: 40, height: 24),
        Paint()..color = const Color(0xFFFBEF76).withValues(alpha: 0.3));

    // Stars
    final starPaint = Paint()..color = const Color(0xFFFBEF76).withValues(alpha: 0.7);
    canvas.drawCircle(const Offset(50, 50), 3, starPaint);
    canvas.drawCircle(const Offset(230, 60), 4, starPaint);
    canvas.drawCircle(const Offset(200, 30), 3,
        Paint()..color = const Color(0xFFFEC288).withValues(alpha: 0.7));
    canvas.drawCircle(const Offset(80, 30), 2.5,
        Paint()..color = const Color(0xFFFEC288).withValues(alpha: 0.7));

    // Animated flame (drawn first so rocket is on top)
    canvas.save();
    canvas.translate(140, 170);
    canvas.scale(1.0, flameScale);
    canvas.translate(-140, -170);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(140, 170), width: 40, height: 60),
        Paint()..color = const Color(0xFFFBEF76).withValues(alpha: flameOpacity));
    canvas.drawOval(
        Rect.fromCenter(center: Offset(140, 175), width: 30, height: 50),
        Paint()..color = const Color(0xFFFEC288).withValues(alpha: flameOpacity));
    canvas.drawOval(
        Rect.fromCenter(center: Offset(140, 180), width: 20, height: 40),
        Paint()..color = const Color(0xFFFD8A6B).withValues(alpha: flameOpacity));
    canvas.restore();

    // Smoke trail
    canvas.drawCircle(const Offset(140, 210), 12,
        Paint()..color = const Color(0xFFFEC288).withValues(alpha: smokeOpacity * 0.5));
    canvas.drawCircle(const Offset(135, 225), 10,
        Paint()..color = const Color(0xFFFEC288).withValues(alpha: smokeOpacity * 0.35));
    canvas.drawCircle(const Offset(145, 225), 10,
        Paint()..color = const Color(0xFFFEC288).withValues(alpha: smokeOpacity * 0.35));

    // Rocket body
    final rocketPath = Path()
      ..moveTo(120, 140)
      ..lineTo(120, 60)
      ..quadraticBezierTo(120, 30, 140, 30)
      ..quadraticBezierTo(160, 30, 160, 60)
      ..lineTo(160, 140)
      ..close();
    canvas.drawPath(rocketPath, Paint()..color = const Color(0xFFFA5C5C));

    // Rocket nose highlight
    final nosePath = Path()
      ..moveTo(120, 60)
      ..quadraticBezierTo(122, 38, 140, 30)
      ..quadraticBezierTo(158, 38, 160, 60);
    canvas.drawPath(nosePath, Paint()..color = const Color(0xFFFD8A6B));

    // Window
    canvas.drawCircle(const Offset(140, 80), 15,
        Paint()..color = const Color(0xFFFBEF76));
    canvas.drawCircle(const Offset(140, 80), 10,
        Paint()..color = Colors.white.withValues(alpha: 0.5));

    // Rocket details (side strips)
    _rrect(canvas, 125, 100, 8, 25, 2, const Color(0xFFFEC288));
    _rrect(canvas, 147, 100, 8, 25, 2, const Color(0xFFFEC288));

    // Fins
    final leftFin = Path()
      ..moveTo(120, 140)
      ..lineTo(100, 165)
      ..lineTo(120, 155)
      ..close();
    canvas.drawPath(leftFin, Paint()..color = const Color(0xFFFD8A6B));

    final rightFin = Path()
      ..moveTo(160, 140)
      ..lineTo(180, 165)
      ..lineTo(160, 155)
      ..close();
    canvas.drawPath(rightFin, Paint()..color = const Color(0xFFFD8A6B));

    // Motion lines
    final linePaint = Paint()
      ..color = const Color(0xFFFEC288).withValues(alpha: 0.4)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(40, 120), const Offset(25, 125), linePaint);
    canvas.drawLine(const Offset(35, 140), const Offset(20, 147), linePaint);
  }

  @override
  bool shouldRepaint(covariant _Illus3Painter old) =>
      old.flameScale != flameScale ||
      old.flameOpacity != flameOpacity ||
      old.smokeOpacity != smokeOpacity;
}

// ─────────────────────────────────────────────────────────────────────────────
// Drawing helpers
// ─────────────────────────────────────────────────────────────────────────────

void _rrect(
    Canvas canvas, double l, double t, double w, double h, double r, Color c) {
  canvas.drawRRect(
    RRect.fromLTRBR(l, t, l + w, t + h, Radius.circular(r)),
    Paint()..color = c,
  );
}

void _drawStar(Canvas canvas, Offset center, double size, Color color) {
  final paint = Paint()..color = color;
  final path = Path();
  const points = 5;
  final outerR = size;
  final innerR = size * 0.45;
  for (int i = 0; i < points * 2; i++) {
    final angle = (i * math.pi / points) - math.pi / 2;
    final r = i.isEven ? outerR : innerR;
    final x = center.dx + r * math.cos(angle);
    final y = center.dy + r * math.sin(angle);
    if (i == 0) {
      path.moveTo(x, y);
    } else {
      path.lineTo(x, y);
    }
  }
  path.close();
  canvas.drawPath(path, paint);
}



