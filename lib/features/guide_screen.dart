import 'package:material_ui/material_ui.dart';

import '../app.dart';
import '../design/tokens.dart';
import '../design/widgets.dart';

/// Guia "Como conectar": explica a ligação capacete → celular → celular → capacete
/// e o passo a passo de quem cria e de quem entra na sala.
class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final platform = Deps.of(context).platform;
    return Scaffold(
      appBar: AppBar(
        title: const Text('COMO CONECTAR'),
        toolbarHeight: Touch.min,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Sp.md, Sp.sm, Sp.md, Sp.md),
                children: [
                  const Rise(child: _LinkDiagram()),
                  const SizedBox(height: Sp.sm),
                  Rise(
                    delay: const Duration(milliseconds: 80),
                    child: Text(
                      'Cada piloto usa o próprio celular com o próprio capacete. '
                      'Os dois celulares conversam por Wi-Fi, sem internet e sem '
                      'sinal de operadora.',
                      style: Ty.body.copyWith(color: p.textDim),
                    ),
                  ),
                  const SizedBox(height: Sp.lg),
                  Rise(
                    delay: const Duration(milliseconds: 140),
                    child: _Step(
                      number: '1',
                      title: 'Os dois: liguem o capacete no celular',
                      body:
                          'Pareie o intercomunicador do capacete no Bluetooth do '
                          'celular, como um fone comum. Serve qualquer marca que '
                          'atenda ligações.',
                      action: 'Abrir Bluetooth',
                      onAction: () => platform.openSettings('bluetooth'),
                    ),
                  ),
                  Rise(
                    delay: const Duration(milliseconds: 200),
                    child: _Step(
                      number: '2',
                      title: 'Quem cria a sala: ligue o roteador Wi-Fi',
                      body:
                          'Ative o roteador Wi-Fi do celular (hotspot ou Acesso '
                          'Pessoal) e toque em Criar sala. A tela mostra um PIN '
                          'de 6 números.',
                      action: 'Abrir roteador Wi-Fi',
                      onAction: () => platform.openSettings('hotspot'),
                    ),
                  ),
                  Rise(
                    delay: const Duration(milliseconds: 260),
                    child: _Step(
                      number: '3',
                      title: 'Quem entra: conecte no Wi-Fi do outro piloto',
                      body:
                          'Entre na rede Wi-Fi criada pelo outro celular, abra o '
                          'Comboio e toque na sala que aparecer. O PIN só é '
                          'pedido na primeira vez.',
                      action: 'Abrir Wi-Fi',
                      onAction: () => platform.openSettings('wifi'),
                    ),
                  ),
                  Rise(
                    delay: const Duration(milliseconds: 320),
                    child: const _Step(
                      number: '4',
                      title: 'Guardem o celular e rodem',
                      body:
                          'A conversa continua com a tela bloqueada. Se as motos '
                          'se afastarem, ela volta sozinha quando se '
                          'aproximarem: você ouve o aviso no capacete.',
                    ),
                  ),
                  const SizedBox(height: Sp.sm),
                  Rise(
                    delay: const Duration(milliseconds: 380),
                    child: Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BOM SABER',
                            style: Ty.title.copyWith(color: p.accentText),
                          ),
                          const SizedBox(height: Sp.sm),
                          const _Tip(
                            icon: Icons.social_distance_rounded,
                            text:
                                'O alcance é de algumas dezenas de metros. '
                                'Funciona melhor com as motos próximas.',
                          ),
                          const _Tip(
                            icon: Icons.smartphone_rounded,
                            text:
                                'Celular em bolso externo ou no suporte do '
                                'guidão alcança mais que no bolso de dentro.',
                          ),
                          const _Tip(
                            icon: Icons.volume_off_rounded,
                            text:
                                'Sem som no capacete? Confira se ele aparece '
                                'como conectado no Bluetooth do celular.',
                          ),
                          const _Tip(
                            icon: Icons.music_note_rounded,
                            text:
                                'Durante a conversa, a música toca com som de '
                                'ligação. A voz do GPS continua normal.',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Sp.md, 0, Sp.md, Sp.md),
              child: BigButton(
                label: 'Entendi',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Desenho da ligação: capacete, celular, ondas de Wi-Fi, celular, capacete.
class _LinkDiagram extends StatelessWidget {
  const _LinkDiagram();

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    Widget node(IconData icon, String label, Color color) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: p.surfaceHigh,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 3),
          ),
          child: Icon(icon, size: 28, color: p.text),
        ),
        const SizedBox(height: Sp.xs),
        Text(label, style: Ty.label.copyWith(color: p.textDim)),
      ],
    );
    Widget link(String label, Color color) => Expanded(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: Ty.label.copyWith(color: color, fontSize: 12),
              ),
            ),
            const SizedBox(height: 2),
            Container(height: 3, color: color),
          ],
        ),
      ),
    );
    return Semantics(
      label:
          'Capacete ligado ao celular por Bluetooth. Os dois celulares ligados '
          'por Wi-Fi. O outro celular ligado ao outro capacete por Bluetooth.',
      child: ExcludeSemantics(
        child: Panel(
          padding: const EdgeInsets.symmetric(
            horizontal: Sp.sm,
            vertical: Sp.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              node(Icons.sports_motorsports_rounded, 'Você', pilotColor(0)),
              link('Bluetooth', p.textDim),
              node(Icons.smartphone_rounded, 'Celular', pilotColor(0)),
              link('Wi-Fi', p.accentText),
              node(Icons.smartphone_rounded, 'Celular', pilotColor(2)),
              link('Bluetooth', p.textDim),
              node(Icons.sports_motorsports_rounded, 'Piloto 2', pilotColor(2)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.title,
    required this.body,
    this.action,
    this.onAction,
  });

  final String number;
  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.md),
      child: Panel(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: p.accent,
                shape: BoxShape.circle,
              ),
              child: Text(
                number,
                style: Ty.headline.copyWith(color: p.onAccent, fontSize: 28),
              ),
            ),
            const SizedBox(width: Sp.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Ty.title.copyWith(color: p.text)),
                  const SizedBox(height: Sp.xs),
                  Text(body, style: Ty.body.copyWith(color: p.textDim)),
                  if (action != null) ...[
                    const SizedBox(height: Sp.sm + Sp.xs),
                    BigButton(
                      label: action!,
                      kind: BigButtonKind.quiet,
                      height: Touch.min,
                      onPressed: onAction,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.sm + Sp.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 26, color: p.accentText),
          const SizedBox(width: Sp.sm + Sp.xs),
          Expanded(
            child: Text(text, style: Ty.body.copyWith(color: p.text)),
          ),
        ],
      ),
    );
  }
}
