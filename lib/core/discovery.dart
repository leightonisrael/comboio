import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'protocol.dart';

/// Uma sala encontrada na rede local.
class RoomAd {
  RoomAd({
    required this.ip,
    required this.room,
    required this.hostId,
    required this.hostName,
    required this.color,
    required this.count,
    required this.max,
  });

  final String ip;
  final String room;
  final String hostId;
  final String hostName;
  final int color;
  final int count;
  final int max;
}

bool _isPrivate(List<int> b) =>
    b[0] == 10 || (b[0] == 172 && b[1] >= 16 && b[1] <= 31) || (b[0] == 192 && b[1] == 168);

const _cellularPrefixes = ['rmnet', 'pdp_ip', 'ccmni', 'v4-rmnet', 'tun', 'ipsec', 'utun'];

/// Endereços IPv4 deste aparelho em redes locais (Wi-Fi ou hotspot).
Future<List<InternetAddress>> localAddresses() async {
  final out = <InternetAddress>[];
  try {
    final ifaces =
        await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false);
    for (final i in ifaces) {
      final name = i.name.toLowerCase();
      if (_cellularPrefixes.any(name.startsWith)) continue;
      for (final a in i.addresses) {
        if (_isPrivate(a.rawAddress)) out.add(a);
      }
    }
  } catch (_) {}
  return out;
}

/// Consulta `/info` em um endereço. Retorna null se não houver sala ali.
Future<RoomAd?> probe(String ip, {int port = kPort, int timeoutMs = 900}) async {
  final client = HttpClient()..connectionTimeout = Duration(milliseconds: timeoutMs);
  try {
    final req = await client.getUrl(Uri.parse('http://$ip:$port/info'));
    final res = await req.close().timeout(Duration(milliseconds: timeoutMs));
    final body = await res.transform(utf8.decoder).join().timeout(Duration(milliseconds: timeoutMs));
    final j = jsonDecode(body);
    if (j is! Map || j['app'] != 'comboio') return null;
    return RoomAd(
      ip: ip,
      room: '${j['room'] ?? 'Sala'}',
      hostId: '${j['hid'] ?? ''}',
      hostName: '${j['host'] ?? 'Piloto'}',
      color: (j['color'] as num?)?.toInt() ?? 0,
      count: (j['n'] as num?)?.toInt() ?? 1,
      max: (j['max'] as num?)?.toInt() ?? kMaxPilots,
    );
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}

/// Procura salas: primeiro o gateway de cada rede (o host costuma ser o dono
/// do hotspot), depois o restante da sub-rede /24.
Future<List<RoomAd>> scanRooms() async {
  final mine = await localAddresses();
  if (mine.isEmpty) return [];
  final own = mine.map((a) => a.address).toSet();
  final first = <String>[];
  final rest = <String>[];
  for (final a in mine) {
    final b = a.rawAddress;
    final prefix = '${b[0]}.${b[1]}.${b[2]}';
    for (var h = 1; h <= 254; h++) {
      final ip = '$prefix.$h';
      if (own.contains(ip)) continue;
      (h == 1 ? first : rest).add(ip);
    }
  }
  final found = <String, RoomAd>{};
  Future<void> run(List<String> ips, int timeoutMs) async {
    const batch = 64;
    for (var i = 0; i < ips.length; i += batch) {
      final slice = ips.skip(i).take(batch);
      final ads = await Future.wait(slice.map((ip) => probe(ip, timeoutMs: timeoutMs)));
      for (final ad in ads) {
        if (ad != null) found[ad.hostId.isEmpty ? ad.ip : ad.hostId] = ad;
      }
    }
  }

  await run(first, 900);
  if (found.isEmpty) await run(rest, 700);
  return found.values.toList();
}
