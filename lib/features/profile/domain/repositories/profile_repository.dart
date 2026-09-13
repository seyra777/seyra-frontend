import 'package:seyra/core/errors/result.dart';
import 'package:seyra/features/profile/domain/entities/user_profile.dart';

abstract interface class ProfileRepository {
  Stream<UserProfile> watchProfile({
    required String userId,
    required String username,
  });

  Stream<UserPreferences> watchPreferences();

  Future<Result<UserProfile>> updateProfile({
    required String userId,
    required String displayName,
    required String bio,
  });

  Future<Result<UserProfile>> changeUsername(String username);

  Future<Result<UserPreferences>> updatePreferences(UserPreferences preferences);

  Future<Result<UserProfile>> uploadAvatar({
    required List<int> bytes,
    required String filename,
    required String contentType,
  });

  Future<Result<UserProfile>> removeAvatar();

  Future<List<int>?> fetchAvatar(String userId);

  Future<void> reloadRemote();
}
