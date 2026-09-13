import 'package:seyra/features/auth/data/models/auth_credentials_model.dart';
import 'package:seyra/features/auth/data/models/user_model.dart';
import 'package:seyra/features/auth/domain/entities/auth_session.dart';

final class AuthSessionModel {
  const AuthSessionModel({
    required this.user,
    this.sessionId,
    this.expiresAt,
    this.credentials,
  });

  final UserModel user;
  final String? sessionId;
  final DateTime? expiresAt;

  /// Present on login/register/refresh responses. Never copied into [AuthSession].
  final AuthCredentialsModel? credentials;

  factory AuthSessionModel.fromJson(Map<String, dynamic> json) {
    final session = json['session'] as Map<String, dynamic>?;
    final credentials = json['credentials'] as Map<String, dynamic>?;
    final expiresAtRaw = session?['expires_at'] as String?;

    return AuthSessionModel(
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
      sessionId: session?['id'] as String?,
      expiresAt: expiresAtRaw == null ? null : DateTime.parse(expiresAtRaw),
      credentials: credentials == null
          ? null
          : AuthCredentialsModel.fromJson(credentials),
    );
  }

  /// Client-visible fields only. Credentials are omitted on purpose.
  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'session': {
        if (sessionId != null) 'id': sessionId,
        if (expiresAt != null) 'expires_at': expiresAt!.toUtc().toIso8601String(),
      },
    };
  }

  AuthSession toEntity() {
    return AuthSession(
      user: user.toEntity(),
      sessionId: sessionId,
      expiresAt: expiresAt,
    );
  }
}
