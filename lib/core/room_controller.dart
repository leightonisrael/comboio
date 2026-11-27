import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'discovery.dart';
import 'feedback_service.dart';
import 'peer_link.dart';
import 'platform_bridge.dart';
import 'protocol.dart';
import 'settings_store.dart';
import 'signaling_client.dart';
import 'signaling_host.dart';

enum RoomPhase { idle, starting, active, reconnecting }

/// O que a tela mostra de cada piloto remoto.
class PilotView {
  PilotView(this.info);

  PeerInfo info;
  LinkState state = LinkState.connecting;
  double level = 0;
  bool talking = false;
  bool muted = false;
  int quality = 0;
  bool everConnected = false;
  DateTime? lostSince;
}

/// Orquestra a sala: sinalização, conexões de áudio, VOX/PTT, reconexão e avisos.
class RoomController extends ChangeNotifier {
  RoomController(this.settings, this.feedback, this.platform);

  final Settings settings;
  final FeedbackService feedback;
  final PlatformBridge platform;

  RoomPhase phase = RoomPhase.idle;
  bool isHost = false;
  String roomName = '';
  String pin = '';
  String? hostIp;
  String? hostId;

  /// Mensagem para a Home depois que a sala termina por causa externa.
  String? endReason;

  final pilots = <String, PilotView>{};
  List<String> localIps = const [];

  bool muted = false;

  /// Fone mudo: para de ouvir os outros pilotos sem sair da sala.
  bool deafened = false;

  /// Áudio saindo pelo alto-falante do celular em vez do capacete.
  bool speaker = false;
  bool pttDown = false;
  bool transmitting = false;
  double localLevel = 0;
  double volume = 1.0;
  HelmetStatus helmet = const HelmetStatus.unknown();

  final _links = <String, PeerLink>{};
  final _lastOffer = <String, DateTime>{};
  Signaling? _sig;
  StreamSubscription<Map<String, dynamic>>? _sub;
  MediaStream? _local;
  Timer? _tick;
  Timer? _stats;
  int _ticks = 0;
  bool _statsBusy = false;
  DateTime _voxHold = DateTime.fromMillisecondsSinceEpoch(0);
  int _session = 0;

  PeerInfo get _self => PeerInfo(
    id: settings.peerId,
    name: settings.name,
    color: settings.colorIndex,
  );

  TalkMode get mode => settings.mode;
  bool get inRoom => phase != RoomPhase.idle;

  // ---------------------------------------------------------------- entrada

  Future<void> createRoom() async {
    if (inRoom) return;
    final session = ++_session;
    phase = RoomPhase.starting;
    endReason = null;
    isHost = true;
    roomName = 'Sala de ${settings.name}';
    pin = settings.pin;
    hostId = settings.peerId;
    notifyListeners();
    try {
      await _startMedia();
      final host = SignalingHost(self: _self, pin: pin, roomName: roomName);
      await host.start();
      if (session != _session) {
        await host.close();
        return;
      }
      _attach(host);
      localIps = (await localAddresses()).map((a) => a.address).toList();
      phase = RoomPhase.active;
      notifyListeners();
      feedback.say('Sala criada');
    } catch (e) {
      await _teardown();
      endReason = 'Não foi possível criar a sala. ${_describe(e)}';
      notifyListeners();
    }
  }

  /// Retorna null em caso de sucesso, ou o erro para a tela tratar.
  Future<JoinError?> joinRoom(
    String ip,
    String pinCode, {
    String? knownHostId,
  }) async {
    if (inRoom) return null;
    final session = ++_session;
    phase = RoomPhase.starting;
    endReason = null;
    isHost = false;
    hostIp = ip;
    hostId = knownHostId;
    pin = pinCode;
    notifyListeners();
    try {
      final client = await SignalingClient.connect(
        host: ip,
        self: _self,
        pin: pinCode,
      );
      if (session != _session) {
        await client.close();
        return null;
      }
      await _startMedia();
      roomName = client.roomName;
      _attach(client);
      phase = RoomPhase.active;
      for (final p in client.peers) {
        _addPeer(p);
      }
      if (client.peers.isNotEmpty) hostId ??= client.peers.first.id;
      if (hostId != null) settings.rememberPin(hostId!, pinCode);
      notifyListeners();
      return null;
    } on JoinError catch (e) {
      await _teardown();
      notifyListeners();
      return e;
    } catch (e) {
      await _teardown();
      notifyListeners();
      return JoinError(_isMicError(e) ? 'mic' : 'network');
    }
  }

