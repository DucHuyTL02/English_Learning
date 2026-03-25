import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/services/app_services.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _entryController;
  late AnimationController _pulseController;
  late AnimationController _dotsController;

  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;
  late Animation<double> _titleSlideAnim;
  late Animation<double> _titleOpacityAnim;
  late Animation<double> _taglineSlideAnim;
  late Animation<double> _taglineOpacityAnim;
  late Animation<double> _dotsOpacityAnim;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _scaleAnim = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOut));
    _opacityAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOut));

    _titleSlideAnim = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );
    _titleOpacityAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );

    _taglineSlideAnim = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.65, 1.0, curve: Curves.easeOut),
      ),
    );
    _taglineOpacityAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.65, 1.0, curve: Curves.easeOut),
      ),
    );

    _dotsOpacityAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _dotsController, curve: Curves.easeIn));

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _entryController.forward();
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) _dotsController.forward();
    });

    Timer(const Duration(milliseconds: 3000), _navigateFromSession);
  }

  Future<void> _navigateFromSession() async {
    final activeUser = await AppServices.userRepository.getActiveUser();
    if (!mounted) return;
    if (activeUser != null) {
      final lastRoute = AppServices.routeStateService.getLastRestorableRoute();
      context.go(lastRoute ?? '/home');
      return;
    }
    context.go('/login');
  }

  @override
  void dispose() {
    _entryController.dispose();
    _pulseController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFA5C5C), Color(0xFFFD8A6B)],
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _entryController,
              _pulseController,
              _dotsController,
            ]),
            builder: (context, _) {
              return Opacity(
                opacity: _opacityAnim.value,
                child: Transform.scale(
                  scale: _scaleAnim.value,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo
                      Transform.scale(
                        scale: _pulseAnim.value,
                        child: Container(
                          width: 192,
                          height: 192,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(40),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFBEF76).withValues(
                                  alpha:
                                      0.4 +
                                      0.4 * (_pulseAnim.value - 1.0) / 0.1,
                                ),
                                blurRadius:
                                    20 + 20 * (_pulseAnim.value - 1.0) / 0.1,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: CustomPaint(
                            painter: _BookLogoPainter(),
                            size: const Size(120, 120),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // App Name
                      Transform.translate(
                        offset: Offset(0, _titleSlideAnim.value),
                        child: Opacity(
                          opacity: _titleOpacityAnim.value,
                          child: const Text(
                            'LinguaJoy',
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Tagline
                      Transform.translate(
                        offset: Offset(0, _taglineSlideAnim.value),
                        child: Opacity(
                          opacity: _taglineOpacityAnim.value,
                          child: const Text(
                            'Học tiếng Anh vui vẻ mỗi ngày',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 48),

                      // Loading dots
                      Opacity(
                        opacity: _dotsOpacityAnim.value,
                        child: _BouncingDots(),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Bouncing dots loader
// ──────────────────────────────────────────────────────────────────────────────
class _BouncingDots extends StatefulWidget {
  @override
  State<_BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<_BouncingDots>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 800),
      ),
    );
    _anims = _controllers
        .map(
          (c) => Tween<double>(
            begin: 0,
            end: -15,
          ).animate(CurvedAnimation(parent: c, curve: Curves.easeInOut)),
        )
        .toList();

    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) _controllers[i].repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(_controllers),
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Transform.translate(
                offset: Offset(0, _anims[i].value),
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(
                      alpha: 0.5 + 0.5 * (_anims[i].value.abs() / 15),
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Book logo painter
// ──────────────────────────────────────────────────────────────────────────────
class _BookLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Centre the 120×120 drawing inside the 192×192 container
    canvas.translate((size.width - 120) / 2, (size.height - 120) / 2);

    final bookPaint = Paint()..color = const Color(0xFFFA5C5C);
    final whitePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Book body
    final rrect = RRect.fromLTRBR(22, 20, 98, 100, const Radius.circular(8));
    canvas.drawRRect(rrect, bookPaint);

    // Centre divider
    canvas.drawLine(const Offset(60, 20), const Offset(60, 100), whitePaint);

    // Left circle (yellow)
    canvas.drawCircle(
      const Offset(42, 50),
      8,
      Paint()..color = const Color(0xFFFBEF76),
    );
    // Right circle (peach)
    canvas.drawCircle(
      const Offset(78, 50),
      8,
      Paint()..color = const Color(0xFFFEC288),
    );

    // Left line
    canvas.drawLine(
      const Offset(42, 70),
      const Offset(50, 70),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    // Right line
    canvas.drawLine(
      const Offset(70, 70),
      const Offset(78, 70),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
