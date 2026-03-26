import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/repositories/user_repository.dart';
import '../data/services/app_services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shared widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Mini LinguaJoy book logo used in both auth screens.
class _AuthLogo extends StatelessWidget {
  const _AuthLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
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
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: CustomPaint(
          size: const Size(48, 48),
          painter: _MiniBookPainter(),
        ),
      ),
    );
  }
}

class _MiniBookPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Outer book (scaled 48×48 from the 48×48 SVG viewBox)
    final rrect = RRect.fromLTRBR(
      size.width * (8 / 48),
      size.height * (8 / 48),
      size.width * (40 / 48),
      size.height * (40 / 48),
      Radius.circular(size.width * (4 / 48)),
    );
    canvas.drawRRect(rrect, Paint()..color = Colors.white);

    // Centre divider
    canvas.drawLine(
      Offset(size.width / 2, size.height * (8 / 48)),
      Offset(size.width / 2, size.height * (40 / 48)),
      Paint()
        ..color = const Color(0xFFFA5C5C)
        ..strokeWidth = size.width * (2 / 48),
    );

    // Left dot (yellow)
    canvas.drawCircle(
      Offset(size.width * (17 / 48), size.height * (20 / 48)),
      size.width * (3 / 48),
      Paint()..color = const Color(0xFFFBEF76),
    );

    // Right dot (peach)
    canvas.drawCircle(
      Offset(size.width * (31 / 48), size.height * (20 / 48)),
      size.width * (3 / 48),
      Paint()..color = const Color(0xFFFEC288),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Styled text field used by both screens.
class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    this.obscure = false,
    this.toggleObscure,
    this.keyboardType,
  });

  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final bool obscure;
  final VoidCallback? toggleObscure;
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
          obscureText: obscure,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 15, color: Color(0xFF111827)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
            prefixIcon: Icon(icon, color: const Color(0xFF9CA3AF), size: 20),
            suffixIcon: toggleObscure != null
                ? IconButton(
                    icon: Icon(
                      obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: const Color(0xFF9CA3AF),
                      size: 20,
                    ),
                    onPressed: toggleObscure,
                    splashRadius: 18,
                  )
                : null,
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
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

/// Full-width gradient primary button.
class _PrimaryButton extends StatefulWidget {
  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });
  final String label;
  final VoidCallback onPressed;
  final bool isLoading;

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  double _scale = 1.0;
  bool get _isEnabled => !widget.isLoading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _isEnabled ? (_) => setState(() => _scale = 0.98) : null,
      onTapUp: _isEnabled
          ? (_) {
              setState(() => _scale = 1.0);
              widget.onPressed();
            }
          : null,
      onTapCancel: _isEnabled ? () => setState(() => _scale = 1.0) : null,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Opacity(
          opacity: _isEnabled ? 1 : 0.85,
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
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: widget.isLoading
                ? const SizedBox(
                    height: 24,
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                    ),
                  )
                : Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// "Or" divider row.
class _OrDivider extends StatelessWidget {
  const _OrDivider();
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFE5E7EB), thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Hoặc',
            style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
          ),
        ),
        const Expanded(child: Divider(color: Color(0xFFE5E7EB), thickness: 1)),
      ],
    );
  }
}

