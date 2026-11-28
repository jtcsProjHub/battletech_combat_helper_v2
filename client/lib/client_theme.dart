// File: lib/client_theme.dart
// Colors and theme matching the desktop app (its lib/app_theme.dart).
// Duplicated for now; shared widgets and theme go to their own package
// later.

import 'package:flutter/material.dart';

class ClientColors {
  ClientColors._();

  static const background = Color(0xFF0E1114);
  static const panelRaised = Color(0xFF1B2127);
  static const border = Color(0xFF2A3139);
  static const text = Color(0xFFE8EAEC);
  static const textSecondary = Color(0xFFC4CAD0);
  static const textDim = Color(0xFF9AA3AB);
  static const accent = Color(0xFFF28A1E);
  static const danger = Color(0xFFE0503F);
  static const ok = Color(0xFF7FD6A4);
}

ThemeData buildClientTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: ClientColors.accent,
        brightness: Brightness.dark,
      ).copyWith(
        primary: ClientColors.accent,
        onPrimary: ClientColors.background,
        surface: ClientColors.background,
        onSurface: ClientColors.text,
        error: ClientColors.danger,
        outline: ClientColors.border,
      );
  return ThemeData(
    useMaterial3: true,
    // Bundled (see pubspec.yaml); the hotspot has no internet.
    fontFamily: 'Roboto',
    colorScheme: scheme,
    scaffoldBackgroundColor: ClientColors.background,
  );
}

/// Small accent label above a title.
const eyebrowStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  letterSpacing: 2,
  color: ClientColors.accent,
);

const titleStyle = TextStyle(
  fontSize: 30,
  fontWeight: FontWeight.w700,
  color: ClientColors.text,
);
