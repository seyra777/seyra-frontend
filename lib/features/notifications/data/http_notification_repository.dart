import 'dart:convert';

import 'package:seyra/core/errors/failures.dart';
import 'package:seyra/core/errors/network_failure.dart';
import 'package:seyra/core/errors/result.dart';
import 'package:seyra/core/network/api_client.dart';
import 'package:seyra/core/storage/secure_storage.dart';
import 'package:seyra/features/auth/data/storage/auth_secure_storage_keys.dart';
import 'package:seyra/features/auth/domain/failures/auth_failures.dart';
import 'package:seyra/features/notifications/domain/entities/notification_models.dart';
import 'package:seyra/features/notifications/domain/repositories/notification_repository.dart';

final class HttpNotificationRepository implements NotificationRepository {
  HttpNotificationRepository({
    required this.apiClient,
    required this.secureStorage,
    required this.baseUrl,
  });

  final ApiClient apiClient;
  final SecureStorage secureStorage;
  final Uri baseUrl;

  @override
  Future<Result<String>> registerDevice({
    required String platform,
    required String token,
  }) {
    return _map((json) => json['id'] as String? ?? '', () {
      return _send(
        method: 'POST',
        path: '/v1/notifications/devices',
        jsonBody: {'platform': platform, 'token': token},
      );
    });
  }

  @override
  Future<Result<void>> unregisterDevice(String deviceId) async {
    try {
      final access = await secureStorage.read(AuthSecureStorageKeys.accessToken);
      if (access == null || access.isEmpty) {
        return const FailureResult(UnauthorizedFailure());
      }
      final response = await apiClient.send(
        method: 'DELETE',
        uri: baseUrl.resolve('/v1/notifications/devices/$deviceId'),
        headers: {'Authorization': 'Bearer $access'},
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return const Success<void>(null);
      }
      return const FailureResult(NetworkFailure());
    } catch (_) {
      return const FailureResult(NetworkFailure());
    }
  }

  @override
  Future<Result<NotificationPreferences>> getPreferences() {
    return _map(_prefs, () {
      return _send(method: 'GET', path: '/v1/notifications/preferences');
    });
  }

  @override
  Future<Result<NotificationPreferences>> updatePreferences(
    NotificationPreferences preferences,
  ) {
    return _map(_prefs, () {
      return _send(
        method: 'PUT',
        path: '/v1/notifications/preferences',
        jsonBody: {
          'messages_enabled': preferences.messagesEnabled,
          'calls_enabled': preferences.callsEnabled,
          'show_preview': preferences.showPreview,
        },
      );
    });
  }

  NotificationPreferences _prefs(Map<String, dynamic> json) {
    return NotificationPreferences(
      messagesEnabled: json['messages_enabled'] as bool? ?? true,
      callsEnabled: json['calls_enabled'] as bool? ?? true,
      showPreview: json['show_preview'] as bool? ?? true,
    );
  }

  Future<Result<T>> _map<T>(
    T Function(Map<String, dynamic> json) parse,
    Future<ApiResponse> Function() send,
  ) async {
    try {
      final response = await send();
      if (response.statusCode == 401) {
        return const FailureResult(UnauthorizedFailure());
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const FailureResult(NetworkFailure());
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return const FailureResult(UnexpectedFailure());
      }
      return Success(parse(decoded));
    } catch (error) {
      if (error is StateError) {
        return const FailureResult(UnauthorizedFailure());
      }
      return const FailureResult(NetworkFailure());
    }
  }

  Future<ApiResponse> _send({
    required String method,
    required String path,
    Object? jsonBody,
  }) async {
    final access = await secureStorage.read(AuthSecureStorageKeys.accessToken);
    if (access == null || access.isEmpty) {
      throw StateError('unauthorized');
    }
    return apiClient.send(
      method: method,
      uri: baseUrl.resolve(path),
      headers: {'Authorization': 'Bearer $access'},
      jsonBody: jsonBody,
    );
  }
}

final class MemoryNotificationRepository implements NotificationRepository {
  NotificationPreferences _preferences = const NotificationPreferences();
  String? lastToken;

  @override
  Future<Result<String>> registerDevice({
    required String platform,
    required String token,
  }) async {
    lastToken = token;
    return const Success('dev_local');
  }

  @override
  Future<Result<void>> unregisterDevice(String deviceId) async {
    return const Success<void>(null);
  }

  @override
  Future<Result<NotificationPreferences>> getPreferences() async {
    return Success(_preferences);
  }

  @override
  Future<Result<NotificationPreferences>> updatePreferences(
    NotificationPreferences preferences,
  ) async {
    _preferences = preferences;
    return Success(_preferences);
  }
}
