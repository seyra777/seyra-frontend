import 'package:seyra/features/chat/domain/entities/chat_message.dart';
import 'package:seyra/features/chat/domain/entities/conversation.dart';
import 'package:seyra/features/chat/domain/entities/user_preview.dart';
import 'package:seyra/features/chat/domain/entities/room_member.dart';
import 'package:seyra/features/notifications/domain/entities/notification_models.dart';

/// Local/mock or future remote adapter. Domain stays independent of storage.
abstract interface class ChatDataSource {
  Stream<List<Conversation>> watchConversations();

  Stream<List<ChatMessage>> watchMessages(String conversationId);

  Stream<bool> watchPeerTyping(String conversationId);

  Stream<IncomingAlert> watchIncomingAlerts();

  Conversation? getConversation(String id);

  String get currentUserId;

  Future<Conversation> startDirectChat(String username);

  Future<Conversation> startGroup({
    required String title,
    required List<String> usernames,
  });

  Future<Conversation> startChannel({
    required String title,
    required List<String> usernames,
    String visibility = 'private',
  });

  Future<List<RoomMember>> listMembers(String conversationId);

  Future<List<RoomMember>> addMembers({
    required String conversationId,
    required List<String> usernames,
  });

  Future<void> removeMember({
    required String conversationId,
    required String userId,
  });

  Future<void> setMemberRole({
    required String conversationId,
    required String userId,
    required MemberRole role,
  });

  Future<void> leaveConversation(String conversationId);

  Future<List<UserPreview>> searchUsers(String query);

  Future<void> refreshConversations();

  void setActiveConversation(String? conversationId);

  Future<ChatMessage> retryMessage({
    required String conversationId,
    required String messageId,
  });

  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String body,
    String? replyToId,
    String? attachmentId,
  });

  Future<void> deleteMessage({
    required String conversationId,
    required String messageId,
  });

  Future<void> reactToMessage({
    required String conversationId,
    required String messageId,
    required String emoji,
  });

  Future<void> markConversationRead(String conversationId);

  Future<void> clearConversation(String conversationId);

  Future<void> setMuted({required String conversationId, required bool muted});
}

final class ChatNotFoundException implements Exception {
  const ChatNotFoundException(this.message);

  final String message;
}
