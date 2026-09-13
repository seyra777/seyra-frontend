import 'package:seyra/features/chat/domain/entities/chat_message.dart';

final class ChatMessageModel {
  const ChatMessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.replyToId,
    this.attachmentId,
    this.e2e = false,
    this.editedAt,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String body;
  final DateTime createdAt;
  final String? replyToId;
  final String? attachmentId;
  final bool e2e;
  final DateTime? editedAt;

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      body: json['body'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
      replyToId: json['reply_to_id'] as String?,
      attachmentId: json['attachment_id'] as String?,
      e2e: json['e2e'] == true,
      editedAt: json['edited_at'] == null
          ? null
          : DateTime.parse(json['edited_at'] as String).toUtc(),
    );
  }

  ChatMessage toEntity({String? decryptedBody, String? decryptErrorCode}) {
    return ChatMessage(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      body: decryptedBody ?? body,
      sentAt: createdAt.toLocal(),
      delivery: MessageDelivery.sent,
      replyToId: replyToId,
      attachmentId: attachmentId,
      e2e: e2e,
      edited: editedAt != null,
      decryptErrorCode: decryptErrorCode,
    );
  }
}
