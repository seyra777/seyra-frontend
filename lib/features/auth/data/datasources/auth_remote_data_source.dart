import 'package:seyra/features/auth/data/models/auth_session_model.dart';
import 'package:seyra/features/auth/data/models/current_account_model.dart';

abstract interface class AuthRemoteDataSource {
  Future<AuthSessionModel> login({
    required String username,
    required String password,
  });

  Future<AuthSessionModel> register({
    required String username,
    required String password,
  });

  Future<void> logout();

  Future<AuthSessionModel?> restoreSession();

  Future<AuthSessionModel> refreshSession();

  Future<void> deleteAccount({required String password});

  Future<CurrentAccountModel> getCurrentAccount();
}