  bool _isMicError(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('permission') ||
        s.contains('notallowed') ||
        s.contains('getusermedia');
  }

  Future<void> leave({String? reason}) async {
    if (!inRoom) return;
    _session++;
    _sig?.send({'t': isHost ? 'room-closed' : 'bye'});
    // Dá tempo de o aviso sair antes de fechar o socket.
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await _teardown();
    endReason = reason;
    notifyListeners();
  }

  // ------------------------------------------------------------------ mídia

  Future<void> _startMedia() async {
    await platform.startBackground(
      roomName.isEmpty ? 'Conversa ativa' : roomName,
    );
    await platform.configureAudio();
    _local = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
        'googHighpassFilter': true,
      },
      'video': false,
    });
    await platform.routeToHelmet();
    await platform.keepScreenOn(settings.keepScreenOn);
    muted = false;
    deafened = false;
    speaker = false;
    pttDown = false;
    _applyGate(force: true);
  }

  void _attach(Signaling sig) {
    _sub?.cancel();
    _sig = sig;
    _sub = sig.messages.listen(_onMessage);
    _tick ??= Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => _onTick(),
    );
    _stats ??= Timer.periodic(
      const Duration(milliseconds: 120),
      (_) => _pollStats(),
    );
  }

  Future<void> _teardown() async {
    _tick?.cancel();
    _tick = null;
    _stats?.cancel();
    _stats = null;
    await _sub?.cancel();
    _sub = null;
    final sig = _sig;
    _sig = null;
    for (final l in _links.values.toList()) {
      await l.dispose();
    }
    _links.clear();
    _lastOffer.clear();
    pilots.clear();
    try {
      await sig?.close();
    } catch (_) {}
    final local = _local;
    _local = null;
    if (local != null) {
      for (final t in local.getTracks()) {
        try {
          await t.stop();
        } catch (_) {}
      }
      try {
        await local.dispose();
      } catch (_) {}
    }
    await platform.keepScreenOn(false);
    await platform.stopBackground();
    phase = RoomPhase.idle;
    transmitting = false;
    localLevel = 0;
    isHost = false;
  }

  // ----------------------------------------------------------- sinalização

  void _onMessage(Map<String, dynamic> m) {
    final from = m['from'] as String?;
    switch (m['t']) {
      case 'peer-joined':
        _addPeer(
          PeerInfo.fromJson(Map<String, dynamic>.from(m['peer'] as Map)),
        );
      case 'peer-left':
        final id = '${m['id']}';
        if (m['reason'] == 'bye') {
          final gone = pilots.remove(id);
          _links.remove(id)?.dispose();
          _lastOffer.remove(id);
          if (gone != null) feedback.say('${gone.info.name} saiu da sala');
        }
      // Queda sem aviso: o heartbeat decide quando marcar como fora do alcance.
      case 'offer':
        if (from != null) _onOffer(from, m);
      case 'answer':
        final link = _links[from];
        if (link != null && link.sid == m['sid']) {
          link.onAnswer('${m['sdp']}').catchError((_) {});
        }
      case 'candidate':
        final link = _links[from];
        if (link != null && link.sid == m['sid']) {
          link.onCandidate(Map<String, dynamic>.from(m['cand'] as Map));
        }
      case 'room-closed':
        leave(reason: 'O host encerrou a sala.');
        feedback.say('Sala encerrada', strong: true);
        return;
      case '_closed':
        if (!isHost && phase == RoomPhase.active) {
          phase = RoomPhase.reconnecting;
          _reconnectLoop(_session);
        }
    }
    notifyListeners();
  }

  void _addPeer(PeerInfo info) {
    if (info.id == settings.peerId) return;
    final view = pilots.putIfAbsent(info.id, () => PilotView(info));
    view.info = info;
    if (_isOfferer(info.id)) _startOffer(info.id);
  }

  /// Entre dois pilotos, quem tem o id menor envia a oferta.
  bool _isOfferer(String remoteId) => settings.peerId.compareTo(remoteId) < 0;

  PeerLink _newLink(String remoteId, String sid) {
    _links.remove(remoteId)?.dispose();
    final link = PeerLink(
      remoteId: remoteId,
      sid: sid,
      bitrate: settings.bitrate,
      sendSignal: (msg) => _sig?.send(msg),
    );
    _links[remoteId] = link;
    link.start(_local!);
    return link;
  }

  void _startOffer(String remoteId) {
    if (_local == null) return;
    _lastOffer[remoteId] = DateTime.now();
    _newLink(remoteId, randomHex(4)).makeOffer().catchError((_) {});
  }

  void _onOffer(String from, Map<String, dynamic> m) {
    if (_local == null) return;
    pilots.putIfAbsent(
      from,
      () => PilotView(PeerInfo(id: from, name: 'Piloto', color: 0)),
    );
    _newLink(from, '${m['sid']}').onOffer('${m['sdp']}').catchError((_) {});
  }

  Future<void> _reconnectLoop(int session) async {
    var attempt = 0;
    while (session == _session && phase == RoomPhase.reconnecting) {
      try {
        final client = await SignalingClient.connect(
          host: hostIp!,
          self: _self,
          pin: pin,
          timeout: const Duration(milliseconds: 1800),
        );
        if (session != _session || phase != RoomPhase.reconnecting) {
          await client.close();
          return;
        }
        final old = _sig;
        _attach(client);
        old?.close();
        phase = RoomPhase.active;
        for (final p in client.peers) {
          _addPeer(p);
        }
        notifyListeners();
        return;
      } on JoinError catch (e) {
        if (e.code == 'auth' || e.code == 'version' || e.code == 'full') {
          if (hostId != null && e.code == 'auth') settings.forgetPin(hostId!);
          await leave(reason: e.message);
          return;
        }
      } catch (_) {}
      attempt++;
      await Future<void>.delayed(Duration(seconds: attempt < 30 ? 2 : 5));
    }
  }

  // ---------------------------------------------------------------- relógio

  void _onTick() {
    _ticks++;
    final beat = _ticks.isEven;
    final takeQuality = _ticks % 8 == 0;
    final now = DateTime.now();
    for (final e in pilots.entries) {
      final id = e.key;
      final view = e.value;
      final link = _links[id];
      if (beat) link?.heartbeat(tx: transmitting, muted: muted);

      final next = link?.state ?? LinkState.lost;
      final prev = view.state;
      if (next != prev) {
        if (next == LinkState.connected) {
          if (!view.everConnected) {
            view.everConnected = true;
            feedback.say('${view.info.name} conectado');
          } else if (view.lostSince != null) {
            feedback.say('${view.info.name} reconectado');
          }
          view.lostSince = null;
        } else if (next == LinkState.lost &&
            view.everConnected &&
            view.lostSince == null) {
          view.lostSince = now;
          feedback.say('${view.info.name} fora do alcance', strong: true);
        }
        view.state = next;
      }
      if (link != null) {
        view.muted = link.remoteMuted;
        view.talking =
            next == LinkState.connected && link.remoteTx && !link.remoteMuted;
        view.level = view.talking ? link.remoteLevel : 0;
        if (takeQuality) view.quality = link.takeQuality();
      } else {
        view.talking = false;
        view.level = 0;
        view.quality = 0;
      }

      // Quem é o ofertante refaz a conexão enquanto o link estiver caído.
      if (next == LinkState.lost &&
          phase == RoomPhase.active &&
          _isOfferer(id)) {
        final last = _lastOffer[id];
        if (last == null || now.difference(last).inSeconds >= 4) {
          _startOffer(id);
        }
      }
    }
    if (_ticks % 8 == 0) {
      _refreshHelmet();
      // Conexões novas nascem no volume máximo: reaplica o escolhido.
      if (volume < 0.999 || deafened) setVolumeSilently();
    }
    notifyListeners();
  }

  Future<void> _refreshHelmet() async {
    final h = await platform.helmet();
    if (h.connected != helmet.connected || h.name != helmet.name) {
      final was = helmet;
      helmet = h;
      // Sem alerta na tela nem na voz: quando o capacete volta, só devolve o
      // áudio para ele.
      if (was.known && h.known && h.connected) {
        speaker = false;
        await platform.routeToHelmet();
      }
    }
  }

  Future<void> _pollStats() async {
    if (_statsBusy || _links.isEmpty) return;
    _statsBusy = true;
    try {
      var gotLocal = false;
      for (final link in _links.values.toList()) {
        final conn = link.pc;
        if (conn == null) continue;
        final reports = await conn.getStats();
        for (final r in reports) {
          final v = r.values;
          if (v['kind'] != 'audio') continue;
          final lvl = (v['audioLevel'] as num?)?.toDouble();
          if (lvl == null) continue;
          if (r.type == 'inbound-rtp') {
            link.remoteLevel = lvl;
          } else if (r.type == 'media-source' && !gotLocal) {
            localLevel = lvl;
            gotLocal = true;
          }
        }
      }
    } catch (_) {
    } finally {
      _statsBusy = false;
    }
    _applyGate();
  }

  // ------------------------------------------------------------ fala e mudo

  void _applyGate({bool force = false}) {
    final now = DateTime.now();
    bool want;
    if (muted) {
      want = false;
    } else {
      switch (mode) {
        case TalkMode.open:
          want = true;
        case TalkMode.ptt:
          want = pttDown;
        case TalkMode.vox:
          if (localLevel >= settings.voxThreshold) {
            _voxHold = now.add(const Duration(milliseconds: 900));
          }
          want = now.isBefore(_voxHold);
      }
    }
    if (want == transmitting && !force) return;
    transmitting = want;
    for (final t in _local?.getAudioTracks() ?? const <MediaStreamTrack>[]) {
      t.enabled = want;
    }
  }

  void toggleMute() {
    muted = !muted;
    _applyGate(force: true);
    feedback.say(muted ? 'Mudo' : 'Microfone aberto');
    notifyListeners();
  }

  void setMode(TalkMode m) {
    settings.mode = m;
    pttDown = false;
    _applyGate(force: true);
    feedback.say(m.spoken);
    notifyListeners();
  }

  void setPtt(bool down) {
    if (pttDown == down) return;
    pttDown = down;
    feedback.tick();
    _applyGate(force: true);
    notifyListeners();
  }

  void toggleDeafen() {
    deafened = !deafened;
    setVolumeSilently();
    feedback.say(deafened ? 'Fone mudo' : 'Fone aberto');
    notifyListeners();
  }

  void toggleSpeaker() {
    speaker = !speaker;
    platform.setSpeaker(speaker);
    feedback.say(speaker ? 'Alto-falante' : 'Capacete');
    notifyListeners();
  }

  void setVolume(double v) {
    volume = v;
    deafened = false;
    setVolumeSilently();
    notifyListeners();
  }

  void setVolumeSilently() {
    for (final link in _links.values) {
      final t = link.remoteTrack;
      if (t != null) platform.setTrackVolume(t, deafened ? 0 : volume);
    }
  }

  String _describe(Object e) {
    final s = e.toString();
    if (s.contains('SocketException')) return 'A porta de rede está em uso.';
    if (_isMicError(e)) return 'Permita o uso do microfone.';
    return '';
  }
}
