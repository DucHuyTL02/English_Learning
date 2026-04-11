import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/repositories/user_repository.dart';
import '../data/services/app_services.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  StreamSubscription<bool>? _verificationSub;
  bool _isChecking = false;
  bool _isResending = false;
  String _email = '';

  @override
  void initState() {
    super.initState();
    _email = AppServices.userRepository.currentFirebaseUser?.email ?? '';
    _sendInitialVerificationEmailSilently();
    _startWatchingVerification();
  }

  Future<void> _sendInitialVerificationEmailSilently() async {
    try {
      await AppServices.userRepository.sendEmailVerificationForCurrentUser();
    } catch (_) {
      // best effort
    }
  }

  void _startWatchingVerification() {
    final currentUser = AppServices.userRepository.currentFirebaseUser;
    if (currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.go('/login');
      });
      return;
    }

    _verificationSub = AppServices.userRepository
        .watchCurrentUserEmailVerified()
        .listen((isVerified) async {
          if (!mounted || !isVerified) return;
          try {
            await AppServices.userRepository.syncVerifiedCurrentUserToLocal();
          } catch (_) {
            // best effort
          }
          if (!mounted) return;
          context.go('/home');
        });
  }

  @override
  void dispose() {
    _verificationSub?.cancel();
    super.dispose();
  }

  Future<void> _checkNow() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);
    try {
      final isVerified = await AppServices.userRepository
          .reloadAndCheckCurrentUserEmailVerified();
      if (!mounted) return;
      if (!isVerified) {
        _showSnackBar('Email của bạn chưa được xác thực.');
        return;
      }
      await AppServices.userRepository.syncVerifiedCurrentUserToLocal();
      if (!mounted) return;
      context.go('/home');
    } on UserRepositoryException catch (e) {
      if (!mounted) return;
      _showSnackBar(e.message);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Không thể kiểm tra trạng thái xác thực.');
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  Future<void> _resendVerificationEmail() async {
    if (_isResending) return;
    setState(() => _isResending = true);
    try {
      await AppServices.userRepository.sendEmailVerificationForCurrentUser();
      if (!mounted) return;
      _showSnackBar('Đã gửi lại email xác thực.', isError: false);
    } on UserRepositoryException catch (e) {
      if (!mounted) return;
      _showSnackBar(e.message);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Không thể gửi lại email xác thực.');
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  Future<void> _backToLogin() async {
    try {
      await AppServices.userRepository.logoutActiveUser();
    } catch (_) {
      // best effort
    }
    if (!mounted) return;
    context.go('/login');
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? const Color(0xFFFA5C5C)
            : const Color(0xFF16A34A),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Xác Thực Email'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tài khoản đã được tạo thành công.',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Chúng tôi đã gửi email xác thực tới:\n${_email.isEmpty ? '(không có email)' : _email}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF4B5563),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Bạn cần xác thực email trước khi vào màn hình chính.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isChecking ? null : _checkNow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFA5C5C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isChecking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text('Tôi Đã Xác Thực'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isResending ? null : _resendVerificationEmail,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(
                      color: Color(0xFFE5E7EB),
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isResending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Gửi Lại Email Xác Thực',
                          style: TextStyle(color: Color(0xFF374151)),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _backToLogin,
                  child: const Text(
                    'Quay Lại Đăng Nhập',
                    style: TextStyle(color: Color(0xFF6B7280)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
