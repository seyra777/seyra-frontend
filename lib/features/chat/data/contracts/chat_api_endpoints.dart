abstract final class ChatApiEndpoints {
  static const chats = '/v1/chats';
  static const realtime = '/v1/realtime';
  static const userSearch = '/v1/users/search';

  static const groups = '/v1/chats/groups';
  static const channels = '/v1/chats/channels';

  static String messages(
    String chatId, {
    String? before,
    int? limit,
  }) {
    final params = <String, String>{};
    if (before != null && before.isNotEmpty) {
      params['before'] = before;
    }
    if (limit != null) {
      params['limit'] = '$limit';
    }
    if (params.isEmpty) {
      return '/v1/chats/$chatId/messages';
    }
    final query = params.entries
        .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return '/v1/chats/$chatId/messages?$query';
  }

  static String message(String chatId, String messageId) =>
      '/v1/chats/$chatId/messages/$messageId';

  static String members(String chatId) => '/v1/chats/$chatId/members';

  static String member(String chatId, String userId) =>
      '/v1/chats/$chatId/members/$userId';

  static String memberRole(String chatId, String userId) =>
      '/v1/chats/$chatId/members/$userId/role';

  static String leave(String chatId) => '/v1/chats/$chatId/leave';

  static String reactions(String chatId, String messageId) =>
      '/v1/chats/$chatId/messages/$messageId/reactions';

  static String markRead(String chatId) => '/v1/chats/$chatId/read';

  static String receipts(String chatId) => '/v1/chats/$chatId/receipts';
}
