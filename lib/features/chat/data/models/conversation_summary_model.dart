import 'package:seyra/features/chat/domain/entities/conversation.dart';

String chatInitials(String username) {
  final value = username.trim();
  if (value.isEmpty) {
    return '?';
  }
  if (value.length == 1) {
    return value.toUpperCase();
  }
  return value.substring(0, 2).toUpperCase();
}

ConversationKind conversationKindFromApi(String? value) {
  return switch (value) {
    'group' => ConversationKind.group,
    'channel' => ConversationKind.channel,
    _ => ConversationKind.direct,
  };
}

final class ConversationSummaryModel {
  const ConversationSummaryModel({
    required this.id,
    required this.kind,
    required this.title,
    required this.peerId,
    required this.peerUsername,
    required this.lastMessagePreview,
    required this.lastMessageAt,
    required this.unreadCount,
    required this.memberCount,
    this.lastMessageId = '',
    this.lastMessageSenderId = '',
    this.lastMessageBody = '',
    this.lastMessageE2e = false,
  });

  final String id;
  final ConversationKind kind;
  final String title;
  final String peerId;
  final String peerUsername;
  final String lastMessagePreview;
  final DateTime lastMessageAt;
  final int unreadCount;
  final int memberCount;
  final String lastMessageId;
  final String lastMessageSenderId;
  final String lastMessageBody;
  final bool lastMessageE2e;

  factory ConversationSummaryModel.fromJson(Map<String, dynamic> json) {
    final peer = json['peer'] as Map<String, dynamic>? ?? const {};
    final peerUsername = peer['username'] as String? ?? '';
    final title = (json['title'] as String?)?.trim() ?? '';
    return ConversationSummaryModel(
      id: json['id'] as String,
      kind: conversationKindFromApi(json['kind'] as String?),
      title: title.isEmpty ? peerUsername : title,
      peerId: peer['id'] as String? ?? '',
      peerUsername: peerUsername,
      lastMessagePreview: json['last_message_preview'] as String? ?? '',
      lastMessageAt: DateTime.parse(json['last_message_at'] as String).toUtc(),
      unreadCount: json['unread_count'] as int? ?? 0,
      memberCount: json['member_count'] as int? ?? 0,
      lastMessageId: json['last_message_id'] as String? ?? '',
      lastMessageSenderId: json['last_message_sender_id'] as String? ?? '',
      lastMessageBody: json['last_message_body'] as String? ?? '',
      lastMessageE2e: json['last_message_e2e'] == true,
    );
  }

  Conversation toEntity({String? preview}) {
    final shown = preview ?? lastMessagePreview;
    final statusText = switch (kind) {
      ConversationKind.group =>
        memberCount > 0 ? '$memberCount members' : 'Group',
      ConversationKind.channel => 'Channel',
      ConversationKind.direct =>
        peerUsername.isEmpty ? '' : '@$peerUsername',
    };
    return Conversation(
      id: id,
      title: title,
      initials: chatInitials(title),
      kind: kind,
      lastMessagePreview: shown.isEmpty ? 'No messages yet' : shown,
      lastMessageAt: lastMessageAt.toLocal(),
      unreadCount: unreadCount,
      statusText: statusText,
      peerId: peerId,
    );
  }
}
