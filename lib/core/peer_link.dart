import 'dart:async';
import 'dart:convert';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'protocol.dart';

enum LinkState { connecting, connected, degraded, lost }

/// Uma conexão WebRTC de áudio com um piloto, mais o canal de controle
/// (heartbeat a cada 500 ms) usado para detectar perda de link rapidamente.
class PeerLink {
  PeerLink({
    required this.remoteId,
    required this.sid,
    required this.bitrate,
    required this.sendSignal,
  });

  final String remoteId;

  /// Identifica esta tentativa de conexão; sinais de tentativas antigas são ignorados.
  final String sid;
  final int bitrate;
  final void Function(Map<String, dynamic>) sendSignal;

  final created = DateTime.now();
  RTCPeerConnection? pc;
  RTCDataChannel? _ctl;
  MediaStreamTrack? remoteTrack;
  DateTime? lastSeen;
  bool remoteTx = false;
  bool remoteMuted = false;
  double remoteLevel = 0;
  int _seq = 0;
  int _lastRemoteSeq = -1;
  int _received = 0;
  int _expected = 0;

  final _pending = <RTCIceCandidate>[];
  bool _remoteSet = false;
  bool _disposed = false;
  late final Future<void> ready;

  void start(MediaStream local) {
    ready = _open(local);
  }

  Future<void> _open(MediaStream local) async {
    final conn = await createPeerConnection({
      'iceServers': <dynamic>[],
      'sdpSemantics': 'unified-plan',
    });
    if (_disposed) {
      await conn.close();
      return;
    }
    pc = conn;
    for (final t in local.getAudioTracks()) {
      await conn.addTrack(t, local);
    }
    conn.onIceCandidate = (c) {
      final cand = c.candidate;
      if (cand == null || cand.isEmpty) return;
      sendSignal({'t': 'candidate', 'to': remoteId, 'sid': sid, 'cand': c.toMap()});
    };
    conn.onTrack = (e) {
      if (e.track.kind == 'audio') remoteTrack = e.track;
    };
    final init = RTCDataChannelInit()
      ..negotiated = true
      ..id = 0
      ..ordered = false
      ..maxRetransmits = 0;
    final ch = await conn.createDataChannel('ctl', init);
    _ctl = ch;
    ch.onMessage = (m) {
      if (m.isBinary) return;
      try {
        final j = jsonDecode(m.text) as Map;
        lastSeen = DateTime.now();
        remoteTx = j['tx'] == true;
        remoteMuted = j['muted'] == true;
        final seq = (j['seq'] as num?)?.toInt() ?? 0;
        if (_lastRemoteSeq >= 0 && seq > _lastRemoteSeq) {
          _expected += seq - _lastRemoteSeq;
          _received += 1;
        }
        _lastRemoteSeq = seq;
      } catch (_) {}
    };
  }

  Future<void> makeOffer() async {
    await ready;
    final conn = pc;
    if (conn == null) return;
    final offer = await conn.createOffer({});
    await conn.setLocalDescription(offer);
    sendSignal({'t': 'offer', 'to': remoteId, 'sid': sid, 'sdp': offer.sdp});
  }

  Future<void> onOffer(String sdp) async {
    await ready;
    final conn = pc;
    if (conn == null) return;
    await conn.setRemoteDescription(RTCSessionDescription(tuneOpus(sdp, bitrate), 'offer'));
    await _flushCandidates();
    final answer = await conn.createAnswer({});
    await conn.setLocalDescription(answer);
    sendSignal({'t': 'answer', 'to': remoteId, 'sid': sid, 'sdp': answer.sdp});
  }

  Future<void> onAnswer(String sdp) async {
    await ready;
    final conn = pc;
    if (conn == null) return;
    await conn.setRemoteDescription(RTCSessionDescription(tuneOpus(sdp, bitrate), 'answer'));
    await _flushCandidates();
  }

  Future<void> onCandidate(Map<String, dynamic> cand) async {
    final c = RTCIceCandidate(
      cand['candidate'] as String?,
      cand['sdpMid'] as String?,
      (cand['sdpMLineIndex'] as num?)?.toInt(),
    );
    if (!_remoteSet) {
      _pending.add(c);
      return;
    }
    try {
      await pc?.addCandidate(c);
    } catch (_) {}
  }

  Future<void> _flushCandidates() async {
    _remoteSet = true;
    for (final c in List.of(_pending)) {
      try {
        await pc?.addCandidate(c);
      } catch (_) {}
    }
    _pending.clear();
  }

  void heartbeat({required bool tx, required bool muted}) {
    final ch = _ctl;
    if (ch == null || ch.state != RTCDataChannelState.RTCDataChannelOpen) return;
    try {
      ch.send(RTCDataChannelMessage(jsonEncode({'seq': _seq++, 'tx': tx, 'muted': muted})));
    } catch (_) {}
  }

  LinkState get state {
    final seen = lastSeen;
    final now = DateTime.now();
    if (seen == null) {
      return now.difference(created).inSeconds < 8 ? LinkState.connecting : LinkState.lost;
    }
    final ms = now.difference(seen).inMilliseconds;
    if (ms < 1500) return LinkState.connected;
    if (ms < 4000) return LinkState.degraded;
    return LinkState.lost;
  }

  /// Qualidade de 0 a 4 pela fração de heartbeats que chegaram na última janela.
  int takeQuality() {
    final s = state;
    if (s == LinkState.lost || s == LinkState.connecting) return 0;
    if (s == LinkState.degraded) return 1;
    final ratio = _expected == 0 ? 1.0 : _received / _expected;
    _received = 0;
    _expected = 0;
    if (ratio > 0.97) return 4;
    if (ratio > 0.88) return 3;
    if (ratio > 0.7) return 2;
    return 1;
  }

  Future<void> dispose() async {
    _disposed = true;
    try {
      await _ctl?.close();
    } catch (_) {}
    try {
      await pc?.close();
    } catch (_) {}
    pc = null;
  }
}
