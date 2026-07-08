/// Valeurs par défaut de configuration, issues des recommandations de
/// SPECIFICATIONS_FONCTIONNELLES.md (section 16 — Paramètres configurables).
///
/// Ces constantes sont des valeurs *par défaut* uniquement : elles doivent
/// rester surchargeables via `menu-config.json` (ex. `defaultDwellTimeMs`)
/// et/ou les réglages utilisateur (Phase 3). Elles centralisent les nombres
/// "magiques" du cahier des charges pour éviter toute divergence entre les
/// couches `domain`, `eyetracking` et `ui`.
abstract final class AppDefaults {
  const AppDefaults._();

  /// Durée de fixation (dwell time) par défaut avant validation d'un choix.
  /// Section 4.4 : recommandée entre 1,2 s et 1,5 s.
  static const Duration dwellTime = Duration(milliseconds: 1300);

  /// Part minimale du centre de l'écran réservée à la zone morte (section
  /// 4.3 et 16 : 15 à 25 %).
  static const double centerDeadZoneMinRatio = 0.15;

  /// Part maximale du centre de l'écran réservée à la zone morte.
  static const double centerDeadZoneMaxRatio = 0.25;

  /// Nombre maximal de choix affichables sur un écran standard (règle du
  /// carré magique, section 4.1). Utilisé par le validateur de schéma de
  /// menu-config.json (Phase 1a).
  static const int maxChoicesPerScreen = 4;
}
