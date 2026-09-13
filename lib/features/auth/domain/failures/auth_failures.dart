import 'package:seyra/core/errors/failures.dart';

/// Returned when authentication cannot run because no backend is connected.
final class AuthUnavailableFailure extends Failure {
  const AuthUnavailableFailure([
    super.message = 'Authentication is not connected yet',
  ]);
}

final class InvalidCredentialsFailure extends Failure {
  const InvalidCredentialsFailure([
    super.message = 'Invalid username or password',
  ]);
}

final class UsernameTakenFailure extends Failure {
  const UsernameTakenFailure([super.message = 'Username is already taken']);
}

final class SessionExpiredFailure extends Failure {
  const SessionExpiredFailure([super.message = 'Session expired']);
}

final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([super.message = 'Not authorized']);
}
