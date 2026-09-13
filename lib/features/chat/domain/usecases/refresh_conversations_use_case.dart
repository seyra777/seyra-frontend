import 'package:seyra/core/errors/result.dart';
import 'package:seyra/features/chat/domain/repositories/chat_repository.dart';

final class RefreshConversationsUseCase {
  const RefreshConversationsUseCase(this._repository);

  final ChatRepository _repository;

  Future<Result<void>> call() => _repository.refreshConversations();
}
