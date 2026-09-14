import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:seyra/core/crypto/key_backup_service.dart';
import 'package:seyra/core/errors/result.dart';
import 'package:seyra/core/network/api_client.dart';
import 'package:seyra/core/storage/memory_secure_storage.dart';
import 'package:seyra/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:seyra/features/auth/data/exceptions/auth_remote_exceptions.dart';
import 'package:seyra/features/auth/data/models/auth_session_model.dart';
import 'package:seyra/features/auth/data/models/current_account_model.dart';
import 'package:seyra/features/auth/data/storage/auth_secure_storage_keys.dart';
import 'package:seyra/features/chat/data/datasources/http_chat_data_source.dart';
import 'package:seyra/features/chat/data/models/call_signaling.dart';
import 'package:seyra/features/chat/data/models/conversation_summary_model.dart';
import 'package:seyra/features/chat/data/models/message_sync.dart';
import 'package:seyra/features/chat/data/realtime/chat_realtime_port.dart';
import 'package:seyra/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:seyra/features/chat/domain/entities/chat_message.dart';
import 'package:seyra/features/chat/domain/entities/conversation.dart';
import 'package:seyra/features/chat/domain/entities/user_preview.dart';
import 'package:seyra/features/chat/domain/failures/chat_failures.dart';

void main() {
  test('maps chat list JSON to conversation tiles', () {
    final conversation = ConversationSummaryModel.fromJson({
      'id': 'cht_1',
      'peer': {'id': 'usr_lin', 'username': 'lin'},
      'last_message_preview': 'Hello from Seyra',
      'last_message_at': '2026-09-08T00:00:00.000Z',
      'unread_count': 2,
    }).toEntity();

    expect(conversation.title, 'lin');
    expect(conversation.initials, 'LI');
    expect(conversation.kind, ConversationKind.direct);
    expect(conversation.lastMessagePreview, 'Hello from Seyra');
    expect(conversation.unreadCount, 2);
  });

  test('maps group and channel JSON to conversation tiles', () {
    final group = ConversationSummaryModel.fromJson({
      'id': 'cht_g',
      'kind': 'group',
      'title': 'Design Team',
      'member_count': 3,
      'peer': {'id': '', 'username': ''},
      'last_message_preview': 'Ship the header',
      'last_message_at': '2026-09-08T00:00:00.000Z',
      'unread_count': 0,
    }).toEntity();
    expect(group.kind, ConversationKind.group);
    expect(group.title, 'Design Team');
    expect(group.statusText, '3 members');

    final channel = ConversationSummaryModel.fromJson({
      'id': 'cht_c',
      'kind': 'channel',
      'title': 'Seyra News',
      'member_count': 2,
      'last_message_preview': 'Privacy update',
      'last_message_at': '2026-09-08T00:00:00.000Z',
      'unread_count': 1,
    }).toEntity();
    expect(channel.kind, ConversationKind.channel);
    expect(channel.statusText, 'Channel');
  });

  test('loads messages and sends without exposing tokens', () async {
    final api = _FakeApiClient()
      ..responses.add(
        const ApiResponse(
          statusCode: 200,
          body:
              '{"chats":[{"id":"cht_1","peer":{"id":"usr_lin","username":"lin"},"last_message_preview":"Hi","last_message_at":"2026-09-08T00:00:00.000Z","unread_count":0}]}',
        ),
      )
      ..responses.add(
        const ApiResponse(
          statusCode: 200,
          body:
              '{"messages":[{"id":"msg_1","conversation_id":"cht_1","sender_id":"usr_lin","body":"Hi","created_at":"2026-09-08T00:00:00.000Z"}]}',
        ),
      )
      ..responses.add(
        const ApiResponse(
          statusCode: 201,
          body:
              '{"id":"msg_2","conversation_id":"cht_1","sender_id":"usr_ada","body":"Hello from Seyra","created_at":"2026-09-08T00:01:00.000Z"}',
        ),
      );
    final storage = MemorySecureStorage();
    await storage.write(key: AuthSecureStorageKeys.accessToken, value: 'secret-token');
    final source = HttpChatDataSource(
      apiClient: api,
      secureStorage: storage,
      authRemote: _FakeAuthRemote(),
      baseUrl: Uri.parse('http://127.0.0.1:8080'),
      realtime: _FakeRealtime(),
    );
    final repository = ChatRepositoryImpl(dataSource: source);

    final chats = await repository.watchConversations().first;
    expect(chats.single.title, 'lin');
    expect(chats.toString().contains('secret-token'), isFalse);

    final messages = await repository.watchMessages('cht_1').first;
    expect(messages.single.body, 'Hi');
    expect(messages.single.isFrom('usr_ada'), isFalse);

    final sent = await repository.sendMessage(
      conversationId: 'cht_1',
      body: 'Hello from Seyra',
    );
    expect((sent as Success<ChatMessage>).value.body, 'Hello from Seyra');
    expect(sent.value.isFrom('usr_ada'), isTrue);
    expect(sent.value.delivery, MessageDelivery.sent);
    expect(sent.toString().contains('secret-token'), isFalse);
  });

  test('search users maps public fields only', () async {
    final api = _FakeApiClient()
      ..responses.add(
        const ApiResponse(statusCode: 200, body: '{"chats":[]}'),
      )
      ..responses.add(
        const ApiResponse(
          statusCode: 200,
          body: '{"users":[{"id":"usr_lin","username":"lin"}]}',
        ),
      );
    final storage = MemorySecureStorage();
    await storage.write(key: AuthSecureStorageKeys.accessToken, value: 'token');
    final repository = ChatRepositoryImpl(
      dataSource: HttpChatDataSource(
        apiClient: api,
        secureStorage: storage,
        authRemote: _FakeAuthRemote(),
        baseUrl: Uri.parse('http://127.0.0.1:8080'),
        realtime: _FakeRealtime(),
      ),
    );
    await repository.watchConversations().first;
    final result = await repository.searchUsers('li');
    final users = (result as Success<List<UserPreview>>).value;
    expect(users.single.username, 'lin');
  });

  test('unread increments for peer messages when chat is not open', () async {
    final api = _FakeApiClient()
      ..responses.add(
        const ApiResponse(
          statusCode: 200,
          body:
              '{"chats":[{"id":"cht_1","peer":{"id":"usr_lin","username":"lin"},"last_message_preview":"Hi","last_message_at":"2026-09-08T00:00:00.000Z","unread_count":0}]}',
        ),
      );
    final realtime = _ControllableRealtime();
    final storage = MemorySecureStorage();
    await storage.write(key: AuthSecureStorageKeys.accessToken, value: 'token');
    final source = HttpChatDataSource(
      apiClient: api,
      secureStorage: storage,
      authRemote: _FakeAuthRemote(),
      baseUrl: Uri.parse('http://127.0.0.1:8080'),
      realtime: realtime,
    );
    final repository = ChatRepositoryImpl(dataSource: source);
    final seen = <List<Conversation>>[];
    final sub = repository.watchConversations().listen(seen.add);
    await Future<void>.delayed(Duration.zero);
    expect(seen.last.single.unreadCount, 0);
    realtime.emit({
      'type': 'message.created',
      'payload': {
        'id': 'msg_new',
        'conversation_id': 'cht_1',
        'sender_id': 'usr_lin',
        'body': 'ping',
        'created_at': '2026-09-08T00:02:00.000Z',
      },
    });
    await Future<void>.delayed(Duration.zero);
    expect(seen.last.single.unreadCount, 1);
    expect(seen.last.single.lastMessagePreview, 'ping');
    await sub.cancel();
  });

  test('own websocket echo replaces the sending placeholder', () async {
    final api = _FakeApiClient()
      ..messagePostHold = Completer<void>()
      ..responses.add(
        const ApiResponse(
          statusCode: 200,
          body:
              '{"chats":[{"id":"cht_1","peer":{"id":"usr_lin","username":"lin"},"last_message_preview":"Hi","last_message_at":"2026-09-08T00:00:00.000Z","unread_count":0}]}',
        ),
      )
      ..responses.add(
        const ApiResponse(
          statusCode: 200,
          body:
              '{"messages":[{"id":"msg_1","conversation_id":"cht_1","sender_id":"usr_lin","body":"Hi","created_at":"2026-09-08T00:00:00.000Z"}]}',
        ),
      )
      ..responses.add(
        const ApiResponse(
          statusCode: 201,
          body:
              '{"id":"msg_echo","conversation_id":"cht_1","sender_id":"usr_ada","body":"Hello","created_at":"2026-09-08T00:02:00.000Z"}',
        ),
      );
    final realtime = _ControllableRealtime();
    final storage = MemorySecureStorage();
    await storage.write(key: AuthSecureStorageKeys.accessToken, value: 'token');
    final source = HttpChatDataSource(
      apiClient: api,
      secureStorage: storage,
      authRemote: _FakeAuthRemote(),
      baseUrl: Uri.parse('http://127.0.0.1:8080'),
      realtime: realtime,
    );
    final repository = ChatRepositoryImpl(dataSource: source);
    await repository.watchConversations().first;
    final watched = <List<ChatMessage>>[];
    final sub = repository.watchMessages('cht_1').listen(watched.add);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final sent = repository.sendMessage(
      conversationId: 'cht_1',
      body: 'Hello',
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(
      source.peekMessages('cht_1').where((item) => item.body == 'Hello').length,
      1,
    );
    expect(
      source.peekMessages('cht_1').singleWhere((item) => item.body == 'Hello').delivery,
      MessageDelivery.sending,
    );

    realtime.emit({
      'type': 'message.created',
      'payload': {
        'id': 'msg_echo',
        'conversation_id': 'cht_1',
        'sender_id': 'usr_ada',
        'body': 'Hello',
        'created_at': '2026-09-08T00:02:00.000Z',
      },
    });
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final afterEcho = source
        .peekMessages('cht_1')
        .where((item) => item.body == 'Hello')
        .toList();
    expect(afterEcho, hasLength(1));
    expect(afterEcho.single.id, 'msg_echo');
    expect(afterEcho.single.delivery, MessageDelivery.sent);

    api.messagePostHold!.complete();
    final result = await sent;
    expect((result as Success<ChatMessage>).value.id, 'msg_echo');
    expect(
      source.peekMessages('cht_1').where((item) => item.body == 'Hello').length,
      1,
    );
    expect(
      watched.last.where((item) => item.body == 'Hello').length,
      1,
    );
    await sub.cancel();
  });

  test('http timeout after websocket ack does not leave a clock bubble', () async {
    final api = _FakeApiClient()
      ..messagePostHold = Completer<void>()
      ..responses.add(
        const ApiResponse(
          statusCode: 200,
          body:
              '{"chats":[{"id":"cht_1","peer":{"id":"usr_lin","username":"lin"},"last_message_preview":"Hi","last_message_at":"2026-09-08T00:00:00.000Z","unread_count":0}]}',
        ),
      )
      ..responses.add(
        const ApiResponse(
          statusCode: 200,
          body:
              '{"messages":[{"id":"msg_1","conversation_id":"cht_1","sender_id":"usr_lin","body":"Hi","created_at":"2026-09-08T00:00:00.000Z"}]}',
        ),
      )
      ..responses.add(const ApiResponse(statusCode: 504, body: '{}'));
    final realtime = _ControllableRealtime();
    final storage = MemorySecureStorage();
    await storage.write(key: AuthSecureStorageKeys.accessToken, value: 'token');
    final source = HttpChatDataSource(
      apiClient: api,
      secureStorage: storage,
      authRemote: _FakeAuthRemote(),
      baseUrl: Uri.parse('http://127.0.0.1:8080'),
      realtime: realtime,
    );
    final repository = ChatRepositoryImpl(dataSource: source);
    await repository.watchConversations().first;
    await repository.watchMessages('cht_1').first;

    final sent = repository.sendMessage(
      conversationId: 'cht_1',
      body: 'Hello',
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    realtime.emit({
      'type': 'message.created',
      'payload': {
        'id': 'msg_echo',
        'conversation_id': 'cht_1',
        'sender_id': 'usr_ada',
        'body': 'Hello',
        'created_at': '2026-09-08T00:02:00.000Z',
      },
    });
    await Future<void>.delayed(const Duration(milliseconds: 50));
    api.messagePostHold!.complete();
    final result = await sent;
    expect(result, isA<Success<ChatMessage>>());
    expect((result as Success<ChatMessage>).value.id, 'msg_echo');
    final hellos = source.peekMessages('cht_1').where((item) => item.body == 'Hello');
    expect(hellos.length, 1);
    expect(hellos.single.delivery, MessageDelivery.sent);
  });

  test('failed send then retry replaces the local message', () async {
    final api = _FakeApiClient()
      ..responses.add(
        const ApiResponse(
          statusCode: 200,
          body:
              '{"chats":[{"id":"cht_1","peer":{"id":"usr_lin","username":"lin"},"last_message_preview":"Hi","last_message_at":"2026-09-08T00:00:00.000Z","unread_count":0}]}',
        ),
      )
      ..responses.add(
        const ApiResponse(
          statusCode: 200,
          body:
              '{"messages":[{"id":"msg_1","conversation_id":"cht_1","sender_id":"usr_lin","body":"Hi","created_at":"2026-09-08T00:00:00.000Z"}]}',
        ),
      )
      ..responses.add(const ApiResponse(statusCode: 500, body: '{}'))
      ..responses.add(
        const ApiResponse(
          statusCode: 201,
          body:
              '{"id":"msg_2","conversation_id":"cht_1","sender_id":"usr_ada","body":"retry me","created_at":"2026-09-08T00:03:00.000Z"}',
        ),
      );
    final storage = MemorySecureStorage();
    await storage.write(key: AuthSecureStorageKeys.accessToken, value: 'token');
    final source = HttpChatDataSource(
      apiClient: api,
      secureStorage: storage,
      authRemote: _FakeAuthRemote(),
      baseUrl: Uri.parse('http://127.0.0.1:8080'),
      realtime: _FakeRealtime(),
    );
    final repository = ChatRepositoryImpl(dataSource: source);
    await repository.watchConversations().first;
    await repository.watchMessages('cht_1').first;

    final failed = await repository.sendMessage(
      conversationId: 'cht_1',
      body: 'retry me',
    );
    expect(failed, isA<FailureResult<ChatMessage>>());
    expect(
      source.peekMessages('cht_1').singleWhere((item) => item.body == 'retry me').delivery,
      MessageDelivery.failed,
    );
    final pendingId = source
        .peekMessages('cht_1')
        .lastWhere((item) => item.body == 'retry me')
        .id;

    final retried = await repository.retryMessage(
      conversationId: 'cht_1',
      messageId: pendingId,
    );
    expect((retried as Success<ChatMessage>).value.id, 'msg_2');
    expect(retried.value.delivery, MessageDelivery.sent);
    expect(
      source.peekMessages('cht_1').where((item) => item.body == 'retry me').length,
      1,
    );
    expect(
      source.peekMessages('cht_1').any((item) => item.delivery == MessageDelivery.failed),
      isFalse,
    );
  });

  test('delete waits for success and keeps the message on failure', () async {
    final api = _FakeApiClient()
      ..responses.add(
        const ApiResponse(
          statusCode: 200,
          body:
              '{"chats":[{"id":"cht_1","peer":{"id":"usr_lin","username":"lin"},"last_message_preview":"Hi","last_message_at":"2026-09-08T00:00:00.000Z","unread_count":0}]}',
        ),
      )
      ..responses.add(
        const ApiResponse(
          statusCode: 200,
          body:
              '{"messages":[{"id":"msg_1","conversation_id":"cht_1","sender_id":"usr_ada","body":"Hi","created_at":"2026-09-08T00:00:00.000Z"}]}',
        ),
      )
      ..responses.add(
        const ApiResponse(
          statusCode: 403,
          body: '{"error":{"code":"forbidden","message":"Forbidden"}}',
        ),
      )
      ..responses.add(const ApiResponse(statusCode: 204, body: ''));
    final storage = MemorySecureStorage();
    await storage.write(key: AuthSecureStorageKeys.accessToken, value: 'token');
    final source = HttpChatDataSource(
      apiClient: api,
      secureStorage: storage,
      authRemote: _FakeAuthRemote(),
      baseUrl: Uri.parse('http://127.0.0.1:8080'),
      realtime: _FakeRealtime(),
    );
    final repository = ChatRepositoryImpl(dataSource: source);
    await repository.watchConversations().first;
    await repository.watchMessages('cht_1').first;

    final denied = await repository.deleteMessage(
      conversationId: 'cht_1',
      messageId: 'msg_1',
    );
    expect(denied, isA<FailureResult<void>>());
    expect(source.peekMessages('cht_1').any((item) => item.id == 'msg_1'), isTrue);

    final ok = await repository.deleteMessage(
      conversationId: 'cht_1',
      messageId: 'msg_1',
    );
    expect(ok, isA<Success<void>>());
    expect(source.peekMessages('cht_1').any((item) => item.id == 'msg_1'), isFalse);
  });

  test('reconnect merge does not duplicate messages', () async {
    final api = _FakeApiClient()
      ..responses.add(
        const ApiResponse(
          statusCode: 200,
          body:
              '{"chats":[{"id":"cht_1","peer":{"id":"usr_lin","username":"lin"},"last_message_preview":"Hi","last_message_at":"2026-09-08T00:00:00.000Z","unread_count":0}]}',
        ),
      )
      ..responses.add(
        const ApiResponse(
          statusCode: 200,
          body:
              '{"messages":[{"id":"msg_1","conversation_id":"cht_1","sender_id":"usr_lin","body":"Hi","created_at":"2026-09-08T00:00:00.000Z"}]}',
        ),
      )
      ..responses.add(
        const ApiResponse(
          statusCode: 200,
          body:
              '{"chats":[{"id":"cht_1","peer":{"id":"usr_lin","username":"lin"},"last_message_preview":"Later","last_message_at":"2026-09-08T00:04:00.000Z","unread_count":0}]}',
        ),
      )
      ..responses.add(
        const ApiResponse(
          statusCode: 200,
          body:
              '{"messages":[{"id":"msg_1","conversation_id":"cht_1","sender_id":"usr_lin","body":"Hi","created_at":"2026-09-08T00:00:00.000Z"},{"id":"msg_2","conversation_id":"cht_1","sender_id":"usr_lin","body":"Later","created_at":"2026-09-08T00:04:00.000Z"}]}',
        ),
      );
    final realtime = _ControllableRealtime();
    final storage = MemorySecureStorage();
    await storage.write(key: AuthSecureStorageKeys.accessToken, value: 'token');
    final repository = ChatRepositoryImpl(
      dataSource: HttpChatDataSource(
        apiClient: api,
        secureStorage: storage,
        authRemote: _FakeAuthRemote(),
        baseUrl: Uri.parse('http://127.0.0.1:8080'),
        realtime: realtime,
      ),
    );
    await repository.watchConversations().first;
    final seen = <List<ChatMessage>>[];
    final sub = repository.watchMessages('cht_1').listen(seen.add);
    for (var i = 0; i < 20 && seen.isEmpty; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(seen, isNotEmpty);
    await Future<void>.delayed(Duration.zero);
    expect(seen.last.map((item) => item.id), ['msg_1']);
    realtime.emit({'type': 'realtime.connected'});
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(seen.last.map((item) => item.id), ['msg_1', 'msg_2']);
    await sub.cancel();
  });

  test('realtime message.deleted removes the message', () async {
    final api = _FakeApiClient()
      ..responses.add(
        const ApiResponse(
          statusCode: 200,
          body:
              '{"chats":[{"id":"cht_1","peer":{"id":"usr_lin","username":"lin"},"last_message_preview":"Hi","last_message_at":"2026-09-08T00:00:00.000Z","unread_count":0}]}',
        ),
      )
      ..responses.add(
        const ApiResponse(
          statusCode: 200,
          body:
              '{"messages":[{"id":"msg_1","conversation_id":"cht_1","sender_id":"usr_lin","body":"Hi","created_at":"2026-09-08T00:00:00.000Z"}]}',
        ),
      );
    final realtime = _ControllableRealtime();
    final storage = MemorySecureStorage();
    await storage.write(key: AuthSecureStorageKeys.accessToken, value: 'token');
    final repository = ChatRepositoryImpl(
      dataSource: HttpChatDataSource(
        apiClient: api,
        secureStorage: storage,
        authRemote: _FakeAuthRemote(),
        baseUrl: Uri.parse('http://127.0.0.1:8080'),
        realtime: realtime,
      ),
    );
    await repository.watchConversations().first;
    final seen = <List<ChatMessage>>[];
    final sub = repository.watchMessages('cht_1').listen(seen.add);
    for (var i = 0; i < 20 && seen.isEmpty; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(seen, isNotEmpty);
    await Future<void>.delayed(Duration.zero);
    expect(seen.last.single.id, 'msg_1');
    realtime.emit({
      'type': 'message.deleted',
      'payload': {'id': 'msg_1', 'conversation_id': 'cht_1'},
    });
    await Future<void>.delayed(Duration.zero);
    expect(seen.last, isEmpty);
    await sub.cancel();
  });

  test('peer receipt.updated marks own messages as read', () async {
    final api = _FakeApiClient()
      ..responses.add(
        const ApiResponse(
          statusCode: 200,
          body:
              '{"chats":[{"id":"cht_1","peer":{"id":"usr_lin","username":"lin"},"last_message_preview":"Hi","last_message_at":"2026-09-08T00:00:00.000Z","unread_count":0}]}',
        ),
      )
      ..responses.add(
        const ApiResponse(
          statusCode: 200,
          body:
              '{"messages":[{"id":"msg_1","conversation_id":"cht_1","sender_id":"usr_ada","body":"hi","created_at":"2026-09-08T00:00:00.000Z"}]}',
        ),
      );
    final realtime = _ControllableRealtime();
    final storage = MemorySecureStorage();
    await storage.write(key: AuthSecureStorageKeys.accessToken, value: 'token');
    final source = HttpChatDataSource(
      apiClient: api,
      secureStorage: storage,
      authRemote: _FakeAuthRemote(),
      baseUrl: Uri.parse('http://127.0.0.1:8080'),
      realtime: realtime,
    );
    final repository = ChatRepositoryImpl(dataSource: source);
    await repository.watchConversations().first;
    final seen = <List<ChatMessage>>[];
    final sub = repository.watchMessages('cht_1').listen(seen.add);
    for (var i = 0; i < 20 && seen.isEmpty; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(seen.last.single.delivery, MessageDelivery.sent);
    realtime.emit({
      'type': 'receipt.updated',
      'payload': {
        'conversation_id': 'cht_1',
        'user_id': 'usr_lin',
        'last_read_at': '2026-09-08T00:00:01.000Z',
      },
    });
    await Future<void>.delayed(Duration.zero);
    expect(seen.last.single.delivery, MessageDelivery.read);
    await sub.cancel();
  });

  test('maps missing username to ChatUserNotFoundFailure', () async {
    final api = _FakeApiClient()
      ..responses.add(
        const ApiResponse(statusCode: 200, body: '{"chats":[]}'),
      )
      ..responses.add(
        const ApiResponse(
          statusCode: 404,
          body: '{"error":{"code":"not_found","message":"Not found"}}',
        ),
      );
    final storage = MemorySecureStorage();
    await storage.write(key: AuthSecureStorageKeys.accessToken, value: 'token');
    final repository = ChatRepositoryImpl(
      dataSource: HttpChatDataSource(
        apiClient: api,
        secureStorage: storage,
        authRemote: _FakeAuthRemote(),
        baseUrl: Uri.parse('http://127.0.0.1:8080'),
        realtime: _FakeRealtime(),
      ),
    );

    await repository.watchConversations().first;
    final result = await repository.startDirectChat('ghost');
    expect(
      (result as FailureResult<Conversation>).failure,
      isA<ChatUserNotFoundFailure>(),
    );
  });

  test('rebinds chats when the signed-in account changes', () async {
    final auth = _FakeAuthRemote();
    final api = _FakeApiClient()
      ..responses.add(
        const ApiResponse(
          statusCode: 200,
          body:
              '{"chats":[{"id":"cht_old","peer":{"id":"usr_lin","username":"lin"},"last_message_preview":"old","last_message_at":"2026-09-08T00:00:00.000Z","unread_count":0}]}',
        ),
      )
      ..responses.add(
        const ApiResponse(
          statusCode: 200,
          body:
              '{"chats":[{"id":"cht_new","peer":{"id":"usr_ada","username":"ada"},"last_message_preview":"new","last_message_at":"2026-09-08T00:00:00.000Z","unread_count":0}]}',
        ),
      );
    final storage = MemorySecureStorage();
    await storage.write(key: AuthSecureStorageKeys.accessToken, value: 'token');
    final source = HttpChatDataSource(
      apiClient: api,
      secureStorage: storage,
      authRemote: auth,
      baseUrl: Uri.parse('http://127.0.0.1:8080'),
      realtime: _FakeRealtime(),
    );
    final repository = ChatRepositoryImpl(dataSource: source);

    final first = await repository.watchConversations().first;
    expect(first.single.id, 'cht_old');
    expect(repository.currentUserId, 'usr_ada');

    auth.id = 'usr_new';
    auth.username = 'newbie';
    final second = await repository.watchConversations().first;
    expect(repository.currentUserId, 'usr_new');
    expect(second.single.id, 'cht_new');
    expect(second.single.title, 'ada');
  });

  test('1:1 Signal send shows plaintext locally and decrypts for the peer', () async {
    final hub = _E2eHub();
    final realtimeAda = _ControllableRealtime();
    final adaStorage = MemorySecureStorage();
    final linStorage = MemorySecureStorage();
    await adaStorage.write(key: AuthSecureStorageKeys.accessToken, value: 'ada-token');
    await linStorage.write(key: AuthSecureStorageKeys.accessToken, value: 'lin-token');
    final adaSource = HttpChatDataSource(
      apiClient: _E2eApiClient(hub, 'usr_ada'),
      secureStorage: adaStorage,
      authRemote: _FakeAuthRemote(),
      baseUrl: Uri.parse('http://127.0.0.1:8080'),
      realtime: realtimeAda,
    );
    final linSource = HttpChatDataSource(
      apiClient: _E2eApiClient(hub, 'usr_lin'),
      secureStorage: linStorage,
      authRemote: _FakeAuthRemote()
        ..id = 'usr_lin'
        ..username = 'lin',
      baseUrl: Uri.parse('http://127.0.0.1:8080'),
      realtime: _FakeRealtime(),
    );

    await adaSource.watchConversations().first;
    await linSource.watchConversations().first;
    await adaSource.watchMessages('cht_1').first;
    await linSource.watchMessages('cht_1').first;

    final sent = await adaSource.sendMessage(
      conversationId: 'cht_1',
      body: 'hello',
    );
    expect(sent.body, 'hello');
    expect(sent.e2e, isTrue);
    expect(hub.lastBody, isNot('hello'));
    expect(hub.lastE2e, isTrue);
    expect(adaSource.getConversation('cht_1')?.lastMessagePreview, 'hello');

    realtimeAda.emit({
      'type': 'message.created',
      'payload': hub.lastMessageJson,
    });
    await Future<void>.delayed(Duration.zero);
    expect(adaSource.peekMessages('cht_1').last.body, 'hello');

    final linSeen = await linSource.watchMessages('cht_1').first;
    expect(linSeen.last.body, 'hello');
    expect(linSeen.last.e2e, isTrue);

    final adaAgain = HttpChatDataSource(
      apiClient: _E2eApiClient(hub, 'usr_ada'),
      secureStorage: adaStorage,
      authRemote: _FakeAuthRemote(),
      baseUrl: Uri.parse('http://127.0.0.1:8080'),
      realtime: _FakeRealtime(),
    );
    final restored = await adaAgain.watchMessages('cht_1').first;
    expect(restored.last.body, 'hello');
    expect(adaAgain.getConversation('cht_1')?.lastMessagePreview, 'hello');

    final linReply = await linSource.sendMessage(
      conversationId: 'cht_1',
      body: 'hello back',
    );
    expect(linReply.body, 'hello back');
    final adaIncoming = await adaSource.watchMessages('cht_1').first;
    expect(adaIncoming.last.body, 'hello back');

    expect(
      adaSource.peekMessages('cht_1').where((item) => item.body == 'thanks'),
      isEmpty,
    );
  });

  test('reinstall restore: 10+10 each way stays readable for both users', () async {
    final hub = _E2eHub();
    final adaStorage = MemorySecureStorage();
    final linStorage = MemorySecureStorage();
    await adaStorage.write(key: AuthSecureStorageKeys.accessToken, value: 'ada');
    await linStorage.write(key: AuthSecureStorageKeys.accessToken, value: 'lin');

    var adaSource = HttpChatDataSource(
      apiClient: _E2eApiClient(hub, 'usr_ada'),
      secureStorage: adaStorage,
      authRemote: _FakeAuthRemote(),
      baseUrl: Uri.parse('http://127.0.0.1:8080'),
      realtime: _FakeRealtime(),
    );
    var linSource = HttpChatDataSource(
      apiClient: _E2eApiClient(hub, 'usr_lin'),
      secureStorage: linStorage,
      authRemote: _FakeAuthRemote()
        ..id = 'usr_lin'
        ..username = 'lin',
      baseUrl: Uri.parse('http://127.0.0.1:8080'),
      realtime: _FakeRealtime(),
    );

    await adaSource.watchConversations().first;
    await linSource.watchConversations().first;
    await adaSource.watchMessages('cht_1').first;
    await linSource.watchMessages('cht_1').first;

    for (var i = 0; i < 10; i++) {
      await adaSource.sendMessage(conversationId: 'cht_1', body: 'a-pre-$i');
      await linSource.sendMessage(conversationId: 'cht_1', body: 'l-pre-$i');
    }

    void expectNoDecryptFailures(List<ChatMessage> items, String who) {
      final bad = items
          .where((item) => isE2eDecryptPlaceholder(item) || item.decryptErrorCode != null)
          .map((item) => '${item.id}:${item.body}:${item.decryptErrorCode}')
          .toList();
      expect(bad, isEmpty, reason: '$who has undecryptable messages: $bad');
    }

    expectNoDecryptFailures(adaSource.peekMessages('cht_1'), 'ada-pre');
    expectNoDecryptFailures(
      await linSource.watchMessages('cht_1').first,
      'lin-pre',
    );

    // Simulate cloud key+outbox backup, then wipe device storage (reinstall).
    final adaBackup = await KeyBackupService(adaStorage).exportPackage('usr_ada');
    final linBackup = await KeyBackupService(linStorage).exportPackage('usr_lin');

    final adaFresh = MemorySecureStorage();
    final linFresh = MemorySecureStorage();
    await adaFresh.write(key: AuthSecureStorageKeys.accessToken, value: 'ada');
    await linFresh.write(key: AuthSecureStorageKeys.accessToken, value: 'lin');
    await KeyBackupService(adaFresh).importPackage(
      userId: 'usr_ada',
      package: adaBackup,
    );
    await KeyBackupService(linFresh).importPackage(
      userId: 'usr_lin',
      package: linBackup,
    );

    adaSource = HttpChatDataSource(
      apiClient: _E2eApiClient(hub, 'usr_ada'),
      secureStorage: adaFresh,
      authRemote: _FakeAuthRemote(),
      baseUrl: Uri.parse('http://127.0.0.1:8080'),
      realtime: _FakeRealtime(),
    );
    linSource = HttpChatDataSource(
      apiClient: _E2eApiClient(hub, 'usr_lin'),
      secureStorage: linFresh,
      authRemote: _FakeAuthRemote()
        ..id = 'usr_lin'
        ..username = 'lin',
      baseUrl: Uri.parse('http://127.0.0.1:8080'),
      realtime: _FakeRealtime(),
    );

    await adaSource.restoreAfterBackup('usr_ada');
    await linSource.restoreAfterBackup('usr_lin');

    final adaHistory = await adaSource.watchMessages('cht_1').first;
    final linHistory = await linSource.watchMessages('cht_1').first;
    expectNoDecryptFailures(adaHistory, 'ada-after-reinstall');
    expectNoDecryptFailures(linHistory, 'lin-after-reinstall');
    expect(adaHistory.where((item) => item.body.startsWith('a-pre-')).length, 10);
    expect(adaHistory.where((item) => item.body.startsWith('l-pre-')).length, 10);
    expect(linHistory.where((item) => item.body.startsWith('a-pre-')).length, 10);
    expect(linHistory.where((item) => item.body.startsWith('l-pre-')).length, 10);

    for (var i = 0; i < 10; i++) {
      await adaSource.sendMessage(conversationId: 'cht_1', body: 'a-post-$i');
      await linSource.sendMessage(conversationId: 'cht_1', body: 'l-post-$i');
    }

    expectNoDecryptFailures(
      await adaSource.watchMessages('cht_1').first,
      'ada-post',
    );
    expectNoDecryptFailures(
      await linSource.watchMessages('cht_1').first,
      'lin-post',
    );
  });

  test('decrypt failure stays a presentation fallback', () async {
    final api = _FakeApiClient()
      ..responses.add(
        const ApiResponse(
          statusCode: 200,
          body:
              '{"chats":[{"id":"cht_1","peer":{"id":"usr_lin","username":"lin"},"last_message_preview":"Encrypted message","last_message_at":"2026-09-08T00:00:00.000Z","unread_count":0}]}',
        ),
      )
      ..responses.add(
        const ApiResponse(
          statusCode: 200,
          body:
              '{"messages":[{"id":"msg_e","conversation_id":"cht_1","sender_id":"usr_lin","body":"not-valid-signal","created_at":"2026-09-08T00:00:00.000Z","e2e":true}]}',
        ),
      );
    final storage = MemorySecureStorage();
    await storage.write(key: AuthSecureStorageKeys.accessToken, value: 'token');
    final source = HttpChatDataSource(
      apiClient: api,
      secureStorage: storage,
      authRemote: _FakeAuthRemote(),
      baseUrl: Uri.parse('http://127.0.0.1:8080'),
      realtime: _FakeRealtime(),
    );
    final messages = await source.watchMessages('cht_1').first;
    expect(messages.single.body, e2eDecryptPlaceholder);
    expect(messages.single.e2e, isTrue);
  });

  test('buffers call ICE until the call screen can consume it', () async {
    final api = _FakeApiClient()
      ..responses.add(
        const ApiResponse(
          statusCode: 200,
          body:
              '{"chats":[{"id":"cht_1","peer":{"id":"usr_lin","username":"lin"},"last_message_preview":"Hi","last_message_at":"2026-09-08T00:00:00.000Z","unread_count":0}]}',
        ),
      );
    final realtime = _ControllableRealtime();
    final storage = MemorySecureStorage();
    await storage.write(key: AuthSecureStorageKeys.accessToken, value: 'token');
    final source = HttpChatDataSource(
      apiClient: api,
      secureStorage: storage,
      authRemote: _FakeAuthRemote(),
      baseUrl: Uri.parse('http://127.0.0.1:8080'),
      realtime: realtime,
    );
    final repository = ChatRepositoryImpl(dataSource: source);
    await repository.watchConversations().first;
    realtime.emit({
      'type': 'call.signal',
      'payload': {
        'call_id': 'call_1',
        'action': 'ice',
        'candidate': 'cand-a',
        'sdpMLineIndex': 1.0,
      },
    });
    await Future<void>.delayed(Duration.zero);
    expect(source.bufferedCallSignals('call_1').single['candidate'], 'cand-a');
    expect(iceMLineIndex(source.bufferedCallSignals('call_1').single['sdpMLineIndex']), 1);
  });
}

final class _FakeApiClient implements ApiClient {
  final List<ApiResponse> responses = [];
  Completer<void>? messagePostHold;

  @override
  Future<ApiResponse> send({
    required String method,
    required Uri uri,
    Map<String, String>? headers,
    Object? jsonBody,
  }) async {
    if (uri.path.contains('/v1/e2e/') ||
        uri.path.endsWith('/read') ||
        uri.path.endsWith('/receipts')) {
      if (uri.path.endsWith('/receipts')) {
        return const ApiResponse(
          statusCode: 200,
          body: '{"visible":false}',
        );
      }
      return const ApiResponse(statusCode: 204, body: '{}');
    }
    if (method == 'POST' &&
        uri.path.contains('/messages') &&
        messagePostHold != null) {
      await messagePostHold!.future;
    }
    if (responses.isEmpty) {
      return const ApiResponse(statusCode: 500, body: '{}');
    }
    return responses.removeAt(0);
  }
}

final class _ControllableRealtime implements ChatRealtimePort {
  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  void emit(Map<String, dynamic> event) => _controller.add(event);

  @override
  Stream<Map<String, dynamic>> connect({
    required Uri uri,
    required Future<String?> Function() accessToken,
  }) {
    return _controller.stream;
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> send(Map<String, dynamic> event) async {}
}

final class _FakeRealtime implements ChatRealtimePort {
  @override
  Stream<Map<String, dynamic>> connect({
    required Uri uri,
    required Future<String?> Function() accessToken,
  }) {
    return const Stream.empty();
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> send(Map<String, dynamic> event) async {}
}

final class _FakeAuthRemote implements AuthRemoteDataSource {
  String id = 'usr_ada';
  String username = 'ada';

  @override
  Future<CurrentAccountModel> getCurrentAccount() async {
    return CurrentAccountModel(
      id: id,
      username: username,
      createdAt: DateTime.utc(2026, 1, 1),
    );
  }

  @override
  Future<AuthSessionModel> login({
    required String username,
    required String password,
  }) async {
    throw const AuthRemoteUnavailableException();
  }

  @override
  Future<AuthSessionModel> register({
    required String username,
    required String password,
  }) {
    return login(username: username, password: password);
  }

  @override
  Future<void> logout() async {}

  @override
  Future<AuthSessionModel?> restoreSession() async => null;

  @override
  Future<AuthSessionModel> refreshSession() async {
    throw const AuthRemoteUnavailableException();
  }

  @override
  Future<void> deleteAccount({required String password}) async {}
}

final class _E2eHub {
  final devices = <String, Map<String, dynamic>>{};
  final prekeys = <String, List<Map<String, dynamic>>>{};
  final messages = <Map<String, dynamic>>[];
  var _seq = 0;

  Map<String, dynamic> get lastMessageJson => messages.last;

  String get lastBody => messages.last['body'] as String;

  bool get lastE2e => messages.last['e2e'] == true;
}

final class _E2eApiClient implements ApiClient {
  _E2eApiClient(this.hub, this.userId);

  final _E2eHub hub;
  final String userId;

  String get _peerId => userId == 'usr_ada' ? 'usr_lin' : 'usr_ada';

  String get _peerName => userId == 'usr_ada' ? 'lin' : 'ada';

  @override
  Future<ApiResponse> send({
    required String method,
    required Uri uri,
    Map<String, String>? headers,
    Object? jsonBody,
  }) async {
    final path = uri.path;
    if (method == 'POST' && path == '/v1/e2e/keys') {
      final body = Map<String, dynamic>.from(jsonBody as Map);
      hub.devices[userId] = body;
      final keys = (body['prekeys'] as List).cast<dynamic>();
      hub.prekeys[userId] = [
        for (final item in keys) Map<String, dynamic>.from(item as Map),
      ];
      return const ApiResponse(statusCode: 204, body: '{}');
    }
    if (method == 'GET' && path.startsWith('/v1/e2e/bundle/')) {
      final peer = path.split('/').last;
      final device = hub.devices[peer];
      final keys = hub.prekeys[peer];
      if (device == null || keys == null || keys.isEmpty) {
        return const ApiResponse(statusCode: 404, body: '{}');
      }
      final ot = keys.removeAt(0);
      return ApiResponse(
        statusCode: 200,
        body: jsonEncode({
          'device_id': device['device_id'],
          'registration_id': device['registration_id'],
          'identity_public': device['identity_public'],
          'signed_prekey_id': device['signed_prekey_id'],
          'signed_prekey_public': device['signed_prekey_public'],
          'signed_prekey_sig': device['signed_prekey_sig'],
          'one_time_prekey_id': ot['key_id'],
          'one_time_prekey_public': ot['public_key'],
        }),
      );
    }
    if (path.endsWith('/read')) {
      return const ApiResponse(statusCode: 204, body: '{}');
    }
    if (path.endsWith('/receipts')) {
      return const ApiResponse(
        statusCode: 200,
        body: '{"visible":false}',
      );
    }
    if (method == 'GET' && path == '/v1/chats') {
      final last = hub.messages.isEmpty ? null : hub.messages.last;
      return ApiResponse(
        statusCode: 200,
        body: jsonEncode({
          'chats': [
            {
              'id': 'cht_1',
              'kind': 'direct',
              'peer': {'id': _peerId, 'username': _peerName},
              'last_message_preview': last == null
                  ? 'Hi'
                  : (last['e2e'] == true ? 'Encrypted message' : last['body']),
              'last_message_at': last == null
                  ? '2026-09-08T00:00:00.000Z'
                  : last['created_at'],
              'unread_count': 0,
              if (last != null) 'last_message_id': last['id'],
              if (last != null) 'last_message_sender_id': last['sender_id'],
              if (last != null) 'last_message_e2e': last['e2e'] == true,
              if (last != null) 'last_message_body': last['body'],
            },
          ],
        }),
      );
    }
    if (method == 'GET' && path == '/v1/chats/cht_1/messages') {
      return ApiResponse(
        statusCode: 200,
        body: jsonEncode({'messages': hub.messages}),
      );
    }
    if (method == 'POST' && path == '/v1/chats/cht_1/messages') {
      final body = Map<String, dynamic>.from(jsonBody as Map);
      hub._seq += 1;
      final message = {
        'id': 'msg_${hub._seq}',
        'conversation_id': 'cht_1',
        'sender_id': userId,
        'body': body['body'],
        'created_at': DateTime.utc(2026, 9, 8, 0, hub._seq).toIso8601String(),
        if (body['e2e'] == true) 'e2e': true,
      };
      hub.messages.add(message);
      return ApiResponse(statusCode: 201, body: jsonEncode(message));
    }
    return const ApiResponse(statusCode: 500, body: '{}');
  }
}
