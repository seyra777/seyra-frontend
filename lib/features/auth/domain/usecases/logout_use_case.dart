import 'package:seyra/core/errors/result.dart';
import 'package:seyra/features/auth/domain/repositories/auth_repository.dart';

final class LogoutUseCase {
  const LogoutUseCase(this._repository);

  final AuthRepository _repository;

  Future<Result<void>> call() => _repository.logout();
}
