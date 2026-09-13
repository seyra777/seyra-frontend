enum ChatRemoteErrorCode {
  notFound,
  forbidden,
  cannotMessageSelf,
  unauthorized,
  sessionExpired,
  invalidInput,
  alreadyMember,
  ownerProtected,
  network,
}

final class ChatRemoteException implements Exception {
  const ChatRemoteException(this.code, {this.statusCode});

  final ChatRemoteErrorCode code;
  final int? statusCode;

  @override
  String toString() => 'ChatRemoteException($code)';
}
