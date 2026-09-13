import 'package:seyra/core/errors/result.dart';
import 'package:seyra/features/chat/domain/entities/room_member.dart';
import 'package:seyra/features/chat/domain/repositories/chat_repository.dart';

final class ListMembersUseCase {
  const ListMembersUseCase(this._repository);

  final ChatRepository _repository;

  Future<Result<List<RoomMember>>> call(String conversationId) {
    return _repository.listMembers(conversationId);
  }
}

final class AddMembersUseCase {
  const AddMembersUseCase(this._repository);

  final ChatRepository _repository;

  Future<Result<List<RoomMember>>> call({
    required String conversationId,
    required List<String> usernames,
  }) {
    return _repository.addMembers(
      conversationId: conversationId,
      usernames: usernames,
    );
  }
}

final class RemoveMemberUseCase {
  const RemoveMemberUseCase(this._repository);

  final ChatRepository _repository;

  Future<Result<void>> call({
    required String conversationId,
    required String userId,
  }) {
    return _repository.removeMember(
      conversationId: conversationId,
      userId: userId,
    );
  }
}

final class SetMemberRoleUseCase {
  const SetMemberRoleUseCase(this._repository);

  final ChatRepository _repository;

  Future<Result<void>> call({
    required String conversationId,
    required String userId,
    required MemberRole role,
  }) {
    return _repository.setMemberRole(
      conversationId: conversationId,
      userId: userId,
      role: role,
    );
  }
}

final class LeaveConversationUseCase {
  const LeaveConversationUseCase(this._repository);

  final ChatRepository _repository;

  Future<Result<void>> call(String conversationId) {
    return _repository.leaveConversation(conversationId);
  }
}
