import 'package:seyra/core/errors/result.dart';
import 'package:seyra/features/chat/domain/repositories/chat_repository.dart';

final class SetConversationMutedUseCase {
  const SetConversationMutedUseCase(this._repository);

  final ChatRepository _repository;

  Future<Result<void>> call({
    required String conversationId,
    required bool muted,
  }) {
    return _repository.setMuted(
      conversationId: conversationId,
      muted: muted,
    );
  }
}
