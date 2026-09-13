import 'dart:convert';

import 'package:seyra/core/network/api_client.dart';
import 'package:seyra/core/storage/secure_storage.dart';
import 'package:seyra/features/auth/data/contracts/auth_api_endpoints.dart';
import 'package:seyra/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:seyra/features/auth/data/exceptions/auth_remote_exceptions.dart';
import 'package:seyra/features/auth/data/models/auth_credentials_model.dart';
import 'package:seyra/features/auth/data/models/auth_request_models.dart';
import 'package:seyra/features/auth/data/models/auth_session_model.dart';
import 'package:seyra/features/auth/data/models/current_account_model.dart';
import 'package:seyra/features/auth/data/storage/auth_secure_storage_keys.dart';

final class HttpAuthRemoteDataSource implements AuthRemoteDataSource {
  HttpAuthRemoteDataSource({
    required this.apiClient,
    required this.secureStorage,
    required this.baseUrl,
  });

  final ApiClient apiClient;
  final SecureStorage secureStorage;
  final Uri baseUrl;

  @override
  Future<AuthSessionModel> login({
    required String username,
    required String password,
  }) {
    return _authenticate(
      AuthApiEndpoints.login,
      AuthPasswordRequest(username: username, password: password),
    );
  }

  @override
  Future<AuthSessionModel> register({
    required String username,
    required String password,
  }) {
    return _authenticate(
      AuthApiEndpoints.register,
      AuthPasswordRequest(username: username, password: password),
    );
  }

  @override
  Future<void> logout() async {
    final access = await secureStorage.read(AuthSecureStorageKeys.accessToken);
    try {
      await _send(
        method: 'POST',
        path: AuthApiEndpoints.logout,
        headers: _bearer(access),
      );
    } on AuthRemoteException catch (error) {
      if (error.code != AuthRemoteErrorCode.unauthorized &&
          error.code != AuthRemoteErrorCode.sessionExpired) {
        rethrow;
      }
    } finally {
      await _clearCredentials();
    }
  }

