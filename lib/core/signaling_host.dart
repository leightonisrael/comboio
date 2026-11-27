import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'protocol.dart';

class _Client {
  _Client(this.ws);

  final WebSocket ws;
  PeerInfo? info;
  String? nonceC;
  String? nonceH;
  bool authed = false;
}

/// Servidor de sinalização que roda no celular de quem criou a sala.
/// Autentica os clientes pelo PIN e retransmite mensagens entre eles.
class SignalingHost implements Signaling {
  SignalingHost({
    required this.self,
    required this.pin,
    required this.roomName,
    this.port = kPort,
  });

  final PeerInfo self;
  final String pin;
  final String roomName;
  final int port;

  HttpServer? _server;
  final _clients = <String, _Client>{};
  final _ctrl = StreamController<Map<String, dynamic>>.broadcast();
  int _failures = 0;
  DateTime? _lockedUntil;

  @override
  Stream<Map<String, dynamic>> get messages => _ctrl.stream;

  int get boundPort => _server?.port ?? port;

  Future<void> start() async {
    _server = await HttpServer.bind(
      InternetAddress.anyIPv4,
      port,
      shared: true,
    );
    _server!.listen(_onRequest, onError: (_) {});
  }

  Future<void> _onRequest(HttpRequest req) async {
    try {
      if (req.uri.path == '/info') {
        req.response.headers.contentType = ContentType.json;
        req.response.write(
          jsonEncode({
            'app': 'comboio',
            'v': kProtocolVersion,
            'room': roomName,
            'hid': self.id,
            'host': self.name,
            'color': self.color,
            'n': _clients.length + 1,
            'max': kMaxPilots,
          }),
        );
        await req.response.close();
        return;
      }
      if (req.uri.path == '/v1' && WebSocketTransformer.isUpgradeRequest(req)) {
        final ws = await WebSocketTransformer.upgrade(req);
        ws.pingInterval = const Duration(seconds: 3);
        _serve(_Client(ws));
        return;
      }
      req.response.statusCode = HttpStatus.notFound;
      await req.response.close();
    } catch (_) {
      // Conexão caiu no meio do pedido: nada a fazer.
    }
  }

  void _serve(_Client c) {
    c.ws.listen(
      (data) {
        if (data is! String) return;
        final Map<String, dynamic> msg;
        try {
          msg = Map<String, dynamic>.from(jsonDecode(data) as Map);
        } catch (_) {
          return;
        }
        _onClientMessage(c, msg);
      },
      onDone: () => _onClientGone(c, 'drop'),
      onError: (_) => _onClientGone(c, 'drop'),
      cancelOnError: true,
    );
  }

  void _reject(_Client c, String code) {
    _sendTo(c, {'t': 'reject', 'code': code});
    c.ws.close();
  }

  void _onClientMessage(_Client c, Map<String, dynamic> msg) {
    final t = msg['t'];
    if (!c.authed) {
      if (t == 'hello') {
        if (msg['v'] != kProtocolVersion) return _reject(c, 'version');
        final locked = _lockedUntil;
        if (locked != null && DateTime.now().isBefore(locked)) {
          return _reject(c, 'locked');
        }
        final info = PeerInfo.fromJson(msg);
        final rejoining = _clients.containsKey(info.id);
        if (!rejoining && _clients.length + 1 >= kMaxPilots) {
          return _reject(c, 'full');
        }
        if (info.id == self.id) return _reject(c, 'auth');
        c.info = info;
        c.nonceC = '${msg['nonce']}';
        c.nonceH = randomHex(16);
        _sendTo(c, {'t': 'challenge', 'nonce': c.nonceH});
      } else if (t == 'auth' && c.info != null) {
        final expected = pinProof(pin, c.nonceH!, c.nonceC!, c.info!.id);
        if (msg['proof'] != expected) {
          if (++_failures >= 5) {
            _failures = 0;
            _lockedUntil = DateTime.now().add(const Duration(minutes: 1));
          }
          return _reject(c, 'auth');
        }
        _failures = 0;
        final id = c.info!.id;
        // Reentrada do mesmo piloto: descarta o socket antigo sem anunciar saída.
        final old = _clients.remove(id);
        old?.ws.close();
        c.authed = true;
        final others = _clients.values.map((o) => o.info!.toJson()).toList();
        _clients[id] = c;
        _sendTo(c, {
          't': 'welcome',
          'proof': pinProof(pin, c.nonceC!, c.nonceH!, 'host'),
          'room': roomName,
          'peers': [self.toJson(), ...others],
        });
        final joined = {'t': 'peer-joined', 'peer': c.info!.toJson()};
        _broadcast(joined, except: id);
        _ctrl.add(joined);
      }
      return;
    }

    // Autenticado: o remetente é sempre carimbado pelo host.
    final from = c.info!.id;
    msg['from'] = from;
    if (t == 'bye') {
      _onClientGone(c, 'bye');
      c.ws.close();
      return;
    }
    final to = msg['to'];
    if (to == null) {
      _broadcast(msg, except: from);
      _ctrl.add(msg);
    } else if (to == self.id) {
      _ctrl.add(msg);
    } else {
      final dest = _clients[to];
      if (dest != null) _sendTo(dest, msg);
    }
  }

  void _onClientGone(_Client c, String reason) {
    final id = c.info?.id;
    if (id == null || !c.authed) return;
    // Só anuncia se este socket ainda é o registrado para o piloto.
    if (!identical(_clients[id], c)) return;
    _clients.remove(id);
    final left = {'t': 'peer-left', 'id': id, 'reason': reason};
    _broadcast(left);
    if (!_ctrl.isClosed) _ctrl.add(left);
  }

  void _sendTo(_Client c, Map<String, dynamic> msg) {
    try {
      c.ws.add(jsonEncode(msg));
    } catch (_) {}
  }

  void _broadcast(Map<String, dynamic> msg, {String? except}) {
    for (final e in _clients.entries) {
      if (e.key != except) _sendTo(e.value, msg);
    }
  }

  @override
  void send(Map<String, dynamic> msg) {
    msg['from'] = self.id;
    final to = msg['to'];
    if (to == null) {
      _broadcast(msg);
    } else {
      final dest = _clients[to];
      if (dest != null) _sendTo(dest, msg);
    }
  }

  @override
  Future<void> close() async {
    final clients = _clients.values.toList();
    _clients.clear();
    for (final c in clients) {
      await c.ws.close().catchError((_) {});
    }
    await _server?.close(force: true);
    _server = null;
    await _ctrl.close();
  }
}
