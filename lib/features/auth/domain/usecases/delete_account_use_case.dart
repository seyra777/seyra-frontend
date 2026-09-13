import 'package:seyra/core/errors/failures.dart';
import 'package:seyra/core/errors/result.dart';
import 'package:seyra/features/auth/domain/repositories/auth_repository.dart';

final class DeleteAccountUseCase {
  const DeleteAccountUseCase(this._repository);

  final AuthRepository _repository;

  Future<Result<void>> call({required String password}) async {
    if (password.isEmpty) {
      return const FailureResult(ValidationFailure('Password is required'));
    }

    return _repository.deleteAccount(password: password);
  }
}
