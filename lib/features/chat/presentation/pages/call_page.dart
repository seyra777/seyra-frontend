import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:seyra/core/errors/result.dart';
import 'package:seyra/features/chat/data/models/call_runtime.dart';
import 'package:seyra/features/chat/data/models/call_signaling.dart';
import 'package:seyra/features/chat/domain/entities/social_models.dart';
import 'package:seyra/features/chat/domain/repositories/chat_social_repository.dart';
import 'package:seyra/features/profile/presentation/widgets/user_avatar.dart';

class CallPage extends StatefulWidget {
  const CallPage({
    super.key,
    required this.social,
    required this.conversationId,
    required this.video,
    required this.outgoing,
    this.incomingPayload,
    this.peerTitle = '',
    this.peerId = '',
    this.peerInitials = '',
    this.currentUserId = '',
  });

  final ChatSocialRepository social;
  final String conversationId;
  final bool video;
  final bool outgoing;
  final Map<String, dynamic>? incomingPayload;
  final String peerTitle;
  final String peerId;
  final String peerInitials;
  final String currentUserId;

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage>
    with SingleTickerProviderStateMixin {
  final _local = RTCVideoRenderer();
  final _remote = RTCVideoRenderer();
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  String? _callId;
  var _muted = false;
  var _cameraOff = false;
  var _speaker = false;
  var _more = false;
  var _mainShowsRemote = true;
  var _status = 'Calling...';
  var _connected = false;
  var _disposed = false;
  var _released = false;
  var _remoteDescriptionSet = false;
  var _renderersReady = false;
  String _pcState = 'new';
  String _iceState = 'new';
  String _iceGathering = 'new';
  DateTime? _connectedAt;
  Timer? _clock;
  late final AnimationController _pulse;
  StreamSubscription<Map<String, dynamic>>? _signals;
  final _pendingLocalIce = <RTCIceCandidate>[];
  final _pendingRemoteIce = <RTCIceCandidate>[];
  final _appliedRemoteIce = <int>{};
  final _diag = CallDiagnostics();
  final _sessionId = DateTime.now().microsecondsSinceEpoch.toString();
  Future<void> _signalGate = Future.value();
  Map<String, dynamic>? _pendingAnswer;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    if (!widget.outgoing) {
      _status = 'Connecting...';
    }
    _diag
      ..role = widget.outgoing ? 'caller' : 'callee'
      ..selfId = widget.currentUserId
      ..peerId = widget.peerId;
    _signals = widget.social.watchCallSignals().listen(_enqueueSignal);
    unawaited(_start());
  }

  @override
  void dispose() {
    _disposed = true;
    _clock?.cancel();
    _pulse.dispose();
    unawaited(_release());
    super.dispose();
  }

  String get _displayName {
    final title = widget.peerTitle.trim();
    if (title.isNotEmpty) {
      return title;
    }
    final fromPayload = widget.incomingPayload?['username'] as String?;
    if (fromPayload != null && fromPayload.trim().isNotEmpty) {
      return fromPayload.trim();
    }
    return 'Seyra';
  }

  String get _handle {
    final title = widget.peerTitle.trim();
    if (title.startsWith('@')) {
      return title;
    }
    if (title.isNotEmpty) {
      return '@$title';
    }
    return '';
  }

