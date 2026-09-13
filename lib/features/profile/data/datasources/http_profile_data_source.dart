import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';
import 'package:seyra/core/network/api_client.dart';
import 'package:seyra/core/storage/secure_storage.dart';
import 'package:seyra/core/theme/theme_controller.dart';
import 'package:seyra/features/auth/data/exceptions/auth_remote_exceptions.dart';
import 'package:seyra/features/auth/data/storage/auth_secure_storage_keys.dart';
import 'package:seyra/features/chat/domain/entities/social_models.dart';
import 'package:seyra/features/profile/data/datasources/profile_data_source.dart';
import 'package:seyra/features/profile/domain/entities/user_profile.dart';

final class HttpProfileDataSource implements ProfileDataSource {
  HttpProfileDataSource({
    required this.apiClient,
    required this.secureStorage,
    required this.baseUrl,
    required this.themeController,
    this.httpClient,
  });

  final ApiClient apiClient;
  final SecureStorage secureStorage;
  final Uri baseUrl;
  final ThemeController themeController;
  final http.Client? httpClient;

  UserProfile? _profile;
  UserPreferences _preferences = const UserPreferences();
  PrivacySettings _privacy = const PrivacySettings();
  var _loadedLocal = false;

  final _profileController = StreamController<UserProfile>.broadcast();
  final _preferencesController =
      StreamController<UserPreferences>.broadcast();

  @override
  Stream<UserProfile> watchProfile({
    required String userId,
    required String username,
  }) async* {
    await _refreshFromServer(fallbackId: userId, fallbackUsername: username);
    if (_profile != null) {
      yield _profile!;
    }
    yield* _profileController.stream;
  }

  @override
  Stream<UserPreferences> watchPreferences() async* {
    await _ensureLocal();
    yield _preferences;
    unawaited(_refreshPrivacy());
    yield* _preferencesController.stream;
  }

  @override
  Future<UserProfile> updateProfile({
    required String userId,
    required String displayName,
    required String bio,
  }) async {
    final response = await _authorized(
      method: 'PUT',
      path: '/v1/users/me',
      jsonBody: {'display_name': displayName, 'bio': bio},
    );
    final profile = _profileFrom(response);
    _emitProfile(profile);
    return profile;
  }

  @override
  Future<UserProfile> changeUsername(String username) async {
    final response = await _authorized(
      method: 'PUT',
      path: '/v1/users/me/username',
      jsonBody: {'username': username},
    );
    final profile = _profileFrom(response);
    _emitProfile(profile);
    return profile;
  }

  @override
  Future<UserPreferences> updatePreferences(UserPreferences preferences) async {
    final previous = _preferences;
    _preferences = preferences;
    await _writeLocal();
    _preferencesController.add(_preferences);
    themeController.apply(preferences.appearance);

    final privacyChanged =
        previous.lastSeenVisibility != preferences.lastSeenVisibility ||
        previous.profilePhotoVisibility != preferences.profilePhotoVisibility;
    if (!privacyChanged) {
      return _preferences;
    }
    _privacy = _privacy.copyWith(
      lastSeenVisible: visibilityToEveryone(preferences.lastSeenVisibility),
      photoVisible: visibilityToEveryone(preferences.profilePhotoVisibility),
    );
    try {
      await _authorized(
        method: 'PUT',
        path: '/v1/privacy',
        jsonBody: {
          'last_seen_visible': _privacy.lastSeenVisible,
          'read_receipts': _privacy.readReceipts,
          'typing_visible': _privacy.typingVisible,
          'profile_visible': _privacy.profileVisible,
          'notification_preview': _privacy.notificationPreview,
          'photo_visible': _privacy.photoVisible,
        },
      );
    } on AuthRemoteException {
      // Appearance/sound already saved on device. Privacy is best-effort.
    }
    return _preferences;
  }

