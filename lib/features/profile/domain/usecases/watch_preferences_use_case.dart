import 'package:seyra/features/profile/domain/entities/user_profile.dart';
import 'package:seyra/features/profile/domain/repositories/profile_repository.dart';

final class WatchPreferencesUseCase {
  const WatchPreferencesUseCase(this._repository);

  final ProfileRepository _repository;

  Stream<UserPreferences> call() => _repository.watchPreferences();
}
