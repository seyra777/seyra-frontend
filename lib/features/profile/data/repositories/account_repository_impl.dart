import 'package:seyra/core/errors/failures.dart';
import 'package:seyra/core/errors/network_failure.dart';
import 'package:seyra/core/errors/result.dart';
import 'package:seyra/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:seyra/features/auth/data/exceptions/auth_remote_exceptions.dart';
import 'package:seyra/features/auth/domain/failures/auth_failures.dart';
import 'package:seyra/features/profile/domain/entities/account.dart';
import 'package:seyra/features/profile/domain/repositories/account_repository.dart';

final class AccountRepositoryImpl implements AccountRepository {
  const AccountRepositoryImpl({required this.remoteDataSource});

  final AuthRemoteDataSource remoteDataSource;

  @override
  Future<Result<Account>> getCurrentAccount() async {
    try {
      final model = await remoteDataSource.getCurrentAccount();
      return Success(
        Account(
          id: model.id,
          username: model.username,
          createdAt: model.createdAt,
        ),
      );
    } on AuthRemoteException catch (error) {
      return FailureResult(_mapAuthError(error));
    } catch (_) {
      return const FailureResult(UnexpectedFailure());
    }
  }

  Failure _mapAuthError(AuthRemoteException error) {
    return switch (error.code) {
      AuthRemoteErrorCode.unavailable => const AuthUnavailableFailure(),
      AuthRemoteErrorCode.invalidCredentials =>
        const InvalidCredentialsFailure(),
      AuthRemoteErrorCode.usernameTaken => const UsernameTakenFailure(),
      AuthRemoteErrorCode.sessionExpired => const SessionExpiredFailure(),
      AuthRemoteErrorCode.unauthorized => const UnauthorizedFailure(),
      AuthRemoteErrorCode.network => const NetworkFailure(),
      AuthRemoteErrorCode.invalidInput =>
        const ValidationFailure('Invalid request'),
    };
  }
}
