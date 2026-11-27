import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'protocol.dart';

/// Lado cliente da sinalização. [connect] só retorna depois do `welcome`.
class SignalingClient implements Signaling {
  SignalingClient._(this._ws, this.self);

  final WebSocket _ws;
  final PeerInfo self;
  final _ctrl = StreamController<Map<String, dynamic>>.broadcast();
  bool _closedByUs = false;

  /// Pilotos já presentes na sala (inclui o host), recebidos no `welcome`.
  List<PeerInfo> peers = const [];
  String roomName = '';

  @override
  Stream<Map<String, dynamic>> get messages => _ctrl.stream;

  static Future<SignalingClient> connect({
    required String host,
    required PeerInfo self,
    required String pin,
    int port = kPort,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final WebSocket ws;
    try {
      ws = await WebSocket.connect('ws://$host:$port/v1').timeout(timeout);
    } catch (_) {
      throw JoinError('network');
    }
    ws.pingInterval = const Duration(seconds: 3);
    final client = SignalingClient._(ws, self);
    final welcomed = Completer<void>();
    final nonceC = randomHex(16);
    String? nonceH;

    void fail(String code) {
      if (!welcomed.isCompleted) welcomed.completeError(JoinError(code));
    }

    ws.listen(
      (data) {
        if (data is! String) return;
        final Map<String, dynamic> msg;
        try {
          msg = Map<String, dynamic>.from(jsonDecode(data) as Map);
        } catch (_) {
          return;
        }
        if (welcomed.isCompleted) {
          if (!client._ctrl.isClosed) client._ctrl.add(msg);
          return;
        }
        switch (msg['t']) {
          case 'challenge':
            nonceH = '${msg['nonce']}';
            ws.add(
              jsonEncode({
                't': 'auth',
                'proof': pinProof(pin, nonceH!, nonceC, self.id),
              }),
            );
          case 'welcome':
            // O host também prova que conhece o PIN.
            if (nonceH == null ||
                msg['proof'] != pinProof(pin, nonceC, nonceH!, 'host')) {
              fail('auth');
              return;
            }
            client.roomName = '${msg['room'] ?? ''}';
            client.peers = [
              for (final p in (msg['peers'] as List? ?? const []))
                PeerInfo.fromJson(Map<String, dynamic>.from(p as Map)),
            ];
            welcomed.complete();
          case 'reject':
            fail('${msg['code'] ?? 'network'}');
        }
      },
      onDone: () {
        fail('network');
        client._onClosed();
      },
      onError: (_) {
        fail('network');
        client._onClosed();
      },
      cancelOnError: true,
    );

    ws.add(
      jsonEncode({
        't': 'hello',
        'v': kProtocolVersion,
        ...self.toJson(),
        'nonce': nonceC,
      }),
    );

    try {
      await welcomed.future.timeout(timeout);
    } on TimeoutException {
      await client.close();
      throw JoinError('network');
    } catch (_) {
      await client.close();
      rethrow;
    }
    return client;
  }

  void _onClosed() {
    if (_ctrl.isClosed) return;
    if (!_closedByUs) _ctrl.add({'t': '_closed'});
    _ctrl.close();
  }

  @override
  void send(Map<String, dynamic> msg) {
    if (_ws.readyState != WebSocket.open) return;
    try {
      _ws.add(jsonEncode(msg));
    } catch (_) {}
  }

  @override
  Future<void> close() async {
    _closedByUs = true;
    try {
      await _ws.close().timeout(const Duration(seconds: 1));
    } catch (_) {}
    if (!_ctrl.isClosed) await _ctrl.close();
  }
}
