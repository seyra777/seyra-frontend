import 'package:flutter_test/flutter_test.dart';
import 'package:seyra/core/errors/result.dart';
import 'package:seyra/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:seyra/features/auth/data/datasources/deferred_auth_remote_data_source.dart';
import 'package:seyra/features/auth/data/exceptions/auth_remote_exceptions.dart';
import 'package:seyra/features/auth/data/models/auth_credentials_model.dart';
import 'package:seyra/features/auth/data/models/auth_session_model.dart';
import 'package:seyra/features/auth/data/models/current_account_model.dart';
import 'package:seyra/features/auth/data/models/user_model.dart';
import 'package:seyra/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:seyra/features/auth/domain/entities/auth_session.dart';
import 'package:seyra/features/auth/domain/entities/user.dart';
import 'package:seyra/features/auth/domain/failures/auth_failures.dart';

void main() {
  test('maps a remote session model to an AuthSession entity', () async {
    final remote = _FakeAuthRemoteDataSource()
      ..session = const AuthSessionModel(
        user: UserModel(id: '1', username: 'ada'),
      );
    final repository = AuthRepositoryImpl(remoteDataSource: remote);

    final result = await repository.login(
      username: 'ada',
      password: 'secret',
    );

    expect(
      result,
      const Success(AuthSession(user: User(id: '1', username: 'ada'))),
    );
    expect(remote.lastUsername, 'ada');
    expect(remote.session?.user.toJson().containsKey('password'), isFalse);
  });

  test('maps unavailable remote login to AuthUnavailableFailure', () async {
    final repository = AuthRepositoryImpl(
      remoteDataSource: const DeferredAuthRemoteDataSource(),
    );

    final result = await repository.login(
      username: 'ada',
      password: 'secret',
    );

    expect(
      (result as FailureResult<AuthSession>).failure,
      isA<AuthUnavailableFailure>(),
    );
  });

  test('maps unavailable remote register to AuthUnavailableFailure', () async {
    final repository = AuthRepositoryImpl(
      remoteDataSource: const DeferredAuthRemoteDataSource(),
    );

    final result = await repository.register(
      username: 'ada',
      password: 'secret',
    );

    expect(
      (result as FailureResult<AuthSession>).failure,
      isA<AuthUnavailableFailure>(),
    );
  });

  test('restoreSession returns null when no backend session exists', () async {
    final repository = AuthRepositoryImpl(
      remoteDataSource: const DeferredAuthRemoteDataSource(),
    );

    final result = await repository.restoreSession();

    expect(result, isA<Success<AuthSession?>>());
    expect((result as Success<AuthSession?>).value, isNull);
  });

  test('logout succeeds when the remote has no session to revoke', () async {
    final repository = AuthRepositoryImpl(
      remoteDataSource: const DeferredAuthRemoteDataSource(),
    );

    final result = await repository.logout();

    expect(result, isA<Success<void>>());
  });

  test('maps unexpected remote errors to UnexpectedFailure', () async {
    final remote = _FakeAuthRemoteDataSource()
      ..error = StateError('boom');
    final repository = AuthRepositoryImpl(remoteDataSource: remote);

    final result = await repository.login(
      username: 'ada',
      password: 'secret',
    );

    expect(result, isA<FailureResult<AuthSession>>());
  });

  test('maps invalid credentials from the remote contract', () async {
    final remote = _FakeAuthRemoteDataSource()
      ..error = const AuthRemoteException(AuthRemoteErrorCode.invalidCredentials);
    final repository = AuthRepositoryImpl(remoteDataSource: remote);

    final result = await repository.login(
      username: 'ada',
      password: 'wrong',
    );

    expect(
      (result as FailureResult<AuthSession>).failure,
      isA<InvalidCredentialsFailure>(),
    );
  });

  test('maps unavailable deleteAccount to AuthUnavailableFailure', () async {
    final repository = AuthRepositoryImpl(
      remoteDataSource: const DeferredAuthRemoteDataSource(),
    );

    final result = await repository.deleteAccount(password: 'secret');

    expect(
      (result as FailureResult<void>).failure,
      isA<AuthUnavailableFailure>(),
    );
  });

  test('session entity does not include remote credentials', () async {
    final remote = _FakeAuthRemoteDataSource()
      ..session = AuthSessionModel(
        user: const UserModel(id: '1', username: 'ada'),
        sessionId: 'ses_1',
        expiresAt: DateTime.utc(2026, 9, 7),
        credentials: const AuthCredentialsModel(
          accessToken: 'access-secret',
          refreshToken: 'refresh-secret',
          tokenType: 'Bearer',
          expiresIn: 3600,
        ),
      );
    final repository = AuthRepositoryImpl(remoteDataSource: remote);

    final result = await repository.login(
      username: 'ada',
      password: 'secret',
    );
    final session = (result as Success<AuthSession>).value;

    expect(session.sessionId, 'ses_1');
    expect(session.user.username, 'ada');
    expect(result.toString().contains('access-secret'), isFalse);
  });
}

final class _FakeAuthRemoteDataSource implements AuthRemoteDataSource {
  AuthSessionModel? session;
  Object? error;
  String? lastUsername;

  @override
  Future<AuthSessionModel> login({
    required String username,
    required String password,
  }) async {
    lastUsername = username;
    if (error != null) {
      throw error!;
    }
    if (session == null) {
      throw const AuthRemoteUnavailableException();
    }
    return session!;
  }

  @override
  Future<AuthSessionModel> register({
    required String username,
    required String password,
  }) {
    return login(username: username, password: password);
  }

  @override
  Future<void> logout() async {}

  @override
  Future<AuthSessionModel?> restoreSession() async => session;

  @override
  Future<AuthSessionModel> refreshSession() {
    return login(username: 'refresh', password: 'unused');
  }

  @override
  Future<void> deleteAccount({required String password}) async {
    if (error != null) {
      throw error!;
    }
  }

  @override
  Future<CurrentAccountModel> getCurrentAccount() async {
    if (error != null) {
      throw error!;
    }
    final current = session;
    if (current == null) {
      throw const AuthRemoteException(AuthRemoteErrorCode.unauthorized);
    }
    return CurrentAccountModel(
      id: current.user.id,
      username: current.user.username,
      createdAt: DateTime.utc(2026, 1, 1),
    );
  }
}
