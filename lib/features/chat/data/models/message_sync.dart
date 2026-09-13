import 'package:seyra/features/chat/domain/entities/chat_message.dart';

/// Shown only when Signal decrypt genuinely cannot be performed.
const e2eDecryptPlaceholder = 'Unable to decrypt';

/// Previous UI copy. Still treated as a failed decrypt for merge/cache.
const e2eLegacyDecryptPlaceholder = 'Encrypted message';

bool isE2eDecryptPlaceholder(ChatMessage message) =>
    message.e2e && isE2ePlaceholderBody(message.body);

bool isE2ePlaceholderBody(String body) =>
    body == e2eDecryptPlaceholder || body == e2eLegacyDecryptPlaceholder;

/// Preview/list text must not treat decrypt placeholders as real history.
String cloudHistoryPreview(ChatMessage message) {
  if (isE2eDecryptPlaceholder(message) || message.decryptErrorCode != null) {
    return '';
  }
  return message.body;
}

bool isLocalPendingId(String id) => id.startsWith('pending_');

/// Merges REST history with local/realtime messages by id.
/// Pending/failed local rows are kept until a server id replaces them.
/// A successful local decrypt is not replaced by a later decrypt failure.
List<ChatMessage> mergeMessagesById({
  required List<ChatMessage> local,
  required List<ChatMessage> remote,
}) {
  final byId = <String, ChatMessage>{
    for (final item in local) item.id: item,
  };
  for (final item in remote) {
    final previous = byId[item.id];
    if (previous != null &&
        isE2eDecryptPlaceholder(item) &&
        !isE2eDecryptPlaceholder(previous)) {
      continue;
    }
    byId[item.id] = item;
  }
  _dropAckedPendings(byId);
  final out = byId.values.toList()
    ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
  return out;
}

bool sameOutgoingPayload(ChatMessage a, ChatMessage b) {
  return a.conversationId == b.conversationId &&
      a.senderId == b.senderId &&
      a.body == b.body &&
      (a.attachmentId ?? '') == (b.attachmentId ?? '');
}

bool isOutgoingAck(ChatMessage pending, ChatMessage remote) {
  if (isLocalPendingId(remote.id) || !isLocalPendingId(pending.id)) {
    return false;
  }
  if (pending.conversationId != remote.conversationId ||
      pending.senderId != remote.senderId) {
    return false;
  }
  if ((pending.attachmentId ?? '') != (remote.attachmentId ?? '')) {
    return false;
  }
  if (pending.body == remote.body) {
    return true;
  }
  return pending.e2e &&
      remote.e2e &&
      (isE2eDecryptPlaceholder(pending) || isE2eDecryptPlaceholder(remote));
}

/// Local `pending_*` row replaced by [remote], or -1.
int indexOfReplacedPending(List<ChatMessage> items, ChatMessage remote) {
  if (isLocalPendingId(remote.id)) {
    return -1;
  }
  var sendingFallback = -1;
  var sendingCount = 0;
  for (var i = 0; i < items.length; i++) {
    final item = items[i];
    if (!isLocalPendingId(item.id) || item.senderId != remote.senderId) {
      continue;
    }
    if (isOutgoingAck(item, remote)) {
      return i;
    }
    if (item.delivery == MessageDelivery.sending) {
      sendingCount++;
      sendingFallback = i;
    }
  }
  if (sendingCount == 1) {
    return sendingFallback;
  }
  return -1;
}

void _dropAckedPendings(Map<String, ChatMessage> byId) {
  final confirmed = byId.values.where((item) => !isLocalPendingId(item.id)).toList();
  final claimed = <String>{};
  for (final pendingId in byId.keys.where(isLocalPendingId).toList()) {
    final pending = byId[pendingId]!;
    ChatMessage? match;
    for (final item in confirmed) {
      if (claimed.contains(item.id)) {
        continue;
      }
      if (!isOutgoingAck(pending, item)) {
        continue;
      }
      match = item;
      break;
    }
    if (match != null) {
      claimed.add(match.id);
      // Never let a decrypt-failure echo replace a successful local plaintext.
      if (isE2eDecryptPlaceholder(match) &&
          !isE2ePlaceholderBody(pending.body)) {
        byId[match.id] = ChatMessage(
          id: match.id,
          conversationId: match.conversationId,
          senderId: match.senderId,
          body: pending.body,
          sentAt: match.sentAt,
          delivery: match.delivery,
          replyToId: match.replyToId,
          replyPreview: match.replyPreview,
          reactions: match.reactions,
          attachmentId: match.attachmentId ?? pending.attachmentId,
          contentType: match.contentType,
          fileKey: match.fileKey,
          fileNonce: match.fileNonce,
          e2e: match.e2e,
          edited: match.edited,
          forwardedFromId: match.forwardedFromId,
        );
      }
      byId.remove(pendingId);
    }
  }
}