/// Google social button.
class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () {},
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: const StadiumBorder(),
        side: const BorderSide(color: Color(0xFFE5E7EB), width: 2),
        backgroundColor: Colors.white,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _GoogleLogo(),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(20, 20), painter: _GoogleLogoPainter());
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    // Blue
    final p1 = Path()
      ..moveTo(s.width * 0.98, s.height * 0.5115)
      ..lineTo(s.width * 0.98, s.height * 0.5115)
      ..cubicTo(
        s.width * 0.98,
        s.height * 0.471,
        s.width * 0.9765,
        s.height * 0.432,
        s.width * 0.97,
        s.height * 0.394,
      )
      ..lineTo(s.width * 0.5, s.height * 0.394)
      ..lineTo(s.width * 0.5, s.height * 0.607)
      ..lineTo(s.width * 0.796, s.height * 0.607)
      ..cubicTo(
        s.width * 0.783,
        s.height * 0.655,
        s.width * 0.748,
        s.height * 0.694,
        s.width * 0.699,
        s.height * 0.721,
      )
      ..lineTo(s.width * 0.857, s.height * 0.859)
      ..cubicTo(
        s.width * 0.961,
        s.height * 0.763,
        s.width * 0.98,
        s.height * 0.645,
        s.width * 0.98,
        s.height * 0.5115,
      )
      ..close();
    canvas.drawPath(p1, Paint()..color = const Color(0xFF4285F4));

    // Green
    final p2 = Path()
      ..moveTo(s.width * 0.5, s.height)
      ..cubicTo(
        s.width * 0.6485,
        s.height,
        s.width * 0.773,
        s.height * 0.951,
        s.width * 0.857,
        s.height * 0.859,
      )
      ..lineTo(s.width * 0.699, s.height * 0.721)
      ..cubicTo(
        s.width * 0.651,
        s.height * 0.754,
        s.width * 0.5795,
        s.height * 0.773,
        s.width * 0.5,
        s.height * 0.773,
      )
      ..cubicTo(
        s.width * 0.357,
        s.height * 0.773,
        s.width * 0.2355,
        s.height * 0.676,
        s.width * 0.192,
        s.height * 0.547,
      )
      ..lineTo(s.width * 0.0285, s.height * 0.689)
      ..cubicTo(
        s.width * 0.1095,
        s.height * 0.878,
        s.width * 0.2885,
        s.height,
        s.width * 0.5,
        s.height,
      )
      ..close();
    canvas.drawPath(p2, Paint()..color = const Color(0xFF34A853));

    // Yellow
    final p3 = Path()
      ..moveTo(s.width * 0.192, s.height * 0.547)
      ..cubicTo(
        s.width * 0.181,
        s.height * 0.514,
        s.width * 0.175,
        s.height * 0.479,
        s.width * 0.175,
        s.height * 0.443,
      )
      ..cubicTo(
        s.width * 0.175,
        s.height * 0.407,
        s.width * 0.181,
        s.height * 0.372,
        s.width * 0.192,
        s.height * 0.339,
      )
      ..lineTo(s.width * 0.0285, s.height * 0.197)
      ..cubicTo(
        s.width * -0.006,
        s.height * 0.271,
        s.width * -0.025,
        s.height * 0.355,
        s.width * -0.025,
        s.height * 0.443,
      )
      ..cubicTo(
        s.width * -0.025,
        s.height * 0.531,
        s.width * -0.006,
        s.height * 0.615,
        s.width * 0.0285,
        s.height * 0.689,
      )
      ..close();
    canvas.drawPath(p3, Paint()..color = const Color(0xFFFBBC05));

    // Red
    final p4 = Path()
      ..moveTo(s.width * 0.5, s.height * 0.113)
      ..cubicTo(
        s.width * 0.581,
        s.height * 0.113,
        s.width * 0.653,
        s.height * 0.14,
        s.width * 0.71,
        s.height * 0.192,
      )
      ..lineTo(s.width * 0.868, s.height * 0.034)
      ..cubicTo(
        s.width * 0.772,
        s.height * -0.048,
        s.width * 0.64,
        s.height * -0.1,
        s.width * 0.5,
        s.height * -0.1,
      )
      ..cubicTo(
        s.width * 0.2885,
        s.height * -0.1,
        s.width * 0.1095,
        s.height * 0.022,
        s.width * 0.0285,
        s.height * 0.211,
      )
      ..lineTo(s.width * 0.192, s.height * 0.353)
      ..cubicTo(
        s.width * 0.2355,
        s.height * 0.224,
        s.width * 0.357,
        s.height * 0.113,
        s.width * 0.5,
        s.height * 0.113,
      )
      ..close();
    canvas.drawPath(p4, Paint()..color = const Color(0xFFEA4335));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Slide-in animation wrapper
