import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

enum BigButtonKind { filled, outlined, danger, quiet }

/// Botão principal: 72 dp de altura, utilizável com luva.
class BigButton extends StatelessWidget {
  const BigButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.kind = BigButtonKind.filled,
    this.height = Touch.primary,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final BigButtonKind kind;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final (Color bg, Color fg, Color? line) = switch (kind) {
      BigButtonKind.filled => (p.accent, p.onAccent, null),
      BigButtonKind.outlined => (Colors.transparent, p.text, p.text),
      BigButtonKind.danger => (p.danger, p.onAccent, null),
      BigButtonKind.quiet => (p.surfaceHigh, p.text, null),
    };
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Material(
          color: bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Rd.md),
            side: line == null ? BorderSide.none : BorderSide(color: line, width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled
                ? () {
                    HapticFeedback.lightImpact();
                    onPressed!();
                  }
                : null,
            child: SizedBox(
              height: height,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 32, color: fg),
                    const SizedBox(width: Sp.sm + Sp.xs),
                  ],
                  Flexible(
                    child: ExcludeSemantics(
                      child: Text(
                        label.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Ty.button.copyWith(color: fg),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Onda de voz: 5 barras cuja altura segue o nível de áudio (0..1).
class VoiceWave extends StatefulWidget {
  const VoiceWave({
    super.key,
    required this.level,
    required this.color,
    this.active = true,
    this.height = 44,
    this.bars = 5,
  });

  final double level;
  final Color color;
  final bool active;
  final double height;
  final int bars;

  @override
  State<VoiceWave> createState() => _VoiceWaveState();
}

class _VoiceWaveState extends State<VoiceWave> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  double _shown = 0;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final target = widget.active ? widget.level.clamp(0.0, 1.0) : 0.0;
          // Sobe rápido, desce devagar: a onda não "pisca".
          _shown += (target - _shown) * (target > _shown ? 0.5 : 0.12);
          return CustomPaint(
            size: Size(widget.bars * 14.0, widget.height),
            painter: _WavePainter(
              level: _shown,
              phase: _c.value * 2 * math.pi,
              color: widget.color,
              bars: widget.bars,
            ),
          );
        },
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.level,
    required this.phase,
    required this.color,
    required this.bars,
  });

  final double level;
  final double phase;
  final Color color;
  final int bars;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final slot = size.width / bars;
    final w = slot * 0.55;
    // Nível de fala real costuma ficar abaixo de 0,3: expande para a onda ser visível.
    final boosted = math.pow(level, 0.5).toDouble();
    for (var i = 0; i < bars; i++) {
      final centerWeight = 1 - (i - (bars - 1) / 2).abs() / bars;
      final wobble = 0.75 + 0.25 * math.sin(phase * 3 + i * 1.7);
      final h = math.max(6.0, size.height * boosted * centerWeight * wobble);
      final rect = Rect.fromCenter(
        center: Offset(slot * i + slot / 2, size.height / 2),
        width: w,
        height: h.clamp(6.0, size.height),
      );
      canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(w / 2)), paint);
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.level != level || old.phase != phase || old.color != color;
}

/// Anel de estado. Pulsa quando [pulseHz] > 0.
class StatusRing extends StatefulWidget {
  const StatusRing({
    super.key,
    required this.color,
    required this.child,
    this.size = 168,
    this.pulseHz = 0,
    this.thickness = 6,
  });

  final Color color;
  final Widget child;
  final double size;
  final double pulseHz;
  final double thickness;

  @override
  State<StatusRing> createState() => _StatusRingState();
}

class _StatusRingState extends State<StatusRing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(StatusRing old) {
    super.didUpdateWidget(old);
    if (old.pulseHz != widget.pulseHz) _sync();
  }

  void _sync() {
    if (widget.pulseHz > 0) {
      _c.duration = Duration(milliseconds: (1000 / widget.pulseHz).round());
      _c.repeat(reverse: true);
    } else {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final alpha = (widget.pulseHz > 0 && !reduce) ? 1 - 0.65 * _c.value : 1.0;
        return Container(
          width: widget.size,
          height: widget.size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.pal.surface,
            border: Border.all(
              color: widget.color.withValues(alpha: alpha),
              width: widget.thickness,
            ),
          ),
          child: child,
        );
      },
    );
  }
}

/// Quatro barras de qualidade do link, sempre com rótulo textual ao lado.
class LinkBars extends StatelessWidget {
  const LinkBars({super.key, required this.quality, required this.color});

  /// 0 a 4.
  final int quality;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final off = context.pal.border;
    return Semantics(
      label: 'Qualidade do link $quality de 4',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 4; i++)
            Container(
              width: 7,
              height: 8.0 + i * 5,
              margin: const EdgeInsets.only(right: 3),
              decoration: BoxDecoration(
                color: i < quality ? color : off,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }
}

/// Cartão padrão.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(Sp.md)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(Rd.md),
        border: Border.all(color: p.border),
      ),
      child: child,
    );
  }
}
