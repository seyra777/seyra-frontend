import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seyra/core/errors/result.dart';
import 'package:seyra/core/theme/app_theme.dart';
import 'package:seyra/features/auth/domain/entities/auth_session.dart';
import 'package:seyra/features/auth/domain/failures/auth_failures.dart';
import 'package:seyra/features/auth/domain/repositories/auth_repository.dart';
import 'package:seyra/features/auth/domain/usecases/register_use_case.dart';
import 'package:seyra/features/auth/presentation/pages/register_page.dart';

void main() {
  testWidgets('shows required-field validation on empty registration submit', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: RegisterPage(
          registerUseCase: RegisterUseCase(_FakeAuthRepository()),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('register_submit_button')));
    await tester.pump();

    expect(find.text('Username is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    expect(find.text('Confirm password is required'), findsOneWidget);
  });

  testWidgets('shows mismatch error when passwords differ', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: RegisterPage(
          registerUseCase: RegisterUseCase(_FakeAuthRepository()),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('register_username_field')),
      'ada',
    );
    await tester.enterText(
      find.byKey(const Key('register_password_field')),
      'secret',
    );
    await tester.enterText(
      find.byKey(const Key('register_confirm_password_field')),
      'other',
    );
    await tester.tap(find.byKey(const Key('register_submit_button')));
    await tester.pump();

    expect(find.text('Passwords do not match'), findsOneWidget);
  });

  testWidgets('shows an error when registration fails', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: RegisterPage(
          registerUseCase: RegisterUseCase(_FakeAuthRepository()),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('register_username_field')),
      'ada',
    );
    await tester.enterText(
      find.byKey(const Key('register_password_field')),
      'secret',
    );
    await tester.enterText(
      find.byKey(const Key('register_confirm_password_field')),
      'secret',
    );
    await tester.tap(find.byKey(const Key('register_submit_button')));
    await tester.pump();

    expect(find.text('Username is already taken'), findsOneWidget);
  });
}

final class _FakeAuthRepository implements AuthRepository {
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
  }) async {
    return const FailureResult(UsernameTakenFailure());
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
