import 'package:flutter_test/flutter_test.dart';
import 'package:seyra/core/errors/result.dart';
import 'package:seyra/core/network/api_client.dart';
import 'package:seyra/core/storage/memory_secure_storage.dart';
import 'package:seyra/features/auth/data/storage/auth_secure_storage_keys.dart';
import 'package:seyra/features/notifications/data/http_notification_repository.dart';
import 'package:seyra/features/notifications/domain/entities/notification_models.dart';

void main() {
  test('register device maps id and never echoes the token', () async {
    final api = _FakeApi()
      ..responses.add(
        const ApiResponse(statusCode: 201, body: '{"id":"dev_1","platform":"android"}'),
      );
    final storage = MemorySecureStorage();
    await storage.write(key: AuthSecureStorageKeys.accessToken, value: 'secret');
    final repo = HttpNotificationRepository(
      apiClient: api,
      secureStorage: storage,
      baseUrl: Uri.parse('http://127.0.0.1:8080'),
    );
    final result = await repo.registerDevice(
      platform: 'android',
      token: 'push-secret',
    );
    expect((result as Success<String>).value, 'dev_1');
    expect(api.lastBody.toString().contains('push-secret'), isTrue);
    expect(result.toString().contains('push-secret'), isFalse);
  });

  test('memory preferences round-trip', () async {
    final repo = MemoryNotificationRepository();
    await repo.updatePreferences(
      const NotificationPreferences(messagesEnabled: false, showPreview: false),
    );
    final prefs =
        (await repo.getPreferences() as Success<NotificationPreferences>).value;
    expect(prefs.messagesEnabled, isFalse);
    expect(prefs.showPreview, isFalse);
  });
}

final class _FakeApi implements ApiClient {
  final List<ApiResponse> responses = [];
  Object? lastBody;

  @override
  Future<ApiResponse> send({
    required String method,
    required Uri uri,
    Map<String, String>? headers,
    Object? jsonBody,
  }) async {
    lastBody = jsonBody;
    if (responses.isEmpty) {
      return const ApiResponse(statusCode: 500, body: '{}');
    }
    return responses.removeAt(0);
  }
}
