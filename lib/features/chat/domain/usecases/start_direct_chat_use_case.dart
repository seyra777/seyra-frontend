import 'package:seyra/core/errors/failures.dart';
import 'package:seyra/core/errors/result.dart';
import 'package:seyra/features/chat/domain/entities/conversation.dart';
import 'package:seyra/features/chat/domain/repositories/chat_repository.dart';

final class StartDirectChatUseCase {
  const StartDirectChatUseCase(this._repository);

  final ChatRepository _repository;

  Future<Result<Conversation>> call(String username) async {
    final value = username.trim();
    if (value.isEmpty) {
      return const FailureResult(ValidationFailure('Username is required'));
    }
    return _repository.startDirectChat(value);
  }
}
