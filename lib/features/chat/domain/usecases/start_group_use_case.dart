import 'package:seyra/core/errors/failures.dart';
import 'package:seyra/core/errors/result.dart';
import 'package:seyra/features/chat/domain/entities/conversation.dart';
import 'package:seyra/features/chat/domain/repositories/chat_repository.dart';

final class StartGroupUseCase {
  const StartGroupUseCase(this._repository);

  final ChatRepository _repository;

  Future<Result<Conversation>> call({
    required String title,
    required List<String> usernames,
  }) async {
    final name = title.trim();
    if (name.isEmpty) {
      return const FailureResult(ValidationFailure('Group name is required'));
    }
    final members = usernames.map((item) => item.trim()).where((item) => item.isNotEmpty).toList();
    if (members.isEmpty) {
      return const FailureResult(
        ValidationFailure('Add at least one member'),
      );
    }
    return _repository.startGroup(title: name, usernames: members);
  }
}
