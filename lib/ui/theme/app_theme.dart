import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

/// Thème sombre haut contraste définitif de "La Voix du Regard"
/// (SPECIFICATIONS_FONCTIONNELLES.md section 15 — Design visuel).
///
/// Remplace le `ThemeData.dark()` provisoire de Phase 0. Toute future
/// évolution du "niveau de contraste" (réglage utilisateur, section 10.4 /
/// 16) doit passer par ce point d'entrée unique plutôt que par des couleurs
/// codées en dur dans les écrans.
abstract final class AppTheme {
  const AppTheme._();

  static ThemeData get dark {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.background,
        onSurface: AppColors.textPrimary,
        primary: AppColors.selectionGlow,
        onPrimary: Colors.black,
        secondary: AppColors.textAccent,
        onSecondary: Colors.black,
        error: AppColors.danger,
        onError: Colors.white,
      ),
      fontFamily: 'Roboto',
    );

    return base.copyWith(
      textTheme: base.textTheme
          .apply(
            bodyColor: AppColors.textPrimary,
            displayColor: AppColors.textPrimary,
          )
          .copyWith(
            headlineLarge: AppTextStyles.yesNoLabel,
            headlineMedium: AppTextStyles.zoneLabel,
            headlineSmall: AppTextStyles.screenTitle,
            titleLarge: AppTextStyles.spokenPhrase,
            bodyMedium: AppTextStyles.caption,
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTextStyles.screenTitle,
      ),
      iconTheme: const IconThemeData(
        color: AppColors.textPrimary,
        size: 48,
      ),
      dividerColor: AppColors.border,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );
  }
}
