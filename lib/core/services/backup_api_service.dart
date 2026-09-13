import 'dart:convert';
import 'dart:typed_data';

import 'package:seyra/core/network/api_client.dart';
import 'package:seyra/core/storage/secure_storage.dart';
import 'package:seyra/features/auth/data/storage/auth_secure_storage_keys.dart';

final class BackupApiException implements Exception {
  const BackupApiException(this.code, [this.message = '']);

  final String code;
  final String message;

  @override
  String toString() => 'BackupApiException($code)';
}

final class BackupRemoteSnapshot {
  const BackupRemoteSnapshot({
    required this.encryptedBlob,
    this.updatedAt,
  });

  final Uint8List encryptedBlob;
  final DateTime? updatedAt;
}

/// Upload/download encrypted backup blobs. The API never sees plaintext.
final class BackupApiService {
  BackupApiService({
    required ApiClient apiClient,
    required SecureStorage secureStorage,
    required Uri baseUrl,
  })  : _apiClient = apiClient,
        _secureStorage = secureStorage,
        _baseUrl = baseUrl;

  final ApiClient _apiClient;
  final SecureStorage _secureStorage;
  final Uri _baseUrl;

  Future<void> uploadEncryptedBlob(Uint8List blob) async {
    final response = await _authorized(
      method: 'POST',
      path: '/v1/backup',
      jsonBody: {
        'encryptedBackup': base64Encode(blob),
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _mapError(response.statusCode, response.body);
    }
  }

  Future<BackupRemoteSnapshot> downloadEncryptedBlob() async {
    final response = await _authorized(
      method: 'GET',
      path: '/v1/backup',
    );
    if (response.statusCode == 404) {
      throw const BackupApiException('not_found', 'No backup found');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _mapError(response.statusCode, response.body);
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final raw = json['encryptedBackup'] as String? ?? '';
    if (raw.isEmpty) {
      throw const BackupApiException('invalid_response');
    }
    final updatedAtRaw = json['updated_at'] as String?;
    return BackupRemoteSnapshot(
      encryptedBlob: Uint8List.fromList(base64Decode(raw)),
      updatedAt: updatedAtRaw == null ? null : DateTime.tryParse(updatedAtRaw),
    );
  }

  Future<bool> hasRemoteBackup() async {
    try {
      await downloadEncryptedBlob();
      return true;
    } on BackupApiException catch (error) {
      if (error.code == 'not_found') {
        return false;
      }
      rethrow;
    }
  }

  Future<void> deleteRemoteBackup() async {
    final response = await _authorized(method: 'DELETE', path: '/v1/backup');
    if (response.statusCode == 404) {
      return;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _mapError(response.statusCode, response.body);
    }
  }

  Future<ApiResponse> _authorized({
    required String method,
    required String path,
    Map<String, dynamic>? jsonBody,
  }) async {
    final access = await _secureStorage.read(AuthSecureStorageKeys.accessToken);
    if (access == null || access.isEmpty) {
      throw const BackupApiException('unauthorized');
    }
    return _apiClient.send(
      method: method,
      uri: _baseUrl.resolve(path),
      headers: {
        'Authorization': 'Bearer $access',
      },
      jsonBody: jsonBody,
    );
  }

  BackupApiException _mapError(int status, String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final error = json['error'] as Map<String, dynamic>?;
      final code = error?['code'] as String? ?? 'unknown';
      final message = error?['message'] as String? ?? '';
      if (status == 401) {
        return BackupApiException('unauthorized', message);
      }
      if (status == 404) {
        return const BackupApiException('not_found', 'No backup found');
      }
      return BackupApiException(code, message);
    } catch (_) {
      return BackupApiException('http_$status');
    }
  }
}
