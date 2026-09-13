import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seyra/core/errors/result.dart';
import 'package:seyra/core/theme/app_theme.dart';
import 'package:seyra/features/chat/domain/entities/chat_message.dart';
import 'package:seyra/features/chat/domain/entities/conversation.dart';
import 'package:seyra/features/chat/domain/entities/user_preview.dart';
import 'package:seyra/features/notifications/domain/entities/notification_models.dart';
import 'package:seyra/features/chat/domain/repositories/chat_repository.dart';
import 'package:seyra/features/chat/domain/usecases/clear_conversation_use_case.dart';
import 'package:seyra/features/chat/domain/usecases/delete_message_use_case.dart';
import 'package:seyra/features/chat/domain/usecases/mark_conversation_read_use_case.dart';
import 'package:seyra/features/chat/domain/usecases/react_to_message_use_case.dart';
import 'package:seyra/features/chat/domain/usecases/retry_message_use_case.dart';
import 'package:seyra/features/chat/domain/usecases/send_message_use_case.dart';
import 'package:seyra/features/chat/domain/usecases/set_active_conversation_use_case.dart';
import 'package:seyra/features/chat/domain/usecases/set_conversation_muted_use_case.dart';
import 'package:seyra/features/chat/domain/usecases/watch_conversations_use_case.dart';
import 'package:seyra/features/chat/domain/usecases/watch_messages_use_case.dart';
import 'package:seyra/features/chat/domain/usecases/watch_peer_typing_use_case.dart';
import '../../../helpers/chat_room_repository_stub.dart';
import 'package:seyra/features/chat/presentation/pages/conversation_page.dart';

