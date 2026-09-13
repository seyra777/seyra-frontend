import 'package:flutter_test/flutter_test.dart';
import 'package:seyra/features/auth/data/datasources/mock_auth_remote_data_source.dart';
import 'package:seyra/features/auth/data/exceptions/auth_remote_exceptions.dart';
import 'package:seyra/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:seyra/features/auth/domain/entities/auth_session.dart';
import 'package:seyra/features/auth/domain/failures/auth_failures.dart';
import 'package:seyra/core/errors/result.dart';

void main() {
  late MockAuthRemoteDataSource remote;
  late AuthRepositoryImpl repository;

  setUp(() {
    remote = MockAuthRemoteDataSource();
    repository = AuthRepositoryImpl(remoteDataSource: remote);
  });

  test('register then login returns a session without exposing tokens', () async {
    final registered = await repository.register(
      username: 'ada',
      password: 'secret',
    );
    final login = await repository.login(
      username: 'ada',
      password: 'secret',
    );

    expect(registered, isA<Success<AuthSession>>());
    expect((login as Success<AuthSession>).value.user.username, 'ada');
    expect(login.value.sessionId, isNotNull);
    expect(login.toString().contains('mock-access'), isFalse);
  });

  test('login with an unknown user fails', () async {
    final result = await repository.login(
      username: 'ada',
      password: 'secret',
    );

    expect(
      (result as FailureResult<AuthSession>).failure,
      isA<InvalidCredentialsFailure>(),
    );
  });

  test('login with the wrong password fails', () async {
    await repository.register(username: 'ada', password: 'secret');

    final result = await repository.login(
      username: 'ada',
      password: 'wrong',
    );

    expect(
      (result as FailureResult<AuthSession>).failure,
      isA<InvalidCredentialsFailure>(),
    );
  });

  test('registering the same username twice fails', () async {
    await repository.register(username: 'ada', password: 'secret');

    final result = await repository.register(
      username: 'ada',
      password: 'other',
    );

    expect(
      (result as FailureResult<AuthSession>).failure,
      isA<UsernameTakenFailure>(),
    );
  });

  test('restoreSession returns the mock session after login', () async {
    await repository.register(username: 'ada', password: 'secret');

    final restored = await repository.restoreSession();

    expect((restored as Success<AuthSession?>).value?.user.username, 'ada');
  });

  test('logout clears the mock session', () async {
    await repository.register(username: 'ada', password: 'secret');
    await repository.logout();

    final restored = await repository.restoreSession();

    expect((restored as Success<AuthSession?>).value, isNull);
  });

  test('does not log passwords in remote exceptions', () {
    const error = AuthRemoteException(AuthRemoteErrorCode.invalidCredentials);
    expect(error.toString().contains('secret'), isFalse);
  });

  test('delete account requires the current password and clears the session', () async {
    await repository.register(username: 'ada', password: 'secret');
    final wrong = await repository.deleteAccount(password: 'nope');
    expect(
      (wrong as FailureResult<void>).failure,
      isA<InvalidCredentialsFailure>(),
    );

    final deleted = await repository.deleteAccount(password: 'secret');
    expect(deleted, isA<Success<void>>());
    final restored = await repository.restoreSession();
    expect((restored as Success<AuthSession?>).value, isNull);
  });
}
