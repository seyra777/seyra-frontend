import 'package:flutter_test/flutter_test.dart';
import 'package:seyra/core/errors/failures.dart';
import 'package:seyra/core/errors/result.dart';
import 'package:seyra/features/chat/domain/entities/conversation.dart';
import 'package:seyra/features/chat/domain/entities/user_preview.dart';
import 'package:seyra/features/notifications/domain/entities/notification_models.dart';
import 'package:seyra/features/chat/domain/repositories/chat_repository.dart';
import 'package:seyra/features/chat/domain/usecases/start_direct_chat_use_case.dart';
import 'package:seyra/features/chat/domain/entities/chat_message.dart';
import '../../../helpers/chat_room_repository_stub.dart';

void main() {
  test('rejects a blank username', () async {
    final useCase = StartDirectChatUseCase(_FakeRepo());
    final result = await useCase('  ');
    expect((result as FailureResult<Conversation>).failure, isA<ValidationFailure>());
  });

  test('starts a direct chat', () async {
    final repo = _FakeRepo();
    final useCase = StartDirectChatUseCase(repo);
    final result = await useCase(' lin ');
    expect((result as Success<Conversation>).value.id, 'cht_1');
    expect(repo.username, 'lin');
  });
}

final class _FakeRepo with ChatRoomRepositoryStub implements ChatRepository {
  String? username;

  @override
  String get currentUserId => 'usr_ada';

  @override
  Future<Result<Conversation>> startDirectChat(String username) async {
    this.username = username;
    return Success(
      Conversation(
        id: 'cht_1',
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
  Future<Result<List<UserPreview>>> searchUsers(String query) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<void>> refreshConversations() async {
    throw UnimplementedError();
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
