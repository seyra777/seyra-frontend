import 'package:seyra/core/errors/result.dart';
import 'package:seyra/features/chat/domain/entities/conversation.dart';
import 'package:seyra/features/chat/domain/repositories/chat_repository.dart';

final class GetConversationUseCase {
  const GetConversationUseCase(this._repository);

  final ChatRepository _repository;

  Future<Result<Conversation>> call(String id) => _repository.getConversation(id);
}
