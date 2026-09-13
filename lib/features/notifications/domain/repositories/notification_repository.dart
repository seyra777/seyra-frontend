import 'package:seyra/core/errors/result.dart';
import 'package:seyra/features/notifications/domain/entities/notification_models.dart';

abstract interface class NotificationRepository {
  Future<Result<String>> registerDevice({
    required String platform,
    required String token,
  });

  Future<Result<void>> unregisterDevice(String deviceId);

  Future<Result<NotificationPreferences>> getPreferences();

  Future<Result<NotificationPreferences>> updatePreferences(
    NotificationPreferences preferences,
  );
}