  @override
  Future<AuthSessionModel?> restoreSession() async {
    final access = await secureStorage.read(AuthSecureStorageKeys.accessToken);
    if (access == null || access.isEmpty) {
      return null;
    }
    try {
      final response = await _send(
        method: 'GET',
        path: AuthApiEndpoints.session,
        headers: _bearer(access),
      );
      return AuthSessionModel.fromJson(_decodeObject(response.body));
    } on AuthRemoteException catch (error) {
      if (error.code == AuthRemoteErrorCode.sessionExpired) {
        return _restoreWithRefresh();
      }
      if (error.code == AuthRemoteErrorCode.unauthorized) {
        await _clearCredentials();
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<AuthSessionModel> refreshSession() async {
    final restored = await _restoreWithRefresh();
    if (restored == null) {
      throw const AuthRemoteException(AuthRemoteErrorCode.sessionExpired);
    }
    return restored;
  }

  @override
  Future<void> deleteAccount({required String password}) async {
    await _authorized(
      method: 'POST',
      path: AuthApiEndpoints.deleteAccount,
      jsonBody: DeleteAccountRequest(password: password).toJson(),
    );
    await _clearCredentials();
  }

  @override
  Future<CurrentAccountModel> getCurrentAccount() async {
    final response = await _authorized(
      method: 'GET',
      path: AuthApiEndpoints.currentUser,
    );
    return CurrentAccountModel.fromJson(_decodeObject(response.body));
  }

  Future<AuthSessionModel> _authenticate(
    String path,
    AuthPasswordRequest request,
  ) async {
    final response = await _send(
      method: 'POST',
      path: path,
      jsonBody: request.toJson(),
    );
    final model = AuthSessionModel.fromJson(_decodeObject(response.body));
    await _persistCredentials(model.credentials);
    return model;
  }

  Future<AuthSessionModel?> _restoreWithRefresh() async {
    final refresh = await secureStorage.read(AuthSecureStorageKeys.refreshToken);
    if (refresh == null || refresh.isEmpty) {
      await _clearCredentials();
      return null;
    }
    try {
      final response = await _send(
        method: 'POST',
        path: AuthApiEndpoints.refresh,
        jsonBody: RefreshSessionRequest(refreshToken: refresh).toJson(),
      );
      final model = AuthSessionModel.fromJson(_decodeObject(response.body));
      await _persistCredentials(model.credentials);
      return model;
    } on AuthRemoteException {
      await _clearCredentials();
      return null;
    }
  }

  Future<ApiResponse> _authorized({
    required String method,
    required String path,
    Object? jsonBody,
  }) async {
    var access = await secureStorage.read(AuthSecureStorageKeys.accessToken);
    if (access == null || access.isEmpty) {
      throw const AuthRemoteException(AuthRemoteErrorCode.unauthorized);
    }
    try {
      return await _send(
        method: method,
        path: path,
        headers: _bearer(access),
        jsonBody: jsonBody,
      );
    } on AuthRemoteException catch (error) {
      if (error.code != AuthRemoteErrorCode.sessionExpired) {
        rethrow;
      }
      final restored = await _restoreWithRefresh();
      if (restored == null) {
        throw const AuthRemoteException(AuthRemoteErrorCode.sessionExpired);
      }
      access = await secureStorage.read(AuthSecureStorageKeys.accessToken);
      return _send(
        method: method,
        path: path,
        headers: _bearer(access),
        jsonBody: jsonBody,
      );
    }
  }

  Future<ApiResponse> _send({
    required String method,
    required String path,
    Map<String, String>? headers,
    Object? jsonBody,
  }) async {
    try {
      final response = await apiClient.send(
        method: method,
        uri: baseUrl.resolve(path),
        headers: headers,
        jsonBody: jsonBody,
      );
      _throwIfError(response);
      return response;
    } on AuthRemoteException {
      rethrow;
    } catch (_) {
      throw const AuthRemoteException(AuthRemoteErrorCode.network);
    }
  }

  void _throwIfError(ApiResponse response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    throw AuthRemoteException(
      _codeFor(response),
      statusCode: response.statusCode,
    );
  }

  AuthRemoteErrorCode _codeFor(ApiResponse response) {
    final code = _errorCode(response.body);
    return switch (code) {
      'username_taken' => AuthRemoteErrorCode.usernameTaken,
      'invalid_credentials' => AuthRemoteErrorCode.invalidCredentials,
      'session_expired' => AuthRemoteErrorCode.sessionExpired,
      'unauthorized' => AuthRemoteErrorCode.unauthorized,
      'invalid_input' => AuthRemoteErrorCode.invalidInput,
      _ => switch (response.statusCode) {
        409 => AuthRemoteErrorCode.usernameTaken,
        401 => AuthRemoteErrorCode.unauthorized,
        400 => AuthRemoteErrorCode.invalidInput,
        501 => AuthRemoteErrorCode.unavailable,
        _ => AuthRemoteErrorCode.network,
      },
    };
  }

  String? _errorCode(String body) {
    if (body.trim().isEmpty) {
      return null;
    }
    try {
      final json = jsonDecode(body);
      if (json is Map<String, dynamic>) {
        final error = json['error'];
        if (error is Map<String, dynamic>) {
          return error['code'] as String?;
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Map<String, dynamic> _decodeObject(String body) {
    final json = jsonDecode(body);
    if (json is Map<String, dynamic>) {
      return json;
    }
    throw const AuthRemoteException(AuthRemoteErrorCode.network);
  }

  Map<String, String> _bearer(String? accessToken) {
    if (accessToken == null || accessToken.isEmpty) {
      return const {};
    }
    return {'Authorization': 'Bearer $accessToken'};
  }

  Future<void> _persistCredentials(AuthCredentialsModel? credentials) async {
    if (credentials == null) {
      return;
    }
    await secureStorage.write(
      key: AuthSecureStorageKeys.accessToken,
      value: credentials.accessToken,
    );
    await secureStorage.write(
      key: AuthSecureStorageKeys.refreshToken,
      value: credentials.refreshToken,
    );
  }

  Future<void> _clearCredentials() async {
    await secureStorage.delete(AuthSecureStorageKeys.accessToken);
    await secureStorage.delete(AuthSecureStorageKeys.refreshToken);
  }
}
