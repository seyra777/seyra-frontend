import 'package:seyra/core/errors/failures.dart';
import 'package:seyra/core/errors/result.dart';
import 'package:seyra/features/profile/domain/entities/user_profile.dart';
import 'package:seyra/features/profile/domain/repositories/profile_repository.dart';

final class UpdateProfileUseCase {
  const UpdateProfileUseCase(this._repository);

  final ProfileRepository _repository;

  Future<Result<UserProfile>> call({
    required String userId,
    required String displayName,
    required String bio,
  }) async {
    final name = displayName.trim();
    if (name.isEmpty) {
      return const FailureResult(ValidationFailure('Display name is required'));
    }
    return _repository.updateProfile(
      userId: userId,
      displayName: name,
      bio: bio.trim(),
    );
  }
}
