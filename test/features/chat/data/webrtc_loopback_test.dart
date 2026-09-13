import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:seyra/features/chat/data/models/call_signaling.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('two local peer connections connect over in-memory signaling', () async {
    late RTCPeerConnection a;
    late RTCPeerConnection b;
    try {
      a = await createPeerConnection({
        'iceServers': [
          {
            'urls': ['stun:stun.l.google.com:19302'],
          },
        ],
        'sdpSemantics': 'unified-plan',
      });
      b = await createPeerConnection({
        'iceServers': [
          {
            'urls': ['stun:stun.l.google.com:19302'],
          },
        ],
        'sdpSemantics': 'unified-plan',
      });
    } on MissingPluginException {
      markTestSkipped('flutter_webrtc native plugin is unavailable on the VM');
      return;
    }

    final pendingA = <RTCIceCandidate>[];
    final pendingB = <RTCIceCandidate>[];
    var iceA = '';
    var iceB = '';
    final connected = Completer<void>();

    Future<void> applyIce(RTCPeerConnection pc, RTCIceCandidate ice) async {
      await pc.addCandidate(ice);
    }

    var aRemoteReady = false;
    a.onIceCandidate = (candidate) {
      if (candidate.candidate == null || candidate.candidate!.isEmpty) {
        return;
      }
      pendingB.add(candidate);
    };
    b.onIceCandidate = (candidate) {
      if (candidate.candidate == null || candidate.candidate!.isEmpty) {
        return;
      }
      if (aRemoteReady) {
        unawaited(applyIce(a, candidate));
      } else {
        pendingA.add(candidate);
      }
    };
    a.onIceConnectionState = (state) {
      iceA = state.toString();
      if (iceA.toLowerCase().contains('connected') ||
          iceA.toLowerCase().contains('completed')) {
        if (!connected.isCompleted) {
          connected.complete();
        }
      }
    };
    b.onIceConnectionState = (state) {
      iceB = state.toString();
      if (iceB.toLowerCase().contains('connected') ||
          iceB.toLowerCase().contains('completed')) {
        if (!connected.isCompleted) {
          connected.complete();
        }
      }
    };

    await a.addTransceiver(
      kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
      init: RTCRtpTransceiverInit(direction: TransceiverDirection.SendRecv),
    );
    await b.addTransceiver(
      kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
      init: RTCRtpTransceiverInit(direction: TransceiverDirection.SendRecv),
    );

    final offer = await a.createOffer(unifiedPlanSdpConstraints());
    await a.setLocalDescription(offer);
    await b.setRemoteDescription(offer);
    for (final ice in List<RTCIceCandidate>.from(pendingB)) {
      await applyIce(b, ice);
    }
    pendingB.clear();
    final answer = await b.createAnswer(unifiedPlanSdpConstraints());
    await b.setLocalDescription(answer);
    await a.setRemoteDescription(answer);
    aRemoteReady = true;
    for (final ice in List<RTCIceCandidate>.from(pendingA)) {
      await applyIce(a, ice);
    }
    pendingA.clear();
    a.onIceCandidate = (candidate) {
      if (candidate.candidate == null || candidate.candidate!.isEmpty) {
        return;
      }
      unawaited(applyIce(b, candidate));
    };

    await connected.future.timeout(const Duration(seconds: 15));
    expect(iceA.toLowerCase().contains('failed'), isFalse);
    expect(iceB.toLowerCase().contains('failed'), isFalse);

    await a.close();
    await b.close();
    await a.dispose();
    await b.dispose();
  });
}
