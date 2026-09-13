import 'package:seyra/core/errors/failures.dart';

abstract final class AuthCredentialsValidator {
  static ValidationFailure? validate({
    required String username,
    required String password,
  }) {
    if (username.trim().isEmpty) {
      return const ValidationFailure('Username is required');
    }
    if (password.isEmpty) {
      return const ValidationFailure('Password is required');
    }
    return null;
  }
}
