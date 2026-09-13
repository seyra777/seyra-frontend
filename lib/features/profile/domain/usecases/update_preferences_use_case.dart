import 'package:seyra/core/errors/result.dart';
import 'package:seyra/features/profile/domain/entities/user_profile.dart';
import 'package:seyra/features/profile/domain/repositories/profile_repository.dart';

final class UpdatePreferencesUseCase {
  const UpdatePreferencesUseCase(this._repository);

  final ProfileRepository _repository;

  Future<Result<UserPreferences>> call(UserPreferences preferences) {
    return _repository.updatePreferences(preferences);
  }
}
