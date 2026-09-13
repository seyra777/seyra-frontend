import 'dart:async';

import 'package:seyra/core/errors/failures.dart';
import 'package:seyra/core/errors/result.dart';
import 'package:seyra/features/chat/data/models/call_signaling.dart';
import 'package:seyra/features/chat/domain/entities/chat_message.dart';
import 'package:seyra/features/chat/domain/entities/conversation.dart';
import 'package:seyra/features/chat/domain/entities/social_models.dart';
import 'package:seyra/features/chat/domain/entities/user_preview.dart';
import 'package:seyra/features/chat/domain/repositories/chat_social_repository.dart';

final class MockChatSocialRepository implements ChatSocialRepository {
  final _calls = StreamController<Map<String, dynamic>>.broadcast();
  final _callBuffer = CallSignalBuffer();
  final _drafts = <String, String>{};
  PrivacySettings _privacy = const PrivacySettings();
  final _history = <CallRecord>[];

  @override
  Future<Result<GlobalSearchResult>> searchGlobal(String query) async {
    return const Success(GlobalSearchResult());
  }

  @override
  Future<Result<List<Conversation>>> discoverChannels(String query) async {
    return const Success([]);
  }

  @override
  Future<Result<Conversation>> joinChannel(String conversationId) async {
    return FailureResult(const UnexpectedFailure('Join is HTTP-only in mock mode'));
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
  }) async {
    return Success('att_mock_$filename');
  }

  @override
  Future<Result<List<RoomAttachment>>> listAttachments(String conversationId) async {
    return const Success([]);
  }

  @override
  Future<Result<List<StickerItem>>> listStickers() async {
    return const Success([
      StickerItem(pack: 'seyra', id: 'wave', emoji: '👋', name: 'Wave'),
    ]);
  }

  @override
  Future<Result<DateTime?>> peerLastSeen(String userId) async => const Success(null);

  @override
  Future<Result<DateTime?>> readReceipt(String conversationId) async =>
      const Success(null);

  @override
  Future<Result<List<int>>> downloadAttachment(String attachmentId) async {
    return const Success([]);
  }

  @override
  Future<Result<void>> editMessage({
    required String conversationId,
    required String messageId,
    required String body,
  }) async {
    return const Success(null);
  }

  @override
  Future<Result<void>> pinMessage({
    required String conversationId,
    required String messageId,
  }) async {
    return const Success(null);
  }

  @override
  Future<Result<void>> unpinMessage({
    required String conversationId,
    required String messageId,
  }) async {
    return const Success(null);
  }

  @override
  Future<Result<List<ChatMessage>>> listPins(String conversationId) async {
    return const Success([]);
  }

  @override
  Future<Result<void>> setArchived({
    required String conversationId,
    required bool archived,
  }) async {
    return const Success(null);
  }

  @override
  Future<Result<void>> persistMute({
    required String conversationId,
    required bool muted,
  }) async {
    return const Success(null);
  }

  @override
  Future<Result<void>> saveDraft({
    required String conversationId,
    required String body,
  }) async {
    _drafts[conversationId] = body;
    return const Success(null);
  }

  @override
  Future<Result<String>> getDraft(String conversationId) async {
    return Success(_drafts[conversationId] ?? '');
  }

  @override
  Future<Result<String>> createInvite(String conversationId) async {
    return const Success('mock-invite');
  }

  @override
  Future<Result<Conversation>> joinInvite(String token) async {
    return FailureResult(const UnexpectedFailure('HTTP-only'));
  }

  @override
  Future<Result<void>> updateRoom({
    required String conversationId,
    String title = '',
    String description = '',
    String visibility = '',
  }) async {
    return const Success(null);
  }

  @override
  Future<Result<void>> transferOwnership({
    required String conversationId,
    required String userId,
  }) async {
    return const Success(null);
  }

  @override
  Future<Result<void>> restrictMember({
    required String conversationId,
    required String userId,
    required bool canSend,
  }) async {
    return const Success(null);
  }

  @override
  Future<Result<ChatMessage>> forwardMessage({
    required String sourceId,
    required String messageId,
    required String destinationId,
  }) async {
    return FailureResult(const UnexpectedFailure('HTTP-only'));
  }

  @override
  Future<Result<PrivacySettings>> getPrivacy() async {
    return Success(_privacy);
  }

  @override
  Future<Result<void>> putPrivacy(PrivacySettings settings) async {
    _privacy = settings;
    return const Success(null);
  }

  @override
  Future<Result<List<UserPreview>>> listBlocked() async {
    return const Success([]);
  }

  @override
  Future<Result<void>> blockUsername(String username) async {
    return const Success(null);
  }

  @override
  Future<Result<void>> unblockUser(String userId) async {
    return const Success(null);
  }

  @override
  Future<Result<void>> reportUser({
    required String username,
    required String reason,
  }) async {
    return const Success(null);
  }

  @override
  Future<Result<List<AuthDeviceSession>>> listSessions() async {
    return const Success([]);
  }

  @override
  Future<Result<void>> revokeSession(String sessionId) async {
    return const Success(null);
  }

  @override
  Future<Result<void>> revokeOtherSessions() async {
    return const Success(null);
  }

  @override
  Future<Result<IceServers>> iceServers() async {
    return const Success(
      IceServers(
        servers: [
          {
            'urls': ['stun:stun.l.google.com:19302'],
          },
        ],
      ),
    );
  }

  @override
  Future<Result<CallRecord>> startCall({
    required String conversationId,
    required String kind,
    Map<String, dynamic>? payload,
  }) async {
    final record = CallRecord(
        id: 'call_mock_${_history.length}',
        conversationId: conversationId,
        callerId: 'local-user',
        kind: kind,
        state: 'ringing',
        createdAt: DateTime.now(),
        peerName: 'lin',
        outgoing: true,
      );
    _history.insert(0, record);
    return Success(record);
  }

  @override
  Future<Result<void>> signalCall({
    required String callId,
    required String action,
    Map<String, dynamic>? payload,
  }) async {
    return const Success(null);
  }

  @override
  Future<Result<List<CallRecord>>> listCalls() async {
    return Success(List<CallRecord>.from(_history));
  }

  @override
  Future<Result<void>> deleteCall(String callId) async {
    _history.removeWhere((item) => item.id == callId);
    return const Success(null);
  }

  @override
  Future<Result<void>> clearCallHistory() async {
    _history.clear();
    return const Success(null);
  }

  @override
  Stream<Map<String, dynamic>> watchCallSignals() => _calls.stream;

  @override
  List<Map<String, dynamic>> bufferedCallSignals(String callId) {
    return _callBuffer.peek(callId);
  }

  @override
  void clearCallSignals(String callId) {
    _callBuffer.clear(callId);
  }

  @override
  Future<void> sendRealtime(Map<String, dynamic> event) async {}

  @override
  Future<Result<BotAccount>> createBot(String username) async {
    return Success(
      BotAccount(id: 'bot_mock', userId: 'usr_bot', username: username, token: 'bot_mock'),
    );
  }

  @override
  Future<Result<List<BotAccount>>> listBots() async {
    return const Success([]);
  }

  @override
  Future<Result<void>> deleteBot(String botId) async {
    return const Success(null);
  }

  @override
  Future<Result<void>> grantBot({
    required String botId,
    required String conversationId,
    bool canSend = true,
    bool canRead = true,
    bool canManageMessages = false,
    bool canManageMembers = false,
  }) async {
    return const Success(null);
  }
}
