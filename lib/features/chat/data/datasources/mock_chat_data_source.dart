import 'dart:async';

import 'package:seyra/features/chat/data/datasources/chat_data_source.dart';
import 'package:seyra/features/chat/domain/entities/chat_message.dart';
import 'package:seyra/features/chat/domain/entities/conversation.dart';
import 'package:seyra/features/chat/domain/entities/user_preview.dart';
import 'package:seyra/features/chat/domain/entities/room_member.dart';
import 'package:seyra/features/notifications/domain/entities/notification_models.dart';

final class MockChatDataSource implements ChatDataSource {
  MockChatDataSource({
    this.deliveryDelay = Duration.zero,
    DateTime? now,
  }) : _now = now ?? DateTime.now() {
    _conversations = _seedConversations(_now);
    _messages = _seedMessages(_now);
  }

  /// When non-zero, mock delivery/read and optional peer replies are delayed.
  final Duration deliveryDelay;
  final DateTime _now;

  late List<Conversation> _conversations;
  late Map<String, List<ChatMessage>> _messages;
  final Map<String, List<RoomMember>> _members = {};
  final Map<String, bool> _typing = {};
  int _seq = 0;

  final _conversationsController =
      StreamController<List<Conversation>>.broadcast();
  final Map<String, StreamController<List<ChatMessage>>> _messageControllers =
      {};
  final Map<String, StreamController<bool>> _typingControllers = {};
  String? _activeConversationId;
  final _alertsController = StreamController<IncomingAlert>.broadcast();

  static const _me = ChatMessage.localUserId;

  @override
  Stream<List<Conversation>> watchConversations() async* {
    yield _sortedConversations();
    yield* _conversationsController.stream;
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String conversationId) async* {
    yield List.unmodifiable(_messages[conversationId] ?? const []);
    yield* _controllerFor(conversationId).stream;
  }

  @override
  Stream<bool> watchPeerTyping(String conversationId) async* {
    yield _typing[conversationId] ?? false;
    yield* _typingControllerFor(conversationId).stream;
  }

  @override
  Stream<IncomingAlert> watchIncomingAlerts() => _alertsController.stream;

