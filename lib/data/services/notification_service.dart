import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_database.dart';
import '../models/app_notification_model.dart';
import '../models/user_model.dart';

class NotificationService {
  NotificationService({
    required AppDatabase database,
    FlutterLocalNotificationsPlugin? localNotificationsPlugin,
  }) : _database = database,
       _plugin = localNotificationsPlugin ?? FlutterLocalNotificationsPlugin();

  static const String _lessonChannelId = 'lesson_updates_channel';
  static const String _lessonChannelName = 'Lesson Updates';
  static const String _lessonChannelDescription =
      'Notification when finishing lessons';

  static const String _reminderChannelId = 'study_reminder_channel';
  static const String _reminderChannelName = 'Study Reminder';
  static const String _reminderChannelDescription =
      'Daily reminders to keep learning';

  static const String _socialChannelId = 'social_updates_channel';
  static const String _socialChannelName = 'Social Updates';
  static const String _socialChannelDescription =
      'Friend requests and social updates';

  static const String _leaderboardChannelId = 'leaderboard_updates_channel';
  static const String _leaderboardChannelName = 'Leaderboard Updates';
  static const String _leaderboardChannelDescription =
      'Ranking changes among friends';

  final AppDatabase _database;
  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(settings);

    await _requestPermission();
    _initialized = true;
  }

  Future<void> notifyLessonCompleted({
    required UserModel user,
    required int lessonId,
    required String lessonTitle,
    required int score,
    required int xpEarned,
  }) async {
    if (user.id == null) return;

    final title = 'Hoàn thành chủ đề: $lessonTitle';
    final message = 'Bạn đã đạt $score% và nhận +$xpEarned XP. Tiếp tục nhé!';
    await _insertNotification(
      userId: user.id!,
      type: 'lesson_completed',
      title: title,
      message: message,
      payload: '/lesson-intro?lessonId=$lessonId',
      showSystem: user.notificationsEnabled,
      channelId: _lessonChannelId,
      channelName: _lessonChannelName,
      channelDescription: _lessonChannelDescription,
    );
  }

  Future<void> notifyFriendRequestReceived({
    required UserModel user,
    required String requestId,
    required String fromName,
    String? dedupeToken,
  }) async {
    if (user.id == null) return;
    final trimmedId = requestId.trim();
    if (trimmedId.isEmpty) return;

    final sender = _safeName(fromName);
    final token = (dedupeToken ?? trimmedId).trim();
    await _insertNotification(
      userId: user.id!,
      type: 'friend_request_received',
      title: 'Lời mời kết bạn mới',
      message: '$sender đã gửi lời mời kết bạn cho bạn.',
      payload:
          '/friends?requestId=$trimmedId&event=${Uri.encodeQueryComponent(token)}',
      showSystem: user.notificationsEnabled,
      channelId: _socialChannelId,
      channelName: _socialChannelName,
      channelDescription: _socialChannelDescription,
      dedupeByTypeAndPayload: true,
    );
  }

  Future<void> notifyFriendRequestAccepted({
    required UserModel user,
    required String requestId,
    required String friendName,
    String? dedupeToken,
  }) async {
    if (user.id == null) return;
    final trimmedId = requestId.trim();
    if (trimmedId.isEmpty) return;

    final friend = _safeName(friendName);
    final token = (dedupeToken ?? trimmedId).trim();
    await _insertNotification(
      userId: user.id!,
      type: 'friend_request_accepted',
      title: 'Lời mời đã được chấp nhận',
      message: '$friend đã chấp nhận lời mời kết bạn của bạn.',
      payload:
          '/friends?acceptedRequestId=$trimmedId&event=${Uri.encodeQueryComponent(token)}',
      showSystem: user.notificationsEnabled,
      channelId: _socialChannelId,
      channelName: _socialChannelName,
      channelDescription: _socialChannelDescription,
      dedupeByTypeAndPayload: true,
    );
  }

  Future<void> notifyLeaderboardRankUp({
    required UserModel user,
    required int previousRank,
    required int currentRank,
  }) async {
    if (user.id == null) return;
    if (previousRank <= 0 || currentRank <= 0 || currentRank >= previousRank) {
      return;
    }

    await _insertNotification(
      userId: user.id!,
      type: 'leaderboard_rank_up',
      title: 'Bạn vua thăng hạng!',
      message:
          'Bạn đã tăng từ hạng #$previousRank lên #$currentRank trên bảng xếp hạng bạn bè.',
      payload: '/leaderboard',
      showSystem: user.notificationsEnabled,
      channelId: _leaderboardChannelId,
      channelName: _leaderboardChannelName,
      channelDescription: _leaderboardChannelDescription,
    );
  }

  Future<void> notifyLeaderboardOvertaken({
    required UserModel user,
    required String friendName,
    required int currentRank,
  }) async {
    if (user.id == null) return;
    if (currentRank <= 0) return;

    final friend = _safeName(friendName);
    await _insertNotification(
      userId: user.id!,
      type: 'leaderboard_overtaken',
      title: 'Bạn vua bị vượt hạng',
      message: '$friend vua vượt bạn trên bảng xếp hạng bạn bè.',
      payload: '/leaderboard',
      showSystem: user.notificationsEnabled,
      channelId: _leaderboardChannelId,
      channelName: _leaderboardChannelName,
      channelDescription: _leaderboardChannelDescription,
    );
  }

  Future<void> maybeSendDailyStudyReminder({required UserModel user}) async {
    if (user.id == null || !user.notificationsEnabled) return;

    final dateKey = _todayKey();
    final prefs = await SharedPreferences.getInstance();
    final prefKey = 'last_study_reminder_user_${user.id}';
    if (prefs.getString(prefKey) == dateKey) {
      return;
    }

    final hasActivity = await _hasTodayActivity(user.id!);
    if (hasActivity) {
      return;
    }

    await _insertNotification(
      userId: user.id!,
      type: 'study_reminder',
      title: 'Nhắc học tập hôm nay',
      message: 'Hãy dành 10 phút luyện tiếng Anh để giữ chuỗi học tập nhe!',
      payload: '/home',
      showSystem: true,
      channelId: _reminderChannelId,
      channelName: _reminderChannelName,
      channelDescription: _reminderChannelDescription,
    );
    await prefs.setString(prefKey, dateKey);
  }

  Future<List<AppNotificationModel>> getByUser(int userId) async {
    final db = await _database.database;
    final rows = await db.query(
      AppDatabase.notificationsTable,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return rows.map(AppNotificationModel.fromMap).toList();
  }

  Future<int> getUnreadCount(int userId) async {
    final db = await _database.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM ${AppDatabase.notificationsTable} WHERE user_id = ? AND is_read = 0',
      [userId],
    );
    final total = rows.first['total'];
    if (total is int) return total;
    if (total is num) return total.toInt();
    return 0;
  }

  Future<void> markAllAsRead(int userId) async {
    final db = await _database.database;
    await db.update(
      AppDatabase.notificationsTable,
      {'is_read': 1},
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  Future<bool> _hasTodayActivity(int userId) async {
    final db = await _database.database;
    final rows = await db.query(
      AppDatabase.dailyActivityTable,
      where: 'user_id = ? AND date = ?',
      whereArgs: [userId, _todayKey()],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> _insertNotification({
    required int userId,
    required String type,
    required String title,
    required String message,
    required String payload,
    required bool showSystem,
    required String channelId,
    required String channelName,
    required String channelDescription,
    bool dedupeByTypeAndPayload = false,
  }) async {
    final db = await _database.database;

    if (dedupeByTypeAndPayload) {
      final existing = await db.query(
        AppDatabase.notificationsTable,
        columns: const ['id'],
        where: 'user_id = ? AND type = ? AND payload = ?',
        whereArgs: [userId, type, payload],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        return;
      }
    }

    final createdAt = DateTime.now().toIso8601String();
    final id = await db.insert(AppDatabase.notificationsTable, {
      'user_id': userId,
      'type': type,
      'title': title,
      'message': message,
      'payload': payload,
      'is_read': 0,
      'created_at': createdAt,
    });

    if (!showSystem || kIsWeb) return;

    const iosDetails = DarwinNotificationDetails();
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    await _plugin.show(id, title, message, details, payload: payload);
  }

  Future<void> _requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestNotificationsPermission();

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _safeName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Mot nguoi ban';
    return trimmed;
  }
}
