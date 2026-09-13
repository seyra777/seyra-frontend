// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import 'package:seyra/features/chat/data/models/call_signaling.dart';
import 'package:seyra/features/chat/data/realtime/chat_realtime_port.dart';

/// Browser WebSocket cannot set Authorization. The access token is sent as a
/// `Sec-WebSocket-Protocol` value (`seyra.` + base64url), not in the URL.
final class IoChatRealtime implements ChatRealtimePort {
  html.WebSocket? _socket;
  StreamController<Map<String, dynamic>>? _events;
  var _closed = false;

  @override
  Stream<Map<String, dynamic>> connect({
    required Uri uri,
    required Future<String?> Function() accessToken,
  }) {
    final events = StreamController<Map<String, dynamic>>.broadcast();
    _events = events;
    _closed = false;
    unawaited(_listen(uri, accessToken, events));
    return events.stream;
  }

  Future<void> _listen(
    Uri uri,
    Future<String?> Function() accessToken,
    StreamController<Map<String, dynamic>> events,
  ) async {
    var delay = const Duration(milliseconds: 400);
    while (!events.isClosed && !_closed) {
      try {
        final token = (await accessToken())?.trim() ?? '';
        if (token.isEmpty) {
          throw StateError('missing access token');
        }
        final protocol =
            'seyra.${base64Url.encode(utf8.encode(token)).replaceAll('=', '')}';
        final socket = html.WebSocket(uri.toString(), [protocol]);
        _socket = socket;
        await socket.onOpen.first;
        delay = const Duration(milliseconds: 400);
        if (!events.isClosed) {
          events.add(const {'type': 'realtime.connected'});
        }
        await for (final raw in socket.onMessage) {
          if (events.isClosed) {
            break;
          }
          final data = raw.data;
          if (data is! String) {
            continue;
          }
          final decoded = jsonDecode(data);
          final map = stringKeyMap(decoded);
          if (map != null) {
            events.add(map);
          }
        }
      } catch (_) {
        if (!events.isClosed) {
          events.add(const {'type': 'realtime.disconnected'});
        }
      }
      _socket = null;
      if (events.isClosed || _closed) {
        return;
      }
      await Future<void>.delayed(delay);
      final nextMs = delay.inMilliseconds * 2;
      delay = Duration(milliseconds: nextMs > 8000 ? 8000 : nextMs);
    }
  }

  @override
  Future<void> disconnect() async {
    _closed = true;
    _socket?.close();
    _socket = null;
    await _events?.close();
    _events = null;
  }

  @override
  Future<void> send(Map<String, dynamic> event) async {
    final socket = _socket;
    if (socket == null || socket.readyState != html.WebSocket.OPEN) {
      return;
    }
    socket.send(jsonEncode(event));
  }
}