  String get _elapsed {
    final start = _connectedAt;
    if (start == null) {
      return '00:00';
    }
    final seconds = DateTime.now().difference(start).inSeconds;
    final mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  Future<void> _release({bool hangup = true}) async {
    if (_released) {
      return;
    }
    _released = true;
    _callLog('cleanup');
    final callId = _callId;
    _callId = null;
    if (hangup && callId != null) {
      await widget.social.signalCall(callId: callId, action: 'hangup');
    }
    if (callId != null) {
      widget.social.clearCallSignals(callId);
    }
    await _signals?.cancel();
    _signals = null;
    _pendingLocalIce.clear();
    _pendingRemoteIce.clear();
    try {
      await Helper.setSpeakerphoneOn(false);
    } catch (error) {
      _webrtcError('speaker', 'cleanup', error);
    }
    final remote = _remoteStream;
    _remoteStream = null;
    if (remote != null) {
      for (final track in remote.getTracks()) {
        await track.stop();
      }
      await remote.dispose();
    }
    _remote.srcObject = null;
    final stream = _localStream;
    _localStream = null;
    if (stream != null) {
      for (final track in stream.getTracks()) {
        await track.stop();
      }
      await stream.dispose();
    }
    _local.srcObject = null;
    final pc = _pc;
    _pc = null;
    await pc?.close();
    await pc?.dispose();
    await _local.dispose();
    await _remote.dispose();
  }

  Future<void> _start() async {
    try {
      await _local.initialize();
      await _remote.initialize();
    } catch (error) {
      _webrtcError('renderer.initialize', 'start', error);
      return;
    }
    _renderersReady = true;
    if (_disposed) {
      return;
    }
    _callLog('start', extra: widget.outgoing ? 'role=caller' : 'role=callee session=$_sessionId');
    _callLog(
      'identity',
      extra:
          'self=${_shortId(widget.currentUserId)} peer=${_shortId(widget.peerId)} caller=${widget.outgoing} callee=${!widget.outgoing}',
    );
    final runtime = await detectCallRuntime();
    _diag
      ..platform = runtime.platform
      ..environment = runtime.environment;
    _callLog(
      'runtime',
      extra:
          'platform=${runtime.platform} env=${runtime.environment} role=${_diag.role}',
    );
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      if (mounted) {
        setState(() => _status = 'Microphone permission denied');
      }
      return;
    }
    if (widget.video) {
      final cam = await Permission.camera.request();
      if (!cam.isGranted) {
        if (mounted) {
          setState(() => _status = 'Camera permission denied');
        }
        return;
      }
    }
    if (_disposed) {
      return;
    }
    final ice = await widget.social.iceServers();
    final raw = switch (ice) {
      Success(:final value) => normalizeIceServers(value.servers),
      FailureResult() => normalizeIceServers(const []),
    };
    final summary = iceServersForRuntime(
      raw,
      emulator: runtime.environment == 'emulator',
    );
    _diag
      ..stunConfigured = summary.stunConfigured
      ..turnConfigured = summary.turnConfigured
      ..iceServerCount = summary.servers.length;
    _callLog(
      'ice_servers',
      extra:
          'ice_servers_count=${summary.servers.length} stun=${summary.stunConfigured} turn=${summary.turnConfigured} emulator=${runtime.environment == 'emulator'}',
    );
    try {
      _pc = await createPeerConnection({
        'iceServers': summary.servers,
        'sdpSemantics': 'unified-plan',
        'bundlePolicy': 'max-bundle',
        'rtcpMuxPolicy': 'require',
      });
    } catch (error) {
      _webrtcError('create_peer_connection', 'start', error);
      if (mounted) {
        setState(() => _status = 'Connection failed');
      }
      return;
    }
    _pc!.onIceCandidate = (candidate) {
      if (candidate.candidate == null || candidate.candidate!.isEmpty) {
        return;
      }
      _diag.localIceGenerated++;
      _diag.countLocalKind(iceCandidateKind(candidate.candidate!));
      _diagTick();
      if (_callId == null) {
        _pendingLocalIce.add(candidate);
        _callLog('ice_local_queued', extra: 'n=${_diag.localIceGenerated}');
        return;
      }
      unawaited(_sendIce(candidate));
    };
    _pc!.onTrack = (event) {
      unawaited(_attachRemoteTrack(event));
    };
    _pc!.onRemoveTrack = (stream, track) {
      _callLog('track_removed', extra: 'kind=${track.kind}');
    };
    _pc!.onConnectionState = (state) {
      _pcState = state.toString();
      _diag.pcState = _pcState;
      _callLog('pc_state', extra: 'state=$_pcState');
      _applyMediaUi();
    };
    _pc!.onIceConnectionState = (state) {
      _iceState = state.toString();
      _diag.iceState = _iceState;
      final lower = _iceState.toLowerCase();
      if (lower.contains('checking')) {
        _diag.iceReachedChecking = true;
      }
      if (lower.contains('connected') || lower.contains('completed')) {
        _diag.iceReachedConnected = true;
      }
      _callLog('ice_connection', extra: 'state=$_iceState');
      if (lower.contains('failed')) {
        _callLog(
          'ice.failed_summary',
          extra: _diag.summary().replaceAll('\n', ' | '),
        );
      }
      _applyMediaUi();
    };
    _pc!.onIceGatheringState = (state) {
      _iceGathering = state.toString();
      _diag.gatherState = _iceGathering;
      _callLog('ice_gathering', extra: 'state=$_iceGathering');
      if (mounted) {
        setState(() {});
      }
    };
    _pc!.onSignalingState = (state) {
      _diag.sdpState = state.toString();
      _callLog('sdp_state', extra: 'state=${_diag.sdpState}');
      if (mounted) {
        setState(() {});
      }
    };
    try {
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': widget.video
            ? {
                'facingMode': 'user',
              }
            : false,
      });
    } catch (error) {
      _webrtcError('get_user_media', 'start', error);
      _diag.lastError = 'media.unavailable';
      if (mounted) {
        setState(() => _status = 'Camera or microphone unavailable');
      }
      return;
    }
    if (_disposed) {
      for (final track in _localStream!.getTracks()) {
        await track.stop();
      }
      await _localStream!.dispose();
      _localStream = null;
      return;
    }
    _local.srcObject = _localStream;
    for (final track in _localStream!.getTracks()) {
      try {
        await _pc!.addTrack(track, _localStream!);
      } catch (error) {
        _webrtcError('add_track', track.kind ?? 'media', error);
        continue;
      }
      if (track.kind == 'audio') {
        _diag.localAudio = true;
      }
      if (track.kind == 'video') {
        _diag.localVideo = true;
      }
      _callLog('track_local_added', extra: 'kind=${track.kind}');
    }
    _callLog(
      'media.local',
      extra:
          'local_audio_track=${_diag.localAudio} local_video_track=${_diag.localVideo}',
    );
    _speaker = widget.video;
    try {
      await Helper.setSpeakerphoneOn(_speaker);
    } catch (error) {
      _webrtcError('speaker', 'start', error);
    }
    if (widget.outgoing) {
      RTCSessionDescription offer;
      try {
        offer = await _pc!.createOffer(unifiedPlanSdpConstraints());
        _callLog('offer.created');
      } catch (error) {
        _webrtcError('create_offer', 'caller_offer', error);
        if (mounted) {
          setState(() => _status = 'Connection failed');
        }
        return;
      }
      try {
        await _pc!.setLocalDescription(offer);
      } catch (error) {
        _webrtcError('set_local_description', 'caller_offer', error);
        if (mounted) {
          setState(() => _status = 'Connection failed');
        }
        return;
      }
      _diag
        ..offerSent = true
        ..localOfferSet = true;
      _callLog('offer.local_description_set');
      final started = await widget.social.startCall(
        conversationId: widget.conversationId,
        kind: widget.video ? 'video' : 'voice',
        payload: {
          'sdp': offer.sdp,
          'type': webrtcSdpType(offer.type, 'offer'),
        },
      );
      if (started is Success<CallRecord>) {
        _callId = started.value.id;
        _diag.callId = _callId ?? '';
        _callLog('offer.sent');
        _callLog(
          'call_created',
          extra: 'caller=${_shortId(started.value.callerId)}',
        );
        await _flushLocalIce();
        await _applyPendingAnswer();
        await _applyBufferedSignals();
        if (mounted) {
          _applyMediaUi();
        }
      } else if (started is FailureResult<CallRecord> && mounted) {
        _callLog('offer.send_failed');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(started.failure.message)),
        );
      }
    } else {
      final payload = widget.incomingPayload ?? const {};
      _callId = signalId(payload['call_id']);
      if (_callId!.isEmpty) {
        _callId = null;
      }
      _diag
        ..callId = _callId ?? ''
        ..offerReceived = true
        ..peerId = signalId(payload['caller_id']).isEmpty
            ? widget.peerId
            : signalId(payload['caller_id']);
      _callLog(
        'offer.received',
        extra:
            'from=${_shortId(_diag.peerId)} current=${_shortId(widget.currentUserId)} caller=false callee=true accepted=yes parsed=yes',
      );
      final sdp = payload['sdp'] as String?;
      final type = webrtcSdpType(payload['type'], 'offer');
      if (sdp != null) {
        try {
          await _pc!.setRemoteDescription(RTCSessionDescription(sdp, type));
          _remoteDescriptionSet = true;
          _diag
            ..remoteDescApplied = true
            ..remoteOfferSet = true;
          _callLog('offer.remote_description_set');
        } catch (error) {
          _webrtcError('set_remote_description', 'callee_offer', error);
          if (mounted) {
            setState(() => _status = 'Connection failed');
          }
          return;
        }
        await _flushRemoteIce();
        RTCSessionDescription answer;
        try {
          answer = await _pc!.createAnswer(unifiedPlanSdpConstraints());
          _callLog('answer.created');
        } catch (error) {
          _webrtcError('create_answer', 'callee_answer', error);
          if (mounted) {
            setState(() => _status = 'Connection failed');
          }
          return;
        }
        try {
          await _pc!.setLocalDescription(answer);
        } catch (error) {
          _webrtcError('set_local_description', 'callee_answer', error);
          if (mounted) {
            setState(() => _status = 'Connection failed');
          }
          return;
        }
        _diag
          ..answerSent = true
          ..localAnswerSet = true;
        _callLog('answer.local_description_set');
        if (_callId != null) {
          await widget.social.signalCall(
            callId: _callId!,
            action: 'answer',
            payload: {
              'sdp': answer.sdp,
              'type': webrtcSdpType(answer.type, 'answer'),
            },
          );
          _callLog('answer.sent');
          await _flushLocalIce();
          await _applyBufferedSignals();
        }
      } else {
        _callLog('offer.missing_sdp', extra: 'parsed=no accepted=no');
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _attachRemoteTrack(RTCTrackEvent event) async {
    if (_disposed || _released) {
      return;
    }
    _callLog('track_added', extra: 'kind=${event.track.kind}');
    if (event.track.kind == 'audio') {
      _diag.remoteAudio = true;
    }
    if (event.track.kind == 'video') {
      _diag.remoteVideo = true;
    }
    try {
      event.track.enabled = true;
    } catch (error) {
      _webrtcError('remote_track_enable', event.track.kind ?? 'media', error);
    }
    MediaStream? stream = event.streams.isNotEmpty ? event.streams.first : null;
    if (stream == null) {
      _remoteStream ??= await createLocalMediaStream('remote');
      await _remoteStream!.addTrack(event.track);
      stream = _remoteStream;
    } else {
      _remoteStream = stream;
    }
    _remote.srcObject = stream;
    if (event.track.kind == 'audio') {
      try {
        await Helper.setSpeakerphoneOn(_speaker || widget.video);
      } catch (error) {
        _webrtcError('speaker', 'remote_audio', error);
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _applyMediaUi() {
    if (_disposed || !mounted) {
      return;
    }
    if (_status.contains('denied') || _status.contains('unavailable')) {
      return;
    }
    final ui = describeCallMedia(
      peerConnectionState: _pcState,
      iceConnectionState: _iceState,
      outgoing: widget.outgoing,
    );
    if (ui.live && !_connected) {
      _connectedAt ??= DateTime.now();
      _clock ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
    setState(() {
      _connected = ui.live;
      _status = ui.label;
    });
  }

  void _webrtcError(String operation, String stage, Object error) {
    final category = webrtcErrorCategory(error);
    _diag.lastError = operation;
    _callLog(
      'webrtc.error',
      extra: 'operation=$operation stage=$stage error_type=$category',
    );
  }

  void _enqueueSignal(Map<String, dynamic> payload) {
    _signalGate = _signalGate.then((_) async {
      if (_disposed) {
        return;
      }
      await _onSignal(payload);
    }).catchError((Object error) {
      _webrtcError('signal.queue', 'receive', error);
    });
  }

  Future<void> _applyPendingAnswer() async {
    final pending = _pendingAnswer;
    _pendingAnswer = null;
    if (pending != null) {
      await _onSignal(pending);
    }
  }

  void _diagTick() {
    if (mounted) {
      setState(() {});
    }
  }

  String _shortId(String value) {
    if (value.length <= 12) {
      return value.isEmpty ? '-' : value;
    }
    return value.substring(0, 12);
  }

  void _callLog(String event, {String extra = ''}) {
    if (!kDebugMode) {
      return;
    }
    final parts = <String>[
      'seyra.call',
      event,
      'call_id=${_callId ?? '-'}',
    ];
    if (extra.isNotEmpty) {
      parts.add(extra);
    }
    debugPrint(parts.join(' '));
  }

  Future<void> _sendIce(RTCIceCandidate candidate) async {
    final callId = _callId;
    if (callId == null || candidate.candidate == null) {
      return;
    }
    _callLog('ice_local_send', extra: 'n=${_diag.localIceGenerated}');
    final result = await widget.social.signalCall(
      callId: callId,
      action: 'ice',
      payload: {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      },
    );
    if (result is FailureResult<void>) {
      _diag.localIceSendFailed++;
      _diag.lastError = 'ice.send_failed';
      _callLog('webrtc.ice.send_failed');
      return;
    }
    _diag.localIceSent++;
    _diagTick();
  }

  Future<void> _flushLocalIce() async {
    final pending = List<RTCIceCandidate>.from(_pendingLocalIce);
    _pendingLocalIce.clear();
    for (final candidate in pending) {
      await _sendIce(candidate);
    }
  }

  Future<void> _flushRemoteIce() async {
    if (!_remoteDescriptionSet || _pc == null) {
      return;
    }
    final pending = List<RTCIceCandidate>.from(_pendingRemoteIce);
    _pendingRemoteIce.clear();
    _callLog('ice_remote_flush', extra: 'count=${pending.length}');
    for (final candidate in pending) {
      await _addRemoteIce(candidate, index: _diag.remoteIceApplied);
    }
  }

  Future<void> _addRemoteIce(RTCIceCandidate ice, {required int index}) async {
    if (ice.sdpMid == null && ice.sdpMLineIndex == null) {
      _diag.remoteIceFailed++;
      _callLog(
        'ice.add_failed',
        extra:
            'stage=apply candidate_index=$index error_category=missing_mid_and_index',
      );
      _diagTick();
      return;
    }
    final key = Object.hash(ice.candidate, ice.sdpMid, ice.sdpMLineIndex);
    if (_appliedRemoteIce.contains(key)) {
      return;
    }
    try {
      await _pc?.addCandidate(
        RTCIceCandidate(
          ice.candidate,
          ice.sdpMid,
          ice.sdpMLineIndex ?? 0,
        ),
      );
      _appliedRemoteIce.add(key);
      _diag.remoteIceApplied++;
      _diagTick();
    } catch (error) {
      _diag.remoteIceFailed++;
      _diag.lastError = 'ice.add_failed';
      _callLog(
        'ice.add_failed',
        extra:
            'stage=apply candidate_index=$index error_category=${webrtcErrorCategory(error)}',
      );
      _diagTick();
    }
  }

  Future<void> _applyBufferedSignals() async {
    final callId = _callId;
    if (callId == null) {
      return;
    }
    for (final payload in widget.social.bufferedCallSignals(callId)) {
      await _onSignal(payload);
    }
  }

  Future<void> _onSignal(Map<String, dynamic> payload) async {
    if (_disposed) {
      return;
    }
    final action = signalId(payload['action']);
    final fromId = signalId(payload['from_id']);
    final callerId = signalId(payload['caller_id']);
    final callId = signalId(payload['call_id']);
    _callLog(
      'signal.receive',
      extra:
          'type=$action from=${_shortId(fromId.isEmpty ? callerId : fromId)} current=${_shortId(widget.currentUserId)} caller=${widget.outgoing} callee=${!widget.outgoing} page_call=${_callId ?? '-'} signal_call=${callId.isEmpty ? '-' : callId} parsed=yes',
    );
    if (!isPeerCallSignal(payload, widget.currentUserId)) {
      _callLog('signal.filtered', extra: 'reason=self_echo type=$action accepted=no');
      return;
    }
    if (_callId != null && callId.isNotEmpty && callId != _callId) {
      _callLog(
        'signal.filtered',
        extra: 'reason=call_id page=${_callId ?? '-'} signal=$callId accepted=no',
      );
      return;
    }
    try {
      if (action == 'answer') {
        _diag.answerReceived = true;
        _callLog(
          'answer.received',
          extra: 'from=${_shortId(fromId)} parsed=yes',
        );
        if (_pc == null) {
          _pendingAnswer = payload;
          _callLog('answer.queued', extra: 'accepted=queued parsed=yes');
          return;
        }
        if (_remoteDescriptionSet) {
          _callLog('answer.ignored', extra: 'reason=remote_already_set accepted=no');
          _diagTick();
          return;
        }
        final sdp = payload['sdp'] as String?;
        if (sdp == null) {
          _diag.lastError = 'sdp.answer_missing';
          _callLog('answer.missing_sdp', extra: 'parsed=no accepted=no');
          return;
        }
        try {
          await _pc?.setRemoteDescription(
            RTCSessionDescription(sdp, webrtcSdpType(payload['type'], 'answer')),
          );
          _remoteDescriptionSet = true;
          _diag
            ..remoteDescApplied = true
            ..remoteAnswerSet = true;
          _callLog('answer.remote_description_set');
        } catch (error) {
          _webrtcError('set_remote_description', 'caller_answer', error);
          return;
        }
        await _flushRemoteIce();
        _diagTick();
      } else if (action == 'ice') {
        final parsed = parseRemoteIce(payload);
        if (parsed == null) {
          _diag.remoteIceFailed++;
          _callLog(
            'ice.add_failed',
            extra:
                'stage=parse candidate_index=${_diag.remoteIceReceived} error_category=missing_candidate parsed=no accepted=no',
          );
          return;
        }
        _diag.remoteIceReceived++;
        _diag.countRemoteKind(parsed.kind);
        final ice = RTCIceCandidate(
          parsed.candidate,
          parsed.sdpMid,
          parsed.sdpMLineIndex,
        );
        if (!_remoteDescriptionSet || _pc == null) {
          _pendingRemoteIce.add(ice);
          _diag.remoteIceQueued++;
          _callLog(
            'ice.remote_queued',
            extra:
                'received=${_diag.remoteIceReceived} queued=${_diag.remoteIceQueued} accepted=queued parsed=yes',
          );
          _diagTick();
          return;
        }
        _callLog(
          'ice.remote_apply',
          extra: 'received=${_diag.remoteIceReceived} accepted=yes parsed=yes',
        );
        await _addRemoteIce(ice, index: _diag.remoteIceReceived);
      } else if (action == 'reject' || action == 'hangup' || action == 'missed') {
        _callLog('signaling', extra: 'signaling=$action accepted=yes');
        _callId = null;
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (error) {
      _webrtcError('signal.handler', action, error);
    }
  }

  Future<void> _hangup() async {
    await _release(hangup: true);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _toggleSpeaker() async {
    _speaker = !_speaker;
    _callLog('speaker', extra: 'on=$_speaker');
    try {
      await Helper.setSpeakerphoneOn(_speaker);
    } catch (error) {
      _webrtcError('speaker', 'toggle', error);
    }
    if (mounted) {
      setState(() {});
    }
  }

  RTCVideoRenderer get _mainRenderer =>
      _mainShowsRemote ? _remote : _local;

  RTCVideoRenderer get _pipRenderer =>
      _mainShowsRemote ? _local : _remote;

  bool get _mainMirrored => !_mainShowsRemote;

  bool get _pipMirrored => _mainShowsRemote;

  void _swapCameraView() {
    if (!widget.video) {
      return;
    }
    setState(() => _mainShowsRemote = !_mainShowsRemote);
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF070B14);
    final videoLive = widget.video && _renderersReady && !_released;
    final failed = !_connected && _status == 'Connection failed';
    return Scaffold(
      backgroundColor: navy,
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) < -240) {
            setState(() => _more = true);
          } else if ((details.primaryVelocity ?? 0) > 240) {
            setState(() => _more = false);
          }
        },
        child: Stack(
          children: [
            const Positioned(
              top: -80,
              left: -60,
              child: _GlowBlob(color: Color(0xFF3B4FD4), size: 280),
            ),
            const Positioned(
              bottom: 40,
              right: -90,
              child: _GlowBlob(color: Color(0xFF6B3CC9), size: 320),
            ),
            if (videoLive)
              Positioned.fill(
                child: RTCVideoView(
                  _mainRenderer,
                  mirror: _mainMirrored,
                  objectFit:
                      RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              ),
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  _StatusPill(
                    live: _connected,
                    label: _status,
                  ),
                  const Spacer(),
                  if (!widget.video) ...[
                    _PulseAvatar(
                      pulse: _pulse,
                      peerId: widget.peerId,
                      initials: widget.peerInitials.isEmpty
                          ? _displayName
                          : widget.peerInitials,
                    ),
                    const SizedBox(height: 28),
                    Text(
                      _displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (_handle.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        _handle,
                        style: const TextStyle(
                          color: Color(0xFF9AA3B5),
                          fontSize: 16,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      _elapsed,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _ConnectionChip(
                      good: _connected,
                      failed: failed,
                      peerName: _displayName,
                    ),
                  ],
                  if (widget.video)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: _ConnectionChip(
                          good: _connected,
                          failed: failed,
                          peerName: _displayName,
                        ),
                      ),
                    ),
                  if (widget.video)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 16, 0),
                        child: Text(
                          _elapsed,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  const Spacer(),
                  if (_more) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.video)
                          _RoundControl(
                            icon: _cameraOff
                                ? Icons.videocam_off
                                : Icons.videocam,
                            label: 'Camera',
                            onTap: () {
                              _cameraOff = !_cameraOff;
                              _localStream?.getVideoTracks().forEach((track) {
                                track.enabled = !_cameraOff;
                              });
                              _callLog(
                                'camera',
                                extra: 'enabled=${!_cameraOff}',
                              );
                              setState(() {});
                            },
                          ),
                      ],
                    ),
                    if (kDebugMode) ...[
                      const SizedBox(height: 12),
                      _CallDebugPanel(text: _diag.summary()),
                    ],
                    if (widget.video && !_diag.remoteVideo) ...[
                      const SizedBox(height: 12),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          'If you don’t see the other camera, make sure both you and the other person have camera permission enabled in the app settings and the device settings.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFB8B4E8),
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _RoundControl(
                          icon: _muted ? Icons.mic_off : Icons.mic,
                          label: 'Mute',
                          onTap: () {
                            _muted = !_muted;
                            _localStream?.getAudioTracks().forEach((track) {
                              track.enabled = !_muted;
                            });
                            _callLog('mute', extra: 'muted=$_muted');
                            setState(() {});
                          },
                        ),
                        _EndCallButton(onTap: _hangup),
                        _RoundControl(
                          icon: _speaker
                              ? Icons.volume_up
                              : Icons.volume_up_outlined,
                          label: 'Speaker',
                          onTap: _toggleSpeaker,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  GestureDetector(
                    onTap: () => setState(() => _more = !_more),
                    child: Column(
                      children: [
                        Icon(
                          _more
                              ? Icons.keyboard_arrow_down
                              : Icons.keyboard_arrow_up,
                          color: const Color(0xFF8B93A7),
                        ),
                        Text(
                          _more ? 'Hide extras' : 'Swipe up for more',
                          style: const TextStyle(
                            color: Color(0xFF8B93A7),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            if (videoLive)
              Positioned(
                top: MediaQuery.paddingOf(context).top + 52,
                right: 16,
                child: GestureDetector(
                  onTap: _swapCameraView,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      width: 108,
                      height: 148,
                      child: RTCVideoView(
                        _pipRenderer,
                        mirror: _pipMirrored,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CallDebugPanel extends StatelessWidget {
  const _CallDebugPanel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 180),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFB8F5C4)),
        ),
        child: SingleChildScrollView(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFFB8F5C4),
              fontSize: 11,
              height: 1.3,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 48, sigmaY: 48),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.live, required this.label});

  final bool live;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: live ? const Color(0xFF3DDC84) : const Color(0xFF9AA3B5),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }
}

class _ConnectionChip extends StatelessWidget {
  const _ConnectionChip({
    required this.good,
    required this.failed,
    required this.peerName,
  });

  final bool good;
  final bool failed;
  final String peerName;

  @override
  Widget build(BuildContext context) {
    final label = good
        ? peerName
        : failed
            ? 'Connection failed'
            : 'Connecting';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.signal_cellular_alt,
            size: 16,
            color: good ? const Color(0xFF5B8CFF) : const Color(0xFF9AA3B5),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _PulseAvatar extends StatelessWidget {
  const _PulseAvatar({
    required this.pulse,
    required this.peerId,
    required this.initials,
  });

  final Animation<double> pulse;
  final String peerId;
  final String initials;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 220,
      child: AnimatedBuilder(
        animation: pulse,
        builder: (context, child) {
          return CustomPaint(
            painter: _RingPainter(pulse.value),
            child: Center(child: child),
          );
        },
        child: Container(
          width: 128,
          height: 128,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFD7E0FF), Color(0xFF8B86FF)],
            ),
          ),
          child: peerId.isEmpty
              ? const Icon(Icons.person, size: 72, color: Colors.white)
              : Center(
                  child: UserAvatar(
                    userId: peerId,
                    initials: initials,
                    radius: 62,
                    hasAvatar: true,
                  ),
                ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (var i = 0; i < 3; i++) {
      final progress = (t + i / 3) % 1.0;
      final radius = 58 + progress * 48;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF6EA8FF).withValues(alpha: (1 - progress) * 0.45);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) => oldDelegate.t != t;
}

class _RoundControl extends StatelessWidget {
  const _RoundControl({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: const Color(0xFF2A3140),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 64,
              height: 64,
              child: Icon(icon, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
      ],
    );
  }
}

class _EndCallButton extends StatelessWidget {
  const _EndCallButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFE53935),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 76,
          height: 76,
          child: Icon(Icons.call_end, color: Colors.white, size: 32),
        ),
      ),
    );
  }
}
