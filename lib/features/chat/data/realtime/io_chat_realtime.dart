import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:seyra/features/chat/data/models/call_signaling.dart';
import 'package:seyra/features/chat/data/realtime/chat_realtime_port.dart';

/// dart:io WebSocket client. Tokens are sent only as an Authorization header.
/// Reconnects with backoff so a later Redis-backed hub can keep the same events.
final class IoChatRealtime implements ChatRealtimePort {
  WebSocket? _socket;
  StreamController<Map<String, dynamic>>? _events;
  var _closed = false;
  var _generation = 0;

  @override
  Stream<Map<String, dynamic>> connect({
    required Uri uri,
    required Future<String?> Function() accessToken,
  }) {
    _generation++;
    final generation = _generation;
    final events = StreamController<Map<String, dynamic>>.broadcast();
    _events = events;
    _closed = false;
    unawaited(_listen(uri, accessToken, events, generation));
    return events.stream;
  }

  Future<void> _listen(
    Uri uri,
    Future<String?> Function() accessToken,
    StreamController<Map<String, dynamic>> events,
    int generation,
  ) async {
    var delay = const Duration(milliseconds: 400);
    while (!events.isClosed && !_closed && generation == _generation) {
      try {
        final token = (await accessToken())?.trim() ?? '';
        if (token.isEmpty) {
          throw StateError('missing access token');
        }
        final previous = _socket;
        _socket = null;
        await previous?.close();
        final socket = await WebSocket.connect(
          uri.toString(),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (generation != _generation || _closed || events.isClosed) {
          await socket.close();
          return;
        }
        _socket = socket;
        delay = const Duration(milliseconds: 400);
        if (!events.isClosed) {
          events.add(const {'type': 'realtime.connected'});
        }
        await for (final raw in socket) {
          if (generation != _generation || events.isClosed) {
            break;
          }
          final text = switch (raw) {
            String value => value,
            List<int> bytes => utf8.decode(bytes),
            _ => null,
          };
          if (text == null) {
            continue;
          }
          final decoded = jsonDecode(text);
          final map = stringKeyMap(decoded);
          if (map != null) {
            events.add(map);
          } else {
            developer.log(
              'seyra.call.ws client_parse_dropped',
              name: 'seyra.call',
            );
          }
        }
      } catch (_) {
        developer.log('seyra.call.ws client_disconnected', name: 'seyra.call');
        if (!events.isClosed) {
          events.add(const {'type': 'realtime.disconnected'});
        }
      }
      _socket = null;
      if (events.isClosed || _closed || generation != _generation) {
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
    _generation++;
    await _socket?.close();
    _socket = null;
    await _events?.close();
    _events = null;
  }

  @override
  Future<void> send(Map<String, dynamic> event) async {
    final socket = _socket;
    if (socket == null) {
      developer.log('seyra.call.ws client_send_dropped', name: 'seyra.call');
      return;
    }
    socket.add(jsonEncode(event));
  }
}
