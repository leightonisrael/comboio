import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../app.dart';
import '../design/tokens.dart';
import '../design/widgets.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _name = TextEditingController();
  int _color = 0;
  bool _busy = false;
  bool _micDenied = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final deps = Deps.of(context);
    setState(() => _busy = true);
    final ok = await deps.platform.ensurePermissions();
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _busy = false;
        _micDenied = true;
      });
      return;
    }
    deps.settings.name = _name.text;
    deps.settings.colorIndex = _color;
    deps.settings.onboarded = true;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Sp.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  children: [
                    const SizedBox(height: Sp.md),
                    Text(
                      'COMBOIO',
                      style: Ty.display.copyWith(color: p.accentText),
                    ),
                    const SizedBox(height: Sp.sm),
                    Text(
                      'Conversa entre pilotos, sem internet.',
                      style: Ty.title.copyWith(color: p.text),
                    ),
                    const SizedBox(height: Sp.xl),
                    _Reason(
                      icon: Icons.mic_rounded,
                      title: 'Microfone',
                      body:
                          'Para os outros pilotos ouvirem você pelo capacete.',
                    ),
                    if (Platform.isAndroid) ...[
                      _Reason(
                        icon: Icons.bluetooth_rounded,
                        title: 'Dispositivos próximos',
                        body:
                            'Para usar o microfone e o fone do capacete Bluetooth.',
                      ),
                      _Reason(
                        icon: Icons.notifications_rounded,
                        title: 'Notificação',
                        body: 'Mantém a conversa ativa com a tela bloqueada.',
                      ),
                    ] else
                      _Reason(
                        icon: Icons.wifi_rounded,
                        title: 'Rede local',
                        body: 'Para os celulares se encontrarem sem internet.',
                      ),
                    const SizedBox(height: Sp.lg),
                    Text(
                      'SEU NOME',
                      style: Ty.label.copyWith(color: p.textDim),
                    ),
                    const SizedBox(height: Sp.sm),
                    TextField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      maxLength: 16,
                      style: Ty.title.copyWith(color: p.text),
                      decoration: const InputDecoration(
                        hintText: 'Piloto',
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: Sp.lg),
                    Text('SUA COR', style: Ty.label.copyWith(color: p.textDim)),
                    const SizedBox(height: Sp.sm),
                    ColorPickerRow(
                      selected: _color,
                      onChanged: (i) => setState(() => _color = i),
                    ),
                    if (_micDenied) ...[
                      const SizedBox(height: Sp.lg),
                      Text(
                        'Sem o microfone o app não funciona. Toque de novo para permitir; '
                        'se o pedido não aparecer, abra os ajustes do app.',
                        style: Ty.body.copyWith(color: p.danger),
                      ),
                      const SizedBox(height: Sp.sm),
                      BigButton(
                        label: 'Abrir ajustes',
                        kind: BigButtonKind.quiet,
                        height: Touch.min,
                        onPressed: () =>
                            Deps.of(context).platform.openSettings('app'),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: Sp.md),
              BigButton(
                label: _busy ? 'Aguarde…' : 'Permitir e continuar',
                onPressed: _busy ? null : _continue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Reason extends StatelessWidget {
  const _Reason({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 32, color: p.accentText),
          const SizedBox(width: Sp.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Ty.title.copyWith(color: p.text)),
                Text(body, style: Ty.body.copyWith(color: p.textDim)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Seis bolinhas grandes para escolher a cor do piloto.
class ColorPickerRow extends StatelessWidget {
  const ColorPickerRow({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < pilotColors.length; i++)
          Semantics(
            button: true,
            selected: i == selected,
            label: 'Cor ${i + 1}',
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: pilotColors[i],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: i == selected ? p.text : Colors.transparent,
                    width: 4,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
