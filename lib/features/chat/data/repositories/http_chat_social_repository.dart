import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:seyra/core/errors/failures.dart';
import 'package:seyra/core/errors/network_failure.dart';
import 'package:seyra/core/errors/result.dart';
import 'package:seyra/features/auth/data/storage/auth_secure_storage_keys.dart';
import 'package:seyra/features/auth/domain/failures/auth_failures.dart';
import 'package:seyra/features/chat/data/datasources/http_chat_data_source.dart';
import 'package:seyra/features/chat/data/exceptions/chat_remote_exceptions.dart';
import 'package:seyra/features/chat/data/models/call_signaling.dart';
import 'package:seyra/features/chat/data/models/chat_message_model.dart';
import 'package:seyra/features/chat/data/models/conversation_summary_model.dart';
import 'package:seyra/features/chat/domain/entities/chat_message.dart';
import 'package:seyra/features/chat/domain/entities/conversation.dart';
import 'package:seyra/features/chat/domain/entities/social_models.dart';
import 'package:seyra/features/chat/domain/entities/user_preview.dart';
import 'package:seyra/features/chat/domain/failures/chat_failures.dart';
import 'package:seyra/features/chat/domain/repositories/chat_social_repository.dart';

final class HttpChatSocialRepository implements ChatSocialRepository {
  HttpChatSocialRepository(this._chat);

  final HttpChatDataSource _chat;

  @override
  Future<Result<GlobalSearchResult>> searchGlobal(String query) {
    return _map(() async {
      final response = await _chat.authorized(
        method: 'GET',
        path: '/v1/search?q=${Uri.encodeQueryComponent(query)}',
      );
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final users = <UserPreview>[];
      for (final item in json['users'] as List? ?? const []) {
        if (item is Map<String, dynamic>) {
          users.add(
            UserPreview(id: item['id'] as String, username: item['username'] as String),
          );
        }
      }
      final conversations = <Conversation>[];
      for (final item in json['conversations'] as List? ?? const []) {
        if (item is Map<String, dynamic>) {
          conversations.add(ConversationSummaryModel.fromJson(item).toEntity());
        }
      }
      final messages = <ChatMessage>[];
      for (final item in json['messages'] as List? ?? const []) {
        if (item is Map<String, dynamic>) {
          messages.add(ChatMessageModel.fromJson(item).toEntity());
        }
      }
      return GlobalSearchResult(
        users: users,
        conversations: conversations,
        messages: messages,
      );
    });
  }

  @override
  Future<Result<List<Conversation>>> discoverChannels(String query) {
    return _map(() async {
      final response = await _chat.authorized(
        method: 'GET',
        path: '/v1/channels/discover?q=${Uri.encodeQueryComponent(query)}',
      );
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final out = <Conversation>[];
      for (final item in json['channels'] as List? ?? const []) {
        if (item is Map<String, dynamic>) {
          out.add(ConversationSummaryModel.fromJson(item).toEntity());
        }
      }
      return out;
    });
  }

