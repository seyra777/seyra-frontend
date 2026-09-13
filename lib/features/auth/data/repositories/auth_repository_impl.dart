import 'package:seyra/core/errors/failures.dart';
import 'package:seyra/core/errors/network_failure.dart';
import 'package:seyra/core/errors/result.dart';
import 'package:seyra/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:seyra/features/auth/data/exceptions/auth_remote_exceptions.dart';
import 'package:seyra/features/auth/data/models/auth_session_model.dart';
import 'package:seyra/features/auth/domain/entities/auth_session.dart';
import 'package:seyra/features/auth/domain/failures/auth_failures.dart';
import 'package:seyra/features/auth/domain/repositories/auth_repository.dart';

final class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({required this.remoteDataSource});

  final AuthRemoteDataSource remoteDataSource;

  @override
  Future<Result<AuthSession>> login({
    required String username,
    required String password,
  }) {
    return _mapSession(
      () => remoteDataSource.login(
        username: username,
        password: password,
      ),
    );
  }

  @override
  Future<Result<AuthSession>> register({
    required String username,
    required String password,
  }) {
    return _mapSession(
      () => remoteDataSource.register(
        username: username,
        password: password,
      ),
    );
  }

  @override
  Future<Result<void>> logout() {
    return _mapVoid(remoteDataSource.logout);
  }

  @override
  Future<Result<AuthSession?>> restoreSession() async {
    try {
      final session = await remoteDataSource.restoreSession();
      return Success(session?.toEntity());
    } on AuthRemoteException catch (error) {
      return FailureResult(_mapAuthError(error));
    } catch (_) {
      return const FailureResult(UnexpectedFailure());
    }
  }

  @override
  Future<Result<AuthSession>> refreshSession() {
    return _mapSession(remoteDataSource.refreshSession);
  }

  @override
  Future<Result<void>> deleteAccount({required String password}) {
    return _mapVoid(() => remoteDataSource.deleteAccount(password: password));
  }

  Future<Result<AuthSession>> _mapSession(
    Future<AuthSessionModel> Function() action,
  ) async {
    try {
      final model = await action();
      return Success(model.toEntity());
    } on AuthRemoteException catch (error) {
      return FailureResult(_mapAuthError(error));
    } catch (_) {
      return const FailureResult(UnexpectedFailure());
    }
  }

  Future<Result<void>> _mapVoid(Future<void> Function() action) async {
    try {
      await action();
      return const Success<void>(null);
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
        const ValidationFailure('Invalid username or password'),
    };
  }
}
