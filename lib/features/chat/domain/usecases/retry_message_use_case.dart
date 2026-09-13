import 'package:seyra/core/errors/result.dart';
import 'package:seyra/features/chat/domain/entities/chat_message.dart';
import 'package:seyra/features/chat/domain/repositories/chat_repository.dart';

final class RetryMessageUseCase {
  const RetryMessageUseCase(this._repository);

  final ChatRepository _repository;

  Future<Result<ChatMessage>> call({
    required String conversationId,
    required String messageId,
  }) {
    return _repository.retryMessage(
      conversationId: conversationId,
      messageId: messageId,
    );
  }
}
