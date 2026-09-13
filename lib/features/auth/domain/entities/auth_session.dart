import 'package:seyra/features/auth/domain/entities/user.dart';

/// Authenticated session visible to domain and presentation.
///
/// Does not carry access tokens, refresh tokens, or passwords.
/// [sessionId] is an opaque server identifier, not a credential.
final class AuthSession {
  const AuthSession({
    required this.user,
    this.sessionId,
    this.expiresAt,
  });

  final User user;
  final String? sessionId;
  final DateTime? expiresAt;

  @override
  bool operator ==(Object other) {
    return other is AuthSession &&
        other.user == user &&
        other.sessionId == sessionId &&
        other.expiresAt == expiresAt;
  }

  @override
  int get hashCode => Object.hash(user, sessionId, expiresAt);
}
