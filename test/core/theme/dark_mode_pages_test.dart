import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seyra/core/errors/result.dart';
import 'package:seyra/core/theme/app_colors.dart';
import 'package:seyra/core/theme/app_theme.dart';
import 'package:seyra/features/auth/domain/entities/auth_session.dart';
import 'package:seyra/features/auth/domain/repositories/auth_repository.dart';
import 'package:seyra/features/auth/domain/usecases/delete_account_use_case.dart';
import 'package:seyra/features/auth/domain/usecases/login_use_case.dart';
import 'package:seyra/features/auth/presentation/pages/login_page.dart';
import 'package:seyra/features/chat/data/repositories/mock_chat_social_repository.dart';
import 'package:seyra/features/chat/domain/entities/chat_message.dart';
import 'package:seyra/features/chat/domain/entities/conversation.dart';
import 'package:seyra/features/chat/domain/entities/user_preview.dart';
import 'package:seyra/features/chat/domain/repositories/chat_repository.dart';
import 'package:seyra/features/chat/domain/usecases/search_users_use_case.dart';
import 'package:seyra/features/chat/domain/usecases/start_direct_chat_use_case.dart';
import 'package:seyra/features/chat/domain/usecases/start_group_use_case.dart';
import 'package:seyra/features/chat/presentation/pages/new_conversation_page.dart';
import 'package:seyra/features/chat/presentation/pages/new_group_page.dart';
import 'package:seyra/features/chat/presentation/pages/social_pages.dart';
import 'package:seyra/features/notifications/domain/entities/notification_models.dart';
import 'package:seyra/features/profile/domain/entities/user_profile.dart';
import 'package:seyra/features/profile/domain/repositories/profile_repository.dart';
import 'package:seyra/features/profile/domain/usecases/change_username_use_case.dart';
import 'package:seyra/features/profile/presentation/pages/delete_account_page.dart';
import 'package:seyra/features/profile/presentation/pages/settings_detail_pages.dart';

import '../../helpers/chat_room_repository_stub.dart';

void main() {
  Future<void> pumpDark(WidgetTester tester, Widget home) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: home,
      ),
    );
  }

  void expectDarkChrome(WidgetTester tester) {
    final context = tester.element(find.byType(Scaffold).first);
    expect(Theme.of(context).scaffoldBackgroundColor, AppColors.darkBg);
    expect(Theme.of(context).colorScheme.surface, AppColors.darkSurface);
    expect(Theme.of(context).colorScheme.primary, AppColors.darkAccent);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(
      scaffold.backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
      AppColors.darkBg,
    );
  }

  testWidgets('new chat search uses navy chrome and surface fill', (tester) async {
    await pumpDark(
      tester,
      NewConversationPage(
        searchUsers: SearchUsersUseCase(_SearchRepo()),
        startDirectChat: StartDirectChatUseCase(_SearchRepo()),
        onOpened: (_) {},
      ),
    );

    expectDarkChrome(tester);
    expect(find.text('Find someone on Seyra'), findsOneWidget);
    final field = tester.widget<TextField>(
      find.byKey(const Key('new_chat_username_field')),
    );
    expect(field.decoration?.fillColor, AppColors.darkSurface);
  });

  testWidgets('delete account warning uses dark danger fill', (tester) async {
    await pumpDark(
      tester,
      DeleteAccountPage(
        deleteAccount: DeleteAccountUseCase(_UnusedAuthRepository()),
        onDeleted: () {},
      ),
    );

    expectDarkChrome(tester);
    expect(find.text('This cannot be undone'), findsOneWidget);
    final boxes = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox));
    expect(
      boxes.any((box) {
        final decoration = box.decoration;
        return decoration is BoxDecoration &&
            decoration.color == AppColors.dangerFillOf(
              tester.element(find.byType(Scaffold)),
            );
      }),
      isTrue,
    );
  });

  testWidgets('global search and discover use search-field fill', (tester) async {
    final social = MockChatSocialRepository();
    await pumpDark(tester, GlobalSearchPage(social: social));
    expectDarkChrome(tester);
    expect(find.text('Type at least 2 characters'), findsOneWidget);
    final search = tester.widget<TextField>(find.byType(TextField));
    expect(search.decoration?.fillColor, AppColors.darkSurface);

    await pumpDark(tester, DiscoverChannelsPage(social: social));
    await tester.pump();
    expectDarkChrome(tester);
    expect(find.text('No public channels'), findsOneWidget);
  });

  testWidgets('privacy, bots, sessions, and calls stay on dark scaffold', (
    tester,
  ) async {
    final social = MockChatSocialRepository();
    await pumpDark(tester, PrivacyControlsPage(social: social));
    await tester.pump();
    expectDarkChrome(tester);
    expect(find.text('Last seen visible'), findsOneWidget);

    await pumpDark(tester, BotsPage(social: social));
    await tester.pump();
    expectDarkChrome(tester);
    expect(find.text('Bots'), findsOneWidget);

    await pumpDark(tester, SessionsPage(social: social));
    await tester.pump();
    expectDarkChrome(tester);

    await pumpDark(
      tester,
      CallHistoryPage(social: social, currentUserId: 'usr_ada'),
    );
    await tester.pump();
    expectDarkChrome(tester);
  });

  testWidgets('settings detail pages use dark scaffold', (tester) async {
    await pumpDark(tester, const EncryptionInfoPage());
    expectDarkChrome(tester);
    expect(find.text('1:1 messages (Signal Protocol)'), findsOneWidget);

    await pumpDark(tester, const AboutSeyraPage());
    expectDarkChrome(tester);

    await pumpDark(
      tester,
      SecuritySettingsPage(
        onSessions: () {},
        onPrivacy: () {},
        onEncryption: () {},
      ),
    );
    expectDarkChrome(tester);

    await pumpDark(
      tester,
      UsernamePage(
        currentUsername: 'ada',
        changeUsername: ChangeUsernameUseCase(_ProfileStub()),
      ),
    );
    expectDarkChrome(tester);
  });

  testWidgets('new group and login dark scaffolds', (tester) async {
    final repo = _SearchRepo();
    await pumpDark(
      tester,
      NewGroupPage(
        kind: ConversationKind.group,
        searchUsers: SearchUsersUseCase(repo),
        startGroup: StartGroupUseCase(repo),
        onOpened: (_) {},
      ),
    );
    expectDarkChrome(tester);
    final titleField = tester.widget<TextField>(
      find.byKey(const Key('group_title_field')),
    );
    expect(titleField.decoration?.fillColor, AppColors.darkSurface);

    await pumpDark(
      tester,
      LoginPage(loginUseCase: LoginUseCase(_UnusedAuthRepository())),
    );
    expectDarkChrome(tester);
  });

  testWidgets('light theme switch has no black track outline', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Switch(value: false, onChanged: (_) {}),
        ),
      ),
    );
    final theme = Theme.of(tester.element(find.byType(Switch))).switchTheme;
    expect(theme.trackOutlineColor?.resolve(const {}), Colors.transparent);
    expect(theme.trackOutlineWidth?.resolve(const {}), 0);
    expect(
      theme.trackColor?.resolve(const {}),
      const Color(0xFFE5E7EB),
    );
    expect(theme.thumbColor?.resolve(const {}), Colors.white);
  });
}

