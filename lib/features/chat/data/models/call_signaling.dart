int? iceMLineIndex(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

String? iceSdpMid(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  if (value is int) {
    return value.toString();
  }
  if (value is num) {
    return value.toInt().toString();
  }
  return null;
}

String webrtcSdpType(Object? value, String fallback) {
  final raw = signalId(value).toLowerCase();
  if (raw.contains('offer')) {
    return 'offer';
  }
  if (raw.contains('answer')) {
    return 'answer';
  }
  return fallback;
}

String webrtcErrorCategory(Object error) {
  return error.runtimeType.toString();
}

Map<String, dynamic> unifiedPlanSdpConstraints() {
  return {
    'mandatory': <String, dynamic>{},
    'optional': <dynamic>[],
  };
}

String iceCandidateKind(String line) {
  final match = RegExp(
    r'\btyp\s+(host|srflx|prflx|relay)\b',
    caseSensitive: false,
  ).firstMatch(line);
  return match?.group(1)?.toLowerCase() ?? 'unknown';
}

final class ParsedIceCandidate {
  const ParsedIceCandidate({
    required this.candidate,
    required this.sdpMid,
    required this.sdpMLineIndex,
    required this.kind,
  });

  final String candidate;
  final String? sdpMid;
  final int? sdpMLineIndex;
  final String kind;
}

ParsedIceCandidate? parseRemoteIce(Map<String, dynamic> payload) {
  Object? candidate = payload['candidate'];
  Object? sdpMid = payload['sdpMid'];
  Object? sdpMLineIndex = payload['sdpMLineIndex'];
  final nested = stringKeyMap(candidate);
  if (nested != null) {
    candidate = nested['candidate'];
    sdpMid ??= nested['sdpMid'];
    sdpMLineIndex ??= nested['sdpMLineIndex'];
  }
  if (candidate is! String || candidate.trim().isEmpty) {
    return null;
  }
  var line = candidate.trim();
  if (line.startsWith('a=')) {
    line = line.substring(2).trim();
  }
  return ParsedIceCandidate(
    candidate: line,
    sdpMid: iceSdpMid(sdpMid),
    sdpMLineIndex: iceMLineIndex(sdpMLineIndex),
    kind: iceCandidateKind(line),
  );
}

String signalId(Object? value) {
  if (value == null) {
    return '';
  }
  if (value is String) {
    return value;
  }
  return value.toString();
}

Map<String, dynamic>? stringKeyMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return {
      for (final entry in value.entries) entry.key.toString(): entry.value,
    };
  }
  return null;
}

bool isPeerCallSignal(Map<String, dynamic> payload, String currentUserId) {
  if (currentUserId.isEmpty) {
    return true;
  }
  final fromId = signalId(payload['from_id']);
  if (fromId.isNotEmpty && fromId == currentUserId) {
    return false;
  }
  final action = signalId(payload['action']);
  final callerId = signalId(payload['caller_id']);
  if (action == 'offer' && callerId.isNotEmpty && callerId == currentUserId) {
    return false;
  }
  return true;
}

final class CallMediaUi {
  const CallMediaUi({required this.label, required this.live});

  final String label;
  final bool live;
}

/// UI from peer-connection + ICE state. Signaling success is not "in call".
CallMediaUi describeCallMedia({
  required String peerConnectionState,
  required String iceConnectionState,
  required bool outgoing,
}) {
  final pc = peerConnectionState.toLowerCase();
  final ice = iceConnectionState.toLowerCase();
  if (pc.contains('failed') || ice.contains('failed')) {
    return const CallMediaUi(label: 'Connection failed', live: false);
  }
  if (pc.contains('closed') || ice.contains('closed')) {
    return const CallMediaUi(label: 'Call ended', live: false);
  }
  if (pc.contains('disconnected') || ice.contains('disconnected')) {
    return const CallMediaUi(label: 'Reconnecting', live: false);
  }
  final iceUp = ice.contains('connected') || ice.contains('completed');
  final pcUp = pc.contains('connected');
  if (pcUp && iceUp) {
    return const CallMediaUi(label: 'In call', live: true);
  }
  return CallMediaUi(
    label: outgoing ? 'Calling...' : 'Connecting...',
    live: false,
  );
}

final class IceServerSummary {
  const IceServerSummary({
    required this.servers,
    required this.stunConfigured,
    required this.turnConfigured,
  });

