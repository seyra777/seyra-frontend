enum AuthRemoteErrorCode {
  unavailable,
  invalidCredentials,
  usernameTaken,
  sessionExpired,
  unauthorized,
  network,
  invalidInput,
}

final class AuthRemoteException implements Exception {
  const AuthRemoteException(this.code, {this.statusCode});

  final AuthRemoteErrorCode code;
  final int? statusCode;

  @override
  String toString() => 'AuthRemoteException($code)';
}

final class AuthRemoteUnavailableException extends AuthRemoteException {
  const AuthRemoteUnavailableException()
    : super(AuthRemoteErrorCode.unavailable);
}
