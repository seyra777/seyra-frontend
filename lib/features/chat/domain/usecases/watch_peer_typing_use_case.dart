import 'package:seyra/features/chat/domain/repositories/chat_repository.dart';

final class WatchPeerTypingUseCase {
  const WatchPeerTypingUseCase(this._repository);

  final ChatRepository _repository;

  Stream<bool> call(String conversationId) {
    return _repository.watchPeerTyping(conversationId);
  }
}
