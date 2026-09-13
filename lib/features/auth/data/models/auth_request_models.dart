/// Wire body for login and registration. Password is for transport only.
final class AuthPasswordRequest {
  const AuthPasswordRequest({
    required this.username,
    required this.password,
  });

  final String username;
  final String password;

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': password,
    };
  }

  @override
  String toString() => 'AuthPasswordRequest(username: $username, password: ***)';
}

/// Wire body for destructive account deletion re-authentication.
final class DeleteAccountRequest {
  const DeleteAccountRequest({required this.password});

  final String password;

  Map<String, dynamic> toJson() {
    return {'password': password};
  }

  @override
  String toString() => 'DeleteAccountRequest(password: ***)';
}

/// Wire body for session refresh. Never expose this to presentation.
final class RefreshSessionRequest {
  const RefreshSessionRequest({required this.refreshToken});

  final String refreshToken;

  Map<String, dynamic> toJson() {
    return {'refresh_token': refreshToken};
  }

  @override
  String toString() => 'RefreshSessionRequest(refresh_token: ***)';
}