void main() {
  testWidgets('delete confirms then waits for the repository', (tester) async {
    final repo = _ConversationRepo();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ConversationPage(
          conversationId: 'cht_1',
          watchConversations: WatchConversationsUseCase(repo),
          watchMessages: WatchMessagesUseCase(repo),
          watchPeerTyping: WatchPeerTypingUseCase(repo),
          sendMessage: SendMessageUseCase(repo),
          retryMessage: RetryMessageUseCase(repo),
          deleteMessage: DeleteMessageUseCase(repo),
          reactToMessage: ReactToMessageUseCase(repo),
          markConversationRead: MarkConversationReadUseCase(repo),
          clearConversation: ClearConversationUseCase(repo),
          setMuted: SetConversationMutedUseCase(repo),
          setActiveConversation: SetActiveConversationUseCase(
            repo.setActiveConversation,
          ),
          currentUserId: 'usr_ada',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('delete me'));
    await tester.pumpAndSettle();
    expect(find.text('Reply'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
    await tester.tap(find.byKey(const Key('message_action_delete')));
    await tester.pumpAndSettle();
    expect(find.text('Delete message?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm_delete_message')));
    await tester.pumpAndSettle();
    expect(repo.deletedId, 'msg_mine');
    expect(repo.activeId, 'cht_1');
  });

  testWidgets('long press then dismiss shows delete selection chrome', (
    tester,
  ) async {
    final repo = _ConversationRepo();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ConversationPage(
          conversationId: 'cht_1',
          watchConversations: WatchConversationsUseCase(repo),
          watchMessages: WatchMessagesUseCase(repo),
          watchPeerTyping: WatchPeerTypingUseCase(repo),
          sendMessage: SendMessageUseCase(repo),
          retryMessage: RetryMessageUseCase(repo),
          deleteMessage: DeleteMessageUseCase(repo),
          reactToMessage: ReactToMessageUseCase(repo),
          markConversationRead: MarkConversationReadUseCase(repo),
          clearConversation: ClearConversationUseCase(repo),
          setMuted: SetConversationMutedUseCase(repo),
          setActiveConversation: SetActiveConversationUseCase(
            repo.setActiveConversation,
          ),
          currentUserId: 'usr_ada',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('delete me'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(12, 12));
    await tester.pumpAndSettle();

    expect(find.text('Delete messages'), findsOneWidget);
    expect(find.text('1 message selected'), findsOneWidget);
    expect(find.text('Delete (1)'), findsOneWidget);
    expect(find.byKey(const Key('selection_footer_delete')), findsOneWidget);
    expect(find.byKey(const Key('selection_appbar_delete')), findsNothing);
    expect(find.text('Delete'), findsNothing);
    expect(find.byKey(const Key('composer_text_field')), findsNothing);
  });

  testWidgets('double tapping send only sends once', (tester) async {
    final repo = _ConversationRepo();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ConversationPage(
          conversationId: 'cht_1',
          watchConversations: WatchConversationsUseCase(repo),
          watchMessages: WatchMessagesUseCase(repo),
          watchPeerTyping: WatchPeerTypingUseCase(repo),
          sendMessage: SendMessageUseCase(repo),
          retryMessage: RetryMessageUseCase(repo),
          deleteMessage: DeleteMessageUseCase(repo),
          reactToMessage: ReactToMessageUseCase(repo),
          markConversationRead: MarkConversationReadUseCase(repo),
          clearConversation: ClearConversationUseCase(repo),
          setMuted: SetConversationMutedUseCase(repo),
          setActiveConversation: SetActiveConversationUseCase(
            repo.setActiveConversation,
          ),
          currentUserId: 'usr_ada',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('composer_text_field')), 'hi');
    await tester.pump();
    await tester.tap(find.byKey(const Key('composer_send_button')));
    await tester.tap(find.byKey(const Key('composer_send_button')));
    await tester.pump();
    expect(repo.sendCalls, 1);
    repo.sendGate.complete();
    await tester.pumpAndSettle();
    expect(repo.sendCalls, 1);
  });
}

final class _ConversationRepo with ChatRoomRepositoryStub implements ChatRepository {
  String? deletedId;
  String? activeId;
  var sendCalls = 0;
  final sendGate = Completer<void>();

  static final _conversation = Conversation(
    id: 'cht_1',
    title: 'lin',
    initials: 'LI',
    kind: ConversationKind.direct,
    lastMessagePreview: 'delete me',
    lastMessageAt: DateTime.utc(2026, 9, 8),
  );

  static final _message = ChatMessage(
    id: 'msg_mine',
    conversationId: 'cht_1',
    senderId: 'usr_ada',
    body: 'delete me',
    sentAt: DateTime.utc(2026, 9, 8, 12),
    delivery: MessageDelivery.sent,
  );

  @override
  String get currentUserId => 'usr_ada';

  @override
  Stream<List<Conversation>> watchConversations() async* {
    yield [_conversation];
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String conversationId) async* {
    yield [_message];
  }

  @override
  Stream<bool> watchPeerTyping(String conversationId) async* {
    yield false;
  }

  @override
  Stream<IncomingAlert> watchIncomingAlerts() => const Stream.empty();

  @override
  Future<Result<void>> deleteMessage({
    required String conversationId,
    required String messageId,
  }) async {
    deletedId = messageId;
    return const Success<void>(null);
  }

  @override
  void setActiveConversation(String? conversationId) {
    activeId = conversationId;
  }

  @override
  Future<Result<void>> markConversationRead(String conversationId) async {
    return const Success<void>(null);
  }

  @override
  Future<Result<Conversation>> getConversation(String id) async {
    return Success(_conversation);
  }

  @override
  Future<Result<Conversation>> startDirectChat(String username) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<List<UserPreview>>> searchUsers(String query) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<void>> refreshConversations() async {
    return const Success<void>(null);
  }

  @override
  Future<Result<ChatMessage>> retryMessage({
    required String conversationId,
    required String messageId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<ChatMessage>> sendMessage({
    required String conversationId,
    required String body,
    String? replyToId,
    String? attachmentId,
  }) async {
    sendCalls += 1;
    await sendGate.future;
    return Success(
      ChatMessage(
        id: 'msg_sent_$sendCalls',
        conversationId: conversationId,
        senderId: currentUserId,
        body: body,
        sentAt: DateTime.utc(2026, 9, 8, 12),
        delivery: MessageDelivery.sent,
      ),
    );
  }

  @override
  Future<Result<void>> reactToMessage({
    required String conversationId,
    required String messageId,
    required String emoji,
  }) async {
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> clearConversation(String conversationId) async {
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> setMuted({
    required String conversationId,
    required bool muted,
  }) async {
    return const Success<void>(null);
  }
}
