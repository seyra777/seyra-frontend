import 'package:seyra/features/chat/domain/entities/chat_message.dart';
import 'package:seyra/features/chat/domain/repositories/chat_repository.dart';

final class WatchMessagesUseCase {
  const WatchMessagesUseCase(this._repository);

  final ChatRepository _repository;

  Stream<List<ChatMessage>> call(String conversationId) {
    return _repository.watchMessages(conversationId);
  }
}
