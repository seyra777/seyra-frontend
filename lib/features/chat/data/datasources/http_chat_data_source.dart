import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:seyra/core/network/api_client.dart';
import 'package:seyra/core/storage/secure_storage.dart';
import 'package:seyra/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:seyra/features/auth/data/exceptions/auth_remote_exceptions.dart';
import 'package:seyra/features/auth/data/models/current_account_model.dart';
import 'package:seyra/features/auth/data/storage/auth_secure_storage_keys.dart';
import 'package:seyra/features/chat/data/contracts/chat_api_endpoints.dart';
import 'package:seyra/features/chat/data/crypto/signal_e2e_service.dart';
import 'package:seyra/features/chat/data/datasources/chat_data_source.dart';
import 'package:seyra/features/chat/data/exceptions/chat_remote_exceptions.dart';
import 'package:seyra/features/chat/data/models/chat_message_model.dart';
import 'package:seyra/features/chat/data/models/conversation_summary_model.dart';
import 'package:seyra/features/chat/data/models/call_signaling.dart';
import 'package:seyra/features/chat/data/models/message_sync.dart';
import 'package:seyra/features/chat/data/realtime/chat_realtime_port.dart';
import 'package:seyra/features/chat/domain/entities/chat_message.dart';
import 'package:seyra/features/chat/domain/entities/conversation.dart';
import 'package:seyra/features/chat/domain/entities/user_preview.dart';
import 'package:seyra/features/chat/domain/entities/room_member.dart';
import 'package:seyra/features/notifications/domain/entities/notification_models.dart';

final class HttpChatDataSource implements ChatDataSource {
  HttpChatDataSource({
    required this.apiClient,
    required this.secureStorage,
    required this.authRemote,
    required this.baseUrl,
    required this.realtime,
  });

  final ApiClient apiClient;
  final SecureStorage secureStorage;
  final AuthRemoteDataSource authRemote;
  final Uri baseUrl;
  final ChatRealtimePort realtime;

  String _currentUserId = '';
  var _started = false;
  List<Conversation> _conversations = [];
  final Map<String, List<ChatMessage>> _messages = {};
  final Map<String, String> _messageCursors = {};
  final _conversationsController =
      StreamController<List<Conversation>>.broadcast();
  final Map<String, StreamController<List<ChatMessage>>> _messageControllers =
      {};
  StreamSubscription<Map<String, dynamic>>? _realtimeSub;
  String? _activeConversationId;
  var _pendingSeq = 0;
  final _alertsController = StreamController<IncomingAlert>.broadcast();
  final _callSignals = StreamController<Map<String, dynamic>>.broadcast();
  final _callSignalBuffer = CallSignalBuffer();
  final Map<String, StreamController<bool>> _typingControllers = {};
  SignalE2eService? _e2e;
  var _keysPublished = false;
  final _e2ePlaintext = <String, String>{};
  final _e2eCiphertext = <String, String>{};
  final _e2ePlaintextByCipher = <String, String>{};

  @override
  String get currentUserId => _currentUserId;

  @override
  Stream<List<Conversation>> watchConversations() async* {
    await _ensureStarted();
    yield List<Conversation>.from(_conversations);
    yield* _conversationsController.stream;
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String conversationId) async* {
    await _ensureStarted();
    await _loadMessages(conversationId);
    yield List<ChatMessage>.from(_messages[conversationId] ?? const []);
    yield* _controllerFor(conversationId).stream;
  }