  @override
  Future<UserProfile> uploadAvatar({
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) async {
    final access = await secureStorage.read(AuthSecureStorageKeys.accessToken);
    final uri = baseUrl.resolve('/v1/users/me/avatar');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $access';
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename.trim().isEmpty ? 'avatar.jpg' : filename,
        contentType: _imageMediaType(contentType),
      ),
    );
    final client = httpClient ?? http.Client();
    try {
      final streamed = await client.send(request);
      final body = await streamed.stream.bytesToString();
      if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
        throw AuthRemoteException(
          AuthRemoteErrorCode.invalidInput,
          statusCode: streamed.statusCode,
        );
      }
      final profile = _profileFromJson(jsonDecode(body) as Map<String, dynamic>);
      _emitProfile(profile);
      return profile;
    } finally {
      if (httpClient == null) {
        client.close();
      }
    }
  }

  @override
  Future<UserProfile> removeAvatar() async {
    final response = await _authorized(method: 'DELETE', path: '/v1/users/me/avatar');
    final profile = _profileFrom(response);
    _emitProfile(profile);
    return profile;
  }

  @override
  Future<List<int>?> fetchAvatar(String userId) async {
    final access = await secureStorage.read(AuthSecureStorageKeys.accessToken);
    if (access == null || access.isEmpty) {
      return null;
    }
    try {
      final client = httpClient ?? http.Client();
      try {
        final response = await client.get(
          baseUrl.resolve('/v1/users/$userId/avatar'),
          headers: {'Authorization': 'Bearer $access'},
        );
        if (response.statusCode != 200) {
          return null;
        }
        return response.bodyBytes;
      } finally {
        if (httpClient == null) {
          client.close();
        }
      }
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> reloadRemote() => _refreshPrivacy();

  Future<void> _refreshFromServer({
    required String fallbackId,
    required String fallbackUsername,
  }) async {
    try {
      final response = await _authorized(method: 'GET', path: '/v1/users/me');
      _emitProfile(_profileFrom(response));
    } catch (_) {
      _profile ??= UserProfile(
        userId: fallbackId,
        username: fallbackUsername,
        displayName: fallbackUsername,
        bio: '',
      );
    }
  }

  Future<void> _refreshPrivacy() async {
    try {
      final response = await _authorized(method: 'GET', path: '/v1/privacy');
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      _privacy = PrivacySettings(
        lastSeenVisible: json['last_seen_visible'] as bool? ?? true,
        readReceipts: json['read_receipts'] as bool? ?? true,
        typingVisible: json['typing_visible'] as bool? ?? true,
        profileVisible: json['profile_visible'] as bool? ?? true,
        notificationPreview: json['notification_preview'] as bool? ?? true,
        photoVisible: json['photo_visible'] as bool? ?? true,
      );
      _preferences = _preferences.copyWith(
        lastSeenVisibility: visibilityFromEveryone(_privacy.lastSeenVisible),
        profilePhotoVisibility: visibilityFromEveryone(_privacy.photoVisible),
      );
      _preferencesController.add(_preferences);
    } catch (_) {}
  }

  Future<void> _ensureLocal() async {
    if (_loadedLocal) {
      return;
    }
    _loadedLocal = true;
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/seyra_device_prefs.json');
      if (!file.existsSync()) {
        themeController.apply(_preferences.appearance);
        return;
      }
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final appearance = switch (json['appearance'] as String?) {
        'dark' => AppearancePreference.dark,
        _ => AppearancePreference.light,
      };
      _preferences = _preferences.copyWith(
        appearance: appearance,
        soundEnabled: json['sound_enabled'] as bool? ?? true,
      );
      themeController.apply(_preferences.appearance);
    } catch (_) {
      themeController.apply(_preferences.appearance);
    }
  }

  Future<void> _writeLocal() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/seyra_device_prefs.json');
      await file.writeAsString(
        jsonEncode({
          'appearance': _preferences.appearance.name,
          'sound_enabled': _preferences.soundEnabled,
        }),
      );
    } catch (_) {}
  }

  void _emitProfile(UserProfile profile) {
    _profile = profile;
    _profileController.add(profile);
  }

  UserProfile _profileFrom(ApiResponse response) {
    return _profileFromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  UserProfile _profileFromJson(Map<String, dynamic> json) {
    final username = json['username'] as String? ?? '';
    final display = json['display_name'] as String? ?? '';
    return UserProfile(
      userId: json['id'] as String? ?? '',
      username: username,
      displayName: display.isEmpty ? username : display,
      bio: json['bio'] as String? ?? '',
      hasAvatar: json['has_avatar'] == true,
    );
  }

  Future<ApiResponse> _authorized({
    required String method,
    required String path,
    Object? jsonBody,
  }) async {
    final access = await secureStorage.read(AuthSecureStorageKeys.accessToken);
    final response = await apiClient.send(
      method: method,
      uri: baseUrl.resolve(path),
      headers: {
        if (access != null && access.isNotEmpty)
          'Authorization': 'Bearer $access',
      },
      jsonBody: jsonBody,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthRemoteException(
        _codeFor(response),
        statusCode: response.statusCode,
      );
    }
    return response;
  }

  AuthRemoteErrorCode _codeFor(ApiResponse response) {
    try {
      final json = jsonDecode(response.body);
      if (json is Map<String, dynamic>) {
        final error = json['error'];
        if (error is Map<String, dynamic>) {
          return switch (error['code'] as String?) {
            'username_taken' => AuthRemoteErrorCode.usernameTaken,
            'invalid_input' => AuthRemoteErrorCode.invalidInput,
            'invalid_type' => AuthRemoteErrorCode.invalidInput,
            'too_large' => AuthRemoteErrorCode.invalidInput,
            'session_expired' => AuthRemoteErrorCode.sessionExpired,
            'unauthorized' => AuthRemoteErrorCode.unauthorized,
            _ => AuthRemoteErrorCode.network,
          };
        }
      }
    } catch (_) {}
    return switch (response.statusCode) {
      409 => AuthRemoteErrorCode.usernameTaken,
      401 => AuthRemoteErrorCode.unauthorized,
      400 => AuthRemoteErrorCode.invalidInput,
      _ => AuthRemoteErrorCode.network,
    };
  }
}

MediaType _imageMediaType(String value) {
  final raw = value.trim().isEmpty ? 'image/jpeg' : value.trim();
  try {
    final parsed = MediaType.parse(raw);
    if (parsed.type == 'image') {
      final subtype = parsed.subtype == 'jpg' ? 'jpeg' : parsed.subtype;
      return MediaType('image', subtype);
    }
  } catch (_) {}
  return MediaType('image', 'jpeg');
}
