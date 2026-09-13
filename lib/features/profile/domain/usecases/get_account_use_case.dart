import 'package:seyra/core/errors/result.dart';
import 'package:seyra/features/profile/domain/entities/account.dart';
import 'package:seyra/features/profile/domain/repositories/account_repository.dart';

final class GetAccountUseCase {
  const GetAccountUseCase(this._repository);

  final AccountRepository _repository;

  Future<Result<Account>> call() {
    return _repository.getCurrentAccount();
  }
}
