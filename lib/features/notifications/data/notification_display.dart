import 'package:seyra/features/notifications/domain/entities/notification_models.dart';

abstract interface class NotificationDisplay {
  Future<void> initialize({
    required void Function(String conversationId) onTapConversation,
  });

  Future<void> show(IncomingAlert alert);

  Future<void> requestPermission();
}

final class NoopNotificationDisplay implements NotificationDisplay {
  @override
  Future<void> initialize({
    required void Function(String conversationId) onTapConversation,
  }) async {}

  @override
  Future<void> show(IncomingAlert alert) async {}

  @override
  Future<void> requestPermission() async {}
}