  final List<Map<String, dynamic>> servers;
  final bool stunConfigured;
  final bool turnConfigured;
}

IceServerSummary normalizeIceServers(List<Map<String, dynamic>> raw) {
  final out = <Map<String, dynamic>>[];
  var stun = false;
  var turn = false;
  for (final item in raw) {
    final urls = <String>[];
    final rawUrls = item['urls'] ?? item['url'];
    if (rawUrls is String && rawUrls.trim().isNotEmpty) {
      urls.add(rawUrls.trim());
    } else if (rawUrls is List) {
      for (final entry in rawUrls) {
        if (entry is String && entry.trim().isNotEmpty) {
          urls.add(entry.trim());
        }
      }
    }
    if (urls.isEmpty) {
      continue;
    }
    for (final url in urls) {
      final lower = url.toLowerCase();
      if (lower.startsWith('stun:')) {
        stun = true;
      }
      if (lower.startsWith('turn:') || lower.startsWith('turns:')) {
        turn = true;
      }
    }
    final server = <String, dynamic>{'urls': urls};
    final username = item['username'];
    final credential = item['credential'];
    if (username is String && username.isNotEmpty) {
      server['username'] = username;
    }
    if (credential is String && credential.isNotEmpty) {
      server['credential'] = credential;
    }
    out.add(server);
  }
  if (out.isEmpty) {
    out.add({
      'urls': ['stun:stun.l.google.com:19302'],
    });
    stun = true;
  }
  return IceServerSummary(
    servers: out,
    stunConfigured: stun,
    turnConfigured: turn,
  );
}

bool isEmulatorOnlyIceUrl(String url) {
  final lower = url.toLowerCase();
  return lower.contains('10.0.2.2') || lower.contains('10.0.2.15');
}

/// Physical phones cannot reach the Android emulator host alias.
/// Docker/TURN on 10.0.2.2 is skipped; public STUN remains.
IceServerSummary iceServersForRuntime(
  IceServerSummary input, {
  required bool emulator,
}) {
  if (emulator) {
    return input;
  }
  final filtered = <Map<String, dynamic>>[];
  for (final server in input.servers) {
    final rawUrls = server['urls'];
    final urls = <String>[];
    if (rawUrls is List) {
      for (final entry in rawUrls) {
        if (entry is String &&
            entry.trim().isNotEmpty &&
            !isEmulatorOnlyIceUrl(entry)) {
          urls.add(entry.trim());
        }
      }
    }
    if (urls.isEmpty) {
      continue;
    }
    final next = <String, dynamic>{'urls': urls};
    final username = server['username'];
    final credential = server['credential'];
    if (username is String && username.isNotEmpty) {
      next['username'] = username;
    }
    if (credential is String && credential.isNotEmpty) {
      next['credential'] = credential;
    }
    filtered.add(next);
  }
  return normalizeIceServers(filtered);
}

final class CallDiagnostics {
  String role = '';
  String callId = '';
  String selfId = '';
  String peerId = '';
  var offerSent = false;
  var offerReceived = false;
  var answerSent = false;
  var answerReceived = false;
  var localOfferSet = false;
  var remoteOfferSet = false;
  var localAnswerSet = false;
  var remoteAnswerSet = false;
  var remoteDescApplied = false;
  var localIceGenerated = 0;
  var localIceSent = 0;
  var localIceSendFailed = 0;
  var remoteIceReceived = 0;
  var remoteIceQueued = 0;
  var remoteIceApplied = 0;
  var remoteIceFailed = 0;
  var localAudio = false;
  var localVideo = false;
  var remoteAudio = false;
  var remoteVideo = false;
  var stunConfigured = false;
  var turnConfigured = false;
  var iceServerCount = 0;
  var localHost = 0;
  var localSrflx = 0;
  var localRelay = 0;
  var remoteHost = 0;
  var remoteSrflx = 0;
  var remoteRelay = 0;
  String platform = '';
  String environment = '';
  var iceReachedChecking = false;
  var iceReachedConnected = false;
  String pcState = 'new';
  String iceState = 'new';
  String gatherState = 'new';
  String sdpState = 'new';
  String lastError = '';

  void countLocalKind(String kind) {
    switch (kind) {
      case 'host':
        localHost++;
      case 'srflx':
        localSrflx++;
      case 'relay':
        localRelay++;
    }
  }

