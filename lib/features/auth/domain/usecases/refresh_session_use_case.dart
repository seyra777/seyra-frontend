import 'package:seyra/core/errors/result.dart';
import 'package:seyra/features/auth/domain/entities/auth_session.dart';
import 'package:seyra/features/auth/domain/repositories/auth_repository.dart';

final class RefreshSessionUseCase {
  const RefreshSessionUseCase(this._repository);

  final AuthRepository _repository;

  Future<Result<AuthSession>> call() => _repository.refreshSession();
}
