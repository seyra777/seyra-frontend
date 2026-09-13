abstract interface class ChatRealtimePort {
  Stream<Map<String, dynamic>> connect({
    required Uri uri,
    required Future<String?> Function() accessToken,
  });

  Future<void> disconnect();

  Future<void> send(Map<String, dynamic> event);
}
