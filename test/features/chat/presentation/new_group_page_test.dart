import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seyra/core/errors/result.dart';
import 'package:seyra/core/theme/app_theme.dart';
import 'package:seyra/features/chat/domain/entities/chat_message.dart';
import 'package:seyra/features/chat/domain/entities/conversation.dart';
import 'package:seyra/features/chat/domain/entities/user_preview.dart';
import 'package:seyra/features/chat/domain/repositories/chat_repository.dart';
import 'package:seyra/features/chat/domain/usecases/search_users_use_case.dart';
import 'package:seyra/features/chat/domain/usecases/start_group_use_case.dart';
import 'package:seyra/features/chat/presentation/pages/new_group_page.dart';
import 'package:seyra/features/notifications/domain/entities/notification_models.dart';

import '../../../helpers/chat_room_repository_stub.dart';

void main() {
  testWidgets('creates a group with selected members', (tester) async {
    final repo = _GroupRepo();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: NewGroupPage(
          kind: ConversationKind.group,
          searchUsers: SearchUsersUseCase(repo),
          startGroup: StartGroupUseCase(repo),
          onOpened: (id) => repo.opened = id,
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('group_title_field')), 'Design');
    await tester.enterText(find.byKey(const Key('group_member_search_field')), 'li');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('group_result_lin')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('create_group_button')));
    await tester.pump();
    await tester.pump();
    expect(repo.opened, 'grp_1');
    expect(repo.title, 'Design');
    expect(repo.usernames, ['lin']);
  });
}

final class _GroupRepo with ChatRoomRepositoryStub implements ChatRepository {
  String? opened;
  String? title;
  List<String>? usernames;

  @override
  String get currentUserId => 'usr_ada';

  @override
  Future<Result<List<UserPreview>>> searchUsers(String query) async {
    return const Success([UserPreview(id: 'usr_lin', username: 'lin')]);
  }

  @override
  Future<Result<Conversation>> startGroup({
    required String title,
    required List<String> usernames,
  }) async {
    this.title = title;
    this.usernames = usernames;
    return Success(
      Conversation(
        id: 'grp_1',
        title: title,
        initials: 'DE',
        kind: ConversationKind.group,
        lastMessagePreview: '',
        lastMessageAt: DateTime.utc(2026, 9, 8),
      ),
    );
  }

  @override
  Future<Result<Conversation>> startDirectChat(String username) async {
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
