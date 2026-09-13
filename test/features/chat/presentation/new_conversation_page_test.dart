import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seyra/core/errors/result.dart';
import 'package:seyra/core/theme/app_theme.dart';
import 'package:seyra/features/chat/domain/entities/conversation.dart';
import 'package:seyra/features/chat/domain/entities/user_preview.dart';
import 'package:seyra/features/chat/domain/repositories/chat_repository.dart';
import 'package:seyra/features/chat/domain/usecases/search_users_use_case.dart';
import 'package:seyra/features/chat/domain/usecases/start_direct_chat_use_case.dart';
import 'package:seyra/features/chat/domain/entities/chat_message.dart';
import 'package:seyra/features/notifications/domain/entities/notification_models.dart';
import 'package:seyra/features/chat/presentation/pages/new_conversation_page.dart';
import '../../../helpers/chat_room_repository_stub.dart';

void main() {
  testWidgets('searches usernames and opens a chat', (tester) async {
    final repo = _SearchRepo();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: NewConversationPage(
          searchUsers: SearchUsersUseCase(repo),
          startDirectChat: StartDirectChatUseCase(repo),
          onOpened: (id) => repo.opened = id,
        ),
      ),
    );

    expect(find.text('Find someone on Seyra'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('new_chat_username_field')), 'li');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('new_chat_result_lin')), findsOneWidget);
    await tester.tap(find.byKey(const Key('new_chat_result_lin')));
    await tester.pumpAndSettle();
    expect(repo.opened, 'cht_lin');
  });

  testWidgets('shows no-results state', (tester) async {
    final repo = _SearchRepo(results: const []);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: NewConversationPage(
          searchUsers: SearchUsersUseCase(repo),
          startDirectChat: StartDirectChatUseCase(repo),
          onOpened: (_) {},
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('new_chat_username_field')), 'zzz');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('new_chat_empty_results')), findsOneWidget);
  });
}

final class _SearchRepo with ChatRoomRepositoryStub implements ChatRepository {
  _SearchRepo({
    this.results = const [UserPreview(id: 'usr_lin', username: 'lin')],
  });

  final List<UserPreview> results;
  String? opened;

  @override
  String get currentUserId => 'usr_ada';

  @override
  Future<Result<List<UserPreview>>> searchUsers(String query) async {
    return Success(results);
  }

  @override
  Future<Result<Conversation>> startDirectChat(String username) async {
    return Success(
      Conversation(
        id: 'cht_$username',
        title: username,
        initials: 'LI',
        kind: ConversationKind.direct,
        lastMessagePreview: '',
        lastMessageAt: DateTime.utc(2026, 9, 8),
      ),
    );
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
