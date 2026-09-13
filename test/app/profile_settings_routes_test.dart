import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seyra/app/app.dart';
import 'package:seyra/app/di/app_dependencies.dart';
import 'package:seyra/features/auth/data/datasources/mock_auth_remote_data_source.dart';
import 'package:seyra/features/profile/presentation/pages/delete_account_page.dart';
import 'package:seyra/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:seyra/features/profile/presentation/pages/settings_page.dart';

void main() {
  setUp(() async {
    await AppDependencies.initialize(
      remoteDataSource: MockAuthRemoteDataSource(),
    );
  });

  Future<void> register(WidgetTester tester) async {
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
  }

  testWidgets('opens profile and settings, then logs out', (tester) async {
    await register(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Profile'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ada'), findsWidgets);
    expect(find.text('@ada'), findsWidgets);
    expect(find.text('Edit Profile'), findsOneWidget);
    expect(find.text('ACCOUNT INFORMATION'), findsOneWidget);
    expect(find.text('Member since'), findsOneWidget);

    await tester.tap(find.byKey(const Key('profile_open_settings_button')));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
    final settingsScroll = find.descendant(
      of: find.byKey(const Key('settings_scroll')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.textContaining('Signal Protocol'),
      300,
      scrollable: settingsScroll,
    );
    expect(
      find.textContaining('Signal Protocol'),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('settings_logout_tile')),
      300,
      scrollable: settingsScroll,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Log out'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsOneWidget);
    expect(find.byType(SettingsPage), findsNothing);
  });

  testWidgets('delete account requires confirmation text and password', (
    tester,
  ) async {
    await register(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Profile'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile_open_settings_button')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('settings_delete_account_tile')),
      400,
    );
    await tester.tap(find.byKey(const Key('settings_delete_account_tile')));
    await tester.pumpAndSettle();
    expect(find.byType(DeleteAccountPage), findsOneWidget);

    await tester.tap(find.byKey(const Key('delete_account_confirm_button')));
    await tester.pumpAndSettle();
    expect(find.byType(DeleteAccountPage), findsOneWidget);

    await tester.tap(find.byKey(const Key('delete_account_cancel_button')));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);
  });

  testWidgets('delete account with password signs the user out', (
    tester,
  ) async {
    await register(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Profile'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile_open_settings_button')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('settings_delete_account_tile')),
      400,
    );
    await tester.tap(find.byKey(const Key('settings_delete_account_tile')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('delete_account_confirm_text_field')),
      'DELETE',
    );
    await tester.enterText(
      find.byKey(const Key('delete_account_password_field')),
      'secret',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('delete_account_confirm_button')));
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsOneWidget);
    expect(find.byType(SettingsPage), findsNothing);
    expect(find.byType(DeleteAccountPage), findsNothing);
  });

  testWidgets('theme dark mode applies immediately', (tester) async {
    await register(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Profile'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile_open_settings_button')));
    await tester.pumpAndSettle();
    final settingsScroll = find.descendant(
      of: find.byKey(const Key('settings_scroll')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('Dark mode'),
      300,
      scrollable: settingsScroll,
    );
    await tester.tap(find.text('Dark mode'));
    await tester.pumpAndSettle();
    expect(AppDependencies.themeController.value, ThemeMode.dark);
  });

  testWidgets('username page validates then saves', (tester) async {
    await register(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Profile'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile_open_settings_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Username'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ab');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.textContaining('3–32'), findsWidgets);
    await tester.enterText(find.byType(TextField), 'ada_prime');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('@ada_prime'), findsWidgets);
  });

  testWidgets('edit profile saves a display name', (tester) async {
    await register(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Profile'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('edit_profile_button')));
    await tester.pumpAndSettle();

    expect(find.byType(EditProfilePage), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('edit_profile_display_name_field')),
      'Ada Lovelace',
    );
    await tester.tap(find.byKey(const Key('edit_profile_save_button')));
    await tester.pumpAndSettle();

    expect(find.byType(EditProfilePage), findsNothing);
    expect(find.text('Ada Lovelace'), findsOneWidget);
  });
}
