import 'package:flutter/material.dart';

/// Palette de couleurs de "La Voix du Regard".
///
/// Toutes les valeurs découlent directement des recommandations de
/// SPECIFICATIONS_FONCTIONNELLES.md, section 15 (Design visuel) — fond
/// sombre haut contraste pensé pour un environnement hospitalier, texte
/// blanc/jaune clair, vert pour OUI, rouge pour NON, bleu/gris contrasté
/// pour la navigation.
///
/// Ne pas utiliser de couleurs Material par défaut directement dans les
/// écrans/widgets : passer par cette classe pour garder un thème cohérent
/// et facile à ajuster globalement (ex. futur réglage "niveau de contraste",
/// section 10.4 / 16).
abstract final class AppColors {
  const AppColors._();

  // --- Fond & surfaces ---------------------------------------------------

  /// Fond principal de l'application : noir pur, contraste maximal.
  static const Color background = Color(0xFF000000);

  /// Surface par défaut d'une zone/bouton (gris très foncé, se détache du
  /// fond noir sans introduire de couleur distrayante).
  static const Color surface = Color(0xFF17171B);

  /// Variante légèrement plus claire, utilisée pour les états
  /// pressés/survolés (mode dégradé tactile, section 17.3).
  static const Color surfaceHighlight = Color(0xFF232329);

  /// Bordure visible au repos (section 15.1 : "bordures visibles").
  static const Color border = Color(0xFF4A4A54);

  // --- Texte ---------------------------------------------------------------

  /// Texte principal : blanc.
  static const Color textPrimary = Colors.white;

  /// Texte important / mis en avant : jaune clair (section 15.3).
  static const Color textAccent = Color(0xFFFFF59D);

  /// Texte secondaire discret (ex. sous-titre d'écran), toujours à
  /// contraste suffisant sur fond noir — jamais utilisé pour un choix
  /// sélectionnable.
  static const Color textMuted = Color(0xFFB8B8C0);

  // --- Sémantique Oui / Non -------------------------------------------------

  /// OUI : vert (section 5.3 et 15.3).
  static const Color yes = Color(0xFF2E7D32);
  static const Color yesHighlight = Color(0xFF43A047);

  /// NON : rouge (section 5.3 et 15.3).
  static const Color no = Color(0xFFC62828);
  static const Color noHighlight = Color(0xFFE53935);

  // --- Navigation / options --------------------------------------------------

  /// Retour / Options : bleu-gris contrasté (section 15.3), toujours
  /// utilisé pour le quadrant bas-droite (section 4.6).
  static const Color navigation = Color(0xFF37474F);
  static const Color navigationHighlight = Color(0xFF455A64);

  // --- Feedback de sélection ---------------------------------------------

  /// Bordure lumineuse / progression de sélection en cours (section 4.5).
  /// Choisie distincte du jaune texte et des couleurs sémantiques pour
  /// rester reconnaissable sur n'importe quelle zone.
  static const Color selectionGlow = Color(0xFF29B6F6);

  /// Zone morte centrale : repère visuel neutre, jamais interactif
  /// (section 4.3).
  static const Color deadZoneMarker = Color(0x33FFFFFF);

  /// Couleur d'alerte pour les confirmations d'actions sensibles
  /// (section 17.2).
  static const Color danger = Color(0xFFD32F2F);
}
