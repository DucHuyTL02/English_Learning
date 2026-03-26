import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.type,
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final String type;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'createdAt': createdAt.toIso8601String(),
      'type': type,
    };
  }

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    final createdAtRaw = map['createdAt'] as String?;
    return AppNotification(
      id: (map['id'] as String?) ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: (map['title'] as String?) ?? 'Thông báo',
      body: (map['body'] as String?) ?? '',
      createdAt: DateTime.tryParse(createdAtRaw ?? '') ?? DateTime.now(),
      type: (map['type'] as String?) ?? 'general',
    );
  }
}

class NotificationService {
  NotificationService({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _localNotifications = localNotifications ?? FlutterLocalNotificationsPlugin();

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;

  static const _storageKey = 'in_app_notifications_v1';
  static const _maxItems = 50;

  Future<void> initialize() async {
    await _initializeLocalNotifications();
    await _initializePushMessaging();
  }

  Future<List<AppNotification>> getNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final list = decoded
          .whereType<Map>()
          .map((item) => AppNotification.fromMap(Map<String, dynamic>.from(item)))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (_) {
      return const [];
    }
  }

  Future<void> addEvent({
    required String title,
    required String body,
    String type = 'general',
    bool showLocalToast = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getNotifications();
    final notification = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      body: body,
      createdAt: DateTime.now(),
      type: type,
    );

    final merged = <AppNotification>[notification, ...current];
    final trimmed = merged.take(_maxItems).toList();
    await prefs.setString(
      _storageKey,
      jsonEncode(trimmed.map((item) => item.toMap()).toList()),
    );

    if (showLocalToast) {
      await _showLocalNotification(notification);
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings, iOS: DarwinInitializationSettings());
    await _localNotifications.initialize(settings);
  }

  Future<void> _initializePushMessaging() async {
    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        final title = message.notification?.title ?? 'Thông báo mới';
        final body = message.notification?.body ?? 'Bạn có cập nhật mới.';
        await addEvent(
          title: title,
          body: body,
          type: 'push',
          showLocalToast: true,
        );
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
        final title = message.notification?.title ?? 'Thông báo';
        final body = message.notification?.body ?? 'Bạn vừa mở một thông báo.';
        await addEvent(title: title, body: body, type: 'push_opened');
      });

      final token = await _messaging.getToken();
      if (kDebugMode && token != null) {
        debugPrint('FCM token: $token');
      }
    } catch (_) {
      // Ignore in unsupported environments.
    }
  }

  Future<void> _showLocalNotification(AppNotification notification) async {
    const androidDetails = AndroidNotificationDetails(
      'english_learning_general',
      'General Notifications',
      channelDescription: 'Thông báo học tập và thành tích',
      importance: Importance.max,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails, iOS: DarwinNotificationDetails());

    await _localNotifications.show(
      notification.createdAt.millisecondsSinceEpoch ~/ 1000,
      notification.title,
      notification.body,
      details,
    );
  }
}
