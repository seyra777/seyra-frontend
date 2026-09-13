import 'dart:async';

import 'package:seyra/core/theme/theme_controller.dart';
import 'package:seyra/features/profile/data/datasources/profile_data_source.dart';
import 'package:seyra/features/profile/domain/entities/user_profile.dart';

final class MockProfileDataSource implements ProfileDataSource {
  MockProfileDataSource({this.themeController})
      : _preferences = const UserPreferences();

  final ThemeController? themeController;
  final Map<String, UserProfile> _profiles = {};
  UserPreferences _preferences;
  UserProfile? _last;

  final _profileController = StreamController<UserProfile>.broadcast();
  final _preferencesController =
      StreamController<UserPreferences>.broadcast();

  @override
  Stream<UserProfile> watchProfile({
    required String userId,
    required String username,
  }) async* {
    yield _ensureProfile(userId: userId, username: username);
    yield* _profileController.stream.where((profile) => profile.userId == userId);
  }

  @override
  Stream<UserPreferences> watchPreferences() async* {
    yield _preferences;
    yield* _preferencesController.stream;
  }

  @override
  Future<UserProfile> updateProfile({
    required String userId,
    required String displayName,
    required String bio,
  }) async {
    final current = _ensureProfile(userId: userId, username: 'user');
    final updated = current.copyWith(displayName: displayName, bio: bio);
    _profiles[userId] = updated;
    _last = updated;
    _profileController.add(updated);
    return updated;
  }

  @override
  Future<UserProfile> changeUsername(String username) async {
    final current = _last;
    if (current == null) {
      return UserProfile(
        userId: 'usr_1',
        username: username,
        displayName: username,
        bio: '',
      );
    }
    final updated = current.copyWith(username: username);
    _profiles[current.userId] = updated;
    _last = updated;
    _profileController.add(updated);
    return updated;
  }

  @override
  Future<UserPreferences> updatePreferences(UserPreferences preferences) async {
    _preferences = preferences;
    themeController?.apply(preferences.appearance);
    _preferencesController.add(_preferences);
    return _preferences;
  }

  @override
  Future<UserProfile> uploadAvatar({
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) async {
    final current = _last;
    if (current == null) {
      return const UserProfile(
        userId: 'usr_1',
        username: 'user',
        displayName: 'User',
        bio: '',
        hasAvatar: true,
      );
    }
    final updated = current.copyWith(hasAvatar: true);
    _profiles[current.userId] = updated;
    _last = updated;
    _profileController.add(updated);
    _avatarBytes = bytes;
    return updated;
  }

  List<int>? _avatarBytes;

  @override
  Future<UserProfile> removeAvatar() async {
    _avatarBytes = null;
    final current = _last;
    if (current == null) {
      return const UserProfile(
        userId: 'usr_1',
        username: 'user',
        displayName: 'User',
        bio: '',
      );
    }
    final updated = current.copyWith(hasAvatar: false);
    _profiles[current.userId] = updated;
    _last = updated;
    _profileController.add(updated);
    return updated;
  }

  @override
  Future<List<int>?> fetchAvatar(String userId) async {
    if (_last?.userId == userId && _last?.hasAvatar == true) {
      return _avatarBytes;
    }
    return null;
  }

  @override
  Future<void> reloadRemote() async {}

  UserProfile _ensureProfile({
    required String userId,
    required String username,
  }) {
    final existing = _profiles[userId];
    if (existing != null) {
      _last = existing;
      return existing;
    }
    final created = UserProfile(
      userId: userId,
      username: username,
      displayName: _titleCase(username),
      bio: 'Private messaging on Seyra.',
    );
    _profiles[userId] = created;
    _last = created;
    return created;
  }

  static String _titleCase(String username) {
    final value = username.trim();
    if (value.isEmpty) {
      return 'Seyra user';
    }
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }
}
