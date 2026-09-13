import 'package:seyra/core/errors/result.dart';
import 'package:seyra/features/auth/domain/entities/auth_session.dart';
import 'package:seyra/features/auth/domain/repositories/auth_repository.dart';
import 'package:seyra/features/auth/domain/usecases/auth_credentials_validator.dart';

final class LoginUseCase {
  const LoginUseCase(this._repository);

  final AuthRepository _repository;

  Future<Result<AuthSession>> call({
    required String username,
    required String password,
  }) async {
    final failure = AuthCredentialsValidator.validate(
      username: username,
      password: password,
    );
    if (failure != null) {
      return FailureResult(failure);
    }

    return _repository.login(
      username: username.trim(),
      password: password,
    );
  }
}
