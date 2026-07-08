import 'package:flutter/material.dart';

import '../../domain/models/app_settings.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

/// Thème sombre haut contraste de "La Voix du Regard"
/// (SPECIFICATIONS_FONCTIONNELLES.md section 15 — Design visuel).
///
/// Remplace le `ThemeData.dark()` provisoire de Phase 0. Le réglage "Thème"/
/// "niveau de contraste" (section 10.4 / 16, [AppContrastLevel]) passe
/// exclusivement par [themeFor] plutôt que par des couleurs codées en dur
/// dans les écrans : seul l'écart fond/surface change entre les deux
/// niveaux ([AppColors.background]/[AppColors.surface] pour
/// [AppContrastLevel.high] contre [AppColors.backgroundStandard]/
/// [AppColors.surfaceStandard] pour [AppContrastLevel.standard]) — le
/// texte, les couleurs sémantiques (OUI/NON/navigation) et les bordures
/// restent identiques (voir la doc de [AppColors.backgroundStandard]).
abstract final class AppTheme {
  const AppTheme._();

  /// Thème par défaut (haut contraste). Conservé pour compatibilité avec le
  /// code/les tests existants qui ne passent pas encore par [themeFor].
  static ThemeData get dark => themeFor(AppContrastLevel.high);

  /// Construit le [ThemeData] correspondant à [contrastLevel] (réglage
  /// utilisateur, section 16, `lib/ui/screens/settings_screen.dart`).
  static ThemeData themeFor(AppContrastLevel contrastLevel) {
    final background = switch (contrastLevel) {
      AppContrastLevel.high => AppColors.background,
      AppContrastLevel.standard => AppColors.backgroundStandard,
    };
    final surface = switch (contrastLevel) {
      AppContrastLevel.high => AppColors.surface,
      AppContrastLevel.standard => AppColors.surfaceStandard,
    };

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.dark(
        surface: background,
        surfaceContainerHighest: surface,
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
      appBarTheme: AppBarTheme(
        backgroundColor: background,
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
