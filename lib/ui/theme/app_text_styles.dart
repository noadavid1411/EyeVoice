import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Styles de texte de "La Voix du Regard".
///
/// Section 15.2 : "les textes doivent être visibles à distance", "police
/// très grande", "les libellés courts doivent être privilégiés". Les tailles
/// ci-dessous sont volontairement bien au-delà des tailles Material par
/// défaut : l'application est lue à distance par un patient alité, pas tenue
/// en main.
abstract final class AppTextStyles {
  const AppTextStyles._();

  /// Libellé d'un bouton de zone (grille 4, Oui/Non, mode expert).
  static const TextStyle zoneLabel = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 34,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  /// Libellé OUI / NON : encore plus grand, c'est l'écran le plus critique
  /// (Niveau 1 — Mode Sécurité, section 5).
  static const TextStyle yesNoLabel = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 56,
    fontWeight: FontWeight.w800,
    height: 1.1,
  );

  /// Titre d'écran (ex. "Physique", "Conversation").
  static const TextStyle screenTitle = TextStyle(
    color: AppColors.textAccent,
    fontSize: 26,
    fontWeight: FontWeight.w600,
  );

  /// Phrase finale affichée en grand avant/pendant la synthèse vocale
  /// (section 7.3).
  static const TextStyle spokenPhrase = TextStyle(
    color: AppColors.textAccent,
    fontSize: 40,
    fontWeight: FontWeight.w700,
    height: 1.25,
  );

  /// Texte secondaire discret (jamais pour un choix sélectionnable).
  static const TextStyle caption = TextStyle(
    color: AppColors.textMuted,
    fontSize: 18,
    fontWeight: FontWeight.w400,
  );
}
