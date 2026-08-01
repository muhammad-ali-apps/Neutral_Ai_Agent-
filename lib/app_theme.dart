import 'package:flutter/material.dart';

class AppColors {
  static const purple = Color(0xFF6C5CE7);
  static const purpleDark = Color(0xFF5A4BD6);
  static const purpleGradientEnd = Color(0xFF8B7CF6);

  static const darkBg = Color(0xFF0B0B14);
  static const darkSurface = Color(0xFF13131F);
  static const darkSurface2 = Color(0xFF191926);
  static const darkBorder = Color(0xFF262636);
  static const darkTextPrimary = Color(0xFFF2F2F7);
  static const darkTextSecondary = Color(0xFF9494A8);

  static const lightBg = Color(0xFFF5F5FA);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurface2 = Color(0xFFF0F0F7);
  static const lightBorder = Color(0xFFE1E1EC);
  static const lightTextPrimary = Color(0xFF17171F);
  static const lightTextSecondary = Color(0xFF6B6B7B);

  static const success = Color(0xFF2ECC71);
  static const openaiGreen = Color(0xFF10A37F);
  static const geminiBlue = Color(0xFF4285F4);
  static const anthropicOrange = Color(0xFFE8724A);
  static const deepseekGray = Color(0xFF6B6B7B);
}

class AppTheme {
  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.darkBg,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.purple,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkTextPrimary,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.darkTextPrimary,
        displayColor: AppColors.darkTextPrimary,
      ),
      dividerColor: AppColors.darkBorder,
      iconTheme: const IconThemeData(color: AppColors.darkTextSecondary),
    );
  }

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.lightBg,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.purple,
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightTextPrimary,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.lightTextPrimary,
        displayColor: AppColors.lightTextPrimary,
      ),
      dividerColor: AppColors.lightBorder,
      iconTheme: const IconThemeData(color: AppColors.lightTextSecondary),
    );
  }
}

extension AppColorsX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get surface => isDark ? AppColors.darkSurface : AppColors.lightSurface;
  Color get surface2 => isDark ? AppColors.darkSurface2 : AppColors.lightSurface2;
  Color get borderColor => isDark ? AppColors.darkBorder : AppColors.lightBorder;
  Color get textPrimary => isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
  Color get textSecondary => isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
  Color get bg => isDark ? AppColors.darkBg : AppColors.lightBg;
}
