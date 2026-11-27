import 'package:flutter/material.dart';

/// Paleta semântica. Cada cor tem um significado fixo (ver docs/02-design.md).
@immutable
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.bg,
    required this.surface,
    required this.surfaceHigh,
    required this.border,
    required this.text,
    required this.textDim,
    required this.accent,
    required this.onAccent,
    required this.accentText,
    required this.live,
    required this.warn,
    required this.danger,
  });

  final Color bg;
  final Color surface;
  final Color surfaceHigh;
  final Color border;
  final Color text;
  final Color textDim;
  final Color accent;
  final Color onAccent;
  final Color accentText;
  final Color live;
  final Color warn;
  final Color danger;

  static const dark = Palette(
    bg: Color(0xFF0A0B0D),
    surface: Color(0xFF14161A),
    surfaceHigh: Color(0xFF1E2127),
    border: Color(0xFF2C3038),
    text: Color(0xFFFFFFFF),
    textDim: Color(0xFFC9CED6),
    accent: Color(0xFFFF8A00),
    onAccent: Color(0xFF0A0B0D),
    accentText: Color(0xFFFF8A00),
    live: Color(0xFF2EE86B),
    warn: Color(0xFFFFD60A),
    danger: Color(0xFFFF4D5E),
  );

  static const light = Palette(
    bg: Color(0xFFF4F5F7),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFE9EBEF),
    border: Color(0xFFC5CAD3),
    text: Color(0xFF0A0B0D),
    textDim: Color(0xFF3A3F49),
    accent: Color(0xFFFF8A00),
    onAccent: Color(0xFF0A0B0D),
    accentText: Color(0xFFA84300),
    live: Color(0xFF0B8F3C),
    warn: Color(0xFF8A6A00),
    danger: Color(0xFFC8102E),
  );

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(ThemeExtension<Palette>? other, double t) =>
      (other is Palette && t >= 0.5) ? other : this;
}

extension PaletteX on BuildContext {
  Palette get pal => Theme.of(this).extension<Palette>() ?? Palette.dark;
}

/// Cores que o piloto pode escolher para si.
const pilotColors = <Color>[
  Color(0xFFFF8A00),
  Color(0xFF2EE86B),
  Color(0xFF3DA9FF),
  Color(0xFFFF4D9D),
  Color(0xFFFFD60A),
  Color(0xFFB58CFF),
];

Color pilotColor(int index) => pilotColors[index % pilotColors.length];

abstract final class Sp {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

abstract final class Rd {
  static const double sm = 12;
  static const double md = 20;
  static const double lg = 28;
}

abstract final class Touch {
  static const double min = 64;
  static const double primary = 72;
  static const double ptt = 160;
}

abstract final class Dur {
  static const fast = Duration(milliseconds: 120);
  static const base = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 400);
}

const displayFont = 'SairaCondensed';

abstract final class Ty {
  static const display = TextStyle(
      fontFamily: displayFont, fontWeight: FontWeight.w700, fontSize: 56, height: 1.0);
  static const headline = TextStyle(
      fontFamily: displayFont, fontWeight: FontWeight.w700, fontSize: 34, height: 1.12);
  static const title = TextStyle(
      fontFamily: displayFont, fontWeight: FontWeight.w600, fontSize: 24, height: 1.17);
  static const button = TextStyle(
      fontFamily: displayFont,
      fontWeight: FontWeight.w700,
      fontSize: 22,
      height: 1.1,
      letterSpacing: 0.5);
  static const body = TextStyle(fontWeight: FontWeight.w400, fontSize: 17, height: 1.4);
  static const label = TextStyle(fontWeight: FontWeight.w600, fontSize: 14, height: 1.3);
}