final class _SearchRepo with ChatRoomRepositoryStub implements ChatRepository {
  @override
  String get currentUserId => 'usr_ada';

  @override
  Future<Result<List<UserPreview>>> searchUsers(String query) async {
    return const Success([]);
  }

  @override
  Future<Result<Conversation>> startDirectChat(String username) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<Conversation>> startGroup({
    required String title,
    required List<String> usernames,
  }) async {
    throw UnimplementedError();
  }

  @override
  Stream<List<Conversation>> watchConversations() => const Stream.empty();

  @override
  Stream<List<ChatMessage>> watchMessages(String conversationId) =>
      const Stream.empty();

  @override
  Stream<bool> watchPeerTyping(String conversationId) => const Stream.empty();

  @override
  Stream<IncomingAlert> watchIncomingAlerts() => const Stream.empty();

  @override
  Future<Result<Conversation>> getConversation(String id) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<ChatMessage>> sendMessage({
    required String conversationId,
    required String body,
    String? replyToId,
    String? attachmentId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<void>> deleteMessage({
    required String conversationId,
    required String messageId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<void>> reactToMessage({
    required String conversationId,
    required String messageId,
    required String emoji,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<void>> markConversationRead(String conversationId) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<void>> clearConversation(String conversationId) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<void>> setMuted({
    required String conversationId,
    required bool muted,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<void>> refreshConversations() async {
    return const Success<void>(null);
  }

  @override
  void setActiveConversation(String? conversationId) {}

  @override
  Future<Result<ChatMessage>> retryMessage({
    required String conversationId,
    required String messageId,
  }) async {
    throw UnimplementedError();
  }
}

final class _ProfileStub implements ProfileRepository {
  @override
  Stream<UserProfile> watchProfile({
    required String userId,
    required String username,
  }) =>
      const Stream.empty();

  @override
  Stream<UserPreferences> watchPreferences() => const Stream.empty();

  @override
  Future<Result<UserProfile>> updateProfile({
    required String userId,
    required String displayName,
    required String bio,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<UserProfile>> changeUsername(String username) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<UserPreferences>> updatePreferences(
    UserPreferences preferences,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<UserProfile>> uploadAvatar({
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<UserProfile>> removeAvatar() async {
    throw UnimplementedError();
  }

  @override
  Future<List<int>?> fetchAvatar(String userId) async => null;

  @override
  Future<void> reloadRemote() async {}
}

final class _UnusedAuthRepository implements AuthRepository {
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
    return const Success(null);
  }
}
