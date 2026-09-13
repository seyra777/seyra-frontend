import 'package:flutter_test/flutter_test.dart';
import 'package:seyra/features/chat/data/models/message_sync.dart';
import 'package:seyra/features/chat/domain/entities/chat_message.dart';

void main() {
  test('merges by id without duplicates and keeps chronological order', () {
    final older = ChatMessage(
      id: 'a',
      conversationId: 'c1',
      senderId: 'usr_lin',
      body: 'Hi',
      sentAt: DateTime.utc(2026, 9, 8, 1),
      delivery: MessageDelivery.sent,
    );
    final newer = ChatMessage(
      id: 'b',
      conversationId: 'c1',
      senderId: 'usr_ada',
      body: 'Hello',
      sentAt: DateTime.utc(2026, 9, 8, 2),
      delivery: MessageDelivery.sent,
    );
    final merged = mergeMessagesById(
      local: [newer, older],
      remote: [older.copyWith(delivery: MessageDelivery.sent), newer],
    );
    expect(merged.map((item) => item.id), ['a', 'b']);
  });

  test('keeps a failed local message that is not on the server', () {
    final failed = ChatMessage(
      id: 'pending_1',
      conversationId: 'c1',
      senderId: 'usr_ada',
      body: 'offline',
      sentAt: DateTime.utc(2026, 9, 8, 3),
      delivery: MessageDelivery.failed,
    );
    final remote = ChatMessage(
      id: 'msg_1',
      conversationId: 'c1',
      senderId: 'usr_lin',
      body: 'Hi',
      sentAt: DateTime.utc(2026, 9, 8, 1),
      delivery: MessageDelivery.sent,
    );
    final merged = mergeMessagesById(local: [failed], remote: [remote]);
    expect(merged.map((item) => item.id), ['msg_1', 'pending_1']);
  });

  test('drops a sending placeholder once the server message exists', () {
    final pending = ChatMessage(
      id: 'pending_1',
      conversationId: 'c1',
      senderId: 'usr_ada',
      body: 'Hello',
      sentAt: DateTime.utc(2026, 9, 8, 2),
      delivery: MessageDelivery.sending,
    );
    final acked = ChatMessage(
      id: 'msg_2',
      conversationId: 'c1',
      senderId: 'usr_ada',
      body: 'Hello',
      sentAt: DateTime.utc(2026, 9, 8, 2, 1),
      delivery: MessageDelivery.sent,
    );
    final merged = mergeMessagesById(local: [pending], remote: [acked]);
    expect(merged.map((item) => item.id), ['msg_2']);
    expect(merged.single.delivery, MessageDelivery.sent);
  });

  test('keeps pending plaintext when e2e echo is a decrypt placeholder', () {
    final pending = ChatMessage(
      id: 'pending_1',
      conversationId: 'c1',
      senderId: 'usr_ada',
      body: 'Hello',
      sentAt: DateTime.utc(2026, 9, 8, 2),
      delivery: MessageDelivery.sending,
      e2e: true,
    );
    final acked = ChatMessage(
      id: 'msg_2',
      conversationId: 'c1',
      senderId: 'usr_ada',
      body: e2eDecryptPlaceholder,
      sentAt: DateTime.utc(2026, 9, 8, 2, 1),
      delivery: MessageDelivery.sent,
      e2e: true,
      decryptErrorCode: 'e2e.missing_outbox',
    );
    expect(indexOfReplacedPending([pending], acked), 0);
    final merged = mergeMessagesById(local: [pending], remote: [acked]);
    expect(merged.map((item) => item.id), ['msg_2']);
    expect(merged.single.body, 'Hello');
    expect(merged.single.decryptErrorCode, isNull);
  });

  test('does not replace a successful local decrypt with the e2e placeholder', () {
    final local = ChatMessage(
      id: 'msg_1',
      conversationId: 'c1',
      senderId: 'usr_lin',
      body: 'hi',
      sentAt: DateTime.utc(2026, 9, 8, 1),
      delivery: MessageDelivery.sent,
      e2e: true,
    );
    final remote = ChatMessage(
      id: 'msg_1',
      conversationId: 'c1',
      senderId: 'usr_lin',
      body: e2eDecryptPlaceholder,
      sentAt: DateTime.utc(2026, 9, 8, 1),
      delivery: MessageDelivery.sent,
      e2e: true,
    );
    final merged = mergeMessagesById(local: [local], remote: [remote]);
    expect(merged.single.body, 'hi');
  });

  test('treats the legacy Encrypted message copy as a decrypt failure', () {
    final local = ChatMessage(
      id: 'msg_1',
      conversationId: 'c1',
      senderId: 'usr_lin',
      body: 'hi',
      sentAt: DateTime.utc(2026, 9, 8, 1),
      delivery: MessageDelivery.sent,
      e2e: true,
    );
    final remote = ChatMessage(
      id: 'msg_1',
      conversationId: 'c1',
      senderId: 'usr_lin',
      body: e2eLegacyDecryptPlaceholder,
      sentAt: DateTime.utc(2026, 9, 8, 1),
      delivery: MessageDelivery.sent,
      e2e: true,
    );
    final merged = mergeMessagesById(local: [local], remote: [remote]);
    expect(merged.single.body, 'hi');
  });

  test('cloudHistoryPreview rejects decrypt placeholders as history text', () {
    final failed = ChatMessage(
      id: 'm1',
      conversationId: 'c1',
      senderId: 'usr_ada',
      body: e2eDecryptPlaceholder,
      sentAt: DateTime.utc(2026, 9, 8, 1),
      delivery: MessageDelivery.sent,
      e2e: true,
      decryptErrorCode: 'e2e.no_session',
    );
    expect(cloudHistoryPreview(failed), isEmpty);

    final readable = ChatMessage(
      id: 'm2',
      conversationId: 'c1',
      senderId: 'usr_ada',
      body: 'Hi',
      sentAt: DateTime.utc(2026, 9, 8, 1),
      delivery: MessageDelivery.sent,
      e2e: true,
    );
    expect(cloudHistoryPreview(readable), 'Hi');
  });
}
