import 'package:seyra/core/errors/result.dart';
import 'package:seyra/features/chat/domain/entities/conversation.dart';
import 'package:seyra/features/chat/domain/entities/room_member.dart';
import 'package:seyra/features/chat/domain/repositories/chat_repository.dart';

/// Shared unimplemented room APIs for test doubles.
mixin ChatRoomRepositoryStub implements ChatRepository {
  @override
  Future<Result<Conversation>> startGroup({
    required String title,
    required List<String> usernames,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<Conversation>> startChannel({
    required String title,
    required List<String> usernames,
    String visibility = 'private',
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<List<RoomMember>>> listMembers(String conversationId) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<List<RoomMember>>> addMembers({
    required String conversationId,
    required List<String> usernames,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<void>> removeMember({
    required String conversationId,
    required String userId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<void>> setMemberRole({
    required String conversationId,
    required String userId,
    required MemberRole role,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<void>> leaveConversation(String conversationId) async {
    throw UnimplementedError();
  }
}
