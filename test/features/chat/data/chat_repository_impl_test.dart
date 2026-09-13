import 'package:flutter_test/flutter_test.dart';
import 'package:seyra/core/errors/result.dart';
import 'package:seyra/features/chat/data/datasources/mock_chat_data_source.dart';
import 'package:seyra/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:seyra/features/chat/domain/entities/chat_message.dart';

void main() {
  late MockChatDataSource source;
  late ChatRepositoryImpl repository;

  setUp(() {
    source = MockChatDataSource(now: DateTime(2026, 9, 7, 21, 0));
    repository = ChatRepositoryImpl(dataSource: source);
  });

  test('send, react, and delete update the local message list', () async {
    final sent = await repository.sendMessage(
      conversationId: '1',
      body: 'On my way',
    );
    expect(sent, isA<Success<ChatMessage>>());
    final message = (sent as Success<ChatMessage>).value;
    expect(message.body, 'On my way');
    expect(message.isMine, isTrue);

    final reacted = await repository.reactToMessage(
      conversationId: '1',
      messageId: message.id,
      emoji: '👍',
    );
    expect(reacted, isA<Success<void>>());

    final messages = await repository.watchMessages('1').first;
    expect(messages.last.reactions.single.emoji, '👍');

    final deleted = await repository.deleteMessage(
      conversationId: '1',
      messageId: message.id,
    );
    expect(deleted, isA<Success<void>>());
    final afterDelete = await repository.watchMessages('1').first;
    expect(afterDelete.any((item) => item.id == message.id), isFalse);
  });
}
