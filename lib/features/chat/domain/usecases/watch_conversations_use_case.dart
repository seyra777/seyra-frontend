import 'package:seyra/features/chat/domain/entities/conversation.dart';
import 'package:seyra/features/chat/domain/repositories/chat_repository.dart';

final class WatchConversationsUseCase {
  const WatchConversationsUseCase(this._repository);

  final ChatRepository _repository;

  Stream<List<Conversation>> call() => _repository.watchConversations();
}
