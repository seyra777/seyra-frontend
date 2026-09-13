import 'package:seyra/core/errors/result.dart';
import 'package:seyra/features/chat/domain/entities/chat_message.dart';
import 'package:seyra/features/chat/domain/entities/conversation.dart';
import 'package:seyra/features/chat/domain/entities/social_models.dart';
import 'package:seyra/features/chat/domain/entities/user_preview.dart';

abstract interface class ChatSocialRepository {
  Future<Result<GlobalSearchResult>> searchGlobal(String query);

  Future<Result<List<Conversation>>> discoverChannels(String query);

  Future<Result<Conversation>> joinChannel(String conversationId);

  Future<Result<String>> uploadAttachment({
    required String conversationId,
    required List<int> bytes,
    required String filename,
    required String contentType,
    bool e2e = false,
    void Function(int sent, int total)? onProgress,
    UploadCancelToken? cancelToken,
  });

  Future<Result<List<RoomAttachment>>> listAttachments(String conversationId);

  Future<Result<List<StickerItem>>> listStickers();

  Future<Result<DateTime?>> peerLastSeen(String userId);

  Future<Result<DateTime?>> readReceipt(String conversationId);

  Future<Result<List<int>>> downloadAttachment(String attachmentId);

  Future<Result<void>> editMessage({
    required String conversationId,
    required String messageId,
    required String body,
  });

  Future<Result<void>> pinMessage({
    required String conversationId,
    required String messageId,
  });

  Future<Result<void>> unpinMessage({
    required String conversationId,
    required String messageId,
  });

  Future<Result<List<ChatMessage>>> listPins(String conversationId);

  Future<Result<void>> setArchived({
    required String conversationId,
    required bool archived,
  });

  Future<Result<void>> persistMute({
    required String conversationId,
    required bool muted,
  });

  Future<Result<void>> saveDraft({
    required String conversationId,
    required String body,
  });

  Future<Result<String>> getDraft(String conversationId);

  Future<Result<String>> createInvite(String conversationId);

  Future<Result<Conversation>> joinInvite(String token);

  Future<Result<void>> updateRoom({
    required String conversationId,
    String title,
    String description,
    String visibility,
  });

  Future<Result<void>> transferOwnership({
    required String conversationId,
    required String userId,
  });

  Future<Result<void>> restrictMember({
    required String conversationId,
    required String userId,
    required bool canSend,
  });

  Future<Result<ChatMessage>> forwardMessage({
    required String sourceId,
    required String messageId,
    required String destinationId,
  });

  Future<Result<PrivacySettings>> getPrivacy();

  Future<Result<void>> putPrivacy(PrivacySettings settings);

  Future<Result<List<UserPreview>>> listBlocked();

  Future<Result<void>> blockUsername(String username);

  Future<Result<void>> unblockUser(String userId);

  Future<Result<void>> reportUser({required String username, required String reason});

  Future<Result<List<AuthDeviceSession>>> listSessions();

  Future<Result<void>> revokeSession(String sessionId);

  Future<Result<void>> revokeOtherSessions();

  Future<Result<IceServers>> iceServers();

  Future<Result<CallRecord>> startCall({
    required String conversationId,
    required String kind,
    Map<String, dynamic>? payload,
  });

  Future<Result<void>> signalCall({
    required String callId,
    required String action,
    Map<String, dynamic>? payload,
  });

  Future<Result<List<CallRecord>>> listCalls();

  Future<Result<void>> deleteCall(String callId);

  Future<Result<void>> clearCallHistory();

  Stream<Map<String, dynamic>> watchCallSignals();

  List<Map<String, dynamic>> bufferedCallSignals(String callId);

  void clearCallSignals(String callId);

  Future<void> sendRealtime(Map<String, dynamic> event);

  Future<Result<BotAccount>> createBot(String username);

  Future<Result<List<BotAccount>>> listBots();

  Future<Result<void>> deleteBot(String botId);

  Future<Result<void>> grantBot({
    required String botId,
    required String conversationId,
    bool canSend = true,
    bool canRead = true,
    bool canManageMessages = false,
    bool canManageMembers = false,
  });
}
