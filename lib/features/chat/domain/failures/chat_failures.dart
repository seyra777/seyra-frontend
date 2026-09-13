import 'package:seyra/core/errors/failures.dart';

final class ChatUserNotFoundFailure extends Failure {
  const ChatUserNotFoundFailure([super.message = 'That username was not found']);
}

final class CannotMessageSelfFailure extends Failure {
  const CannotMessageSelfFailure([
    super.message = 'You cannot message yourself',
  ]);
}

final class ChatForbiddenFailure extends Failure {
  const ChatForbiddenFailure([super.message = 'Not allowed']);
}

final class ChatOwnerProtectedFailure extends Failure {
  const ChatOwnerProtectedFailure([
    super.message = 'The group owner cannot be removed or leave',
  ]);
}
