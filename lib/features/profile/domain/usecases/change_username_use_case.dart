import 'package:seyra/core/errors/failures.dart';
import 'package:seyra/core/errors/result.dart';
import 'package:seyra/features/profile/domain/entities/user_profile.dart';
import 'package:seyra/features/profile/domain/repositories/profile_repository.dart';

final class ChangeUsernameUseCase {
  const ChangeUsernameUseCase(this._repository);

  final ProfileRepository _repository;

  Future<Result<UserProfile>> call(String username) async {
    final value = username.trim();
    if (!RegExp(r'^[A-Za-z0-9_]{3,32}$').hasMatch(value)) {
      return const FailureResult(
        ValidationFailure(
          'Username must be 3–32 letters, numbers, or underscores',
        ),
      );
    }
    return _repository.changeUsername(value);
  }
}
