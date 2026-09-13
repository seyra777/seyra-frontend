import 'package:flutter_test/flutter_test.dart';
import 'package:seyra/features/chat/data/models/call_signaling.dart';

void main() {
  test('parses ICE m-line indexes from JSON numbers', () {
    expect(iceMLineIndex(0), 0);
    expect(iceMLineIndex(1.0), 1);
    expect(iceMLineIndex('2'), 2);
    expect(iceMLineIndex(null), isNull);
    expect(iceSdpMid(1), '1');
    expect(iceSdpMid(1.0), '1');
    expect(iceSdpMid('0'), '0');
    expect(iceSdpMid(''), isNull);
    expect(webrtcSdpType('RTCSdpTypeOffer', 'answer'), 'offer');
    expect(webrtcSdpType('answer', 'offer'), 'answer');
    expect(webrtcErrorCategory(StateError('x')), 'StateError');
  });

  test('parses nested ICE without requiring candidate strings in logs', () {
    final parsed = parseRemoteIce({
      'candidate': {
        'candidate': 'candidate:1 1 udp 2130706431 0.0.0.0 9 typ host',
        'sdpMid': 0,
        'sdpMLineIndex': 0.0,
      },
    });
    expect(parsed, isNotNull);
    expect(parsed!.sdpMid, '0');
    expect(parsed.sdpMLineIndex, 0);
    expect(parsed.kind, 'host');
    expect(parseRemoteIce({'candidate': ''}), isNull);
  });

  test('normalizes websocket maps and non-string ids', () {
    expect(stringKeyMap({'type': 'call.signal'})?['type'], 'call.signal');
    expect(signalId(12), '12');
    expect(
      isPeerCallSignal({'from_id': 'usr_lin', 'action': 'ice'}, 'usr_ada'),
      isTrue,
    );
  });

  test('ignores a caller echoing their own answer or ICE', () {
    expect(
      isPeerCallSignal({'from_id': 'usr_ada', 'action': 'answer'}, 'usr_ada'),
      isFalse,
    );
    expect(
      isPeerCallSignal({'from_id': 'usr_lin', 'action': 'answer'}, 'usr_ada'),
      isTrue,
    );
    expect(
      isPeerCallSignal({'action': 'offer', 'caller_id': 'usr_ada'}, 'usr_ada'),
      isFalse,
    );
  });

  test('keeps ICE that arrives before the call screen opens', () {
    final buffer = CallSignalBuffer();
    buffer.add({
      'call_id': 'call_1',
      'action': 'ice',
      'candidate': 'cand-a',
    });
    buffer.add({
      'call_id': 'call_1',
      'action': 'offer',
      'sdp': 'ignore',
    });
    expect(buffer.peek('call_1').single['candidate'], 'cand-a');
    buffer.clear('call_1');
    expect(buffer.peek('call_1'), isEmpty);
  });

  test('in-call UI requires ICE connected, not answer signaling', () {
    expect(
      describeCallMedia(
        peerConnectionState: 'RTCPeerConnectionStateConnecting',
        iceConnectionState: 'RTCIceConnectionStateChecking',
        outgoing: true,
      ).label,
      'Calling...',
    );
    expect(
      describeCallMedia(
        peerConnectionState: 'RTCPeerConnectionStateConnected',
        iceConnectionState: 'RTCIceConnectionStateChecking',
        outgoing: false,
      ).live,
      isFalse,
    );
    expect(
      describeCallMedia(
        peerConnectionState: 'RTCPeerConnectionStateConnected',
        iceConnectionState: 'RTCIceConnectionStateConnected',
        outgoing: false,
      ).label,
      'In call',
    );
    expect(
      describeCallMedia(
        peerConnectionState: 'RTCPeerConnectionStateConnected',
        iceConnectionState: 'RTCIceConnectionStateFailed',
        outgoing: false,
      ).label,
      'Connection failed',
    );
    expect(
      describeCallMedia(
        peerConnectionState: 'RTCPeerConnectionStateDisconnected',
        iceConnectionState: 'RTCIceConnectionStateDisconnected',
        outgoing: false,
      ).label,
      'Reconnecting',
    );
  });

  test('normalizes STUN urls from JSON lists without logging secrets', () {
    final summary = normalizeIceServers([
      {
        'urls': ['stun:stun.l.google.com:19302'],
      },
      {
        'url': 'turn:example.invalid:3478',
        'username': 'secret-user',
        'credential': 'secret-pass',
      },
    ]);
    expect(summary.stunConfigured, isTrue);
    expect(summary.turnConfigured, isTrue);
    expect(summary.servers.first['urls'], ['stun:stun.l.google.com:19302']);
    expect(summary.servers[1]['urls'], ['turn:example.invalid:3478']);
  });

  test('debug panel lists offer and answer independently', () {
    final diag = CallDiagnostics()
      ..callId = 'call_1'
      ..role = 'caller'
      ..offerSent = true
      ..answerReceived = true
      ..localOfferSet = true
      ..remoteAnswerSet = true
      ..localIceGenerated = 8
      ..localIceSent = 8
      ..remoteIceReceived = 0;
    final text = diag.summary();
    expect(text, contains('CLASS'));
    expect(text, contains('CALL ID call_1'));
    expect(text, contains('offer sent=yes received=no'));
    expect(text, contains('answer sent=no received=yes'));
    expect(text, contains('recv=0'));
  });

  test('classifies emulator ICE failure after candidates are applied', () {
    final diag = CallDiagnostics()
      ..role = 'caller'
      ..environment = 'emulator'
      ..offerSent = true
      ..answerReceived = true
      ..localOfferSet = true
      ..remoteAnswerSet = true
      ..localIceGenerated = 6
      ..localIceSent = 6
      ..remoteIceReceived = 6
      ..remoteIceApplied = 6
      ..iceState = 'RTCIceConnectionStateFailed'
      ..pcState = 'RTCPeerConnectionStateFailed';
    expect(classifyCallFailure(diag), 'EMULATOR_NETWORK_LIMITATION');
  });

  test('classifies missing remote ICE as signaling failure', () {
    final diag = CallDiagnostics()
      ..role = 'caller'
      ..answerReceived = true
      ..localOfferSet = true
      ..remoteAnswerSet = true
      ..localIceGenerated = 4
      ..localIceSent = 4
      ..remoteIceReceived = 0
      ..iceState = 'failed';
    expect(classifyCallFailure(diag), 'SIGNALING_FAILURE');
  });

  test('classifies apply failure when remote ICE is received but not applied', () {
    final diag = CallDiagnostics()
      ..role = 'callee'
      ..offerReceived = true
      ..remoteOfferSet = true
      ..localAnswerSet = true
      ..localIceGenerated = 3
      ..remoteIceReceived = 5
      ..remoteIceApplied = 0
      ..remoteIceFailed = 5
      ..iceState = 'failed';
    expect(classifyCallFailure(diag), 'ICE_APPLY_FAILURE');
  });

  test('physical phones drop emulator-only TURN and keep STUN', () {
    final withTurn = normalizeIceServers([
      {
        'urls': ['stun:stun.l.google.com:19302'],
      },
      {
        'urls': ['turn:10.0.2.2:3478'],
        'username': 'seyra-turn',
        'credential': 'secret',
      },
    ]);
    final phone = iceServersForRuntime(withTurn, emulator: false);
    expect(phone.stunConfigured, isTrue);
    expect(phone.turnConfigured, isFalse);
    expect(
      phone.servers.any(
        (server) => (server['urls'] as List).any(
          (url) => url.toString().contains('10.0.2.2'),
        ),
      ),
      isFalse,
    );
    final emu = iceServersForRuntime(withTurn, emulator: true);
    expect(emu.turnConfigured, isTrue);
  });

  test('falls back to public STUN when ice server list is empty', () {
    final summary = normalizeIceServers(const []);
    expect(summary.stunConfigured, isTrue);
    expect(summary.turnConfigured, isFalse);
    expect(summary.servers, isNotEmpty);
  });
}
