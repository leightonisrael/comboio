import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'protocol.dart';

enum TalkMode { open, vox, ptt }

extension TalkModeLabel on TalkMode {
  String get label => switch (this) {
        TalkMode.open => 'ABERTO',
        TalkMode.vox => 'VOX',
        TalkMode.ptt => 'PTT',
      };

  String get spoken => switch (this) {
        TalkMode.open => 'Microfone aberto',
        TalkMode.vox => 'Ativação por voz',
        TalkMode.ptt => 'Apertar para falar',
      };
}

/// Preferências persistidas do piloto.
class Settings extends ChangeNotifier {
  late SharedPreferences _p;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    if (_p.getString('peerId') == null) await _p.setString('peerId', randomHex(8));
    if (_p.getString('pin') == null) await _p.setString('pin', randomPin());
  }

  void _set(String key, Object value) {
    switch (value) {
      case final String v:
        _p.setString(key, v);
      case final int v:
        _p.setInt(key, v);
      case final double v:
        _p.setDouble(key, v);
      case final bool v:
        _p.setBool(key, v);
    }
    notifyListeners();
  }

  String get peerId => _p.getString('peerId')!;

  bool get onboarded => _p.getBool('onboarded') ?? false;
  set onboarded(bool v) => _set('onboarded', v);

  String get name => _p.getString('name') ?? 'Piloto';
  set name(String v) => _set('name', v.trim().isEmpty ? 'Piloto' : v.trim());

  int get colorIndex => _p.getInt('color') ?? 0;
  set colorIndex(int v) => _set('color', v);

  TalkMode get mode => TalkMode.values[(_p.getInt('mode') ?? 0).clamp(0, 2)];
  set mode(TalkMode v) => _set('mode', v.index);

  /// Limiar do VOX, no mesmo eixo do nível de áudio (0..1).
  double get voxThreshold => _p.getDouble('vox') ?? 0.06;
  set voxThreshold(double v) => _set('vox', v);

  int get bitrate => _p.getInt('bitrate') ?? 24000;
  set bitrate(int v) => _set('bitrate', v);

  ThemeMode get themeMode => ThemeMode.values[(_p.getInt('theme') ?? ThemeMode.dark.index)];
  set themeMode(ThemeMode v) => _set('theme', v.index);

  bool get keepScreenOn => _p.getBool('screenOn') ?? true;
  set keepScreenOn(bool v) => _set('screenOn', v);

  bool get voiceAlerts => _p.getBool('voice') ?? true;
  set voiceAlerts(bool v) => _set('voice', v);

  /// PIN das salas criadas neste aparelho.
  String get pin => _p.getString('pin')!;
  void regeneratePin() => _set('pin', randomPin());

  /// PINs de hosts já pareados: entrar de novo é um toque só.
  Map<String, String> get _known =>
      Map<String, String>.from(jsonDecode(_p.getString('known') ?? '{}') as Map);

  String? pinFor(String hostId) => _known[hostId];

  void rememberPin(String hostId, String pin) {
    if (hostId.isEmpty) return;
    _set('known', jsonEncode(_known..[hostId] = pin));
  }

  void forgetPin(String hostId) => _set('known', jsonEncode(_known..remove(hostId)));

  int get knownCount => _known.length;
  void forgetAll() => _set('known', '{}');
}
