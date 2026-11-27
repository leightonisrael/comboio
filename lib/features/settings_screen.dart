import 'package:material_ui/material_ui.dart';

import '../app.dart';
import '../core/settings_store.dart';
import '../design/tokens.dart';
import '../design/widgets.dart';
import 'onboarding_screen.dart' show ColorPickerRow;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  TextEditingController? _name;

  @override
  void dispose() {
    _name?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deps = Deps.of(context);
    final s = deps.settings;
    final room = deps.room;
    _name ??= TextEditingController(text: s.name);
    final p = context.pal;
    return Scaffold(
      appBar: AppBar(
        title: const Text('CONFIGURAÇÕES'),
        toolbarHeight: Touch.min,
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([s, room]),
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(Sp.md),
          children: [
            _Section('PILOTO', [
              Text('Nome', style: Ty.label.copyWith(color: p.textDim)),
              const SizedBox(height: Sp.sm),
              TextField(
                controller: _name,
                maxLength: 16,
                enabled: !room.inRoom,
                textCapitalization: TextCapitalization.words,
                style: Ty.title.copyWith(color: p.text),
                decoration: InputDecoration(
                  counterText: '',
                  helperText: room.inRoom
                      ? 'Saia da sala para trocar o nome.'
                      : null,
                ),
                onChanged: (v) => s.name = v,
              ),
              const SizedBox(height: Sp.md),
              Text('Cor', style: Ty.label.copyWith(color: p.textDim)),
              const SizedBox(height: Sp.sm),
              ColorPickerRow(
                selected: s.colorIndex,
                onChanged: (i) => s.colorIndex = i,
              ),
            ]),
            _Section('VOZ', [
              Text('Modo de fala', style: Ty.label.copyWith(color: p.textDim)),
              const SizedBox(height: Sp.sm),
              _Choice<TalkMode>(
                value: s.mode,
                options: const {
                  TalkMode.open: 'ABERTO',
                  TalkMode.vox: 'VOX',
                  TalkMode.ptt: 'PTT',
                },
                onChanged: (m) => room.inRoom ? room.setMode(m) : s.mode = m,
              ),
              const SizedBox(height: Sp.sm),
              Text(switch (s.mode) {
                TalkMode.open =>
                  'Microfone sempre aberto. O mais simples e confiável.',
                TalkMode.vox =>
                  'Só transmite quando você fala. Ajuste a sensibilidade com a moto andando.',
                TalkMode.ptt =>
                  'Só transmite enquanto você segura o botão na tela.',
              }, style: Ty.body.copyWith(color: p.textDim)),
              const SizedBox(height: Sp.md),
              Text(
                'Sensibilidade do VOX',
                style: Ty.label.copyWith(color: p.textDim),
              ),
              const SizedBox(height: Sp.sm),
              _VoxMeter(
                level: room.inRoom ? room.localLevel : 0,
                threshold: s.voxThreshold,
              ),
              SizedBox(
                height: Touch.min,
                child: Slider(
                  // Direita = mais sensível = limiar menor.
                  value: (0.30 - s.voxThreshold).clamp(0.0, 0.29),
                  min: 0,
                  max: 0.29,
                  onChanged: (v) => s.voxThreshold = 0.30 - v,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Menos sensível',
                    style: Ty.label.copyWith(color: p.textDim),
                  ),
                  Text(
                    'Mais sensível',
                    style: Ty.label.copyWith(color: p.textDim),
                  ),
                ],
              ),
              if (!room.inRoom) ...[
                const SizedBox(height: Sp.sm),
                Text(
                  'O medidor ao vivo aparece durante uma conversa.',
                  style: Ty.label.copyWith(color: p.textDim),
                ),
              ],
            ]),
            _Section('ÁUDIO', [
              Text('Qualidade', style: Ty.label.copyWith(color: p.textDim)),
              const SizedBox(height: Sp.sm),
              _Choice<int>(
                value: s.bitrate,
                options: const {
                  16000: 'ECONÔMICA',
                  24000: 'PADRÃO',
                  32000: 'ALTA',
                },
                onChanged: (b) => s.bitrate = b,
              ),
              const SizedBox(height: Sp.sm),
              Text(
                'Vale a partir da próxima conexão.',
                style: Ty.label.copyWith(color: p.textDim),
              ),
              _Toggle(
                label: 'Avisos por voz no capacete',
                value: s.voiceAlerts,
                onChanged: (v) => s.voiceAlerts = v,
              ),
            ]),
            _Section('TELA', [
              Text('Tema', style: Ty.label.copyWith(color: p.textDim)),
              const SizedBox(height: Sp.sm),
              _Choice<ThemeMode>(
                value: s.themeMode,
                options: const {
                  ThemeMode.dark: 'ESCURO',
                  ThemeMode.light: 'CLARO',
                  ThemeMode.system: 'SISTEMA',
                },
                onChanged: (m) => s.themeMode = m,
              ),
              _Toggle(
                label: 'Manter a tela acesa na sala',
                value: s.keepScreenOn,
                onChanged: (v) {
                  s.keepScreenOn = v;
                  if (room.inRoom) deps.platform.keepScreenOn(v);
                },
              ),
            ]),
            _Section('SEGURANÇA', [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PIN das suas salas',
                          style: Ty.label.copyWith(color: p.textDim),
                        ),
                        Text(
                          '${s.pin.substring(0, 3)} ${s.pin.substring(3)}',
                          style: Ty.headline.copyWith(
                            color: p.text,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 150,
                    child: BigButton(
                      label: 'Trocar',
                      kind: BigButtonKind.quiet,
                      height: Touch.min,
                      onPressed: room.inRoom ? null : s.regeneratePin,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Sp.sm),
              Text(
                'Quem já entrou com o PIN atual entra de novo com um toque. '
                'Trocar o PIN exige parear de novo.',
                style: Ty.body.copyWith(color: p.textDim),
              ),
              const SizedBox(height: Sp.md),
              BigButton(
                label: 'Esquecer ${s.knownCount} sala(s) conhecida(s)',
                kind: BigButtonKind.quiet,
                height: Touch.min,
                onPressed: s.knownCount == 0 ? null : s.forgetAll,
              ),
            ]),
            const SizedBox(height: Sp.md),
            Text(
              'Comboio 0.1.1',
              textAlign: TextAlign.center,
              style: Ty.label.copyWith(color: p.textDim),
            ),
            const SizedBox(height: Sp.lg),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.children);

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: Sp.xs, bottom: Sp.sm),
            child: Text(
              title,
              style: Ty.title.copyWith(color: context.pal.accentText),
            ),
          ),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

/// Seletor segmentado com alvos de 64 dp.
class _Choice<T> extends StatelessWidget {
  const _Choice({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Row(
      children: [
        for (final e in options.entries)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Semantics(
                button: true,
                selected: e.key == value,
                label: e.value,
                child: Material(
                  color: e.key == value ? p.accent : p.surfaceHigh,
                  borderRadius: BorderRadius.circular(Rd.sm),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onChanged(e.key),
                    child: SizedBox(
                      height: Touch.min,
                      child: Center(
                        child: ExcludeSemantics(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: Sp.sm,
                              ),
                              child: Text(
                                e.value,
                                style: Ty.button.copyWith(
                                  fontSize: 19,
                                  color: e.key == value ? p.onAccent : p.text,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return MergeSemantics(
      child: InkWell(
        onTap: () => onChanged(!value),
        child: SizedBox(
          height: Touch.min,
          child: Row(
            children: [
              Expanded(
                child: Text(label, style: Ty.body.copyWith(color: p.text)),
              ),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nível do microfone ao vivo com a marca do limiar do VOX.
class _VoxMeter extends StatelessWidget {
  const _VoxMeter({required this.level, required this.threshold});

  final double level;
  final double threshold;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    const scale = 0.30;
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final lv = (level / scale).clamp(0.0, 1.0) * w;
        final th = (threshold / scale).clamp(0.0, 1.0) * w;
        return SizedBox(
          height: 24,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: p.surfaceHigh,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              AnimatedContainer(
                duration: Dur.fast,
                width: lv,
                decoration: BoxDecoration(
                  color: level >= threshold ? p.live : p.textDim,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              Positioned(
                left: th - 2,
                top: 0,
                bottom: 0,
                child: Container(width: 4, color: p.accent),
              ),
            ],
          ),
        );
      },
    );
  }
}
