import 'package:seyra/core/errors/result.dart';
import 'package:seyra/features/chat/domain/repositories/chat_repository.dart';

final class ReactToMessageUseCase {
  const ReactToMessageUseCase(this._repository);

  final ChatRepository _repository;

  Future<Result<void>> call({
    required String conversationId,
    required String messageId,
    required String emoji,
  }) {
    return _repository.reactToMessage(
      conversationId: conversationId,
      messageId: messageId,
      emoji: emoji,
    );
  }
}
