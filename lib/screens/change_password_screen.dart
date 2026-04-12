import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/repositories/user_repository.dart';
import '../data/services/app_services.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  bool _isSubmitting = false;
  bool _isRefreshingVerification = false;
  bool _isSendingVerification = false;
  bool? _isEmailVerified;

  @override
  void initState() {
    super.initState();
    _refreshEmailVerificationStatus();
  }

  @override
  void dispose() {
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
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

  void _goBack() {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      context.pop();
      return;
    }
    context.go('/settings');
  }

  Future<void> _refreshEmailVerificationStatus() async {
    if (_isRefreshingVerification) return;
    setState(() => _isRefreshingVerification = true);
    try {
      final isVerified = await AppServices.userRepository
          .reloadAndCheckCurrentUserEmailVerified();
      if (!mounted) return;
      setState(() => _isEmailVerified = isVerified);
    } on UserRepositoryException catch (e) {
      if (!mounted) return;
      _showSnackBar(e.message);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Không thể kiểm tra trạng thái xác thực email.');
    } finally {
      if (mounted) {
        setState(() => _isRefreshingVerification = false);
      }
    }
  }

  Future<void> _sendEmailVerificationReminder() async {
    if (_isSendingVerification) return;
    setState(() => _isSendingVerification = true);
    try {
      await AppServices.userRepository.sendEmailVerificationForCurrentUser();
      if (!mounted) return;
      _showSnackBar(
        'Đã gửi email xác thực. Vui lòng mở email và xác thực rồi thử lại.',
        isError: false,
      );
    } on UserRepositoryException catch (e) {
      if (!mounted) return;
      _showSnackBar(e.message);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Không thể gửi email xác thực lúc này.');
    } finally {
      if (mounted) {
        setState(() => _isSendingVerification = false);
      }
    }
  }

  Future<void> _changePassword() async {
    if (_isSubmitting) return;
    if (_isEmailVerified != true) {
      _showSnackBar('Bạn cần xác thực email trước khi đổi mật khẩu.');
      return;
    }

    final newPassword = _newPasswordCtrl.text.trim();
    final confirmPassword = _confirmPasswordCtrl.text.trim();
    if (newPassword != confirmPassword) {
      _showSnackBar('Mật khẩu mới và nhập lại mật khẩu chưa khớp.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await AppServices.userRepository.changePasswordWithEmailVerification(
        currentPassword: _currentPasswordCtrl.text,
        newPassword: newPassword,
      );

      if (!mounted) return;
      _showSnackBar('Đổi mật khẩu thành công.', isError: false);
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      _goBack();
    } on UserRepositoryException catch (e) {
      if (!mounted) return;
      _showSnackBar(e.message);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Không thể đổi mật khẩu lúc này');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscureText,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            obscureText ? Icons.visibility_off_outlined : Icons.visibility,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Doi Mat Khau'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Chỉ hỗ trợ đổi mật khẩu khi email của bạn đã được xác thực. Vui lòng kiểm tra trạng thái xác thực email của bạn bên dưới.',
                style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isEmailVerified == true
                          ? Icons.verified_rounded
                          : Icons.mark_email_unread_outlined,
                      color: _isEmailVerified == true
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFB45309),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _isEmailVerified == true
                            ? 'Email đã xác thực.'
                            : 'Email chưa xác thực.',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF374151),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isRefreshingVerification
                          ? null
                          : _refreshEmailVerificationStatus,
                      child: _isRefreshingVerification
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Kiểm tra lại trạng thái xác thực'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSendingVerification
                          ? null
                          : _sendEmailVerificationReminder,
                      child: _isSendingVerification
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Gui email xac thuc'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildPasswordField(
                controller: _currentPasswordCtrl,
                label: 'Mật khẩu hiện tại',
                obscureText: _obscureCurrentPassword,
                onToggle: () {
                  setState(
                    () => _obscureCurrentPassword = !_obscureCurrentPassword,
                  );
                },
              ),

              const SizedBox(height: 10),
              _buildPasswordField(
                controller: _newPasswordCtrl,
                label: 'Mật khẩu mới',
                obscureText: _obscureNewPassword,
                onToggle: () {
                  setState(() => _obscureNewPassword = !_obscureNewPassword);
                },
              ),
              const SizedBox(height: 12),
              _buildPasswordField(
                controller: _confirmPasswordCtrl,
                label: 'Nhập lại mật khẩu mới',
                obscureText: _obscureConfirmPassword,
                onToggle: () {
                  setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword,
                  );
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_isSubmitting || _isEmailVerified != true)
                      ? null
                      : _changePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFA5C5C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSubmitting
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
                      : const Text('Xác thực và đổi mật khẩu'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _goBack,
                  child: const Text('Quay lại'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
