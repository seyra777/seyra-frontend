class IncomingAlert {
  const IncomingAlert({
    required this.conversationId,
    required this.title,
    required this.body,
    required this.messageId,
  });

  final String conversationId;
  final String title;
  final String body;
  final String messageId;
}

final class NotificationPreferences {
  const NotificationPreferences({
    this.messagesEnabled = true,
    this.callsEnabled = true,
    this.showPreview = true,
  });

  final bool messagesEnabled;
  final bool callsEnabled;
  final bool showPreview;

  NotificationPreferences copyWith({
    bool? messagesEnabled,
    bool? callsEnabled,
    bool? showPreview,
  }) {
    return NotificationPreferences(
      messagesEnabled: messagesEnabled ?? this.messagesEnabled,
      callsEnabled: callsEnabled ?? this.callsEnabled,
      showPreview: showPreview ?? this.showPreview,
    );
  }
}
