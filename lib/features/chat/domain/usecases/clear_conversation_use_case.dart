import 'package:seyra/core/errors/result.dart';
import 'package:seyra/features/chat/domain/repositories/chat_repository.dart';

final class ClearConversationUseCase {
  const ClearConversationUseCase(this._repository);

  final ChatRepository _repository;

  Future<Result<void>> call(String conversationId) {
    return _repository.clearConversation(conversationId);
  }
}
