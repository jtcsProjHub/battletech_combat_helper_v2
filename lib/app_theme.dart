import 'package:flutter/material.dart';

/// Colors from the Main Menu design on the canvas.
class AppColors {
  AppColors._();

  static const background = Color(0xFF0E1114);
  static const panel = Color(0xFF151A1F);
  static const panelRaised = Color(0xFF1B2127);
  static const panelActive = Color(0xFF1E242B);
  static const border = Color(0xFF2A3139);
  static const borderStrong = Color(0xFF3A434C);
  static const text = Color(0xFFE8EAEC);
  static const textSecondary = Color(0xFFC4CAD0);
  static const textDim = Color(0xFF9AA3AB);
  static const iconDim = Color(0xFF5C6670);
  static const accent = Color(0xFFF28A1E);
  static const danger = Color(0xFFE0503F);
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    brightness: Brightness.dark,
  ).copyWith(
    primary: AppColors.accent,
    onPrimary: AppColors.background,
    surface: AppColors.background,
    onSurface: AppColors.text,
    error: AppColors.danger,
    outline: AppColors.border,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.text,
      elevation: 0,
      shape: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    dividerColor: AppColors.border,
  );
}
