import 'package:flutter/material.dart';

class AppColors {
  static const purple = Color(0xFF10A37F); // ChatGPT OpenAI Green primary
  static const purpleDark = Color(0xFF0E8E6E);
  static const purpleGradientEnd = Color(0xFF10A37F);

  static const darkBg = Color(0xFF212121);
  static const darkSurface = Color(0xFF171717);
  static const darkSurface2 = Color(0xFF2F2F2F);
  static const darkBorder = Color(0xFF383838);
  static const darkTextPrimary = Color(0xFFECECF1);
  static const darkTextSecondary = Color(0xFFB4B4B4);

  static const lightBg = Color(0xFFFFFFFF);
  static const lightSurface = Color(0xFFF9F9F9);
  static const lightSurface2 = Color(0xFFF4F4F4);
  static const lightBorder = Color(0xFFE5E5E5);
  static const lightTextPrimary = Color(0xFF0D0D0D);
  static const lightTextSecondary = Color(0xFF666666);

  static const success = Color(0xFF10A37F);
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

