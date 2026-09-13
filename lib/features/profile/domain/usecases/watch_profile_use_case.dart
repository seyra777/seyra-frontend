import 'package:seyra/features/profile/domain/entities/user_profile.dart';
import 'package:seyra/features/profile/domain/repositories/profile_repository.dart';

final class WatchProfileUseCase {
  const WatchProfileUseCase(this._repository);

  final ProfileRepository _repository;

  Stream<UserProfile> call({
    required String userId,
    required String username,
  }) {
    return _repository.watchProfile(userId: userId, username: username);
  }
}
