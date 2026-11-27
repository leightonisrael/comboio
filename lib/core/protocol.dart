import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Porta fixa da sinalização (HTTP /info e WebSocket /v1).
const kPort = 47800;
const kProtocolVersion = 1;
const kMaxPilots = 6;

final _rng = Random.secure();

String randomHex(int bytes) => List.generate(
  bytes,
  (_) => _rng.nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();

String randomPin() => _rng.nextInt(1000000).toString().padLeft(6, '0');

/// Prova de conhecimento do PIN, amarrada aos dois nonces e a quem prova.
String pinProof(String pin, String nonceA, String nonceB, String who) => Hmac(
  sha256,
  utf8.encode('comboio-v1:$pin'),
).convert(utf8.encode('$nonceA|$nonceB|$who')).toString();

class PeerInfo {
  PeerInfo({required this.id, required this.name, required this.color});

  final String id;
  String name;
  int color;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'color': color};

  static PeerInfo fromJson(Map<String, dynamic> j) => PeerInfo(
    id: '${j['id']}',
    name: '${j['name'] ?? 'Piloto'}',
    color: (j['color'] as num?)?.toInt() ?? 0,
  );
}

class JoinError implements Exception {
  JoinError(this.code);

  /// `auth`, `full`, `version`, `locked`, `mic`, `network`.
  final String code;

  String get message => switch (code) {
    'auth' => 'PIN incorreto.',
    'full' => 'A sala está cheia.',
    'version' => 'Os apps estão em versões diferentes. Atualize os dois.',
    'locked' => 'Muitas tentativas erradas. Espere um minuto.',
    'mic' => 'Permita o uso do microfone para conversar.',
    _ => 'Não foi possível conectar à sala.',
  };

  @override
  String toString() => 'JoinError($code)';
}

/// Canal de sinalização visto pelo controlador da sala, seja host ou cliente.
abstract class Signaling {
  Stream<Map<String, dynamic>> get messages;

  /// Envia para `msg['to']`, ou para todos quando não há destinatário.
  void send(Map<String, dynamic> msg);

  Future<void> close();
}

/// Ajusta o Opus no SDP recebido: DTX, FEC in-band, bitrate e mono.
/// Os parâmetros do fmtp remoto dizem ao nosso codificador como enviar.
String tuneOpus(String sdp, int bitrate) {
  final map = RegExp(
    r'a=rtpmap:(\d+) opus/48000/2',
    caseSensitive: false,
  ).firstMatch(sdp);
  if (map == null) return sdp;
  final pt = map.group(1)!;
  final extra = 'usedtx=1;useinbandfec=1;maxaveragebitrate=$bitrate;stereo=0';
  const managed = ['usedtx', 'useinbandfec', 'maxaveragebitrate', 'stereo'];
  final fmtp = RegExp('a=fmtp:$pt ([^\r\n]*)');
  if (fmtp.hasMatch(sdp)) {
    return sdp.replaceFirstMapped(fmtp, (m) {
      final kept = m
          .group(1)!
          .split(';')
          .map((s) => s.trim())
          .where(
            (s) => s.isNotEmpty && !managed.any((k) => s.startsWith('$k=')),
          )
          .toList();
      return 'a=fmtp:$pt ${[...kept, extra].join(';')}';
    });
  }
  return sdp.replaceFirst(
    map.group(0)!,
    '${map.group(0)}\r\na=fmtp:$pt $extra',
  );
}
