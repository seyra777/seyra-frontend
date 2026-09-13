import 'package:flutter_test/flutter_test.dart';
import 'package:seyra/core/errors/failures.dart';
import 'package:seyra/core/errors/result.dart';
import 'package:seyra/features/auth/domain/entities/auth_session.dart';
import 'package:seyra/features/auth/domain/entities/user.dart';
import 'package:seyra/features/auth/domain/failures/auth_failures.dart';
import 'package:seyra/features/auth/domain/repositories/auth_repository.dart';
import 'package:seyra/features/auth/domain/usecases/login_use_case.dart';

void main() {
  late _FakeAuthRepository repository;
  late LoginUseCase useCase;

  setUp(() {
    repository = _FakeAuthRepository();
    useCase = LoginUseCase(repository);
  });

  test('returns ValidationFailure when username is blank', () async {
    final result = await useCase(username: '   ', password: 'secret');

    expect(result, isA<FailureResult<AuthSession>>());
    expect(
      (result as FailureResult<AuthSession>).failure,
      isA<ValidationFailure>(),
    );
    expect(repository.loginCalls, 0);
  });

  test('returns ValidationFailure when password is empty', () async {
    final result = await useCase(username: 'ada', password: '');

    expect(
      (result as FailureResult<AuthSession>).failure,
      isA<ValidationFailure>(),
    );
    expect(repository.loginCalls, 0);
  });

  test('trims username and delegates valid credentials to the repository', () async {
    const session = AuthSession(user: User(id: '1', username: 'ada'));
    repository.loginResult = const Success(session);

    final result = await useCase(username: '  ada  ', password: 'secret');

    expect(result, const Success(session));
    expect(repository.lastUsername, 'ada');
    expect(repository.loginCalls, 1);
  });

  test('propagates repository failure without treating it as success', () async {
    repository.loginResult = const FailureResult(AuthUnavailableFailure());

    final result = await useCase(username: 'ada', password: 'secret');

    expect(
      (result as FailureResult<AuthSession>).failure,
      isA<AuthUnavailableFailure>(),
    );
  });
}

final class _FakeAuthRepository implements AuthRepository {
  Result<AuthSession>? loginResult;
  String? lastUsername;
  int loginCalls = 0;

  @override
  Future<Result<AuthSession>> login({
    required String username,
    required String password,
  }) async {
    loginCalls += 1;
    lastUsername = username;
    return loginResult ?? const FailureResult(AuthUnavailableFailure());
  }

  @override
  Future<Result<AuthSession>> register({
    required String username,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Result<void>> logout() {
    throw UnimplementedError();
  }

  @override
  Future<Result<AuthSession?>> restoreSession() {
    throw UnimplementedError();
  }

  @override
  Future<Result<AuthSession>> refreshSession() {
    throw UnimplementedError();
  }

  @override
  Future<Result<void>> deleteAccount({required String password}) {
    throw UnimplementedError();
  }
}