// ─────────────────────────────────────────────────────────────────────────────
class _SlideIn extends StatefulWidget {
  const _SlideIn({required this.child, this.delay = 0, this.dy = 20.0});
  final Widget child;
  final int delay;
  final double dy;

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
      begin: widget.dy,
      end: 0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _opacity = Tween<double>(
      begin: 0,
      end: 1,
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
          offset: Offset(0, _slide.value),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOGIN SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('Vui lòng nhập đầy đủ email và mật khẩu.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await AppServices.userRepository.login(email: email, password: password);
      if (!mounted) return;
      context.go('/home');
    } on UserRepositoryException catch (e) {
      if (!mounted) return;
      _showSnackBar(e.message);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Đăng nhập thất bại. Vui lòng thử lại.');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const SizedBox(height: 40),

              // ── Header ──
              _SlideIn(
                delay: 0,
                dy: -20,
                child: Column(
                  children: const [
                    _AuthLogo(),
                    SizedBox(height: 20),
                    Text(
                      'Chào Mừng Trở Lại!',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Đăng nhập để tiếp tục học',
                      style: TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // ── Form ──
              _SlideIn(
                delay: 200,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AuthField(
                      label: 'Email',
                      hint: 'email.cua.ban@example.com',
                      icon: Icons.mail_outline_rounded,
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 20),
                    _AuthField(
                      label: 'Mật khẩu',
                      hint: 'Nhập mật khẩu của bạn',
                      icon: Icons.lock_outline_rounded,
                      controller: _passCtrl,
                      obscure: _obscure,
                      toggleObscure: () => setState(() => _obscure = !_obscure),
                    ),
                    const SizedBox(height: 10),

                    // Forgot password
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () => context.push('/reset-password'),
                        child: const Text(
                          'Quên mật khẩu?',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFFA5C5C),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    _PrimaryButton(
                      label: 'Đăng Nhập',
                      isLoading: _isSubmitting,
                      onPressed: () => _login(),
                    ),

                    const SizedBox(height: 24),
                    const _OrDivider(),
                    const SizedBox(height: 20),

                    const _GoogleButton(label: 'Tiếp tục với Google'),

                    const SizedBox(height: 32),

                    // Sign-up link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Chưa có tài khoản? ',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => context.go('/register'),
                          child: const Text(
                            'Đăng ký ngay',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFA5C5C),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REGISTER SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _termsAccepted = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final fullName = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;

    if (fullName.isEmpty || email.isEmpty || password.isEmpty) {
      _showSnackBar('Vui lòng nhập đầy đủ thông tin đăng ký.');
      return;
    }
    if (!_termsAccepted) {
      _showSnackBar('Vui lòng chấp nhận điều khoản và điều kiện.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await AppServices.userRepository.registerUser(
        fullName: fullName,
        email: email,
        password: password,
      );
      if (!mounted) return;
      context.go('/home');
    } on UserRepositoryException catch (e) {
      if (!mounted) return;
      _showSnackBar(e.message);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Đăng ký thất bại. Vui lòng thử lại.');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const SizedBox(height: 40),

              // ── Header ──
              _SlideIn(
                delay: 0,
                dy: -20,
                child: Column(
                  children: const [
                    _AuthLogo(),
                    SizedBox(height: 20),
                    Text(
                      'Tạo Tài Khoản',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Đăng ký để bắt đầu hành trình học tập',
                      style: TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // ── Form ──
              _SlideIn(
                delay: 200,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AuthField(
                      label: 'Họ Tên',
                      hint: 'Nhập họ tên của bạn',
                      icon: Icons.person_outline_rounded,
                      controller: _nameCtrl,
                    ),
                    const SizedBox(height: 18),
                    _AuthField(
                      label: 'Email',
                      hint: 'email.cua.ban@example.com',
                      icon: Icons.mail_outline_rounded,
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 18),
                    _AuthField(
                      label: 'Mật khẩu',
                      hint: 'Tạo mật khẩu mạnh',
                      icon: Icons.lock_outline_rounded,
                      controller: _passCtrl,
                      obscure: _obscure,
                      toggleObscure: () => setState(() => _obscure = !_obscure),
                    ),
                    const SizedBox(height: 18),

                    // Terms checkbox
                    GestureDetector(
                      onTap: () =>
                          setState(() => _termsAccepted = !_termsAccepted),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            margin: const EdgeInsets.only(top: 1),
                            decoration: BoxDecoration(
                              color: _termsAccepted
                                  ? const Color(0xFFFA5C5C)
                                  : Colors.white,
                              border: Border.all(
                                color: _termsAccepted
                                    ? const Color(0xFFFA5C5C)
                                    : const Color(0xFFD1D5DB),
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: _termsAccepted
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 14,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: RichText(
                              text: const TextSpan(
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF6B7280),
                                ),
                                children: [
                                  TextSpan(text: 'Tôi đồng ý với '),
                                  TextSpan(
                                    text: 'Điều khoản & Điều kiện',
                                    style: TextStyle(
                                      color: Color(0xFFFA5C5C),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  TextSpan(text: ' và '),
                                  TextSpan(
                                    text: 'Chính sách Bảo mật',
                                    style: TextStyle(
                                      color: Color(0xFFFA5C5C),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    _PrimaryButton(
                      label: 'Đăng Ký',
                      isLoading: _isSubmitting,
                      onPressed: () => _register(),
                    ),

                    const SizedBox(height: 24),
                    const _OrDivider(),
                    const SizedBox(height: 20),

                    const _GoogleButton(label: 'Google'),

                    const SizedBox(height: 32),

                    // Login link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Đã có tài khoản? ',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => context.go('/login'),
                          child: const Text(
                            'Đăng nhập',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFA5C5C),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
