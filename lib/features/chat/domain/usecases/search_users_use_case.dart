import 'package:seyra/core/errors/failures.dart';
import 'package:seyra/core/errors/result.dart';
import 'package:seyra/features/chat/domain/entities/user_preview.dart';
import 'package:seyra/features/chat/domain/repositories/chat_repository.dart';

final class SearchUsersUseCase {
  const SearchUsersUseCase(this._repository);

  final ChatRepository _repository;

  Future<Result<List<UserPreview>>> call(String query) {
    final value = query.trim();
    if (value.isEmpty) {
      return Future.value(const Success(<UserPreview>[]));
    }
    if (value.length > 32) {
      return Future.value(
        const FailureResult(ValidationFailure('Search is too long')),
      );
    }
    return _repository.searchUsers(value);
  }
}
