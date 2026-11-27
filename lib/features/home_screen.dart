import 'dart:async';

import 'package:flutter/material.dart';

import '../app.dart';
import '../core/discovery.dart';
import '../core/platform_bridge.dart';
import '../design/tokens.dart';
import '../design/widgets.dart';
import 'pin_pad.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<RoomAd> _rooms = const [];
  bool _scanning = false;
  bool _scannedOnce = false;
  bool _busy = false;
  bool _hasNetwork = true;
  HelmetStatus _helmet = const HelmetStatus.unknown();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
      _showEndReason();
    });
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  void _showEndReason() {
    final room = Deps.of(context).room;
    final reason = room.endReason;
    if (reason != null && reason.isNotEmpty) {
      room.endReason = null;
      _snack(reason);
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 5)));
  }

  Future<void> _refresh() async {
    if (_scanning || _busy || !mounted) return;
    final deps = Deps.of(context);
    if (deps.room.inRoom) return;
    _scanning = true;
    try {
      final helmet = await deps.platform.helmet();
      final addrs = await localAddresses();
      final rooms = addrs.isEmpty ? <RoomAd>[] : await scanRooms();
      if (!mounted) return;
      setState(() {
        _helmet = helmet;
        _hasNetwork = addrs.isNotEmpty;
        _rooms = rooms;
        _scannedOnce = true;
      });
    } finally {
      _scanning = false;
    }
  }

  Future<bool> _ready() async {
    final ok = await Deps.of(context).platform.ensurePermissions();
    if (!ok) _snack('Permita o uso do microfone para conversar.');
    return ok;
  }

  Future<void> _create() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (!await _ready() || !mounted) return;
      final room = Deps.of(context).room;
      await room.createRoom();
      if (!room.inRoom && room.endReason != null) {
        _snack(room.endReason!);
        room.endReason = null;
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join(RoomAd ad) async {
    if (_busy) return;
    final deps = Deps.of(context);
    var pin = deps.settings.pinFor(ad.hostId);
    if (pin == null) {
      pin = await showPinPad(context, title: ad.room);
      if (pin == null || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      if (!await _ready()) return;
      final err = await deps.room.joinRoom(ad.ip, pin, knownHostId: ad.hostId);
      if (err != null) {
        if (err.code == 'auth') deps.settings.forgetPin(ad.hostId);
        _snack(err.message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _manualJoin() async {
    final ip = await showDialog<String>(context: context, builder: (_) => const _IpDialog());
    if (ip == null || ip.isEmpty || !mounted) return;
    setState(() => _busy = true);
    final ad = await probe(ip, timeoutMs: 2500);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ad == null) {
      _snack('Nenhuma sala em $ip. Confira se os dois estão no mesmo Wi-Fi.');
      return;
    }
    await _join(ad);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final deps = Deps.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Sp.md, Sp.sm, Sp.md, Sp.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('COMBOIO', style: Ty.headline.copyWith(color: p.accentText)),
                  ),
                  IconButton(
                    tooltip: 'Configurações',
                    iconSize: 32,
                    constraints: const BoxConstraints(minWidth: Touch.min, minHeight: Touch.min),
                    icon: Icon(Icons.settings_rounded, color: p.text),
                    onPressed: () => Navigator.of(context)
                        .push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
                  ),
                ],
              ),
              const SizedBox(height: Sp.sm),
              HelmetChip(
                status: _helmet,
                onTap: () => deps.platform.openSettings('bluetooth'),
              ),
              const SizedBox(height: Sp.lg),
              Row(
                children: [
                  Expanded(
                    child: Text('SALAS POR PERTO', style: Ty.label.copyWith(color: p.textDim)),
                  ),
                  if (_scanning || !_scannedOnce)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: p.textDim),
                    ),
                ],
              ),
              const SizedBox(height: Sp.sm),
              Expanded(child: _roomsArea(context)),
              const SizedBox(height: Sp.md),
              BigButton(
                label: 'Entrar pelo endereço',
                kind: BigButtonKind.outlined,
                icon: Icons.login_rounded,
                onPressed: _busy ? null : _manualJoin,
              ),
              const SizedBox(height: Sp.md),
              BigButton(
                label: _busy ? 'Aguarde…' : 'Criar sala',
                icon: Icons.add_rounded,
                onPressed: _busy ? null : _create,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roomsArea(BuildContext context) {
    final p = context.pal;
    final deps = Deps.of(context);
    if (_rooms.isNotEmpty) {
      return ListView.separated(
        itemCount: _rooms.length,
        separatorBuilder: (_, _) => const SizedBox(height: Sp.sm + Sp.xs),
        itemBuilder: (context, i) {
          final ad = _rooms[i];
          final known = deps.settings.pinFor(ad.hostId) != null;
          return _RoomTile(ad: ad, known: known, onTap: _busy ? null : () => _join(ad));
        },
      );
    }
    final String title;
    final String body;
    final IconData icon;
    if (!_hasNetwork) {
      icon = Icons.wifi_off_rounded;
      title = 'SEM REDE LOCAL';
      body = 'Para entrar: conecte no Wi-Fi (hotspot) do outro piloto.\n'
          'Para criar: ligue o seu hotspot e toque em Criar sala.';
    } else if (!_scannedOnce) {
      icon = Icons.sensors_rounded;
      title = 'PROCURANDO…';
      body = 'Buscando salas nesta rede.';
    } else {
      icon = Icons.sensors_rounded;
      title = 'NENHUMA SALA POR PERTO';
      body = 'Confira se você está no Wi-Fi do outro piloto e se ele já criou a sala.';
    }
    return Panel(
      padding: const EdgeInsets.all(Sp.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: p.textDim),
          const SizedBox(height: Sp.md),
          Text(title, textAlign: TextAlign.center, style: Ty.title.copyWith(color: p.text)),
          const SizedBox(height: Sp.sm),
          Text(body, textAlign: TextAlign.center, style: Ty.body.copyWith(color: p.textDim)),
          if (!_hasNetwork) ...[
            const SizedBox(height: Sp.md),
            Row(
              children: [
                Expanded(
                  child: BigButton(
                    label: 'Wi-Fi',
                    kind: BigButtonKind.quiet,
                    height: Touch.min,
                    onPressed: () => deps.platform.openSettings('wifi'),
                  ),
                ),
                const SizedBox(width: Sp.md),
                Expanded(
                  child: BigButton(
                    label: 'Hotspot',
                    kind: BigButtonKind.quiet,
                    height: Touch.min,
                    onPressed: () => deps.platform.openSettings('hotspot'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  const _RoomTile({required this.ad, required this.known, required this.onTap});

  final RoomAd ad;
  final bool known;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final full = ad.count >= ad.max;
    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Rd.md),
        side: BorderSide(color: known ? p.live : p.border, width: known ? 2 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: full ? null : onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Touch.primary + 8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.sm + Sp.xs),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(color: pilotColor(ad.color), shape: BoxShape.circle),
                ),
                const SizedBox(width: Sp.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ad.room,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Ty.title.copyWith(color: p.text)),
                      Text(
                        full
                            ? 'Sala cheia'
                            : known
                                ? 'Piloto conhecido · toque para entrar'
                                : 'Pede PIN · ${ad.count}/${ad.max} pilotos',
                        style: Ty.label.copyWith(color: p.textDim),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 28, color: p.text),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Estado do capacete: cor + ícone + palavra, nunca só cor.
class HelmetChip extends StatelessWidget {
  const HelmetChip({super.key, required this.status, this.onTap});

  final HelmetStatus status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final (Color color, IconData icon, String text) = !status.known
        ? (p.textDim, Icons.headset_mic_rounded, 'Capacete: conecte pelo Bluetooth')
        : status.connected
            ? (
                p.live,
                Icons.check_circle_rounded,
                status.name.isEmpty ? 'Capacete conectado' : '${status.name} conectado'
              )
            : (p.danger, Icons.warning_rounded, 'Capacete desconectado · toque para abrir');
    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Rd.sm),
        side: BorderSide(color: color, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.sm),
            child: Row(
              children: [
                Icon(icon, size: 28, color: color),
                const SizedBox(width: Sp.sm + Sp.xs),
                Expanded(
                  child: Text(text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Ty.body.copyWith(color: p.text, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IpDialog extends StatefulWidget {
  const _IpDialog();

  @override
  State<_IpDialog> createState() => _IpDialogState();
}

class _IpDialogState extends State<_IpDialog> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return AlertDialog(
      title: Text('ENDEREÇO DA SALA', style: Ty.title.copyWith(color: p.text)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Aparece na tela de quem criou a sala.',
              style: Ty.body.copyWith(color: p.textDim)),
          const SizedBox(height: Sp.md),
          TextField(
            controller: _c,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: Ty.title.copyWith(color: p.text),
            decoration: const InputDecoration(hintText: '192.168.43.1'),
            onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('CANCELAR', style: Ty.button.copyWith(color: p.textDim, fontSize: 18)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_c.text.trim()),
          child: Text('ENTRAR', style: Ty.button.copyWith(color: p.accentText, fontSize: 18)),
        ),
      ],
    );
  }
}
