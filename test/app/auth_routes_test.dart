import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seyra/app/app.dart';
import 'package:seyra/app/di/app_dependencies.dart';
import 'package:seyra/core/constants/app_constants.dart';
import 'package:seyra/features/auth/data/datasources/mock_auth_remote_data_source.dart';
import 'package:seyra/features/auth/presentation/pages/login_page.dart';
import 'package:seyra/features/auth/presentation/pages/register_page.dart';

void main() {
  setUp(() async {
    await AppDependencies.initialize(
      remoteDataSource: MockAuthRemoteDataSource(),
    );
  });

  testWidgets('navigates from the shell to the login page', (tester) async {
    await tester.pumpWidget(const SeyraApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets('navigates from the shell to the registration page', (
    tester,
  ) async {
    await tester.pumpWidget(const SeyraApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();

    expect(find.byType(RegisterPage), findsOneWidget);
  });

  testWidgets('navigates from login to registration', (tester) async {
    await tester.pumpWidget(const SeyraApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();

    expect(find.byType(RegisterPage), findsOneWidget);
  });

  testWidgets('register then login failure then success reaches the shell', (
    tester,
  ) async {
    await tester.pumpWidget(const SeyraApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
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
    await tester.pumpAndSettle();

    expect(find.text(AppConstants.appName), findsWidgets);
    expect(find.text('Alex Carter'), findsOneWidget);

    await tester.tap(find.byKey(const Key('shell_overflow_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shell_sign_out_button')));
    await tester.pumpAndSettle();
    expect(find.text('Log out?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Log out'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('login_username_field')), 'ada');
    await tester.enterText(
      find.byKey(const Key('login_password_field')),
      'wrong',
    );
    await tester.tap(find.byKey(const Key('login_submit_button')));
    await tester.pumpAndSettle();

    expect(find.text('Invalid username or password'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('login_password_field')),
      'secret',
    );
    await tester.tap(find.byKey(const Key('login_submit_button')));
    await tester.pumpAndSettle();

    expect(find.text('Alex Carter'), findsOneWidget);
  });
}
