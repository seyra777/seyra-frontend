enum MessageDelivery { sending, sent, delivered, read, failed }

final class MessageReaction {
  const MessageReaction({
    required this.emoji,
    required this.count,
    required this.reactedByMe,
  });

  final String emoji;
  final int count;
  final bool reactedByMe;
}

final class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.sentAt,
    required this.delivery,
    this.replyToId,
    this.replyPreview,
    this.reactions = const [],
    this.attachmentId,
    this.contentType,
    this.fileKey,
    this.fileNonce,
    this.e2e = false,
    this.edited = false,
    this.forwardedFromId,
    this.decryptErrorCode,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String body;
  final DateTime sentAt;
  final MessageDelivery delivery;
  final String? replyToId;
  final String? replyPreview;
  final List<MessageReaction> reactions;
  final String? attachmentId;
  final String? contentType;
  final List<int>? fileKey;
  final List<int>? fileNonce;
  final bool e2e;
  final bool edited;
  final String? forwardedFromId;

  /// Internal E2E failure code (e.g. `e2e.no_session`). Not shown as chat text.
  final String? decryptErrorCode;

  bool isFrom(String userId) => senderId == userId;

  bool get isMine => senderId == ChatMessage.localUserId;

  static const localUserId = 'local-user';

  ChatMessage copyWith({
    String? id,
    String? body,
    MessageDelivery? delivery,
    String? replyPreview,
    List<MessageReaction>? reactions,
    String? attachmentId,
    String? contentType,
    List<int>? fileKey,
    List<int>? fileNonce,
    bool? e2e,
    bool? edited,
    String? decryptErrorCode,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId,
      senderId: senderId,
      body: body ?? this.body,
      sentAt: sentAt,
      delivery: delivery ?? this.delivery,
      replyToId: replyToId,
      replyPreview: replyPreview ?? this.replyPreview,
      reactions: reactions ?? this.reactions,
      attachmentId: attachmentId ?? this.attachmentId,
      contentType: contentType ?? this.contentType,
      fileKey: fileKey ?? this.fileKey,
      fileNonce: fileNonce ?? this.fileNonce,
      e2e: e2e ?? this.e2e,
      edited: edited ?? this.edited,
      forwardedFromId: forwardedFromId,
      decryptErrorCode: decryptErrorCode ?? this.decryptErrorCode,
    );
  }
}
