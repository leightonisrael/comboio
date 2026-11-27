import 'package:flutter/material.dart';

import 'tokens.dart';

ThemeData buildTheme(Brightness brightness) {
  final p = brightness == Brightness.dark ? Palette.dark : Palette.light;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: p.accent,
    onPrimary: p.onAccent,
    secondary: p.live,
    onSecondary: p.onAccent,
    error: p.danger,
    onError: p.onAccent,
    surface: p.surface,
    onSurface: p.text,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    extensions: [p],
    textTheme: TextTheme(
      displayLarge: Ty.display.copyWith(color: p.text),
      headlineMedium: Ty.headline.copyWith(color: p.text),
      titleLarge: Ty.title.copyWith(color: p.text),
      bodyLarge: Ty.body.copyWith(color: p.text),
      bodyMedium: Ty.body.copyWith(color: p.textDim),
      labelLarge: Ty.label.copyWith(color: p.textDim),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg,
      foregroundColor: p.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: Ty.title.copyWith(color: p.text),
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 10,
      activeTrackColor: p.accent,
      inactiveTrackColor: p.surfaceHigh,
      thumbColor: p.text,
      overlayColor: p.accent.withValues(alpha: 0.15),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 16),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.onAccent : p.textDim),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.accent : p.surfaceHigh),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surfaceHigh,
      contentPadding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Rd.sm),
        borderSide: BorderSide(color: p.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Rd.sm),
        borderSide: BorderSide(color: p.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Rd.sm),
        borderSide: BorderSide(color: p.accent, width: 2),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.surfaceHigh,
      contentTextStyle: Ty.body.copyWith(color: p.text),
      behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rd.md)),
    ),
  );
}
