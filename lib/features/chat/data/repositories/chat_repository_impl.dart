import 'package:seyra/core/errors/failures.dart';
import 'package:seyra/core/errors/network_failure.dart';
import 'package:seyra/core/errors/result.dart';
import 'package:seyra/features/auth/domain/failures/auth_failures.dart';
import 'package:seyra/features/chat/data/datasources/chat_data_source.dart';
import 'package:seyra/features/chat/data/exceptions/chat_remote_exceptions.dart';
import 'package:seyra/features/chat/domain/entities/chat_message.dart';
import 'package:seyra/features/chat/domain/entities/conversation.dart';
import 'package:seyra/features/chat/domain/entities/user_preview.dart';
import 'package:seyra/features/chat/domain/entities/room_member.dart';
import 'package:seyra/features/chat/domain/failures/chat_failures.dart';
import 'package:seyra/features/chat/domain/repositories/chat_repository.dart';
import 'package:seyra/features/notifications/domain/entities/notification_models.dart';

final class ChatRepositoryImpl implements ChatRepository {
  const ChatRepositoryImpl({required this.dataSource});

  final ChatDataSource dataSource;

  @override
  Stream<List<Conversation>> watchConversations() {
    return dataSource.watchConversations();
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String conversationId) {
    return dataSource.watchMessages(conversationId);
  }

  @override
  Stream<bool> watchPeerTyping(String conversationId) {
    return dataSource.watchPeerTyping(conversationId);
  }

  @override
  Stream<IncomingAlert> watchIncomingAlerts() {
    return dataSource.watchIncomingAlerts();
  }

  @override
  Future<Result<Conversation>> getConversation(String id) async {
    final conversation = dataSource.getConversation(id);
    if (conversation == null) {
      return const FailureResult(UnexpectedFailure('Conversation not found'));
    }
    return Success(conversation);
  }

  @override
  String get currentUserId => dataSource.currentUserId;

  @override
  Future<Result<Conversation>> startDirectChat(String username) {
    return _map(() => dataSource.startDirectChat(username));
  }

  @override
  Future<Result<Conversation>> startGroup({
    required String title,
    required List<String> usernames,
  }) {
    return _map(() => dataSource.startGroup(title: title, usernames: usernames));
  }

  @override
  Future<Result<Conversation>> startChannel({
    required String title,
    required List<String> usernames,
    String visibility = 'private',
  }) {
    return _map(
      () => dataSource.startChannel(
        title: title,
        usernames: usernames,
        visibility: visibility,
      ),
    );
  }

  @override
  Future<Result<List<RoomMember>>> listMembers(String conversationId) {
    return _map(() => dataSource.listMembers(conversationId));
  }

  @override
  Future<Result<List<RoomMember>>> addMembers({
    required String conversationId,
    required List<String> usernames,
  }) {
    return _map(
      () => dataSource.addMembers(
        conversationId: conversationId,
        usernames: usernames,
      ),
    );
  }

  @override
  Future<Result<void>> removeMember({
    required String conversationId,
    required String userId,
  }) {
    return _mapVoid(
      () => dataSource.removeMember(
        conversationId: conversationId,
        userId: userId,
      ),
    );
  }

  @override
  Future<Result<void>> setMemberRole({
    required String conversationId,
    required String userId,
    required MemberRole role,
  }) {
    return _mapVoid(
      () => dataSource.setMemberRole(
        conversationId: conversationId,
        userId: userId,
        role: role,
      ),
    );
  }

  @override
  Future<Result<void>> leaveConversation(String conversationId) {
    return _mapVoid(() => dataSource.leaveConversation(conversationId));
  }

  @override
  Future<Result<List<UserPreview>>> searchUsers(String query) {
    return _map(() => dataSource.searchUsers(query));
  }

  @override
  Future<Result<void>> refreshConversations() {
    return _mapVoid(dataSource.refreshConversations);
  }

  @override
  void setActiveConversation(String? conversationId) {
    dataSource.setActiveConversation(conversationId);
  }

  @override
  Future<Result<ChatMessage>> retryMessage({
    required String conversationId,
    required String messageId,
  }) {
    return _map(
      () => dataSource.retryMessage(
        conversationId: conversationId,
        messageId: messageId,
      ),
    );
  }

  @override
  Future<Result<ChatMessage>> sendMessage({
    required String conversationId,
    required String body,
    String? replyToId,
    String? attachmentId,
  }) {
    return _map(
      () => dataSource.sendMessage(
        conversationId: conversationId,
        body: body,
        replyToId: replyToId,
        attachmentId: attachmentId,
      ),
    );
  }

  @override
  Future<Result<void>> deleteMessage({
    required String conversationId,
    required String messageId,
  }) {
    return _mapVoid(
      () => dataSource.deleteMessage(
        conversationId: conversationId,
        messageId: messageId,
      ),
    );
  }

  @override
  Future<Result<void>> reactToMessage({
    required String conversationId,
    required String messageId,
    required String emoji,
  }) {
    return _mapVoid(
      () => dataSource.reactToMessage(
        conversationId: conversationId,
        messageId: messageId,
        emoji: emoji,
      ),
    );
  }

  @override
  Future<Result<void>> markConversationRead(String conversationId) {
    return _mapVoid(() => dataSource.markConversationRead(conversationId));
  }

  @override
  Future<Result<void>> clearConversation(String conversationId) {
    return _mapVoid(() => dataSource.clearConversation(conversationId));
  }

  @override
  Future<Result<void>> setMuted({
    required String conversationId,
    required bool muted,
  }) {
    return _mapVoid(
      () => dataSource.setMuted(conversationId: conversationId, muted: muted),
    );
  }

  Future<Result<T>> _map<T>(Future<T> Function() action) async {
    try {
      return Success(await action());
    } on ChatRemoteException catch (error) {
      return FailureResult(_mapRemote(error));
    } on ChatNotFoundException catch (error) {
      return FailureResult(UnexpectedFailure(error.message));
    } catch (_) {
      return const FailureResult(UnexpectedFailure());
    }
  }

  Future<Result<void>> _mapVoid(Future<void> Function() action) async {
    try {
      await action();
      return const Success<void>(null);
    } on ChatRemoteException catch (error) {
      return FailureResult(_mapRemote(error));
    } on ChatNotFoundException catch (error) {
      return FailureResult(UnexpectedFailure(error.message));
    } catch (_) {
      return const FailureResult(UnexpectedFailure());
    }
  }

  Failure _mapRemote(ChatRemoteException error) {
    return switch (error.code) {
      ChatRemoteErrorCode.notFound => const ChatUserNotFoundFailure(),
      ChatRemoteErrorCode.forbidden => const ChatForbiddenFailure(),
      ChatRemoteErrorCode.cannotMessageSelf => const CannotMessageSelfFailure(),
      ChatRemoteErrorCode.unauthorized => const UnauthorizedFailure(),
      ChatRemoteErrorCode.sessionExpired => const SessionExpiredFailure(),
      ChatRemoteErrorCode.invalidInput =>
        const ValidationFailure('Invalid request'),
      ChatRemoteErrorCode.alreadyMember =>
        const ValidationFailure('That user is already a member'),
      ChatRemoteErrorCode.ownerProtected => const ChatOwnerProtectedFailure(),
      ChatRemoteErrorCode.network => const NetworkFailure(),
    };
  }
}
