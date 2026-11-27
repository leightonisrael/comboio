import 'package:material_ui/material_ui.dart';

import '../app.dart';
import '../core/peer_link.dart';
import '../core/room_controller.dart';
import '../core/settings_store.dart';
import '../design/tokens.dart';
import '../design/widgets.dart';
import 'settings_screen.dart';

class RoomScreen extends StatelessWidget {
  const RoomScreen({super.key});

  Future<void> _confirmLeave(BuildContext context, RoomController room) async {
    final p = context.pal;
    final leave = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Rd.lg)),
      ),
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Sp.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                room.isHost ? 'ENCERRAR A SALA?' : 'SAIR DA SALA?',
                textAlign: TextAlign.center,
                style: Ty.headline.copyWith(color: p.text),
              ),
              if (room.isHost) ...[
                const SizedBox(height: Sp.sm),
                Text(
                  'Todos os pilotos serão desconectados.',
                  textAlign: TextAlign.center,
                  style: Ty.body.copyWith(color: p.textDim),
                ),
              ],
              const SizedBox(height: Sp.lg),
              BigButton(
                label: room.isHost ? 'Encerrar' : 'Sair',
                kind: BigButtonKind.danger,
                onPressed: () => Navigator.of(sheet).pop(true),
              ),
              const SizedBox(height: Sp.md),
              BigButton(
                label: 'Continuar na conversa',
                kind: BigButtonKind.outlined,
                onPressed: () => Navigator.of(sheet).pop(false),
              ),
            ],
          ),
        ),
      ),
    );
    if (leave == true) await room.leave();
  }

  @override
  Widget build(BuildContext context) {
    final room = Deps.of(context).room;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave(context, room);
      },
      child: Scaffold(
        body: SafeArea(
          child: ListenableBuilder(
            listenable: room,
            builder: (context, _) {
              final p = context.pal;
              final pilots = room.pilots.values.toList();
              return Padding(
                padding: const EdgeInsets.fromLTRB(Sp.md, Sp.sm, Sp.md, Sp.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(
                      room: room,
                      onLeave: () => _confirmLeave(context, room),
                    ),
                    if (room.phase == RoomPhase.reconnecting) ...[
                      const SizedBox(height: Sp.sm),
                      _Banner(
                        color: p.danger,
                        icon: Icons.wifi_off_rounded,
                        text: 'FORA DO ALCANCE · reconectando sozinho',
                      ),
                    ],
                    const SizedBox(height: Sp.md),
                    Expanded(
                      child: room.phase == RoomPhase.starting
                          ? Center(
                              child: CircularProgressIndicator(color: p.accent),
                            )
                          : pilots.isEmpty
                          ? _Waiting(room: room)
                          : _PilotArea(pilots: pilots),
                    ),
                    const SizedBox(height: Sp.md),
                    Rise(
                      delay: const Duration(milliseconds: 120),
                      child: _SelfBar(room: room),
                    ),
                    const SizedBox(height: Sp.md),
                    Rise(
                      delay: const Duration(milliseconds: 200),
                      child: _VolumeRow(room: room),
                    ),
                    const SizedBox(height: Sp.md),
                    Rise(
                      delay: const Duration(milliseconds: 280),
                      child: _Controls(room: room),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.room, required this.onLeave});

  final RoomController room;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Row(
      children: [
        Material(
          color: p.surfaceHigh,
          borderRadius: BorderRadius.circular(Rd.sm),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onLeave,
            child: SizedBox(
              height: Touch.min,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Sp.md),
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 28, color: p.danger),
                    const SizedBox(width: Sp.sm),
                    Text('SAIR', style: Ty.button.copyWith(color: p.text)),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: Sp.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                room.roomName.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Ty.title.copyWith(color: p.text),
              ),
              Text(
                room.isHost ? 'PIN ${room.pin}' : 'Conectado como convidado',
                style: Ty.label.copyWith(color: p.textDim),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Configurações',
          iconSize: 30,
          constraints: const BoxConstraints(
            minWidth: Touch.min,
            minHeight: Touch.min,
          ),
          icon: Icon(Icons.settings_rounded, color: p.text),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
          ),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.color, required this.icon, required this.text});

  final Color color;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Sp.md,
        vertical: Sp.sm + Sp.xs,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(Rd.sm),
      ),
      child: Row(
        children: [
          Icon(icon, size: 28, color: p.onAccent),
          const SizedBox(width: Sp.sm + Sp.xs),
          Expanded(
            child: Text(
              text,
              style: Ty.button.copyWith(color: p.onAccent, fontSize: 19),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sala criada, ninguém entrou ainda: mostra como o outro piloto entra.
class _Waiting extends StatelessWidget {
  const _Waiting({required this.room});

  final RoomController room;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    if (!room.isHost) {
      return Center(
        child: Text(
          'Conectando aos pilotos…',
          style: Ty.title.copyWith(color: p.textDim),
        ),
      );
    }
    final ips = room.localIps;
    return Panel(
      padding: const EdgeInsets.all(Sp.lg),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Text(
              'AGUARDANDO PILOTOS',
              style: Ty.title.copyWith(color: p.textDim),
            ),
            const SizedBox(height: Sp.md),
            Text('PIN DA SALA', style: Ty.label.copyWith(color: p.textDim)),
            FittedBox(
              child: Text(
                '${room.pin.substring(0, 3)} ${room.pin.substring(3)}',
                style: Ty.display.copyWith(
                  color: p.accentText,
                  fontSize: 72,
                  letterSpacing: 4,
                ),
              ),
            ),
            const SizedBox(height: Sp.md),
            if (ips.isEmpty) ...[
              Icon(Icons.warning_rounded, size: 40, color: p.warn),
              const SizedBox(height: Sp.sm),
              Text(
                'Este celular não está em nenhuma rede local. Ligue o hotspot (roteador Wi-Fi) '
                'para o outro piloto conectar.',
                textAlign: TextAlign.center,
                style: Ty.body.copyWith(color: p.text),
              ),
              const SizedBox(height: Sp.md),
              BigButton(
                label: 'Abrir hotspot',
                kind: BigButtonKind.quiet,
                height: Touch.min,
                onPressed: () =>
                    Deps.of(context).platform.openSettings('hotspot'),
              ),
            ] else ...[
              Text(
                'O outro piloto conecta no seu Wi-Fi, abre o Comboio e toca na sala.',
                textAlign: TextAlign.center,
                style: Ty.body.copyWith(color: p.text),
              ),
              const SizedBox(height: Sp.sm),
              Text(
                'Endereço: ${ips.join('  ·  ')}',
                textAlign: TextAlign.center,
                style: Ty.label.copyWith(color: p.textDim),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PilotArea extends StatelessWidget {
  const _PilotArea({required this.pilots});

  final List<PilotView> pilots;

  @override
  Widget build(BuildContext context) {
    if (pilots.length == 1) {
      return Center(
        child: SingleChildScrollView(child: _PilotHero(view: pilots.first)),
      );
    }
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: Sp.md,
      crossAxisSpacing: Sp.md,
      childAspectRatio: 0.95,
      children: [for (final v in pilots) _PilotCard(view: v)],
    );
  }
}

({Color color, String label, double pulse}) _linkLook(Palette p, PilotView v) {
  if (v.state == LinkState.connected) {
    if (v.muted) return (color: p.textDim, label: 'MUDO', pulse: 0);
    if (v.talking) return (color: p.live, label: 'FALANDO', pulse: 0);
    return (color: p.live, label: 'CONECTADO', pulse: 0);
  }
  return switch (v.state) {
    LinkState.degraded => (color: p.warn, label: 'SINAL FRACO', pulse: 1),
    LinkState.lost => (color: p.danger, label: 'FORA DO ALCANCE', pulse: 2),
    _ => (color: p.textDim, label: 'CONECTANDO', pulse: 1),
  };
}

class _PilotHero extends StatelessWidget {
  const _PilotHero({required this.view});

  final PilotView view;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final look = _linkLook(p, view);
    final own = pilotColor(view.info.color);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SweepHalo(
          color: p.accent,
          size: 232,
          child: StatusRing(
            color: look.color,
            pulseHz: look.pulse,
            glow: view.talking,
            size: 200,
            thickness: 8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                VoiceWave(
                  level: view.level,
                  color: own,
                  active: view.talking,
                  height: 56,
                ),
                const SizedBox(height: Sp.sm),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Sp.lg),
                  child: Text(
                    view.info.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Ty.headline.copyWith(color: p.text),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Sp.md),
        Text(look.label, style: Ty.headline.copyWith(color: look.color)),
        const SizedBox(height: Sp.sm),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinkBars(quality: view.quality, color: look.color),
            const SizedBox(width: Sp.sm),
            Text(
              'LINK ${view.quality}/4',
              style: Ty.label.copyWith(color: p.textDim),
            ),
          ],
        ),
      ],
    );
  }
}

class _PilotCard extends StatelessWidget {
  const _PilotCard({required this.view});

  final PilotView view;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final look = _linkLook(p, view);
    final own = pilotColor(view.info.color);
    return Container(
      padding: const EdgeInsets.all(Sp.md),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(Rd.md),
        border: Border.all(color: look.color, width: view.talking ? 4 : 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          VoiceWave(level: view.level, color: own, active: view.talking),
          const SizedBox(height: Sp.sm),
          Text(
            view.info.name.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Ty.title.copyWith(color: p.text),
          ),
          const SizedBox(height: Sp.xs),
          Text(
            look.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Ty.label.copyWith(color: look.color),
          ),
          const SizedBox(height: Sp.sm),
          LinkBars(quality: view.quality, color: look.color),
        ],
      ),
    );
  }
}

/// Faixa "você": mostra se o seu microfone está indo para os outros.
class _SelfBar extends StatelessWidget {
  const _SelfBar({required this.room});

  final RoomController room;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final settings = Deps.of(context).settings;
    final String status;
    final Color color;
    if (room.muted) {
      status = 'MUDO';
      color = p.danger;
    } else if (room.transmitting) {
      status = 'TRANSMITINDO';
      color = p.live;
    } else {
      status = room.mode == TalkMode.ptt
          ? 'SEGURE PARA FALAR'
          : 'AGUARDANDO VOZ';
      color = p.textDim;
    }
    return Panel(
      padding: const EdgeInsets.symmetric(
        horizontal: Sp.md,
        vertical: Sp.sm + Sp.xs,
      ),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: pilotColor(settings.colorIndex),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: Sp.sm + Sp.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VOCÊ · ${settings.name}'.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Ty.label.copyWith(color: p.textDim),
                ),
                Text(status, style: Ty.title.copyWith(color: color)),
              ],
            ),
          ),
          VoiceWave(
            level: room.localLevel,
            color: pilotColor(settings.colorIndex),
            active: room.transmitting,
            height: 36,
          ),
        ],
      ),
    );
  }
}

