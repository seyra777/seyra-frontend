import 'package:seyra/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:seyra/features/auth/data/exceptions/auth_remote_exceptions.dart';
import 'package:seyra/features/auth/data/models/auth_session_model.dart';
import 'package:seyra/features/auth/data/models/current_account_model.dart';

/// Placeholder remote auth adapter. It does not call a backend or persist data.
final class DeferredAuthRemoteDataSource implements AuthRemoteDataSource {
  const DeferredAuthRemoteDataSource();

  @override
  Future<AuthSessionModel> login({
    required String username,
    required String password,
  }) async {
    throw const AuthRemoteUnavailableException();
  }

  @override
  Future<AuthSessionModel> register({
    required String username,
    required String password,
  }) async {
    throw const AuthRemoteUnavailableException();
  }

  @override
  Future<void> logout() async {}

  @override
  Future<AuthSessionModel?> restoreSession() async => null;

  @override
  Future<AuthSessionModel> refreshSession() async {
    throw const AuthRemoteUnavailableException();
  }

  @override
  Future<void> deleteAccount({required String password}) async {
    throw const AuthRemoteUnavailableException();
  }

  @override
  Future<CurrentAccountModel> getCurrentAccount() async {
    throw const AuthRemoteUnavailableException();
  }
}
