import 'package:seyra/core/errors/result.dart';
import 'package:seyra/features/chat/domain/entities/chat_message.dart';
import 'package:seyra/features/chat/domain/entities/conversation.dart';
import 'package:seyra/features/chat/domain/entities/user_preview.dart';
import 'package:seyra/features/chat/domain/entities/room_member.dart';
import 'package:seyra/features/notifications/domain/entities/notification_models.dart';

abstract interface class ChatRepository {
  Stream<List<Conversation>> watchConversations();

  Stream<List<ChatMessage>> watchMessages(String conversationId);

  Stream<bool> watchPeerTyping(String conversationId);

  Stream<IncomingAlert> watchIncomingAlerts();

  Future<Result<Conversation>> getConversation(String id);

  Future<Result<Conversation>> startDirectChat(String username);

  Future<Result<Conversation>> startGroup({
    required String title,
    required List<String> usernames,
  });

  Future<Result<Conversation>> startChannel({
    required String title,
    required List<String> usernames,
    String visibility = 'private',
  });

  Future<Result<List<RoomMember>>> listMembers(String conversationId);

  Future<Result<List<RoomMember>>> addMembers({
    required String conversationId,
    required List<String> usernames,
  });

  Future<Result<void>> removeMember({
    required String conversationId,
    required String userId,
  });

  Future<Result<void>> setMemberRole({
    required String conversationId,
    required String userId,
    required MemberRole role,
  });

  Future<Result<void>> leaveConversation(String conversationId);

  Future<Result<List<UserPreview>>> searchUsers(String query);

  Future<Result<void>> refreshConversations();

  void setActiveConversation(String? conversationId);

  Future<Result<ChatMessage>> retryMessage({
    required String conversationId,
    required String messageId,
  });

  String get currentUserId;

  Future<Result<ChatMessage>> sendMessage({
    required String conversationId,
    required String body,
    String? replyToId,
    String? attachmentId,
  });

  Future<Result<void>> deleteMessage({
    required String conversationId,
    required String messageId,
  });

  Future<Result<void>> reactToMessage({
    required String conversationId,
    required String messageId,
    required String emoji,
  });

  Future<Result<void>> markConversationRead(String conversationId);

  Future<Result<void>> clearConversation(String conversationId);

  Future<Result<void>> setMuted({
    required String conversationId,
    required bool muted,
  });
}