class _VolumeRow extends StatelessWidget {
  const _VolumeRow({required this.room});

  final RoomController room;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return SizedBox(
      height: Touch.min,
      child: Row(
        children: [
          Semantics(
            button: true,
            label: room.deafened
                ? 'Fone mudo. Toque para voltar a ouvir.'
                : 'Silenciar o fone',
            child: Material(
              color: room.deafened ? p.danger : p.surfaceHigh,
              borderRadius: BorderRadius.circular(Rd.sm),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: room.toggleDeafen,
                child: SizedBox(
                  width: Touch.min,
                  height: Touch.min,
                  child: Icon(
                    room.deafened
                        ? Icons.volume_off_rounded
                        : Icons.volume_down_rounded,
                    size: 30,
                    color: room.deafened ? p.onAccent : p.text,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Slider(
              value: room.deafened ? 0 : room.volume,
              min: 0,
              max: 1,
              divisions: 10,
              semanticFormatterCallback: (v) =>
                  'Volume ${(v * 100).round()} por cento',
              onChanged: room.setVolume,
            ),
          ),
          Semantics(
            button: true,
            label: room.speaker
                ? 'Alto-falante ligado. Toque para voltar ao capacete.'
                : 'Ouvir pelo alto-falante do celular',
            child: Material(
              color: room.speaker ? p.accent : p.surfaceHigh,
              borderRadius: BorderRadius.circular(Rd.sm),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: room.toggleSpeaker,
                child: SizedBox(
                  width: Touch.min,
                  height: Touch.min,
                  child: Icon(
                    Icons.volume_up_rounded,
                    size: 30,
                    color: room.speaker ? p.onAccent : p.text,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.room});

  final RoomController room;

  void _nextMode() {
    const order = TalkMode.values;
    room.setMode(order[(room.mode.index + 1) % order.length]);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final mute = Expanded(
      flex: 3,
      child: BigButton(
        label: room.muted ? 'Mudo' : 'Silenciar',
        icon: room.muted ? Icons.mic_off_rounded : Icons.mic_rounded,
        kind: room.muted ? BigButtonKind.danger : BigButtonKind.filled,
        onPressed: room.toggleMute,
      ),
    );
    final modeButton = Expanded(
      flex: 2,
      child: Semantics(
        button: true,
        label: 'Modo de fala: ${room.mode.spoken}. Toque para trocar.',
        child: Material(
          color: p.surfaceHigh,
          borderRadius: BorderRadius.circular(Rd.md),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _nextMode,
            child: SizedBox(
              height: Touch.primary,
              child: ExcludeSemantics(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('MODO', style: Ty.label.copyWith(color: p.textDim)),
                    Text(
                      room.mode.label,
                      style: Ty.button.copyWith(color: p.accentText),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (room.mode == TalkMode.ptt && !room.muted) ...[
          _PttButton(room: room),
          const SizedBox(height: Sp.md),
        ],
        Row(
          children: [
            modeButton,
            const SizedBox(width: Sp.md),
            mute,
          ],
        ),
      ],
    );
  }
}

/// Segurar para falar. Usa Listener para não soltar com a trepidação do dedo.
class _PttButton extends StatelessWidget {
  const _PttButton({required this.room});

  final RoomController room;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final down = room.pttDown;
    return Semantics(
      button: true,
      label: 'Segure para falar',
      child: Listener(
        onPointerDown: (_) => room.setPtt(true),
        onPointerUp: (_) => room.setPtt(false),
        onPointerCancel: (_) => room.setPtt(false),
        child: AnimatedContainer(
          duration: Dur.fast,
          height: Touch.ptt,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: down ? p.live : p.surface,
            borderRadius: BorderRadius.circular(Rd.lg),
            border: Border.all(color: down ? p.live : p.accent, width: 4),
          ),
          child: ExcludeSemantics(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.mic_rounded,
                  size: 48,
                  color: down ? p.onAccent : p.accentText,
                ),
                const SizedBox(height: Sp.sm),
                Text(
                  down ? 'FALANDO' : 'SEGURE PARA FALAR',
                  style: Ty.headline.copyWith(
                    color: down ? p.onAccent : p.text,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
