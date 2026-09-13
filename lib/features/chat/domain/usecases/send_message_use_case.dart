import 'package:seyra/core/errors/failures.dart';
import 'package:seyra/core/errors/result.dart';
import 'package:seyra/features/chat/domain/entities/chat_message.dart';
import 'package:seyra/features/chat/domain/repositories/chat_repository.dart';

final class SendMessageUseCase {
  const SendMessageUseCase(this._repository);

  final ChatRepository _repository;

  Future<Result<ChatMessage>> call({
    required String conversationId,
    required String body,
    String? replyToId,
    String? attachmentId,
  }) async {
    final text = body.trim();
    if (text.isEmpty && (attachmentId == null || attachmentId.isEmpty)) {
      return const FailureResult(ValidationFailure('Message is empty'));
    }
    return _repository.sendMessage(
      conversationId: conversationId,
      body: text,
      replyToId: replyToId,
      attachmentId: attachmentId,
    );
  }
}
