import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:seyra/features/notifications/data/notification_display.dart';
import 'package:seyra/features/notifications/domain/entities/notification_models.dart';

/// Presents OS notifications. Does not talk to FCM/APNs directly.
final class LocalNotificationDisplay implements NotificationDisplay {
  LocalNotificationDisplay({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  void Function(String conversationId)? _onTap;

  @override
  Future<void> initialize({
    required void Function(String conversationId) onTapConversation,
  }) async {
    _onTap = onTapConversation;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (response) {
        final id = response.payload;
        if (id != null && id.isNotEmpty) {
          _onTap?.call(id);
        }
      },
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final payload = launch?.notificationResponse?.payload;
    if (launch?.didNotificationLaunchApp == true &&
        payload != null &&
        payload.isNotEmpty) {
      onTapConversation(payload);
    }
  }

  @override
  Future<void> requestPermission() async {
    if (kIsWeb) {
      return;
    }
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  bool playSound = true;

  @override
  Future<void> show(IncomingAlert alert) async {
    final android = AndroidNotificationDetails(
      'seyra_messages',
      'Messages',
      channelDescription: 'New Seyra messages',
      importance: Importance.high,
      priority: Priority.high,
      playSound: playSound,
    );
    await _plugin.show(
      alert.messageId.hashCode,
      alert.title,
      alert.body,
      NotificationDetails(
        android: android,
        iOS: DarwinNotificationDetails(presentSound: playSound),
      ),
      payload: alert.conversationId,
    );
  }
}
