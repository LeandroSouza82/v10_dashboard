import 'package:flutter/material.dart';
import '../constants/colors.dart';

final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.background,
  colorScheme: ColorScheme.dark(
    surface: AppColors.surface,
    primary: AppColors.accent,
    onPrimary: AppColors.textPrimary,
    onSurface: AppColors.textPrimary,
  ),
  textTheme: const TextTheme(bodySmall: TextStyle(fontSize: 12.0)),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surface,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.accent,
      foregroundColor: AppColors.textPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
  // cardTheme left default to avoid SDK type differences
);
