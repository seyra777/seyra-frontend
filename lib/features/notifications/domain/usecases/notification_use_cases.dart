import 'package:seyra/core/errors/result.dart';
import 'package:seyra/features/notifications/domain/entities/notification_models.dart';
import 'package:seyra/features/notifications/domain/repositories/notification_repository.dart';

final class RegisterDeviceUseCase {
  const RegisterDeviceUseCase(this._repository);

  final NotificationRepository _repository;

  Future<Result<String>> call({
    required String platform,
    required String token,
  }) {
    return _repository.registerDevice(platform: platform, token: token);
  }
}

final class UnregisterDeviceUseCase {
  const UnregisterDeviceUseCase(this._repository);

  final NotificationRepository _repository;

  Future<Result<void>> call(String deviceId) {
    return _repository.unregisterDevice(deviceId);
  }
}

final class GetNotificationPreferencesUseCase {
  const GetNotificationPreferencesUseCase(this._repository);

  final NotificationRepository _repository;

  Future<Result<NotificationPreferences>> call() => _repository.getPreferences();
}

final class UpdateNotificationPreferencesUseCase {
  const UpdateNotificationPreferencesUseCase(this._repository);

  final NotificationRepository _repository;

  Future<Result<NotificationPreferences>> call(
    NotificationPreferences preferences,
  ) {
    return _repository.updatePreferences(preferences);
  }
}
