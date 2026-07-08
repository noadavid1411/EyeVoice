/// Exceptions levées par le moteur de données de `menu-config.json`
/// (parsing et validation — Phase 1a, domain-logic-engineer).
///
/// Deux familles distinctes, volontairement séparées :
///
/// - [MenuConfigParseException] : la donnée JSON est structurellement
///   invalide (champ manquant, type incorrect, valeur d'enum inconnue).
///   Levée pendant `fromJson`, avant même qu'un [MenuConfig] complet
///   n'existe.
/// - [MenuConfigValidationException] : le JSON est structurellement valide
///   et un [MenuConfig] a pu être construit, mais il viole une règle
///   métier globale (ex. règle des 4 choix, section 4.1 ; `homeScreenId`
///   introuvable ; cible de navigation inexistante). Levée par
///   `validateMenuConfig` (voir `menu_config_validator.dart`), qui collecte
///   toutes les erreurs trouvées plutôt que de s'arrêter à la première.
sealed class MenuConfigException implements Exception {
  const MenuConfigException();
}

/// Le JSON source ne respecte pas la forme attendue par
/// SPECIFICATIONS_FONCTIONNELLES.md section 11.2.
final class MenuConfigParseException extends MenuConfigException {
  final String message;

  const MenuConfigParseException(this.message);

  @override
  String toString() => 'MenuConfigParseException: $message';
}

/// Le JSON est bien formé mais viole une ou plusieurs règles métier de
/// cohérence globale (section 4.1, 10.1, 12).
///
/// Toutes les erreurs détectées sont collectées dans [errors] plutôt que de
/// s'arrêter à la première trouvée, pour permettre à l'aidant/développeur de
/// corriger `menu-config.json` en une seule fois (section 10.4).
final class MenuConfigValidationException extends MenuConfigException {
  final List<String> errors;

  const MenuConfigValidationException(this.errors);

  @override
  String toString() =>
      'MenuConfigValidationException:\n${errors.map((e) => '  - $e').join('\n')}';
}