  void countRemoteKind(String kind) {
    switch (kind) {
      case 'host':
        remoteHost++;
      case 'srflx':
        remoteSrflx++;
      case 'relay':
        remoteRelay++;
    }
  }

  String classification() => classifyCallFailure(this);

  String summary() {
    String yn(bool value) => value ? 'yes' : 'no';
    return [
      'CLASS ${classification()}',
      'CALL ID ${callId.isEmpty ? '-' : callId}',
      'ROLE $role platform=$platform env=$environment',
      'offer sent=${yn(offerSent)} received=${yn(offerReceived)}',
      'answer sent=${yn(answerSent)} received=${yn(answerReceived)}',
      'local offer=${yn(localOfferSet)} remote offer=${yn(remoteOfferSet)}',
      'local answer=${yn(localAnswerSet)} remote answer=${yn(remoteAnswerSet)}',
      'ICE gen=$localIceGenerated sent=$localIceSent recv=$remoteIceReceived applied=$remoteIceApplied fail=$remoteIceFailed queued=$remoteIceQueued',
      'host l=$localHost r=$remoteHost srflx l=$localSrflx r=$remoteSrflx relay l=$localRelay r=$remoteRelay',
      'servers=$iceServerCount STUN=${yn(stunConfigured)} TURN=${yn(turnConfigured)}',
      'PC $pcState ICE $iceState gather $gatherState',
      'checking=${yn(iceReachedChecking)} connected=${yn(iceReachedConnected)}',
      'media local a=${yn(localAudio)} v=${yn(localVideo)} remote a=${yn(remoteAudio)} v=${yn(remoteVideo)}',
      if (lastError.isNotEmpty) 'err=$lastError',
    ].join('\n');
  }
}

String classifyCallFailure(CallDiagnostics d) {
  final ice = d.iceState.toLowerCase();
  final pc = d.pcState.toLowerCase();
  final iceFailed = ice.contains('failed');
  final pcFailed = pc.contains('failed');
  if (!iceFailed && !pcFailed) {
    return 'NONE';
  }
  if (d.role == 'caller' && !d.answerReceived) {
    return 'SIGNALING_FAILURE';
  }
  if (d.role == 'callee' && !d.offerReceived) {
    return 'SIGNALING_FAILURE';
  }
  if (d.localIceSent > 0 && d.remoteIceReceived == 0) {
    return 'SIGNALING_FAILURE';
  }
  if (d.role == 'caller' && (!d.localOfferSet || !d.remoteAnswerSet)) {
    return 'SDP_FAILURE';
  }
  if (d.role == 'callee' && (!d.remoteOfferSet || !d.localAnswerSet)) {
    return 'SDP_FAILURE';
  }
  if (d.localIceGenerated == 0) {
    return 'ICE_GATHERING_FAILURE';
  }
  if (d.remoteIceReceived > 0 && d.remoteIceApplied == 0) {
    if (d.remoteIceFailed > 0) {
      return 'ICE_APPLY_FAILURE';
    }
    return 'ICE_PARSE_FAILURE';
  }
  if (pcFailed && d.iceReachedConnected) {
    return 'PEER_CONNECTION_FAILURE';
  }
  if (d.remoteIceApplied > 0 && iceFailed) {
    if (d.environment == 'emulator' && d.localRelay == 0 && d.remoteRelay == 0) {
      return 'EMULATOR_NETWORK_LIMITATION';
    }
    if (d.stunConfigured && d.localSrflx == 0 && d.remoteSrflx == 0) {
      return 'STUN_FAILURE';
    }
    if (!d.turnConfigured) {
      return 'TURN_REQUIRED';
    }
    return 'UNKNOWN';
  }
  return 'UNKNOWN';
}

final class CallSignalBuffer {
  final _byCall = <String, List<Map<String, dynamic>>>{};

  void add(Map<String, dynamic> payload) {
    final callId = signalId(payload['call_id']);
    final action = signalId(payload['action']);
    if (callId.isEmpty || (action != 'ice' && action != 'answer')) {
      return;
    }
    final list = _byCall.putIfAbsent(callId, () => []);
    list.add(Map<String, dynamic>.from(payload));
    while (list.length > 200) {
      list.removeAt(0);
    }
  }

  List<Map<String, dynamic>> peek(String callId) {
    return List<Map<String, dynamic>>.from(_byCall[callId] ?? const []);
  }

  void clear(String callId) {
    _byCall.remove(callId);
  }
}
