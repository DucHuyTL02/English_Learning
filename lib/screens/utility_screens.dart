import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/models/user_model.dart';
import '../data/repositories/user_repository.dart';
import '../data/services/app_services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFICATIONS SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  List<_NotifItem> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final items = await AppServices.notificationService.getNotifications();
    if (!mounted) return;

    setState(() {
      _notifications = items
          .map(
            (item) => _NotifItem(
              icon: _iconForType(item.type),
              title: item.title,
              desc: item.body,
              time: _timeAgo(item.createdAt),
              color: _colorForType(item.type),
            ),
          )
          .toList();
      _loading = false;
    });
  }

  String _timeAgo(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inHours < 1) return '${diff.inMinutes} phút trước';
    if (diff.inDays < 1) return '${diff.inHours} giờ trước';
    return '${diff.inDays} ngày trước';
  }

  String _iconForType(String type) {
    switch (type) {
      case 'achievement':
        return '🏆';
      case 'lesson':
        return '🎯';
      case 'push':
        return '🔔';
      default:
        return '📌';
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'achievement':
        return const Color(0xFFFA5C5C);
      case 'lesson':
        return const Color(0xFFFD8A6B);
      case 'push':
        return const Color(0xFFFEC288);
      default:
        return const Color(0xFFFBEF76);
    }
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
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              bottom: 16, left: 24, right: 24,
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => context.go('/home'),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(20)),
                    child: const Icon(Icons.arrow_back_rounded, size: 20, color: Color(0xFF374151)),
                  ),
                ),
                const SizedBox(width: 12),
                const Text('Thông Báo', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                const Spacer(),
                const Text('🔔', style: TextStyle(fontSize: 28)),
              ],
            ),
          ),
          Expanded(
            child: _notifications.isEmpty
                ? const Center(
                    child: Text(
                      'Chưa có thông báo nào',
                      style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: _notifications.length,
                         separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final n = _notifications[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white, borderRadius: BorderRadius.circular(16),
                          boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2))],
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 48, height: 48,
                              decoration: BoxDecoration(color: n.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
                              child: Center(child: Text(n.icon, style: const TextStyle(fontSize: 22))),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(n.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
                                  const SizedBox(height: 2),
                                  Text(n.desc, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                                ],
                              ),
                            ),
                            Text(n.time, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _NotifItem {
  const _NotifItem({required this.icon, required this.title, required this.desc, required this.time, required this.color});
  final String icon, title, desc, time;
  final Color color;
}

class LocalUsersDebugScreen extends StatefulWidget {
  const LocalUsersDebugScreen({super.key});

  @override
  State<LocalUsersDebugScreen> createState() => _LocalUsersDebugScreenState();
}

class _LocalUsersDebugScreenState extends State<LocalUsersDebugScreen> {
  bool _loading = true;
  List<UserModel> _users = const [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final users = await AppServices.userRepository.getAllLocalUsers();
    if (!mounted) return;
    setState(() {
      _users = users;
      _loading = false;
    });
  }

  String _displayFirebaseUid(String? uid) {
    if (uid == null || uid.isEmpty) return '(chua lien ket Firebase)';
    if (uid.length <= 12) return uid;
    return '${uid.substring(0, 6)}...${uid.substring(uid.length - 6)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug SQL Users'),
        actions: [
          IconButton(
            onPressed: _loadUsers,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? const Center(child: Text('Khong co user nao trong SQLite.'))
              : ListView.separated(
                  itemCount: _users.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final u = _users[index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(u.avatarEmoji),
                      ),
                      title: Text('${u.fullName} (#${u.id ?? '-'})'),
                      subtitle: Text(
                        '${u.email}\nactive: ${u.isActive ? 1 : 0} | firebase: ${_displayFirebaseUid(u.firebaseUid)}',
                      ),
                      isThreeLine: true,
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/home'),
        icon: const Icon(Icons.home_rounded),
        label: const Text('Home'),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUBSCRIPTION/PREMIUM SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Hero
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFFFA5C5C), Color(0xFFFD8A6B)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 12,
                bottom: 32, left: 24, right: 24,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.go('/profile'),
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                          child: const Icon(Icons.arrow_back_rounded, size: 20, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('👑', style: TextStyle(fontSize: 52)),
                  const SizedBox(height: 12),
                  const Text('LinguaJoy Premium', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 6),
                  Text('Mở khóa toàn bộ tính năng', style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.9))),
                ],
              ),
            ),
            // Features
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _FeatureRow(icon: '📚', title: 'Không giới hạn bài học', desc: 'Truy cập tất cả bài học mọi lúc'),
                  const SizedBox(height: 12),
                  _FeatureRow(icon: '🎤', title: 'Luyện phát âm nâng cao', desc: 'Phân tích phát âm chi tiết với AI'),
                  const SizedBox(height: 12),
                  _FeatureRow(icon: '📊', title: 'Báo cáo chi tiết', desc: 'Theo dõi tiến độ học tập chuyên sâu'),
                  const SizedBox(height: 12),
                  _FeatureRow(icon: '🚫', title: 'Không quảng cáo', desc: 'Trải nghiệm học tập liền mạch'),
                  const SizedBox(height: 24),
                  // Price cards
                  Row(
                    children: [
                      Expanded(
                        child: _PriceCard(title: 'Tháng', price: '99.000₫', sub: '/tháng', selected: false),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PriceCard(title: 'Năm', price: '599.000₫', sub: '/năm • Tiết kiệm 50%', selected: true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFA5C5C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: const StadiumBorder(),
                      ),
                      child: const Text('Bắt Đầu Dùng Thử 7 Ngày', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Hủy bất cứ lúc nào • Không mất phí trong 7 ngày', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.title, required this.desc});
  final String icon, title, desc;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2))]),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
              const SizedBox(height: 2),
              Text(desc, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            ],
          )),
        ],
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  const _PriceCard({required this.title, required this.price, required this.sub, required this.selected});
  final String title, price, sub;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? const Color(0xFFFA5C5C) : const Color(0xFFE5E7EB), width: selected ? 2 : 1),
        boxShadow: selected ? const [BoxShadow(color: Color(0x20FA5C5C), blurRadius: 12, offset: Offset(0, 4))] : null,
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          if (selected) Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: const Color(0xFFFA5C5C), borderRadius: BorderRadius.circular(20)),
            child: const Text('Phổ Biến', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          if (selected) const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
          const SizedBox(height: 6),
          Text(price, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
          const SizedBox(height: 4),
          Text(sub, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELP & SUPPORT SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final faqs = const [
      _FaqItem(q: 'Làm sao để bắt đầu học?', a: 'Vào trang chủ, nhấn "Bắt Đầu Bài Học" để bắt đầu bài học tiếp theo trong lộ trình.'),
      _FaqItem(q: 'Chuỗi ngày hoạt động thế nào?', a: 'Mỗi ngày bạn hoàn thành ít nhất một bài học, chuỗi sẽ tăng lên 1. Nếu bỏ qua một ngày, chuỗi sẽ reset về 0.'),
      _FaqItem(q: 'XP là gì?', a: 'XP (Experience Points) là điểm kinh nghiệm bạn nhận được khi hoàn thành bài học. Điểm càng cao, thứ hạng càng tốt.'),
      _FaqItem(q: 'Làm sao để lưu từ vựng?', a: 'Trong phần Từ Điển, bạn có thể thêm từ mới và quản lý các từ đã lưu.'),
      _FaqItem(q: 'Tôi quên mật khẩu, phải làm sao?', a: 'Vào Hồ Sơ → Cài Đặt → Đổi Mật Khẩu để thay đổi mật khẩu của bạn.'),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              bottom: 16, left: 24, right: 24,
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => context.go('/settings'),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(20)),
                    child: const Icon(Icons.arrow_back_rounded, size: 20, color: Color(0xFF374151)),
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Trợ Giúp & Hỗ Trợ', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                    Text('Câu hỏi thường gặp', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                  ],
                ),
                const Spacer(),
                const Text('💬', style: TextStyle(fontSize: 28)),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: faqs.length + 1,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index == faqs.length) {
                  // Contact section
                  return Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFFA5C5C), Color(0xFFFD8A6B)]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Text('Cần thêm hỗ trợ?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 6),
                        Text('Liên hệ với đội ngũ hỗ trợ', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.9))),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white, foregroundColor: const Color(0xFFFA5C5C),
                              padding: const EdgeInsets.symmetric(vertical: 14), shape: const StadiumBorder(),
                            ),
                            child: const Text('Gửi Phản Hồi', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => context.go('/debug/local-users'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white70),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: const StadiumBorder(),
                            ),
                            icon: const Icon(Icons.bug_report_rounded),
                            label: const Text('Mở SQL Debug Users'),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return _FaqCard(faq: faqs[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqItem {
  const _FaqItem({required this.q, required this.a});
  final String q, a;
}

class _FaqCard extends StatefulWidget {
  const _FaqCard({required this.faq});
  final _FaqItem faq;

  @override
  State<_FaqCard> createState() => _FaqCardState();
}

class _FaqCardState extends State<_FaqCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2))],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(widget.faq.q, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
                ),
                Icon(_expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF9CA3AF)),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 10),
              Text(widget.faq.a, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.5)),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CHANGE PASSWORD SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _error;
  bool _success = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() { _error = null; _success = false; });
    final current = _currentCtrl.text.trim();
    final newPw = _newCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();
    if (current.isEmpty || newPw.isEmpty || confirm.isEmpty) {
      setState(() => _error = 'Vui lòng điền đầy đủ thông tin');
      return;
    }
    if (newPw.length < 6) {
      setState(() => _error = 'Mật khẩu mới phải có ít nhất 6 ký tự');
      return;
    }
    if (newPw != confirm) {
      setState(() => _error = 'Mật khẩu xác nhận không khớp');
      return;
    }
    // Verify current password
    final user = await AppServices.userRepository.getActiveUser();
    if (user == null) {
      setState(() => _error = 'Không tìm thấy người dùng');
      return;
    }
    final verified = await AppServices.userRepository.verifyPassword(user.id!, current);
    if (!verified) {
      setState(() => _error = 'Mật khẩu hiện tại không đúng');
      return;
    }
    await AppServices.userRepository.updatePassword(user.id!, newPw);
    if (!mounted) return;
    setState(() => _success = true);
    _currentCtrl.clear();
    _newCtrl.clear();
    _confirmCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              color: Colors.white,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 12,
                bottom: 16, left: 24, right: 24,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.go('/settings'),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(20)),
                      child: const Icon(Icons.arrow_back_rounded, size: 20, color: Color(0xFF374151)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('Đổi Mật Khẩu', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                  const Spacer(),
                  const Text('🔐', style: TextStyle(fontSize: 28)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_success)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 20),
                          SizedBox(width: 8),
                          Text('Đổi mật khẩu thành công!', style: TextStyle(color: Color(0xFF166534), fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  if (_error != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 20),
                          const SizedBox(width: 8),
                          Flexible(child: Text(_error!, style: const TextStyle(color: Color(0xFF991B1B), fontWeight: FontWeight.w600))),
                        ],
                      ),
                    ),
                  _PasswordField(label: 'Mật khẩu hiện tại', controller: _currentCtrl,
                    obscure: _obscureCurrent, onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent)),
                  const SizedBox(height: 16),
                  _PasswordField(label: 'Mật khẩu mới', controller: _newCtrl,
                    obscure: _obscureNew, onToggle: () => setState(() => _obscureNew = !_obscureNew)),
                  const SizedBox(height: 16),
                  _PasswordField(label: 'Xác nhận mật khẩu mới', controller: _confirmCtrl,
                    obscure: _obscureConfirm, onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm)),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFA5C5C), foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16), shape: const StadiumBorder(),
                      ),
                      child: const Text('Đổi Mật Khẩu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

class _PasswordField extends StatelessWidget {
  const _PasswordField({required this.label, required this.controller, required this.obscure, required this.onToggle});
  final String label;
  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          decoration: InputDecoration(
            filled: true, fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFA5C5C), width: 2)),
            suffixIcon: IconButton(
              icon: Icon(obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: const Color(0xFF9CA3AF)),
              onPressed: onToggle,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FORGOT PASSWORD SCREEN (gửi email đặt lại mật khẩu)
// ─────────────────────────────────────────────────────────────────────────────

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  bool _isSubmitting = false;
  String? _error;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _emailSent = false;
    });

    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Vui lòng nhập email của bạn.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await AppServices.userRepository.sendPasswordResetEmail(email);
      if (!mounted) return;
      setState(() => _emailSent = true);
    } on UserRepositoryException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Không thể gửi email. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // ── Back button ──
              GestureDetector(
                onTap: () => Navigator.of(context).canPop()
                    ? Navigator.of(context).pop()
                    : context.go('/login'),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    size: 20,
                    color: Color(0xFF374151),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // ── Header ──
              const Center(
                child: Text(
                  '🔑',
                  style: TextStyle(fontSize: 56),
                ),
              ),
              const SizedBox(height: 20),
              const Center(
                child: Text(
                  'Quên Mật Khẩu?',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Nhập email để nhận liên kết đặt lại mật khẩu',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // ── Success banner ──
              if (_emailSent)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: const [
                      Icon(Icons.mark_email_read_rounded,
                          color: Color(0xFF22C55E), size: 36),
                      SizedBox(height: 10),
                      Text(
                        'Email đã được gửi!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF166534),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Kiểm tra hộp thư (và mục Spam) để nhận\n'
                        'liên kết đặt lại mật khẩu từ Firebase.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF166534),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Error banner ──
              if (_error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Color(0xFFDC2626), size: 20),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: Color(0xFF991B1B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Email field ──
              const Text(
                'Email',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'email.cua.ban@example.com',
                  hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                  prefixIcon: const Icon(Icons.mail_outline_rounded,
                      color: Color(0xFF9CA3AF)),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: Color(0xFFFA5C5C), width: 2),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ── Submit ──
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFA5C5C),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        const Color(0xFFFA5C5C).withValues(alpha: 0.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: const StadiumBorder(),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Gửi Email Đặt Lại',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Back to login ──
              Center(
                child: GestureDetector(
                  onTap: () => context.go('/login'),
                  child: const Text(
                    '← Quay lại Đăng Nhập',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFA5C5C),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