  @override
  Stream<bool> watchPeerTyping(String conversationId) async* {
    yield false;
    yield* _typingControllers
        .putIfAbsent(conversationId, StreamController<bool>.broadcast)
        .stream;
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

  List<ChatMessage> peekMessages(String conversationId) {
    return List<ChatMessage>.from(_messages[conversationId] ?? const []);
  }

  @override
  Future<Conversation> startDirectChat(String username) async {
    await _ensureStarted();
    final response = await _authorized(
      method: 'POST',
      path: ChatApiEndpoints.chats,
      jsonBody: {'username': username},
    );
    final conversation = ConversationSummaryModel.fromJson(
      _decodeObject(response.body),
    ).toEntity();
    _upsertConversation(conversation);
    return conversation;
  }

  @override
  Future<Conversation> startGroup({
    required String title,
    required List<String> usernames,
  }) {
    return _startRoom(
      path: ChatApiEndpoints.groups,
      title: title,
      usernames: usernames,
    );
  }

  @override
  Future<Conversation> startChannel({
    required String title,
    required List<String> usernames,
    String visibility = 'private',
  }) {
    return _startRoom(
      path: ChatApiEndpoints.channels,
      title: title,
      usernames: usernames,
      visibility: visibility,
    );
  }

  Future<Conversation> _startRoom({
    required String path,
    required String title,
    required List<String> usernames,
    String visibility = 'private',
  }) async {
    await _ensureStarted();
    final response = await _authorized(
      method: 'POST',
      path: path,
      jsonBody: {
        'title': title,
        'usernames': usernames,
        if (visibility.isNotEmpty) 'visibility': visibility,
      },
    );
    final conversation = ConversationSummaryModel.fromJson(
      _decodeObject(response.body),
    ).toEntity();
    _upsertConversation(conversation);
    return conversation;
  }

  @override
  Future<List<RoomMember>> listMembers(String conversationId) async {
    await _ensureStarted();
    final response = await _authorized(
      method: 'GET',
      path: ChatApiEndpoints.members(conversationId),
    );
    return _parseMembers(_decodeObject(response.body));
  }

  @override
  Future<List<RoomMember>> addMembers({
    required String conversationId,
    required List<String> usernames,
  }) async {
    await _ensureStarted();
    final response = await _authorized(
      method: 'POST',
      path: ChatApiEndpoints.members(conversationId),
      jsonBody: {'usernames': usernames},
    );
    unawaited(refreshConversations());
    return _parseMembers(_decodeObject(response.body));
  }

  @override
  Future<void> removeMember({
    required String conversationId,
    required String userId,
  }) async {
    await _ensureStarted();
    await _authorized(
      method: 'DELETE',
      path: ChatApiEndpoints.member(conversationId, userId),
    );
    unawaited(refreshConversations());
  }

  @override
  Future<void> setMemberRole({
    required String conversationId,
    required String userId,
    required MemberRole role,
  }) async {
    await _ensureStarted();
    final value = switch (role) {
      MemberRole.owner => 'owner',
      MemberRole.admin => 'admin',
      MemberRole.member => 'member',
    };
    await _authorized(
      method: 'POST',
      path: ChatApiEndpoints.memberRole(conversationId, userId),
      jsonBody: {'role': value},
    );
  }

  @override
  Future<void> leaveConversation(String conversationId) async {
    await _ensureStarted();
    await _authorized(
      method: 'POST',
      path: ChatApiEndpoints.leave(conversationId),
    );
    _conversations = _conversations.where((item) => item.id != conversationId).toList();
    _conversationsController.add(List<Conversation>.from(_conversations));
  }

  List<RoomMember> _parseMembers(Map<String, dynamic> json) {
    final raw = json['members'];
    final out = <RoomMember>[];
    if (raw is! List) {
      return out;
    }
    for (final item in raw) {
      if (item is Map<String, dynamic>) {
        out.add(
          RoomMember(
            id: item['id'] as String? ?? '',
            username: item['username'] as String? ?? '',
            role: memberRoleFromApi(item['role'] as String?),
          ),
        );
      }
    }
    return out;
  }

  @override
  Future<List<UserPreview>> searchUsers(String query) async {
    await _ensureStarted();
    final encoded = Uri.encodeQueryComponent(query.trim());
    final response = await _authorized(
      method: 'GET',
      path: '${ChatApiEndpoints.userSearch}?q=$encoded',
    );
    final json = _decodeObject(response.body);
    final raw = json['users'];
    final users = <UserPreview>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          final id = item['id'] as String? ?? '';
          final username = item['username'] as String? ?? '';
          if (id.isEmpty || username.isEmpty) {
            continue;
          }
          users.add(UserPreview(id: id, username: username));
        }
      }
    }
    return users;
  }

  @override
  Future<void> refreshConversations() async {
    await _ensureStarted();
    await _loadConversations();
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
    await _ensureStarted();
    final items = _messages[conversationId] ?? const <ChatMessage>[];
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
    return _sendWithLocal(
      conversationId: conversationId,
      body: failed.body,
      replaceId: messageId,
    );
  }

  @override
  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String body,
    String? replyToId,
    String? attachmentId,
  }) async {
    await _ensureStarted();
    return _sendWithLocal(
      conversationId: conversationId,
      body: body,
      replyToId: replyToId,
      attachmentId: attachmentId,
    );
  }

  Future<ChatMessage> _sendWithLocal({
    required String conversationId,
    required String body,
    String? replyToId,
    String? replaceId,
    String? attachmentId,
  }) async {
    final localId = replaceId ?? 'pending_${++_pendingSeq}';
    var outbound = body;
    var e2e = false;
    final conversation = getConversation(conversationId);
    if (conversation?.kind == ConversationKind.direct && body.isNotEmpty) {
      try {
        await _ensureE2e();
        try {
          if (!_keysPublished) {
            await publishLocalKeys();
          }
        } catch (_) {}
        final peerId = conversation!.peerId;
        if (peerId.isNotEmpty) {
          // Only adopt from inbound PreKey messages when we have no session.
          if (!await _e2e!.hasSession(peerId)) {
            await _adoptSessionFromPeerMessages(conversationId);
          }
          try {
            await establishSession(peerId);
          } catch (_) {
            // Peer may not have published keys yet.
          }
          if (await _e2e!.hasSession(peerId)) {
            final cipher = await _e2e!.encrypt(
              peerUserId: peerId,
              plaintext: body,
            );
            if (cipher == null) {
              throw const ChatRemoteException(ChatRemoteErrorCode.invalidInput);
            }
            outbound = cipher;
            e2e = true;
            await _rememberPlaintext('', body, ciphertext: cipher);
          }
        }
      } on ChatRemoteException {
        rethrow;
      } catch (_) {
        // Crypto blew up after a session existed — do not fall back to plaintext.
        final peerId = conversation?.peerId ?? '';
        if (e2e ||
            (peerId.isNotEmpty &&
                _e2e != null &&
                await _e2e!.hasSession(peerId))) {
          throw const ChatRemoteException(ChatRemoteErrorCode.invalidInput);
        }
      }
    }
    if (_containsAttachmentKeys(body) && !e2e) {
      throw const ChatRemoteException(ChatRemoteErrorCode.invalidInput);
    }
    final pending = ChatMessage(
      id: localId,
      conversationId: conversationId,
      senderId: _currentUserId,
      body: body,
      sentAt: DateTime.now(),
      delivery: MessageDelivery.sending,
      attachmentId: attachmentId,
      e2e: e2e,
    );
    if (replaceId == null) {
      _upsertMessage(pending, countUnread: false);
    } else {
      _replaceMessage(conversationId, localId, pending);
    }
    try {
      final response = await _authorized(
        method: 'POST',
        path: ChatApiEndpoints.messages(conversationId),
        jsonBody: {
          'body': outbound,
          if (replyToId != null && replyToId.isNotEmpty) 'reply_to_id': replyToId,
          if (attachmentId != null && attachmentId.isNotEmpty)
            'attachment_id': attachmentId,
          if (e2e) 'e2e': true,
        },
      );
      final message = await _hydrateMessage(
        ChatMessageModel.fromJson(_decodeObject(response.body)),
        outgoingPlaintext: body,
      );
      await _rememberPlaintext(message.id, body, ciphertext: outbound);
      _removeMessage(conversationId, localId);
      _upsertMessage(message, countUnread: false);
      return message;
    } catch (error) {
      final acked = _ackedOutgoing(conversationId, pending);
      if (acked != null) {
        _removeMessage(conversationId, localId);
        return acked;
      }
      _replaceMessage(
        conversationId,
        localId,
        pending.copyWith(delivery: MessageDelivery.failed),
      );
      rethrow;
    }
  }

  @override
  Future<void> deleteMessage({
    required String conversationId,
    required String messageId,
  }) async {
    await _authorized(
      method: 'DELETE',
      path: ChatApiEndpoints.message(conversationId, messageId),
    );
    final items = _messages[conversationId];
    if (items == null) {
      return;
    }
    items.removeWhere((item) => item.id == messageId);
    _emitMessages(conversationId);
  }

  @override
  Future<void> reactToMessage({
    required String conversationId,
    required String messageId,
    required String emoji,
  }) async {
    await _ensureStarted();
    await _authorized(
      method: 'PUT',
      path: ChatApiEndpoints.reactions(conversationId, messageId),
      jsonBody: {'emoji': emoji},
    );
  }

  @override
  Future<void> markConversationRead(String conversationId) async {
    final conversation = getConversation(conversationId);
    if (conversation == null) {
      return;
    }
    _upsertConversation(conversation.copyWith(unreadCount: 0));
    try {
      await _authorized(
        method: 'POST',
        path: ChatApiEndpoints.markRead(conversationId),
      );
    } catch (_) {}
  }

  Future<void> _pullPeerReceipt(String conversationId) async {
    final conversation = getConversation(conversationId);
    if (conversation == null || conversation.kind != ConversationKind.direct) {
      return;
    }
    try {
      final response = await _authorized(
        method: 'GET',
        path: ChatApiEndpoints.receipts(conversationId),
      );
      final json = _decodeObject(response.body);
      if (json['visible'] != true) {
        return;
      }
      final at = DateTime.tryParse(json['last_read_at'] as String? ?? '');
      if (at != null) {
        _applyPeerRead(conversationId, at.toUtc());
      }
    } catch (_) {}
  }

  void _applyPeerRead(String conversationId, DateTime lastReadAt) {
    final items = _messages[conversationId];
    if (items == null) {
      return;
    }
    var changed = false;
    for (var i = 0; i < items.length; i++) {
      final message = items[i];
      if (message.senderId != _currentUserId) {
        continue;
      }
      if (message.delivery == MessageDelivery.sending ||
          message.delivery == MessageDelivery.failed) {
        continue;
      }
      if (message.sentAt.toUtc().isAfter(lastReadAt)) {
        continue;
      }
      if (message.delivery != MessageDelivery.read) {
        items[i] = message.copyWith(delivery: MessageDelivery.read);
        changed = true;
      }
    }
    if (changed) {
      _emitMessages(conversationId);
    }
  }

  @override
  Future<void> clearConversation(String conversationId) async {
    _messages[conversationId] = [];
    _emitMessages(conversationId);
  }

  @override
  Future<void> setMuted({
    required String conversationId,
    required bool muted,
  }) async {
    await _authorized(
      method: 'PUT',
      path: '/v1/chats/$conversationId/mute',
      jsonBody: {'value': muted},
    );
    final conversation = getConversation(conversationId);
    if (conversation == null) {
      return;
    }
    _upsertConversation(conversation.copyWith(isMuted: muted));
  }

  Future<void> _ensureStarted() async {
    final CurrentAccountModel account;
    try {
      account = await authRemote.getCurrentAccount();
    } on AuthRemoteException catch (error) {
      throw ChatRemoteException(_fromAuth(error.code));
    }
    if (_started && account.id == _currentUserId) {
      return;
    }
    await _bindAccount(account.id);
  }

  Future<void> _bindAccount(String userId) async {
    await _realtimeSub?.cancel();
    _realtimeSub = null;
    await realtime.disconnect();
    _conversations = [];
    _messages.clear();
    _messageCursors.clear();
    _e2e = null;
    _keysPublished = false;
    _e2ePlaintext.clear();
    _e2eCiphertext.clear();
    _e2ePlaintextByCipher.clear();
    _currentUserId = userId;
    _started = true;
    _conversationsController.add(const []);
    await _loadE2eOutbox();
    await _loadConversations();
    try {
      if (!_keysPublished) {
        await publishLocalKeys();
      }
    } catch (_) {}
    await _connectRealtime();
  }

  Future<void> _loadConversations() async {
    final response = await _authorized(
      method: 'GET',
      path: ChatApiEndpoints.chats,
    );
    final json = _decodeObject(response.body);
    final raw = json['chats'];
    final chats = <Conversation>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          chats.add(
            await _conversationFromSummary(
              ConversationSummaryModel.fromJson(item),
            ),
          );
        }
      }
    }
    _conversations = chats;
    _conversationsController.add(List<Conversation>.from(_conversations));
  }

  Future<Conversation> _conversationFromSummary(
    ConversationSummaryModel model,
  ) async {
    var preview = model.lastMessagePreview;
    final cached = _messages[model.id];
    if (cached != null && cached.isNotEmpty) {
      final last = cached.last;
      if (!isE2eDecryptPlaceholder(last) &&
          last.decryptErrorCode == null &&
          last.body.isNotEmpty) {
        preview = last.body;
      }
    } else if (model.lastMessageE2e && model.lastMessageBody.isNotEmpty) {
      final hydrated = await _hydrateMessage(
        ChatMessageModel(
          id: model.lastMessageId.isEmpty ? 'preview_${model.id}' : model.lastMessageId,
          conversationId: model.id,
          senderId: model.lastMessageSenderId,
          body: model.lastMessageBody,
          createdAt: model.lastMessageAt,
          e2e: true,
        ),
      );
      preview = cloudHistoryPreview(hydrated);
    }
    return model.toEntity(preview: preview);
  }

  void _refreshConversationPreview(String conversationId) {
    final conversation = getConversation(conversationId);
    final items = _messages[conversationId];
    if (conversation == null || items == null || items.isEmpty) {
      return;
    }
    final last = items.last;
    final preview = cloudHistoryPreview(last);
    if (preview.isEmpty) {
      return;
    }
    if (conversation.lastMessagePreview == preview) {
      return;
    }
    _upsertConversation(
      conversation.copyWith(
        lastMessagePreview: preview,
        lastMessageAt: last.sentAt,
      ),
    );
  }

  Future<void> _loadMessages(
    String conversationId, {
    String? before,
    bool prepend = false,
  }) async {
    final response = await _authorized(
      method: 'GET',
      path: ChatApiEndpoints.messages(
        conversationId,
        before: before,
        limit: 100,
      ),
    );
    final json = _decodeObject(response.body);
    final raw = json['messages'];
    final models = <ChatMessageModel>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          models.add(ChatMessageModel.fromJson(item));
        }
      }
    }
    final items = <ChatMessage>[];
    for (final model in models) {
      items.add(await _hydrateMessage(model));
    }
    for (var pass = 0; pass < 2; pass++) {
      var progressed = false;
      for (var i = 0; i < items.length; i++) {
        if (!isE2eDecryptPlaceholder(items[i])) {
          continue;
        }
        if (models[i].senderId == _currentUserId) {
          continue;
        }
        final again = await _hydrateMessage(models[i]);
        if (!isE2eDecryptPlaceholder(again)) {
          items[i] = again;
          progressed = true;
        }
      }
      if (!progressed) {
        break;
      }
    }
    final previous = List<ChatMessage>.from(
      _messages[conversationId] ?? const <ChatMessage>[],
    );
    if (prepend && before != null) {
      _messages[conversationId] = mergeMessagesById(
        local: previous,
        remote: items,
      );
    } else {
      _messages[conversationId] = mergeMessagesById(
        local: previous,
        remote: items,
      );
    }
    _messageCursors[conversationId] = json['next_before'] as String? ?? '';
    _emitMessages(conversationId);
    _refreshConversationPreview(conversationId);
    unawaited(_pullPeerReceipt(conversationId));
  }

  /// Fetch older cloud history using the server `before` cursor.
  Future<void> loadOlderMessages(String conversationId) async {
    await _ensureStarted();
    final existing = _messages[conversationId];
    final cursor = _messageCursors[conversationId];
    final before = (cursor != null && cursor.isNotEmpty)
        ? cursor
        : (existing == null || existing.isEmpty ? null : existing.first.id);
    if (before == null || before.isEmpty) {
      await _loadMessages(conversationId);
      return;
    }
    await _loadMessages(conversationId, before: before, prepend: true);
  }

  Future<void> _connectRealtime() async {
    final access = await secureStorage.read(AuthSecureStorageKeys.accessToken);
    if (access == null || access.isEmpty) {
      return;
    }
    final wsUrl = _wsUri(baseUrl.resolve(ChatApiEndpoints.realtime));
    await _realtimeSub?.cancel();
    _realtimeSub = realtime
        .connect(
          uri: wsUrl,
          accessToken: () =>
              secureStorage.read(AuthSecureStorageKeys.accessToken),
        )
        .listen(
          _onRealtime,
          onError: (_) {
            unawaited(_resyncAfterReconnect());
          },
        );
  }

  Future<void> _resyncAfterReconnect() async {
    try {
      await _loadConversations();
      for (final id in _messages.keys.toList()) {
        await _loadMessages(id);
      }
    } catch (_) {}
  }

  void _onRealtime(Map<String, dynamic> event) {
    // Serialize realtime handling so message.created hydrates cannot race
    // each other ahead of the Signal mutex / plaintext cache.
    _realtimeChain = _realtimeChain
        .then((_) => _handleRealtime(event))
        .catchError((_) {});
  }

  Future<void> _realtimeChain = Future<void>.value();

  Future<void> _handleRealtime(Map<String, dynamic> event) async {
    final type = event['type'] as String?;
    if (type == 'realtime.connected') {
      unawaited(_resyncAfterReconnect());
      return;
    }
    if (type == 'realtime.disconnected') {
      try {
        await authRemote.refreshSession();
      } catch (_) {}
      return;
    }
    final payload = stringKeyMap(event['payload']);
    if (payload == null) {
      if (kDebugMode && type == 'call.signal') {
        debugPrint('seyra.call.signal.receive dropped=payload_type');
      }
      return;
    }
    if (type == 'message.created') {
      final message = await _hydrateMessage(ChatMessageModel.fromJson(payload));
      _upsertMessage(message);
      if (message.senderId != _currentUserId &&
          message.conversationId == _activeConversationId) {
        unawaited(markConversationRead(message.conversationId));
      }
    } else if (type == 'receipt.updated') {
      final conversationId = payload['conversation_id'] as String? ?? '';
      final userId = payload['user_id'] as String? ?? '';
      final rawAt = payload['last_read_at'] as String?;
      if (conversationId.isEmpty ||
          userId.isEmpty ||
          userId == _currentUserId ||
          rawAt == null) {
        return;
      }
      final at = DateTime.tryParse(rawAt);
      if (at != null) {
        _applyPeerRead(conversationId, at.toUtc());
      }
    } else if (type == 'message.updated') {
      unawaited(_loadMessages(payload['conversation_id'] as String? ?? ''));
    } else if (type == 'message.deleted') {
      final id = payload['id'] as String?;
      final conversationId = payload['conversation_id'] as String?;
      if (id == null || conversationId == null) {
        return;
      }
      _messages[conversationId]?.removeWhere((item) => item.id == id);
      _emitMessages(conversationId);
    } else if (type == 'call.signal') {
      if (kDebugMode) {
        final action = signalId(payload['action']);
        final from = signalId(payload['from_id']);
        final caller = signalId(payload['caller_id']);
        debugPrint(
          [
            'seyra.call.signal.receive',
            'type=$action',
            'from=${from.isEmpty ? caller : from}',
            'current=$_currentUserId',
            'call_id=${signalId(payload['call_id'])}',
            'parsed=yes',
            'caller=${caller.isNotEmpty && caller == _currentUserId}',
          ].join(' '),
        );
      }
      _callSignalBuffer.add(payload);
      _callSignals.add(payload);
    } else if (type == 'typing') {
      final conversationId = payload['conversation_id'] as String? ?? '';
      final userId = payload['user_id'] as String? ?? '';
      if (conversationId.isEmpty || userId == _currentUserId) {
        return;
      }
      _typingControllers
          .putIfAbsent(conversationId, StreamController<bool>.broadcast)
          .add(payload['typing'] == true);
    } else if (type == 'message.pinned' ||
        type == 'message.unpinned' ||
        type == 'member.joined' ||
        type == 'member.left' ||
        type == 'member.updated') {
      unawaited(refreshConversations());
    }
  }

  void _upsertMessage(ChatMessage message, {bool countUnread = true}) {
    final items = _messages.putIfAbsent(message.conversationId, () => []);
    var droppedPending = false;
    var incoming = message;
    if (!isLocalPendingId(incoming.id)) {
      final pendingIndex = indexOfReplacedPending(items, incoming);
      if (pendingIndex >= 0) {
        final pending = items[pendingIndex];
        if (isE2eDecryptPlaceholder(incoming) &&
            !isE2ePlaceholderBody(pending.body)) {
          incoming = ChatMessage(
            id: incoming.id,
            conversationId: incoming.conversationId,
            senderId: incoming.senderId,
            body: pending.body,
            sentAt: incoming.sentAt,
            delivery: incoming.delivery,
            replyToId: incoming.replyToId,
            replyPreview: incoming.replyPreview,
            reactions: incoming.reactions,
            attachmentId: incoming.attachmentId ?? pending.attachmentId,
            contentType: incoming.contentType,
            fileKey: incoming.fileKey,
            fileNonce: incoming.fileNonce,
            e2e: incoming.e2e,
            edited: incoming.edited,
            forwardedFromId: incoming.forwardedFromId,
          );
          unawaited(
            _rememberPlaintext(
              incoming.id,
              pending.body,
              ciphertext: _e2eCiphertext[incoming.id],
            ),
          );
        }
        items.removeAt(pendingIndex);
        droppedPending = true;
      }
    } else {
      final alreadyAcked = items.any(
        (item) => !isLocalPendingId(item.id) && isOutgoingAck(incoming, item),
      );
      if (alreadyAcked) {
        return;
      }
    }
    final existingIndex = items.indexWhere((item) => item.id == incoming.id);
    if (existingIndex >= 0) {
      final existing = items[existingIndex];
      if (isE2eDecryptPlaceholder(existing) &&
          !isE2eDecryptPlaceholder(incoming)) {
        items[existingIndex] = incoming;
        _emitMessages(incoming.conversationId);
        return;
      }
      // Never overwrite a successful decrypt with a later failure.
      if (!isE2eDecryptPlaceholder(existing) &&
          isE2eDecryptPlaceholder(incoming)) {
        if (droppedPending) {
          _emitMessages(incoming.conversationId);
        }
        return;
      }
      if (droppedPending) {
        _emitMessages(incoming.conversationId);
        return;
      }
      return;
    }
    items.add(incoming);
    items.sort((a, b) => a.sentAt.compareTo(b.sentAt));
    _emitMessages(incoming.conversationId);
    final conversation = getConversation(incoming.conversationId);
    if (conversation != null) {
      final fromPeer = incoming.senderId != _currentUserId;
      final incrementUnread = countUnread &&
          fromPeer &&
          incoming.conversationId != _activeConversationId;
      final unread = incrementUnread
          ? conversation.unreadCount + 1
          : incoming.conversationId == _activeConversationId
          ? 0
          : conversation.unreadCount;
      _upsertConversation(
        conversation.copyWith(
          lastMessagePreview: cloudHistoryPreview(incoming).isEmpty
              ? conversation.lastMessagePreview
              : incoming.body,
          lastMessageAt: incoming.sentAt,
          unreadCount: unread,
        ),
      );
    }
    if (countUnread &&
        incoming.senderId != _currentUserId &&
        incoming.conversationId != _activeConversationId) {
      final title = conversation?.title ?? 'Seyra';
      _alertsController.add(
        IncomingAlert(
          conversationId: incoming.conversationId,
          title: title,
          body: incoming.body,
          messageId: incoming.id,
        ),
      );
    }
  }

  ChatMessage? _ackedOutgoing(String conversationId, ChatMessage pending) {
    final items = _messages[conversationId];
    if (items == null) {
      return null;
    }
    for (final item in items) {
      if (isOutgoingAck(pending, item)) {
        return item;
      }
    }
    return null;
  }

  void _replaceMessage(
    String conversationId,
    String messageId,
    ChatMessage next,
  ) {
    final items = _messages[conversationId];
    if (items == null) {
      return;
    }
    final index = items.indexWhere((item) => item.id == messageId);
    if (index < 0) {
      if (isLocalPendingId(next.id) && _ackedOutgoing(conversationId, next) != null) {
        return;
      }
      items.add(next);
    } else {
      items[index] = next;
    }
    _emitMessages(conversationId);
  }

  void _removeMessage(String conversationId, String messageId) {
    final items = _messages[conversationId];
    if (items == null) {
      return;
    }
    final before = items.length;
    items.removeWhere((item) => item.id == messageId);
    if (items.length != before) {
      _emitMessages(conversationId);
    }
  }

  void _upsertConversation(Conversation conversation) {
    final exists = _conversations.any((item) => item.id == conversation.id);
    if (exists) {
      _conversations = [
        for (final item in _conversations)
          if (item.id == conversation.id) conversation else item,
      ];
    } else {
      _conversations = [..._conversations, conversation];
    }
    _conversations.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
    _conversationsController.add(List<Conversation>.from(_conversations));
  }

  StreamController<List<ChatMessage>> _controllerFor(String id) {
    return _messageControllers.putIfAbsent(
      id,
      StreamController<List<ChatMessage>>.broadcast,
    );
  }

  void _emitMessages(String conversationId) {
    _controllerFor(conversationId).add(
      List<ChatMessage>.from(_messages[conversationId] ?? const []),
    );
  }

  Future<ApiResponse> _authorized({
    required String method,
    required String path,
    Object? jsonBody,
  }) async {
    var access = await secureStorage.read(AuthSecureStorageKeys.accessToken);
    if (access == null || access.isEmpty) {
      throw const ChatRemoteException(ChatRemoteErrorCode.unauthorized);
    }
    try {
      return await _send(
        method: method,
        path: path,
        headers: {'Authorization': 'Bearer $access'},
        jsonBody: jsonBody,
      );
    } on ChatRemoteException catch (error) {
      if (error.code != ChatRemoteErrorCode.sessionExpired) {
        rethrow;
      }
      try {
        await authRemote.refreshSession();
      } catch (_) {
        throw const ChatRemoteException(ChatRemoteErrorCode.sessionExpired);
      }
      access = await secureStorage.read(AuthSecureStorageKeys.accessToken);
      return _send(
        method: method,
        path: path,
        headers: {'Authorization': 'Bearer $access'},
        jsonBody: jsonBody,
      );
    }
  }

  Future<ApiResponse> _send({
    required String method,
    required String path,
    Map<String, String>? headers,
    Object? jsonBody,
  }) async {
    try {
      final response = await apiClient.send(
        method: method,
        uri: baseUrl.resolve(path),
        headers: headers,
        jsonBody: jsonBody,
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response;
      }
      throw ChatRemoteException(
        _codeFor(response),
        statusCode: response.statusCode,
      );
    } on ChatRemoteException {
      rethrow;
    } catch (_) {
      throw const ChatRemoteException(ChatRemoteErrorCode.network);
    }
  }

  ChatRemoteErrorCode _codeFor(ApiResponse response) {
    final code = _errorCode(response.body);
    return switch (code) {
      'not_found' => ChatRemoteErrorCode.notFound,
      'forbidden' => ChatRemoteErrorCode.forbidden,
      'cannot_message_self' => ChatRemoteErrorCode.cannotMessageSelf,
      'session_expired' => ChatRemoteErrorCode.sessionExpired,
      'unauthorized' => ChatRemoteErrorCode.unauthorized,
      'invalid_input' => ChatRemoteErrorCode.invalidInput,
      'already_member' => ChatRemoteErrorCode.alreadyMember,
      'owner_protected' => ChatRemoteErrorCode.ownerProtected,
      _ => switch (response.statusCode) {
        404 => ChatRemoteErrorCode.notFound,
        403 => ChatRemoteErrorCode.forbidden,
        401 => ChatRemoteErrorCode.unauthorized,
        400 => ChatRemoteErrorCode.invalidInput,
        _ => ChatRemoteErrorCode.network,
      },
    };
  }

  String? _errorCode(String body) {
    if (body.trim().isEmpty) {
      return null;
    }
    try {
      final json = jsonDecode(body);
      if (json is Map<String, dynamic>) {
        final error = json['error'];
        if (error is Map<String, dynamic>) {
          return error['code'] as String?;
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Map<String, dynamic> _decodeObject(String body) {
    final json = jsonDecode(body);
    if (json is Map<String, dynamic>) {
      return json;
    }
    throw const ChatRemoteException(ChatRemoteErrorCode.network);
  }

  ChatRemoteErrorCode _fromAuth(AuthRemoteErrorCode code) {
    return switch (code) {
      AuthRemoteErrorCode.sessionExpired => ChatRemoteErrorCode.sessionExpired,
      AuthRemoteErrorCode.unauthorized => ChatRemoteErrorCode.unauthorized,
      AuthRemoteErrorCode.network => ChatRemoteErrorCode.network,
      _ => ChatRemoteErrorCode.network,
    };
  }

  Uri _wsUri(Uri httpUri) {
    final scheme = httpUri.scheme == 'https' ? 'wss' : 'ws';
    return httpUri.replace(scheme: scheme);
  }

  Future<ApiResponse> authorized({
    required String method,
    required String path,
    Object? jsonBody,
  }) {
    return _authorized(method: method, path: path, jsonBody: jsonBody);
  }

  Stream<Map<String, dynamic>> watchCallSignals() => _callSignals.stream;

  List<Map<String, dynamic>> bufferedCallSignals(String callId) {
    return _callSignalBuffer.peek(callId);
  }

  void clearCallSignals(String callId) {
    _callSignalBuffer.clear(callId);
  }

  Future<void> sendRealtime(Map<String, dynamic> event) {
    return realtime.send(event);
  }

  Future<ChatMessage> hydrateMessage(ChatMessageModel model) =>
      _hydrateMessage(model);

  Future<ChatMessage> _hydrateMessage(
    ChatMessageModel model, {
    String? outgoingPlaintext,
  }) async {
    if (!model.e2e || model.body.isEmpty) {
      return model.toEntity(decryptedBody: outgoingPlaintext);
    }
    if (!isE2ePlaceholderBody(model.body)) {
      _e2eCiphertext[model.id] = model.body;
    }
    if (outgoingPlaintext != null && outgoingPlaintext.isNotEmpty) {
      await _rememberPlaintext(
        model.id,
        outgoingPlaintext,
        ciphertext: model.body,
      );
      return _entityFromPlain(model, outgoingPlaintext);
    }
    final remembered = _plaintextFor(model);
    if (remembered != null) {
      await _rememberPlaintext(model.id, remembered, ciphertext: model.body);
      return _entityFromPlain(model, remembered);
    }
    final cached = _cachedPlaintext(model);
    if (cached != null) {
      await _rememberPlaintext(model.id, cached.body, ciphertext: model.body);
      return cached;
    }
    if (model.senderId == _currentUserId) {
      return model.toEntity(
        decryptedBody: e2eDecryptPlaceholder,
        decryptErrorCode: 'e2e.missing_outbox',
      );
    }
    final ciphertext = _e2eCiphertext[model.id] ?? model.body;
    if (isE2ePlaceholderBody(ciphertext)) {
      return model.toEntity(
        decryptedBody: e2eDecryptPlaceholder,
        decryptErrorCode: 'e2e.missing_ciphertext',
      );
    }
    try {
      await _ensureE2e();
      final peerId = model.senderId;
      if (peerId.isEmpty) {
        return model.toEntity(
          decryptedBody: e2eDecryptPlaceholder,
          decryptErrorCode: 'e2e.missing_sender',
        );
      }
      final plain = await _e2e!.decrypt(
        peerUserId: peerId,
        ciphertext: ciphertext,
      );
      await _rememberPlaintext(model.id, plain, ciphertext: ciphertext);
      return _entityFromPlain(model, plain);
    } on E2eDecryptException catch (error) {
      _logDecryptFailure(error.code);
      if (error.code == 'e2e.duplicate') {
        final cached = _cachedPlaintext(model);
        if (cached != null) {
          return cached;
        }
        final remembered = _plaintextFor(model);
        if (remembered != null) {
          return _entityFromPlain(model, remembered);
        }
      }
      // Keep original ciphertext in _e2eCiphertext for a later restore.
      return _cachedPlaintext(model) ??
          model.toEntity(
            decryptedBody: e2eDecryptPlaceholder,
            decryptErrorCode: error.code,
          );
    } catch (error) {
      final code =
          E2eDecryptException.fromError(error, hasSession: true).code;
      _logDecryptFailure(code);
      return _cachedPlaintext(model) ??
          model.toEntity(
            decryptedBody: e2eDecryptPlaceholder,
            decryptErrorCode: code,
          );
    }
  }

  String? _plaintextFor(ChatMessageModel model) {
    final byId = _e2ePlaintext[model.id];
    if (byId != null && byId.isNotEmpty) {
      return byId;
    }
    if (!isE2ePlaceholderBody(model.body)) {
      final byCipher = _e2ePlaintextByCipher[model.body];
      if (byCipher != null && byCipher.isNotEmpty) {
        return byCipher;
      }
    }
    return null;
  }

  void _logDecryptFailure(String code) {
    if (kDebugMode) {
      debugPrint('seyra.e2e.decrypt_failed code=$code');
    }
  }

  Future<void> _rememberPlaintext(
    String messageId,
    String plaintext, {
    String? ciphertext,
  }) async {
    if (plaintext.isEmpty || isE2ePlaceholderBody(plaintext)) {
      return;
    }
    if (messageId.isNotEmpty) {
      _e2ePlaintext[messageId] = plaintext;
    }
    if (ciphertext != null &&
        ciphertext.isNotEmpty &&
        !isE2ePlaceholderBody(ciphertext)) {
      _e2ePlaintextByCipher[ciphertext] = plaintext;
      if (messageId.isNotEmpty) {
        _e2eCiphertext[messageId] = ciphertext;
      }
    }
    await _persistE2eOutbox();
  }

  String get _outboxKey =>
      _currentUserId.isEmpty
          ? 'seyra.e2e.outbox'
          : 'seyra.e2e.outbox.$_currentUserId';

  Future<void> _loadE2eOutbox() async {
    var raw = await secureStorage.read(_outboxKey);
    if ((raw == null || raw.isEmpty) && _currentUserId.isNotEmpty) {
      // Legacy unscoped key from older builds.
      raw = await secureStorage.read('seyra.e2e.outbox');
      if (raw != null && raw.isNotEmpty) {
        await secureStorage.write(key: _outboxKey, value: raw);
      }
    }
    if (raw == null || raw.isEmpty) {
      return;
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final ids = map['ids'] as Map<String, dynamic>? ?? {};
      for (final entry in ids.entries) {
        final value = entry.value as String?;
        if (value != null && value.isNotEmpty) {
          _e2ePlaintext[entry.key] = value;
        }
      }
      final ciphers = map['ciphers'] as Map<String, dynamic>? ?? {};
      for (final entry in ciphers.entries) {
        final value = entry.value as String?;
        if (value != null && value.isNotEmpty) {
          _e2ePlaintextByCipher[entry.key] = value;
        }
      }
    } catch (_) {}
  }

  Future<void> _persistE2eOutbox() async {
    final ids = Map<String, String>.from(_e2ePlaintext);
    final ciphers = Map<String, String>.from(_e2ePlaintextByCipher);
    while (ids.length > 2000) {
      ids.remove(ids.keys.first);
    }
    while (ciphers.length > 2000) {
      ciphers.remove(ciphers.keys.first);
    }
    await secureStorage.write(
      key: _outboxKey,
      value: jsonEncode({'ids': ids, 'ciphers': ciphers}),
    );
    final notify = onOutboxUpdated;
    final userId = _currentUserId;
    if (notify != null && userId.isNotEmpty) {
      unawaited(notify(userId));
    }
  }

  Future<void> _adoptSessionFromPeerMessages(String conversationId) async {
    final items = _messages[conversationId];
    if (items == null || items.isEmpty) {
      return;
    }
    for (final item in items) {
      if (!item.e2e || item.senderId == _currentUserId) {
        continue;
      }
      final cipher = _e2eCiphertext[item.id];
      if (cipher == null || isE2ePlaceholderBody(cipher)) {
        continue;
      }
      if (_e2ePlaintext.containsKey(item.id) ||
          _e2ePlaintextByCipher.containsKey(cipher)) {
        continue;
      }
      try {
        await _ensureE2e();
        final plain = await _e2e!.decrypt(
          peerUserId: item.senderId,
          ciphertext: cipher,
        );
        await _rememberPlaintext(item.id, plain, ciphertext: cipher);
        _replaceMessage(
          conversationId,
          item.id,
          ChatMessage(
            id: item.id,
            conversationId: item.conversationId,
            senderId: item.senderId,
            body: plain,
            sentAt: item.sentAt,
            delivery: item.delivery,
            replyToId: item.replyToId,
            replyPreview: item.replyPreview,
            reactions: item.reactions,
            attachmentId: item.attachmentId,
            contentType: item.contentType,
            fileKey: item.fileKey,
            fileNonce: item.fileNonce,
            e2e: item.e2e,
            edited: item.edited,
            forwardedFromId: item.forwardedFromId,
          ),
        );
      } catch (_) {}
    }
  }

  ChatMessage? _cachedPlaintext(ChatMessageModel model) {
    final items = _messages[model.conversationId];
    if (items == null) {
      return null;
    }
    for (final item in items) {
      if (item.id == model.id &&
          item.e2e &&
          !isE2eDecryptPlaceholder(item)) {
        return item;
      }
    }
    return null;
  }

  ChatMessage _entityFromPlain(ChatMessageModel model, String plain) {
    try {
      final decoded = jsonDecode(plain);
      if (decoded is Map<String, dynamic> && decoded['v'] == 1) {
        final kind = decoded['kind'] as String?;
        if (kind == 'file') {
          List<int>? key;
          List<int>? nonce;
          try {
            final encodedKey = decoded['k'] as String?;
            final encodedNonce = decoded['n'] as String?;
            if (encodedKey != null && encodedNonce != null) {
              key = base64Decode(encodedKey);
              nonce = base64Decode(encodedNonce);
            }
          } catch (_) {}
          return model.toEntity(
            decryptedBody: decoded['name'] as String? ?? 'Encrypted file',
          ).copyWith(
            attachmentId: decoded['att'] as String? ?? model.attachmentId,
            contentType: decoded['mime'] as String?,
            fileKey: key,
            fileNonce: nonce,
            e2e: true,
          );
        }
        if (kind == 'sticker') {
          return model.toEntity(
            decryptedBody: decoded['emoji'] as String? ?? plain,
          );
        }
      }
    } catch (_) {}
    return model.toEntity(decryptedBody: plain);
  }

  bool _containsAttachmentKeys(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> &&
          decoded['kind'] == 'file' &&
          decoded['k'] is String &&
          decoded['n'] is String;
    } catch (_) {
      return false;
    }
  }

  Future<void> _ensureE2e() async {
    _e2e ??= SignalE2eService(secureStorage, userId: _currentUserId);
    await _e2e!.install();
  }

  Future<void> publishLocalKeys() async {
    await _ensureE2e();
    final bundle = await _e2e!.exportPublicBundle();
    await _authorized(method: 'POST', path: '/v1/e2e/keys', jsonBody: bundle);
    _keysPublished = true;
    try {
      await onKeysPublished?.call(_currentUserId);
    } catch (_) {}
  }

  /// Invoked after Signal public keys are published (e.g. auto cloud backup).
  Future<void> Function(String userId)? onKeysPublished;

  /// Invoked after the local plaintext outbox is persisted (own E2E messages).
  /// Used to upload an encrypted key+outbox backup so reinstall can show
  /// previously sent messages.
  Future<void> Function(String userId)? onOutboxUpdated;

  /// Reinstall Signal state from secure storage after a backup restore.
  Future<void> restoreAfterBackup(String userId) async {
    await _realtimeSub?.cancel();
    _realtimeSub = null;
    try {
      await realtime.disconnect();
    } catch (_) {}
    _e2e = null;
    _keysPublished = false;
    _currentUserId = userId;
    // Mark started so the next `_ensureStarted` does not `_bindAccount` and
    // wipe the just-restored in-memory outbox before history loads.
    _started = true;
    _e2ePlaintext.clear();
    _e2eCiphertext.clear();
    _e2ePlaintextByCipher.clear();
    await _loadE2eOutbox();
    try {
      await publishLocalKeys();
    } catch (_) {}
    await _loadConversations();
    await _connectRealtime();
    final openIds = _messages.keys.toList();
    for (final id in openIds) {
      try {
        await _loadMessages(id);
      } catch (_) {}
    }
  }

  /// Simulate a fresh install: wipe in-memory chat cache, keep auth/keys as-is.
  Future<void> rebuildCloudHistoryFromServer() async {
    await _ensureStarted();
    _messages.clear();
    _messageCursors.clear();
    _conversations = [];
    _conversationsController.add(const []);
    await _loadConversations();
  }

  Future<void> establishSession(String peerUserId) async {
    await _ensureE2e();
    if (!_keysPublished) {
      try {
        await publishLocalKeys();
      } catch (_) {}
    }
    // Reuse an existing Signal session. Fetching /v1/e2e/bundle always
    // consumes a one-time prekey on the server, which must only happen when
    // establishing a new session.
    if (await _e2e!.hasSession(peerUserId)) {
      return;
    }
    final response = await _authorized(
      method: 'GET',
      path: '/v1/e2e/bundle/$peerUserId',
    );
    final bundle = _decodeObject(response.body);
    await _e2e!.processRemoteBundle(
      userId: peerUserId,
      bundle: bundle,
    );
  }
}
