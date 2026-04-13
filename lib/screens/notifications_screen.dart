import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/models/app_notification_model.dart';
import '../data/services/app_services.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  List<AppNotificationModel> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = await AppServices.userRepository.getActiveUser();
    if (user?.id == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _items = const [];
      });
      return;
    }

    final notifications = await AppServices.notificationService.getByUser(
      user!.id!,
    );
    await AppServices.notificationService.markAllAsRead(user.id!);

    if (!mounted) return;
    setState(() {
      _loading = false;
      _items = notifications;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Thông Báo'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? _buildEmpty()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemBuilder: (_, index) => _NotificationTile(
                  item: _items[index],
                  onTap: () {
                    final payload = _items[index].payload.trim();
                    if (payload.isNotEmpty) {
                      context.go(payload);
                    }
                  },
                ),
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemCount: _items.length,
              ),
            ),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFFA5C5C).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              size: 40,
              color: Color(0xFFFA5C5C),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'Chưa có thông báo nào',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            'Khi hoàn thành bài học hoặc có nhắc học,\nthông báo sẽ xuất hiện tại đây.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
        ),
      ],
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onTap});

  final AppNotificationModel item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconData = switch (item.type) {
      'lesson_completed' => Icons.emoji_events_rounded,
      'study_reminder' => Icons.alarm_rounded,
      'friend_request_received' => Icons.person_add_alt_1_rounded,
      'friend_request_accepted' => Icons.handshake_rounded,
      'leaderboard_rank_up' => Icons.trending_up_rounded,
      'leaderboard_overtaken' => Icons.trending_down_rounded,
      _ => Icons.notifications_active_outlined,
    };
    final iconColor = switch (item.type) {
      'lesson_completed' => const Color(0xFF22C55E),
      'study_reminder' => const Color(0xFFFA5C5C),
      'friend_request_received' => const Color(0xFF3B82F6),
      'friend_request_accepted' => const Color(0xFF10B981),
      'leaderboard_rank_up' => const Color(0xFF8B5CF6),
      'leaderboard_overtaken' => const Color(0xFFF59E0B),
      _ => const Color(0xFF6366F1),
    };

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(iconData, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.message,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatTime(item.createdAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9CA3AF),
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

  static String _formatTime(DateTime value) {
    final now = DateTime.now();
    final diff = now.difference(value);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    return '${value.day}/${value.month}/${value.year}';
  }
}
