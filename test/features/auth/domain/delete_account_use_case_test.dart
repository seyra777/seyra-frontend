import 'package:flutter_test/flutter_test.dart';
import 'package:seyra/core/errors/failures.dart';
import 'package:seyra/core/errors/result.dart';
import 'package:seyra/features/auth/domain/entities/auth_session.dart';
import 'package:seyra/features/auth/domain/failures/auth_failures.dart';
import 'package:seyra/features/auth/domain/repositories/auth_repository.dart';
import 'package:seyra/features/auth/domain/usecases/delete_account_use_case.dart';

void main() {
  late _FakeAuthRepository repository;
  late DeleteAccountUseCase useCase;

  setUp(() {
    repository = _FakeAuthRepository();
    useCase = DeleteAccountUseCase(repository);
  });

  test('returns ValidationFailure when password is empty', () async {
    final result = await useCase(password: '');

    expect((result as FailureResult<void>).failure, isA<ValidationFailure>());
    expect(repository.deleteCalls, 0);
  });

  test('delegates a non-empty password to the repository', () async {
    repository.deleteResult = const Success<void>(null);

    final result = await useCase(password: 'secret');

    expect(result, isA<Success<void>>());
    expect(repository.deleteCalls, 1);
  });
}

final class _FakeAuthRepository implements AuthRepository {
  Result<void>? deleteResult;
  int deleteCalls = 0;

  @override
  Future<Result<AuthSession>> login({
    required String username,
    required String password,
  }) {
    throw UnimplementedError();
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
  Future<Result<void>> deleteAccount({required String password}) async {
    deleteCalls += 1;
    return deleteResult ?? const FailureResult(AuthUnavailableFailure());
  }
}
