import 'package:seyra/core/errors/failures.dart';
import 'package:seyra/core/errors/result.dart';
import 'package:seyra/features/chat/domain/entities/conversation.dart';
import 'package:seyra/features/chat/domain/repositories/chat_repository.dart';

final class StartChannelUseCase {
  const StartChannelUseCase(this._repository);

  final ChatRepository _repository;

  Future<Result<Conversation>> call({
    required String title,
    required List<String> usernames,
    String visibility = 'private',
  }) async {
    final name = title.trim();
    if (name.isEmpty) {
      return const FailureResult(ValidationFailure('Channel name is required'));
    }
    return _repository.startChannel(
      title: name,
      usernames: usernames,
      visibility: visibility,
    );
  }
}
