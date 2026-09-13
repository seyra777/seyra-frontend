import 'package:seyra/features/profile/domain/entities/user_profile.dart';

abstract interface class ProfileDataSource {
  Stream<UserProfile> watchProfile({
    required String userId,
    required String username,
  });

  Stream<UserPreferences> watchPreferences();

  Future<UserProfile> updateProfile({
    required String userId,
    required String displayName,
    required String bio,
  });

  Future<UserProfile> changeUsername(String username);

  Future<UserPreferences> updatePreferences(UserPreferences preferences);

  Future<UserProfile> uploadAvatar({
    required List<int> bytes,
    required String filename,
    required String contentType,
  });

  Future<UserProfile> removeAvatar();

  Future<List<int>?> fetchAvatar(String userId);

  Future<void> reloadRemote();
}
