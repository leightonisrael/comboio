import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../design/tokens.dart';

/// Teclado numérico com teclas de 72 dp. Retorna o PIN de 6 dígitos ou null.
Future<String?> showPinPad(BuildContext context, {required String title}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.pal.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Rd.lg)),
    ),
    builder: (_) => _PinPad(title: title),
  );
}

class _PinPad extends StatefulWidget {
  const _PinPad({required this.title});

  final String title;

  @override
  State<_PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<_PinPad> {
  String _pin = '';

  void _press(String d) {
    if (_pin.length >= 6) return;
    HapticFeedback.selectionClick();
    setState(() => _pin += d);
    if (_pin.length == 6) {
      final pin = _pin;
      Future<void>.delayed(const Duration(milliseconds: 150), () {
        if (mounted) Navigator.of(context).pop(pin);
      });
    }
  }

  void _back() {
    if (_pin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    Widget key(String label, {VoidCallback? onTap, IconData? icon}) => Expanded(
      child: Padding(
        padding: const EdgeInsets.all(Sp.xs + 2),
        child: Material(
          color: p.surfaceHigh,
          borderRadius: BorderRadius.circular(Rd.sm),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: Touch.primary,
              child: Center(
                child: icon != null
                    ? Icon(icon, size: 32, color: p.text)
                    : Text(label, style: Ty.headline.copyWith(color: p.text)),
              ),
            ),
          ),
        ),
      ),
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Sp.md, Sp.lg, Sp.md, Sp.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Ty.title.copyWith(color: p.text),
            ),
            const SizedBox(height: Sp.xs),
            Text(
              'Digite o PIN que aparece na tela do outro piloto',
              textAlign: TextAlign.center,
              style: Ty.body.copyWith(color: p.textDim),
            ),
            const SizedBox(height: Sp.md),
            Semantics(
              label: 'PIN, ${_pin.length} de 6 dígitos',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 6; i++)
                    Container(
                      width: 40,
                      height: 56,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: p.bg,
                        borderRadius: BorderRadius.circular(Rd.sm),
                        border: Border.all(
                          color: i == _pin.length ? p.accent : p.border,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        i < _pin.length ? _pin[i] : '',
                        style: Ty.headline.copyWith(color: p.text),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Sp.md),
            for (final row in const [
              ['1', '2', '3'],
              ['4', '5', '6'],
              ['7', '8', '9'],
            ])
              Row(
                children: [for (final d in row) key(d, onTap: () => _press(d))],
              ),
            Row(
              children: [
                key(
                  '',
                  icon: Icons.close_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
                key('0', onTap: () => _press('0')),
                key('', icon: Icons.backspace_rounded, onTap: _back),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
