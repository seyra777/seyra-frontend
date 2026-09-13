import 'package:flutter_test/flutter_test.dart';
import 'package:seyra/core/network/api_client.dart';
import 'package:seyra/core/storage/memory_secure_storage.dart';
import 'package:seyra/features/auth/data/datasources/http_auth_remote_data_source.dart';
import 'package:seyra/features/auth/data/exceptions/auth_remote_exceptions.dart';
import 'package:seyra/features/auth/data/storage/auth_secure_storage_keys.dart';

void main() {
  late _FakeApiClient api;
  late MemorySecureStorage storage;
  late HttpAuthRemoteDataSource remote;

  setUp(() {
    api = _FakeApiClient();
    storage = MemorySecureStorage();
    remote = HttpAuthRemoteDataSource(
      apiClient: api,
      secureStorage: storage,
      baseUrl: Uri.parse('http://127.0.0.1:8080'),
    );
  });

  test('stores credentials from register without exposing them on the entity', () async {
    api.response = const ApiResponse(
      statusCode: 201,
      body: '''
{
  "user": {"id": "usr_1", "username": "ada"},
  "session": {"id": "ses_1", "expires_at": "2026-09-08T00:00:00.000Z"},
  "credentials": {
    "access_token": "access-secret",
    "refresh_token": "refresh-secret",
    "token_type": "Bearer",
    "expires_in": 3600
  }
}
''',
    );

    final session = await remote.register(username: 'ada', password: 'secret');
    expect(session.toEntity().user.username, 'ada');
    expect(session.toJson().containsKey('credentials'), isFalse);
    expect(
      await storage.read(AuthSecureStorageKeys.accessToken),
      'access-secret',
    );
  });

  test('maps 409 to username taken', () async {
    api.response = const ApiResponse(
      statusCode: 409,
      body: '{"error":{"code":"username_taken","message":"taken"}}',
    );

    expect(
      () => remote.register(username: 'ada', password: 'secret'),
      throwsA(
        isA<AuthRemoteException>().having(
          (error) => error.code,
          'code',
          AuthRemoteErrorCode.usernameTaken,
        ),
      ),
    );
  });

  test('loads current account from GET /v1/users/me', () async {
    await storage.write(key: AuthSecureStorageKeys.accessToken, value: 'access');
    api.response = const ApiResponse(
      statusCode: 200,
      body:
          '{"id":"usr_1","username":"ada","created_at":"2026-01-02T03:04:05.000Z"}',
    );

    final account = await remote.getCurrentAccount();
    expect(account.username, 'ada');
    expect(account.id, 'usr_1');
    expect(api.lastUri?.path, '/v1/users/me');
  });

  test('delete account clears stored credentials', () async {
    await storage.write(key: AuthSecureStorageKeys.accessToken, value: 'access');
    await storage.write(
      key: AuthSecureStorageKeys.refreshToken,
      value: 'refresh',
    );
    api.response = const ApiResponse(statusCode: 204, body: '');

    await remote.deleteAccount(password: 'secret');

    expect(await storage.read(AuthSecureStorageKeys.accessToken), isNull);
    expect(await storage.read(AuthSecureStorageKeys.refreshToken), isNull);
    expect(api.lastUri?.path, '/v1/auth/account/delete');
  });
}

final class _FakeApiClient implements ApiClient {
  ApiResponse response = const ApiResponse(statusCode: 500, body: '{}');
  Uri? lastUri;

  @override
  Future<ApiResponse> send({
    required String method,
    required Uri uri,
    Map<String, String>? headers,
    Object? jsonBody,
  }) async {
    lastUri = uri;
    return response;
  }
}
