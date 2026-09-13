import 'package:seyra/core/errors/result.dart';
import 'package:seyra/features/auth/domain/entities/auth_session.dart';

abstract interface class AuthRepository {
  Future<Result<AuthSession>> login({
    required String username,
    required String password,
  });

  Future<Result<AuthSession>> register({
    required String username,
    required String password,
  });

  Future<Result<void>> logout();

  Future<Result<AuthSession?>> restoreSession();

  Future<Result<AuthSession>> refreshSession();

  Future<Result<void>> deleteAccount({required String password});
}
