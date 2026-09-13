import 'package:seyra/core/errors/result.dart';
import 'package:seyra/features/profile/domain/entities/account.dart';

abstract interface class AccountRepository {
  Future<Result<Account>> getCurrentAccount();
}
