import 'dart:async';

import 'package:comboio/core/discovery.dart';
import 'package:comboio/core/protocol.dart';
import 'package:comboio/core/signaling_client.dart';
import 'package:comboio/core/signaling_host.dart';
import 'package:flutter_test/flutter_test.dart';

PeerInfo pilot(String id, String name) => PeerInfo(id: id, name: name, color: 0);

Future<Map<String, dynamic>> nextOf(Stream<Map<String, dynamic>> s, String type) =>
    s.firstWhere((m) => m['t'] == type).timeout(const Duration(seconds: 3));

void main() {
  group('tuneOpus', () {
    const base = 'v=0\r\nm=audio 9 UDP/TLS/RTP/SAVPF 111 63\r\n'
        'a=rtpmap:111 opus/48000/2\r\n';

    test('acrescenta parâmetros ao fmtp existente sem duplicar', () {
      final out = tuneOpus('${base}a=fmtp:111 minptime=10;useinbandfec=1\r\n', 24000);
      expect(out, contains('a=fmtp:111 minptime=10;usedtx=1;useinbandfec=1;maxaveragebitrate=24000;stereo=0\r\n'));
      expect('useinbandfec'.allMatches(out).length, 1);
    });

    test('cria o fmtp quando não existe', () {
      final out = tuneOpus(base, 16000);
      expect(out, contains('a=rtpmap:111 opus/48000/2\r\na=fmtp:111 usedtx=1'));
      expect(out, contains('maxaveragebitrate=16000'));
    });

    test('não mexe em SDP sem Opus', () {
      const sdp = 'v=0\r\na=rtpmap:0 PCMU/8000\r\n';
      expect(tuneOpus(sdp, 24000), sdp);
    });
  });

  test('pinProof depende do PIN, dos nonces e de quem prova', () {
    final a = pinProof('123456', 'n1', 'n2', 'p1');
    expect(a, pinProof('123456', 'n1', 'n2', 'p1'));
    expect(a, isNot(pinProof('123457', 'n1', 'n2', 'p1')));
    expect(a, isNot(pinProof('123456', 'n2', 'n1', 'p1')));
    expect(a, isNot(pinProof('123456', 'n1', 'n2', 'host')));
  });

  group('sinalização', () {
    late SignalingHost host;

    setUp(() async {
      host = SignalingHost(self: pilot('h', 'Host'), pin: '111222', roomName: 'Sala', port: 0);
      await host.start();
    });

    tearDown(() => host.close());

    Future<SignalingClient> join(String id, {String pin = '111222'}) => SignalingClient.connect(
        host: '127.0.0.1', port: host.boundPort, self: pilot(id, 'P$id'), pin: pin);

    test('/info anuncia a sala', () async {
      final ad = await probe('127.0.0.1', port: host.boundPort);
      expect(ad?.room, 'Sala');
      expect(ad?.hostId, 'h');
      expect(ad?.count, 1);
    });

    test('PIN certo entra e recebe a lista de pilotos', () async {
      final joined = nextOf(host.messages, 'peer-joined');
      final a = await join('a');
      expect(a.roomName, 'Sala');
      expect(a.peers.map((p) => p.id), ['h']);
      expect(((await joined)['peer'] as Map)['id'], 'a');
      await a.close();
    });

    test('PIN errado é recusado', () async {
      await expectLater(
        join('a', pin: '000000'),
        throwsA(isA<JoinError>().having((e) => e.code, 'code', 'auth')),
      );
    });

    test('cinco PINs errados bloqueiam novas tentativas', () async {
      for (var i = 0; i < 5; i++) {
        await expectLater(join('x$i', pin: '000000'), throwsA(isA<JoinError>()));
      }
      await expectLater(
        join('a'),
        throwsA(isA<JoinError>().having((e) => e.code, 'code', 'locked')),
      );
    });

    test('host retransmite entre clientes e carimba o remetente', () async {
      final a = await join('a');
      final b = await join('b');
      expect(b.peers.map((p) => p.id).toSet(), {'h', 'a'});

      final atB = nextOf(b.messages, 'offer');
      // "from" falso é sobrescrito pelo host.
      a.send({'t': 'offer', 'to': 'b', 'from': 'h', 'sdp': 'x'});
      final got = await atB;
      expect(got['from'], 'a');
      expect(got['sdp'], 'x');

      final atHost = nextOf(host.messages, 'answer');
      b.send({'t': 'answer', 'to': 'h', 'sdp': 'y'});
      expect((await atHost)['from'], 'b');

      final atA = nextOf(a.messages, 'candidate');
      host.send({'t': 'candidate', 'to': 'a', 'cand': <String, dynamic>{}});
      expect((await atA)['from'], 'h');

      await a.close();
      await b.close();
    });

    test('saída voluntária e queda são distinguidas', () async {
      final a = await join('a');
      final b = await join('b');

      final bye = nextOf(host.messages, 'peer-left');
      a.send({'t': 'bye'});
      expect((await bye)['reason'], 'bye');

      final drop = nextOf(host.messages, 'peer-left');
      await b.close();
      final m = await drop;
      expect(m['id'], 'b');
      expect(m['reason'], 'drop');
    });

    test('reentrada do mesmo piloto não gera saída falsa', () async {
      final a1 = await join('a');
      final left = <Map<String, dynamic>>[];
      final sub = host.messages.where((m) => m['t'] == 'peer-left').listen(left.add);
      final a2 = await join('a');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(left, isEmpty);
      await sub.cancel();
      await a1.close();
      await a2.close();
    });

    test('cliente é avisado quando o host cai', () async {
      final a = await join('a');
      final closed = nextOf(a.messages, '_closed');
      await host.close();
      await closed;
    });
  });
}
