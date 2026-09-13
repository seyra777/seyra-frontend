import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seyra/app/app.dart';
import 'package:seyra/app/di/app_dependencies.dart';
import 'package:seyra/features/auth/data/datasources/mock_auth_remote_data_source.dart';
import 'package:seyra/features/chat/data/datasources/mock_chat_data_source.dart';
import 'package:seyra/features/chat/presentation/pages/conversation_page.dart';

void main() {
  setUp(() async {
    await AppDependencies.initialize(
      remoteDataSource: MockAuthRemoteDataSource(),
      chatSource: MockChatDataSource(now: DateTime(2026, 9, 7, 21, 0)),
    );
  });

  testWidgets('opens a conversation, sends a message, then returns', (
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

    expect(find.text('Alex Carter'), findsOneWidget);

    await tester.tap(find.byKey(const Key('conversation_tile_1')));
    await tester.pumpAndSettle();

    expect(find.byType(ConversationPage), findsOneWidget);
    expect(find.text('Did you get the encrypted files?'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('composer_text_field')),
      'On my way',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('composer_send_button')));
    await tester.pumpAndSettle();

    expect(find.text('On my way'), findsWidgets);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(ConversationPage), findsNothing);
    expect(find.text('On my way'), findsOneWidget);
  });
}
