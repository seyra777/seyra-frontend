import 'package:seyra/core/errors/result.dart';
import 'package:seyra/features/chat/domain/repositories/chat_repository.dart';

final class DeleteMessageUseCase {
  const DeleteMessageUseCase(this._repository);

  final ChatRepository _repository;

  Future<Result<void>> call({
    required String conversationId,
    required String messageId,
  }) {
    return _repository.deleteMessage(
      conversationId: conversationId,
      messageId: messageId,
    );
  }
}
