import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
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
            side: line == null
                ? BorderSide.none
                : BorderSide(color: line, width: 2),
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

class _VoiceWaveState extends State<VoiceWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();
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
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(w / 2)),
        paint,
      );
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
    this.glow = false,
  });

  final Color color;
  final Widget child;
  final double size;
  final double pulseHz;
  final double thickness;

  /// Halo que respira em volta do anel: usado enquanto o piloto fala.
  final bool glow;

  @override
  State<StatusRing> createState() => _StatusRingState();
}

class _StatusRingState extends State<StatusRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(StatusRing old) {
    super.didUpdateWidget(old);
    if (old.pulseHz != widget.pulseHz || old.glow != widget.glow) _sync();
  }

  void _sync() {
    final hz = widget.pulseHz > 0 ? widget.pulseHz : (widget.glow ? 0.8 : 0.0);
    if (hz > 0) {
      _c.duration = Duration(milliseconds: (1000 / hz).round());
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
        final alpha = (widget.pulseHz > 0 && !reduce)
            ? 1 - 0.65 * _c.value
            : 1.0;
        final v = Curves.easeInOut.transform(_c.value);
        return AnimatedContainer(
          duration: Dur.base,
          width: widget.size,
          height: widget.size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.pal.surface,
            boxShadow: [
              if (widget.glow && !reduce)
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.22 + 0.22 * v),
                  blurRadius: 32 + 30 * v,
                  spreadRadius: 2 + 10 * v,
                ),
            ],
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

/// Entrada suave: o conteúdo sobe 18 px e aparece. [delay] escalona os blocos.
class Rise extends StatelessWidget {
  const Rise({super.key, required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;
    const run = Duration(milliseconds: 420);
    final total = run + delay;
    final start = delay.inMilliseconds / total.inMilliseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - t)),
          child: child,
        ),
      ),
    );
  }
}

/// Arco laranja que gira devagar em volta do piloto em destaque: sala "viva".
class SweepHalo extends StatefulWidget {
  const SweepHalo({
    super.key,
    required this.color,
    required this.size,
    required this.child,
  });

  final Color color;
  final double size;
  final Widget child;

  @override
  State<SweepHalo> createState() => _SweepHaloState();
}

class _SweepHaloState extends State<SweepHalo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    return SizedBox.square(
      dimension: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (!reduce)
            ExcludeSemantics(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) => CustomPaint(
                    size: Size.square(widget.size),
                    painter: _SweepPainter(_c.value, widget.color),
                  ),
                ),
              ),
            ),
          widget.child,
        ],
      ),
    );
  }
}

class _SweepPainter extends CustomPainter {
  _SweepPainter(this.t, this.color);

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..shader = SweepGradient(
        colors: [
          color.withValues(alpha: 0),
          color.withValues(alpha: 0),
          color.withValues(alpha: 0.6),
        ],
        stops: const [0, 0.68, 1],
        transform: GradientRotation(t * 2 * math.pi),
      ).createShader(rect);
    canvas.drawCircle(rect.center, size.shortestSide / 2 - 4, paint);
  }

  @override
  bool shouldRepaint(_SweepPainter old) => old.t != t || old.color != color;
}

/// Ondas de radar: três anéis que se expandem enquanto o app procura salas.
class RadarPulse extends StatefulWidget {
  const RadarPulse({super.key, required this.color, this.size = 220});

  final Color color;
  final double size;

  @override
  State<RadarPulse> createState() => _RadarPulseState();
}

class _RadarPulseState extends State<RadarPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            size: Size.square(widget.size),
            painter: _RadarPainter(_c.value, widget.color),
          ),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter(this.t, this.color);

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxR = size.shortestSide / 2;
    for (var i = 0; i < 3; i++) {
      final p = (t + i / 3) % 1.0;
      canvas.drawCircle(
        center,
        maxR * (0.2 + 0.8 * p),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.withValues(alpha: 0.85 * (1 - p)),
      );
    }
    canvas.drawCircle(center, 7, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.t != t || old.color != color;
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
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Sp.md),
  });

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