  @override
  Conversation? getConversation(String id) {
    for (final item in _conversations) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  @override
  String get currentUserId => _me;

  @override
  Future<Conversation> startDirectChat(String username) async {
    final key = username.trim();
    if (key.isEmpty) {
      throw const ChatNotFoundException('Username is required');
    }
    for (final item in _conversations) {
      if (item.kind == ConversationKind.direct &&
          item.title.toLowerCase() == key.toLowerCase()) {
        return item;
      }
    }
    final conversation = Conversation(
      id: 'local-${++_seq}',
      title: key,
      initials: _initials(key),
      kind: ConversationKind.direct,
      lastMessagePreview: 'No messages yet',
      lastMessageAt: DateTime.now(),
      statusText: '@$key',
    );
    _conversations = [..._conversations, conversation];
    _messages[conversation.id] = [];
    _conversationsController.add(_sortedConversations());
    return conversation;
  }

  @override
  Future<Conversation> startGroup({
    required String title,
    required List<String> usernames,
  }) {
    return _startRoom(title: title, usernames: usernames, kind: ConversationKind.group);
  }

  @override
  Future<Conversation> startChannel({
    required String title,
    required List<String> usernames,
    String visibility = 'private',
  }) {
    return _startRoom(
      title: title,
      usernames: usernames,
      kind: ConversationKind.channel,
      visibility: visibility,
    );
  }

  Future<Conversation> _startRoom({
    required String title,
    required List<String> usernames,
    required ConversationKind kind,
    String visibility = 'private',
  }) async {
    final name = title.trim();
    if (name.isEmpty || (kind == ConversationKind.group && usernames.isEmpty)) {
      throw const ChatNotFoundException('A title and members are required');
    }
    final conversation = Conversation(
      id: 'local-${++_seq}',
      title: name,
      initials: _initials(name),
      kind: kind,
      lastMessagePreview: 'No messages yet',
      lastMessageAt: DateTime.now(),
      visibility: visibility,
      statusText: kind == ConversationKind.group
          ? '${usernames.length + 1} members'
          : 'Channel',
    );
    _conversations = [..._conversations, conversation];
    _messages[conversation.id] = [];
    _members[conversation.id] = [
      RoomMember(id: _me, username: 'you', role: MemberRole.owner),
      ...usernames.map(
        (name) => RoomMember(
          id: 'peer-$name',
          username: name,
          role: MemberRole.member,
        ),
      ),
    ];
    _conversationsController.add(_sortedConversations());
    return conversation;
  }

  @override
  Future<List<RoomMember>> listMembers(String conversationId) async {
    return List<RoomMember>.from(_members[conversationId] ?? const []);
  }

  @override
  Future<List<RoomMember>> addMembers({
    required String conversationId,
    required List<String> usernames,
  }) async {
    final current = [...(_members[conversationId] ?? const <RoomMember>[])];
    for (final name in usernames) {
      if (current.any((m) => m.username.toLowerCase() == name.toLowerCase())) {
        continue;
      }
      current.add(
        RoomMember(id: 'peer-$name', username: name, role: MemberRole.member),
      );
    }
    _members[conversationId] = current;
    return current;
  }

  @override
  Future<void> removeMember({
    required String conversationId,
    required String userId,
  }) async {
    final current = [...(_members[conversationId] ?? const <RoomMember>[])];
    current.removeWhere((m) => m.id == userId && m.role != MemberRole.owner);
    _members[conversationId] = current;
  }

  @override
  Future<void> setMemberRole({
    required String conversationId,
    required String userId,
    required MemberRole role,
  }) async {
    final current = [...(_members[conversationId] ?? const <RoomMember>[])];
    _members[conversationId] = [
      for (final m in current)
        if (m.id == userId && m.role != MemberRole.owner)
          RoomMember(id: m.id, username: m.username, role: role)
        else
          m,
    ];
  }

  @override
  Future<void> leaveConversation(String conversationId) async {
    _conversations = _conversations.where((item) => item.id != conversationId).toList();
    _members.remove(conversationId);
    _conversationsController.add(_sortedConversations());
  }

  @override
  Future<List<UserPreview>> searchUsers(String query) async {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) {
      return const [];
    }
    final seen = <String>{};
    final out = <UserPreview>[];
    for (final item in _conversations) {
      if (item.kind != ConversationKind.direct) {
        continue;
      }
      if (!item.title.toLowerCase().contains(needle) &&
          !item.statusText.toLowerCase().contains(needle)) {
        continue;
      }
      final username = item.statusText.startsWith('@')
          ? item.statusText.substring(1)
          : item.title;
      final key = username.toLowerCase();
      if (!seen.add(key)) {
        continue;
      }
      out.add(UserPreview(id: item.id, username: username));
    }
    return out;
  }

  @override
  Future<void> refreshConversations() async {
    _conversationsController.add(_sortedConversations());
  }

  @override
  void setActiveConversation(String? conversationId) {
    _activeConversationId = conversationId;
  }

  @override
  Future<ChatMessage> retryMessage({
    required String conversationId,
    required String messageId,
  }) async {
    final items = _messages[conversationId];
    if (items == null) {
      throw const ChatNotFoundException('Conversation not found');
    }
    ChatMessage? failed;
    for (final item in items) {
      if (item.id == messageId) {
        failed = item;
        break;
      }
    }
    if (failed == null) {
      throw const ChatNotFoundException('Message not found');
    }
    items.removeWhere((item) => item.id == messageId);
    _emitMessages(conversationId);
    return sendMessage(conversationId: conversationId, body: failed.body);
  }