  @override
  Future<Result<Conversation>> joinChannel(String conversationId) {
    return _map(() async {
      final response = await _chat.authorized(
        method: 'POST',
        path: '/v1/chats/$conversationId/join',
      );
      final conversation = ConversationSummaryModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      ).toEntity();
      await _chat.refreshConversations();
      return conversation;
    });
  }

  @override
  Future<Result<String>> uploadAttachment({
    required String conversationId,
    required List<int> bytes,
    required String filename,
    required String contentType,
    bool e2e = false,
    void Function(int sent, int total)? onProgress,
    UploadCancelToken? cancelToken,
  }) {
    return _map(() async {
      final access = await _chat.secureStorage.read(AuthSecureStorageKeys.accessToken);
      final uri = _chat.baseUrl.resolve('/v1/chats/$conversationId/attachments');
      final client = http.Client();
      cancelToken?.bind(client.close);
      try {
        final request = http.MultipartRequest('POST', uri);
        request.headers['Authorization'] = 'Bearer $access';
        if (e2e) {
          request.fields['e2e'] = 'true';
        }
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: filename,
          ),
        );
        onProgress?.call(0, bytes.length);
        final streamed = await client.send(request);
        onProgress?.call(bytes.length, bytes.length);
        final body = await streamed.stream.bytesToString();
        if (cancelToken?.cancelled == true) {
          throw const ChatRemoteException(ChatRemoteErrorCode.network);
        }
        if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
          throw const ChatRemoteException(ChatRemoteErrorCode.invalidInput);
        }
        final json = jsonDecode(body) as Map<String, dynamic>;
        return json['id'] as String;
      } finally {
        client.close();
      }
    });
  }

  @override
  Future<Result<List<RoomAttachment>>> listAttachments(String conversationId) {
    return _map(() async {
      final response = await _chat.authorized(
        method: 'GET',
        path: '/v1/chats/$conversationId/attachments',
      );
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final out = <RoomAttachment>[];
      for (final item in json['attachments'] as List? ?? const []) {
        if (item is Map<String, dynamic>) {
          out.add(
            RoomAttachment(
              id: item['id'] as String,
              filename: item['filename'] as String? ?? 'file',
              contentType: item['content_type'] as String? ?? '',
              byteSize: item['byte_size'] as int? ?? 0,
              e2e: item['e2e'] == true,
              createdAt: DateTime.tryParse(item['created_at'] as String? ?? '') ??
                  DateTime.now().toUtc(),
            ),
          );
        }
      }
      return out;
    });
  }

  @override
  Future<Result<List<StickerItem>>> listStickers() {
    return _map(() async {
      final response = await _chat.authorized(method: 'GET', path: '/v1/stickers');
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final out = <StickerItem>[];
      for (final pack in json['packs'] as List? ?? const []) {
        if (pack is! Map<String, dynamic>) {
          continue;
        }
        for (final item in pack['stickers'] as List? ?? const []) {
          if (item is Map<String, dynamic>) {
            out.add(
              StickerItem(
                pack: item['pack'] as String? ?? 'seyra',
                id: item['id'] as String,
                emoji: item['emoji'] as String? ?? '',
                name: item['name'] as String? ?? '',
              ),
            );
          }
        }
      }
      return out;
    });
  }

  @override
  Future<Result<DateTime?>> peerLastSeen(String userId) {
    return _map(() async {
      final response = await _chat.authorized(
        method: 'GET',
        path: '/v1/users/$userId/last-seen',
      );
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['visible'] != true) {
        return null;
      }
      return DateTime.tryParse(json['last_seen_at'] as String? ?? '');
    });
  }

  @override
  Future<Result<DateTime?>> readReceipt(String conversationId) {
    return _map(() async {
      final response = await _chat.authorized(
        method: 'GET',
        path: '/v1/chats/$conversationId/receipts',
      );
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['visible'] != true) {
        return null;
      }
      return DateTime.tryParse(json['last_read_at'] as String? ?? '');
    });
  }

  @override
  Future<Result<List<int>>> downloadAttachment(String attachmentId) {
    return _map(() async {
      final access = await _chat.secureStorage.read(AuthSecureStorageKeys.accessToken);
      final uri = _chat.baseUrl.resolve('/v1/attachments/$attachmentId');
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $access'},
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const ChatRemoteException(ChatRemoteErrorCode.notFound);
      }
      return response.bodyBytes;
    });
  }

  @override
  Future<Result<void>> editMessage({
    required String conversationId,
    required String messageId,
    required String body,
  }) {
    return _mapVoid(
      () => _chat.authorized(
        method: 'PATCH',
        path: '/v1/chats/$conversationId/messages/$messageId',
        jsonBody: {'body': body},
      ),
    );
  }

  @override
  Future<Result<void>> pinMessage({
    required String conversationId,
    required String messageId,
  }) {
    return _mapVoid(
      () => _chat.authorized(
        method: 'POST',
        path: '/v1/chats/$conversationId/messages/$messageId/pin',
      ),
    );
  }

  @override
  Future<Result<void>> unpinMessage({
    required String conversationId,
    required String messageId,
  }) {
    return _mapVoid(
      () => _chat.authorized(
        method: 'DELETE',
        path: '/v1/chats/$conversationId/messages/$messageId/pin',
      ),
    );
  }

  @override
  Future<Result<List<ChatMessage>>> listPins(String conversationId) {
    return _map(() async {
      final response = await _chat.authorized(
        method: 'GET',
        path: '/v1/chats/$conversationId/pins',
      );
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final out = <ChatMessage>[];
      for (final item in json['messages'] as List? ?? const []) {
        if (item is Map<String, dynamic>) {
          out.add(await _chat.hydrateMessage(ChatMessageModel.fromJson(item)));
        }
      }
      return out;
    });
  }

  @override
  Future<Result<void>> setArchived({
    required String conversationId,
    required bool archived,
  }) {
    return _mapVoid(
      () => _chat.authorized(
        method: 'PUT',
        path: '/v1/chats/$conversationId/archive',
        jsonBody: {'value': archived},
      ),
    );
  }

  @override
  Future<Result<void>> persistMute({
    required String conversationId,
    required bool muted,
  }) {
    return _mapVoid(
      () => _chat.setMuted(conversationId: conversationId, muted: muted),
    );
  }

  @override
  Future<Result<void>> saveDraft({
    required String conversationId,
    required String body,
  }) {
    return _mapVoid(
      () => _chat.authorized(
        method: 'PUT',
        path: '/v1/chats/$conversationId/draft',
        jsonBody: {'body': body},
      ),
    );
  }

  @override
  Future<Result<String>> getDraft(String conversationId) {
    return _map(() async {
      final response = await _chat.authorized(
        method: 'GET',
        path: '/v1/chats/$conversationId/draft',
      );
      return (jsonDecode(response.body) as Map<String, dynamic>)['body'] as String? ??
          '';
    });
  }

  @override
  Future<Result<String>> createInvite(String conversationId) {
    return _map(() async {
      final response = await _chat.authorized(
        method: 'POST',
        path: '/v1/chats/$conversationId/invites',
        jsonBody: const {},
      );
      return (jsonDecode(response.body) as Map<String, dynamic>)['token'] as String;
    });
  }

  @override
  Future<Result<Conversation>> joinInvite(String token) {
    return _map(() async {
      final response = await _chat.authorized(
        method: 'POST',
        path: '/v1/invites/join',
        jsonBody: {'token': token},
      );
      await _chat.refreshConversations();
      return ConversationSummaryModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      ).toEntity();
    });
  }

  @override
  Future<Result<void>> updateRoom({
    required String conversationId,
    String title = '',
    String description = '',
    String visibility = '',
  }) {
    return _mapVoid(
      () => _chat.authorized(
        method: 'PATCH',
        path: '/v1/chats/$conversationId',
        jsonBody: {
          'title': title,
          'description': description,
          'visibility': visibility,
        },
      ),
    );
  }

  @override
  Future<Result<void>> transferOwnership({
    required String conversationId,
    required String userId,
  }) {
    return _mapVoid(
      () => _chat.authorized(
        method: 'POST',
        path: '/v1/chats/$conversationId/transfer',
        jsonBody: {'user_id': userId},
      ),
    );
  }

  @override
  Future<Result<void>> restrictMember({
    required String conversationId,
    required String userId,
    required bool canSend,
  }) {
    return _mapVoid(
      () => _chat.authorized(
        method: 'POST',
        path: '/v1/chats/$conversationId/members/$userId/restrict',
        jsonBody: {'can_send': canSend},
      ),
    );
  }

  @override
  Future<Result<ChatMessage>> forwardMessage({
    required String sourceId,
    required String messageId,
    required String destinationId,
  }) {
    return _map(() async {
      final response = await _chat.authorized(
        method: 'POST',
        path: '/v1/chats/$sourceId/messages/$messageId/forward',
        jsonBody: {'destination_id': destinationId},
      );
      return ChatMessageModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      ).toEntity();
    });
  }

  @override
  Future<Result<PrivacySettings>> getPrivacy() {
    return _map(() async {
      final response = await _chat.authorized(method: 'GET', path: '/v1/privacy');
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return PrivacySettings(
        lastSeenVisible: json['last_seen_visible'] as bool? ?? true,
        readReceipts: json['read_receipts'] as bool? ?? true,
        typingVisible: json['typing_visible'] as bool? ?? true,
        profileVisible: json['profile_visible'] as bool? ?? true,
        notificationPreview: json['notification_preview'] as bool? ?? true,
        photoVisible: json['photo_visible'] as bool? ?? true,
      );
    });
  }

  @override
  Future<Result<void>> putPrivacy(PrivacySettings settings) {
    return _mapVoid(
      () => _chat.authorized(
        method: 'PUT',
        path: '/v1/privacy',
        jsonBody: {
          'last_seen_visible': settings.lastSeenVisible,
          'read_receipts': settings.readReceipts,
          'typing_visible': settings.typingVisible,
          'profile_visible': settings.profileVisible,
          'notification_preview': settings.notificationPreview,
          'photo_visible': settings.photoVisible,
        },
      ),
    );
  }

  @override
  Future<Result<List<UserPreview>>> listBlocked() {
    return _map(() async {
      final response = await _chat.authorized(method: 'GET', path: '/v1/blocks');
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final out = <UserPreview>[];
      for (final item in json['users'] as List? ?? const []) {
        if (item is Map<String, dynamic>) {
          out.add(
            UserPreview(id: item['id'] as String, username: item['username'] as String? ?? ''),
          );
        }
      }
      return out;
    });
  }

  @override
  Future<Result<void>> blockUsername(String username) {
    return _mapVoid(
      () => _chat.authorized(
        method: 'POST',
        path: '/v1/blocks',
        jsonBody: {'username': username},
      ),
    );
  }

  @override
  Future<Result<void>> unblockUser(String userId) {
    return _mapVoid(
      () => _chat.authorized(method: 'DELETE', path: '/v1/blocks/$userId'),
    );
  }

  @override
  Future<Result<void>> reportUser({
    required String username,
    required String reason,
  }) {
    return _mapVoid(
      () => _chat.authorized(
        method: 'POST',
        path: '/v1/reports',
        jsonBody: {'username': username, 'reason': reason},
      ),
    );
  }

  @override
  Future<Result<List<AuthDeviceSession>>> listSessions() {
    return _map(() async {
      final response = await _chat.authorized(method: 'GET', path: '/v1/auth/sessions');
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final out = <AuthDeviceSession>[];
      for (final item in json['sessions'] as List? ?? const []) {
        if (item is Map<String, dynamic>) {
          if (item['revoked'] == true) {
            continue;
          }
          out.add(
            AuthDeviceSession(
              id: item['id'] as String,
              expiresAt: DateTime.parse(item['expires_at'] as String),
              createdAt: DateTime.tryParse(item['created_at'] as String? ?? ''),
              revoked: false,
              current: item['current'] == true,
              userAgent: item['user_agent'] as String? ?? '',
            ),
          );
        }
      }
      return out;
    });
  }

  @override
  Future<Result<void>> revokeSession(String sessionId) {
    return _mapVoid(
      () => _chat.authorized(method: 'DELETE', path: '/v1/auth/sessions/$sessionId'),
    );
  }

  @override
  Future<Result<void>> revokeOtherSessions() {
    return _mapVoid(
      () => _chat.authorized(method: 'POST', path: '/v1/auth/sessions/others'),
    );
  }

  @override
  Future<Result<IceServers>> iceServers() {
    return _map(() async {
      final response = await _chat.authorized(method: 'GET', path: '/v1/calls/ice');
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final raw = json['ice_servers'] as List? ?? const [];
      final maps = <Map<String, dynamic>>[
        for (final item in raw)
          if (item is Map<String, dynamic>) item,
      ];
      return IceServers(servers: normalizeIceServers(maps).servers);
    });
  }

  @override
  Future<Result<CallRecord>> startCall({
    required String conversationId,
    required String kind,
    Map<String, dynamic>? payload,
  }) {
    return _map(() async {
      final response = await _chat.authorized(
        method: 'POST',
        path: '/v1/calls',
        jsonBody: {
          'conversation_id': conversationId,
          'kind': kind,
          'payload': payload ?? {},
        },
      );
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return CallRecord(
        id: json['id'] as String,
        conversationId: json['conversation_id'] as String,
        callerId: json['caller_id'] as String,
        kind: json['kind'] as String,
        state: json['state'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
    });
  }

  @override
  Future<Result<void>> signalCall({
    required String callId,
    required String action,
    Map<String, dynamic>? payload,
  }) {
    return _mapVoid(
      () => _chat.authorized(
        method: 'POST',
        path: '/v1/calls/$callId/signal',
        jsonBody: {'action': action, 'payload': payload ?? {}},
      ),
    );
  }

  @override
  Future<Result<List<CallRecord>>> listCalls() {
    return _map(() async {
      final response = await _chat.authorized(method: 'GET', path: '/v1/calls');
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final out = <CallRecord>[];
      for (final item in json['calls'] as List? ?? const []) {
        if (item is Map<String, dynamic>) {
          out.add(
            CallRecord(
              id: item['id'] as String,
              conversationId: item['conversation_id'] as String,
              callerId: item['caller_id'] as String,
              kind: item['kind'] as String,
              state: item['state'] as String,
              createdAt: DateTime.parse(item['created_at'] as String),
              endedAt: item['ended_at'] == null
                  ? null
                  : DateTime.parse(item['ended_at'] as String),
              durationSeconds: item['duration_seconds'] as int?,
              peerName: item['peer_name'] as String? ?? '',
              outgoing: item['outgoing'] == true,
            ),
          );
        }
      }
      return out;
    });
  }

  @override
  Future<Result<void>> deleteCall(String callId) {
    return _mapVoid(
      () => _chat.authorized(method: 'DELETE', path: '/v1/calls/$callId'),
    );
  }

  @override
  Future<Result<void>> clearCallHistory() {
    return _mapVoid(
      () => _chat.authorized(method: 'DELETE', path: '/v1/calls'),
    );
  }

  @override
  Stream<Map<String, dynamic>> watchCallSignals() => _chat.watchCallSignals();

  @override
  List<Map<String, dynamic>> bufferedCallSignals(String callId) {
    return _chat.bufferedCallSignals(callId);
  }

  @override
  void clearCallSignals(String callId) {
    _chat.clearCallSignals(callId);
  }

  @override
  Future<void> sendRealtime(Map<String, dynamic> event) {
    return _chat.sendRealtime(event);
  }

  @override
  Future<Result<BotAccount>> createBot(String username) {
    return _map(() async {
      final response = await _chat.authorized(
        method: 'POST',
        path: '/v1/bots',
        jsonBody: {'username': username},
      );
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return BotAccount(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        username: json['username'] as String,
        token: json['token'] as String?,
      );
    });
  }

  @override
  Future<Result<List<BotAccount>>> listBots() {
    return _map(() async {
      final response = await _chat.authorized(method: 'GET', path: '/v1/bots');
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final out = <BotAccount>[];
      for (final item in json['bots'] as List? ?? const []) {
        if (item is Map<String, dynamic>) {
          out.add(
            BotAccount(
              id: item['id'] as String,
              userId: item['user_id'] as String,
              username: item['username'] as String,
            ),
          );
        }
      }
      return out;
    });
  }

  @override
  Future<Result<void>> deleteBot(String botId) {
    return _mapVoid(
      () => _chat.authorized(method: 'DELETE', path: '/v1/bots/$botId'),
    );
  }

  @override
  Future<Result<void>> grantBot({
    required String botId,
    required String conversationId,
    bool canSend = true,
    bool canRead = true,
    bool canManageMessages = false,
    bool canManageMembers = false,
  }) {
    return _mapVoid(
      () => _chat.authorized(
        method: 'POST',
        path: '/v1/bots/$botId/grants',
        jsonBody: {
          'conversation_id': conversationId,
          'can_send': canSend,
          'can_read': canRead,
          'can_manage_messages': canManageMessages,
          'can_manage_members': canManageMembers,
        },
      ),
    );
  }

  Future<Result<T>> _map<T>(Future<T> Function() action) async {
    try {
      return Success(await action());
    } on ChatRemoteException catch (error) {
      return FailureResult(_mapRemote(error));
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