  @override
  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String body,
    String? replyToId,
    String? attachmentId,
  }) async {
    final conversation = getConversation(conversationId);
    if (conversation == null) {
      throw const ChatNotFoundException('Conversation not found');
    }

    String? replyPreview;
    if (replyToId != null) {
      for (final item in _messages[conversationId] ?? const <ChatMessage>[]) {
        if (item.id == replyToId) {
          replyPreview = item.body;
          break;
        }
      }
    }

    final message = ChatMessage(
      id: 'local-${++_seq}',
      conversationId: conversationId,
      senderId: _me,
      body: body,
      sentAt: DateTime.now(),
      delivery: deliveryDelay == Duration.zero
          ? MessageDelivery.read
          : MessageDelivery.sent,
      replyToId: replyToId,
      replyPreview: replyPreview,
      attachmentId: attachmentId,
    );

    _append(conversationId, message);
    _updateConversationPreview(conversationId, message.body, message.sentAt);

    if (deliveryDelay > Duration.zero) {
      unawaited(_progressDelivery(conversationId, message.id));
      if (conversation.kind == ConversationKind.direct) {
        unawaited(_mockPeerReply(conversationId));
      }
    }

    return message;
  }

  @override
  Future<void> deleteMessage({
    required String conversationId,
    required String messageId,
  }) async {
    final items = _messages[conversationId];
    if (items == null) {
      throw const ChatNotFoundException('Conversation not found');
    }
    items.removeWhere((item) => item.id == messageId);
    _emitMessages(conversationId);
    final last = items.isEmpty ? null : items.last;
    _updateConversationPreview(
      conversationId,
      last?.body ?? 'No messages yet',
      last?.sentAt ?? DateTime.now(),
    );
  }

  @override
  Future<void> reactToMessage({
    required String conversationId,
    required String messageId,
    required String emoji,
  }) async {
    final items = _messages[conversationId];
    if (items == null) {
      throw const ChatNotFoundException('Conversation not found');
    }
    final index = items.indexWhere((item) => item.id == messageId);
    if (index < 0) {
      throw const ChatNotFoundException('Message not found');
    }
    final current = items[index];
    final existing = [...current.reactions];
    final reactionIndex = existing.indexWhere((item) => item.emoji == emoji);
    if (reactionIndex >= 0) {
      final reaction = existing[reactionIndex];
      if (reaction.reactedByMe) {
        if (reaction.count <= 1) {
          existing.removeAt(reactionIndex);
        } else {
          existing[reactionIndex] = MessageReaction(
            emoji: emoji,
            count: reaction.count - 1,
            reactedByMe: false,
          );
        }
      } else {
        existing[reactionIndex] = MessageReaction(
          emoji: emoji,
          count: reaction.count + 1,
          reactedByMe: true,
        );
      }
    } else {
      existing.add(
        MessageReaction(emoji: emoji, count: 1, reactedByMe: true),
      );
    }
    items[index] = current.copyWith(reactions: existing);
    _emitMessages(conversationId);
  }

  @override
  Future<void> markConversationRead(String conversationId) async {
    final conversation = getConversation(conversationId);
    if (conversation == null) {
      throw const ChatNotFoundException('Conversation not found');
    }
    _replaceConversation(conversation.copyWith(unreadCount: 0));
  }

  @override
  Future<void> clearConversation(String conversationId) async {
    if (getConversation(conversationId) == null) {
      throw const ChatNotFoundException('Conversation not found');
    }
    _messages[conversationId] = [];
    _emitMessages(conversationId);
    _updateConversationPreview(
      conversationId,
      'No messages yet',
      DateTime.now(),
    );
  }

  @override
  Future<void> setMuted({required String conversationId, required bool muted}) async {
    final conversation = getConversation(conversationId);
    if (conversation == null) {
      throw const ChatNotFoundException('Conversation not found');
    }
    _replaceConversation(conversation.copyWith(isMuted: muted));
  }

  void dispose() {
    unawaited(_conversationsController.close());
    for (final controller in _messageControllers.values) {
      unawaited(controller.close());
    }
    for (final controller in _typingControllers.values) {
      unawaited(controller.close());
    }
  }

  List<Conversation> _sortedConversations() {
    final items = [..._conversations];
    items.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      return b.lastMessageAt.compareTo(a.lastMessageAt);
    });
    return List.unmodifiable(items);
  }

  void _append(String conversationId, ChatMessage message) {
    final items = _messages.putIfAbsent(conversationId, () => []);
    items.add(message);
    _emitMessages(conversationId);
  }

  void _replaceMessage(
    String conversationId,
    String messageId,
    ChatMessage Function(ChatMessage current) update,
  ) {
    final items = _messages[conversationId];
    if (items == null) {
      return;
    }
    final index = items.indexWhere((item) => item.id == messageId);
    if (index < 0) {
      return;
    }
    items[index] = update(items[index]);
    _emitMessages(conversationId);
  }

  void _replaceConversation(Conversation conversation) {
    _conversations = [
      for (final item in _conversations)
        if (item.id == conversation.id) conversation else item,
    ];
    _conversationsController.add(_sortedConversations());
  }

  void _updateConversationPreview(
    String conversationId,
    String preview,
    DateTime at, {
    bool fromPeer = false,
  }) {
    final conversation = getConversation(conversationId);
    if (conversation == null) {
      return;
    }
    final unread = conversationId == _activeConversationId
        ? 0
        : fromPeer
        ? conversation.unreadCount + 1
        : conversation.unreadCount;
    _replaceConversation(
      conversation.copyWith(
        lastMessagePreview: preview,
        lastMessageAt: at,
        unreadCount: unread,
      ),
    );
  }

  StreamController<List<ChatMessage>> _controllerFor(String id) {
    return _messageControllers.putIfAbsent(
      id,
      StreamController<List<ChatMessage>>.broadcast,
    );
  }

  StreamController<bool> _typingControllerFor(String id) {
    return _typingControllers.putIfAbsent(
      id,
      StreamController<bool>.broadcast,
    );
  }

  void _emitMessages(String conversationId) {
    _controllerFor(conversationId).add(
      List.unmodifiable(_messages[conversationId] ?? const []),
    );
  }

  void _setTyping(String conversationId, bool value) {
    _typing[conversationId] = value;
    _typingControllerFor(conversationId).add(value);
  }

  Future<void> _progressDelivery(
    String conversationId,
    String messageId,
  ) async {
    await Future<void>.delayed(deliveryDelay);
    _replaceMessage(
      conversationId,
      messageId,
      (current) => current.copyWith(delivery: MessageDelivery.delivered),
    );
    await Future<void>.delayed(deliveryDelay);
    _replaceMessage(
      conversationId,
      messageId,
      (current) => current.copyWith(delivery: MessageDelivery.read),
    );
  }

  Future<void> _mockPeerReply(String conversationId) async {
    await Future<void>.delayed(deliveryDelay);
    _setTyping(conversationId, true);
    await Future<void>.delayed(deliveryDelay);
    _setTyping(conversationId, false);
    final conversation = getConversation(conversationId);
    if (conversation == null) {
      return;
    }
    final reply = ChatMessage(
      id: 'peer-${++_seq}',
      conversationId: conversationId,
      senderId: 'peer-$conversationId',
      body: 'Got it — talking on Seyra.',
      sentAt: DateTime.now(),
      delivery: MessageDelivery.read,
    );
    _append(conversationId, reply);
    _updateConversationPreview(
      conversationId,
      reply.body,
      reply.sentAt,
      fromPeer: true,
    );
  }

  static List<Conversation> _seedConversations(DateTime now) {
    final today = DateTime(now.year, now.month, now.day, 12, 4);
    return [
      Conversation(
        id: '1',
        title: 'Alex Carter',
        initials: 'AC',
        kind: ConversationKind.direct,
        lastMessagePreview: 'Did you get the encrypted files?',
        lastMessageAt: today,
        unreadCount: 2,
        isOnline: true,
        isPinned: true,
        statusText: 'online',
      ),
      Conversation(
        id: '2',
        title: 'Design Team',
        initials: 'DT',
        kind: ConversationKind.group,
        lastMessagePreview: 'Maya: Let\'s ship the new header tonight.',
        lastMessageAt: DateTime(now.year, now.month, now.day, 11, 41),
        isPinned: true,
        statusText: '12 members',
      ),
      Conversation(
        id: '3',
        title: 'Seyra News',
        initials: 'SN',
        kind: ConversationKind.channel,
        lastMessagePreview: 'Privacy update is live for everyone.',
        lastMessageAt: DateTime(now.year, now.month, now.day - 1, 18, 20),
        unreadCount: 12,
        statusText: 'Channel',
      ),
      Conversation(
        id: '4',
        title: 'Jordan Lee',
        initials: 'JL',
        kind: ConversationKind.direct,
        lastMessagePreview: 'Voice message',
        lastMessageAt: DateTime(now.year, now.month, now.day, 10, 12),
        isMuted: true,
        statusText: 'last seen recently',
      ),
      Conversation(
        id: '5',
        title: 'Maya Chen',
        initials: 'MC',
        kind: ConversationKind.direct,
        lastMessagePreview: 'See you at 6. I\'ll bring the keys.',
        lastMessageAt: DateTime(now.year, now.month, now.day, 9, 18),
        unreadCount: 1,
        isOnline: true,
        statusText: 'online',
      ),
      Conversation(
        id: '6',
        title: 'Weekend Hikers',
        initials: 'WH',
        kind: ConversationKind.group,
        lastMessagePreview: 'Sam: Trail photos are in the album.',
        lastMessageAt: now.subtract(const Duration(days: 2, hours: 3)),
        statusText: '8 members',
      ),
      Conversation(
        id: '7',
        title: 'Security Tips',
        initials: 'ST',
        kind: ConversationKind.channel,
        lastMessagePreview: 'How to lock down your account in 2 minutes.',
        lastMessageAt: now.subtract(const Duration(days: 3, hours: 5)),
        statusText: 'Channel',
      ),
      Conversation(
        id: '8',
        title: 'Noah Patel',
        initials: 'NP',
        kind: ConversationKind.direct,
        lastMessagePreview: 'Thanks — received and deleted on my side.',
        lastMessageAt: now.subtract(const Duration(days: 4, hours: 2)),
        statusText: 'last seen Saturday',
      ),
    ];
  }

  static Map<String, List<ChatMessage>> _seedMessages(DateTime now) {
    DateTime today(int hour, int minute) =>
        DateTime(now.year, now.month, now.day, hour, minute);
    DateTime daysAgo(int days, int hour, int minute) =>
        DateTime(now.year, now.month, now.day - days, hour, minute);

    return {
      '1': [
        ChatMessage(
          id: '1-a',
          conversationId: '1',
          senderId: 'peer-1',
          body: 'Are you around this afternoon?',
          sentAt: today(11, 52),
          delivery: MessageDelivery.read,
        ),
        ChatMessage(
          id: '1-b',
          conversationId: '1',
          senderId: _me,
          body: 'Yes — finishing the Seyra chat screen now.',
          sentAt: today(11, 54),
          delivery: MessageDelivery.read,
          replyToId: '1-a',
          replyPreview: 'Are you around this afternoon?',
        ),
        ChatMessage(
          id: '1-c',
          conversationId: '1',
          senderId: 'peer-1',
          body: 'Did you get the encrypted files?',
          sentAt: today(12, 4),
          delivery: MessageDelivery.read,
          reactions: const [
            MessageReaction(emoji: '👍', count: 1, reactedByMe: false),
          ],
        ),
      ],
      '2': [
        ChatMessage(
          id: '2-a',
          conversationId: '2',
          senderId: 'maya',
          body: 'Header mock is in Figma.',
          sentAt: today(11, 20),
          delivery: MessageDelivery.read,
        ),
        ChatMessage(
          id: '2-b',
          conversationId: '2',
          senderId: _me,
          body: 'Looks clean. I\'ll match the bubbles.',
          sentAt: today(11, 28),
          delivery: MessageDelivery.read,
        ),
        ChatMessage(
          id: '2-c',
          conversationId: '2',
          senderId: 'maya',
          body: 'Let\'s ship the new header tonight.',
          sentAt: today(11, 41),
          delivery: MessageDelivery.read,
        ),
      ],
      '3': [
        ChatMessage(
          id: '3-a',
          conversationId: '3',
          senderId: 'channel-3',
          body: 'Privacy update is live for everyone.',
          sentAt: daysAgo(1, 18, 20),
          delivery: MessageDelivery.read,
        ),
      ],
      '4': [
        ChatMessage(
          id: '4-a',
          conversationId: '4',
          senderId: 'peer-4',
          body: 'Voice message',
          sentAt: today(10, 12),
          delivery: MessageDelivery.read,
        ),
      ],
      '5': [
        ChatMessage(
          id: '5-a',
          conversationId: '5',
          senderId: 'peer-5',
          body: 'See you at 6. I\'ll bring the keys.',
          sentAt: today(9, 18),
          delivery: MessageDelivery.read,
        ),
      ],
      '6': [
        ChatMessage(
          id: '6-a',
          conversationId: '6',
          senderId: 'sam',
          body: 'Trail photos are in the album.',
          sentAt: daysAgo(2, 16, 10),
          delivery: MessageDelivery.read,
        ),
      ],
      '7': [
        ChatMessage(
          id: '7-a',
          conversationId: '7',
          senderId: 'channel-7',
          body: 'How to lock down your account in 2 minutes.',
          sentAt: daysAgo(3, 9, 0),
          delivery: MessageDelivery.read,
        ),
      ],
      '8': [
        ChatMessage(
          id: '8-a',
          conversationId: '8',
          senderId: _me,
          body: 'Files received. Deleting my local copy.',
          sentAt: daysAgo(4, 14, 2),
          delivery: MessageDelivery.read,
        ),
        ChatMessage(
          id: '8-b',
          conversationId: '8',
          senderId: 'peer-8',
          body: 'Thanks — received and deleted on my side.',
          sentAt: daysAgo(4, 14, 8),
          delivery: MessageDelivery.read,
        ),
      ],
    };
  }

  static String _initials(String username) {
    final value = username.trim();
    if (value.isEmpty) {
      return '?';
    }
    if (value.length == 1) {
      return value.toUpperCase();
    }
    return value.substring(0, 2).toUpperCase();
  }
}
