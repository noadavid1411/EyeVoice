import 'package:eyevoice/domain/models/menu_config_exception.dart';
import 'package:eyevoice/domain/models/menu_screen.dart';

/// Modèle typé racine de `menu-config.json` (SPECIFICATIONS_FONCTIONNELLES.md
/// section 11.2).
///
/// Ce type ne fait que refléter fidèlement la forme du JSON — il ne
/// vérifie pas les règles métier globales (écran à plus de 4 choix,
/// `homeScreenId` introuvable, cible `navigate` inexistante) : c'est le
/// rôle de `validateMenuConfig` (`menu_config_validator.dart`), volontairement
/// séparé pour que le parsing pur reste testable indépendamment des règles
/// de cohérence.
class MenuConfig {
  final String appName;
  final int defaultDwellTimeMs;
  final String homeScreenId;
  final List<MenuScreen> screens;

  const MenuConfig({
    required this.appName,
    required this.defaultDwellTimeMs,
    required this.homeScreenId,
    required this.screens,
  });

  factory MenuConfig.fromJson(Map<String, dynamic> json) {
    final appNameRaw = json['appName'];
    final dwellRaw = json['defaultDwellTimeMs'];
    final homeIdRaw = json['homeScreenId'];
    final screensRaw = json['screens'];

    if (appNameRaw is! String || appNameRaw.isEmpty) {
      throw const MenuConfigParseException(
        "Configuration invalide : champ 'appName' manquant ou vide",
      );
    }
    if (dwellRaw is! int || dwellRaw <= 0) {
      throw const MenuConfigParseException(
        "Configuration invalide : champ 'defaultDwellTimeMs' manquant ou "
        'non positif',
      );
    }
    if (homeIdRaw is! String || homeIdRaw.isEmpty) {
      throw const MenuConfigParseException(
        "Configuration invalide : champ 'homeScreenId' manquant ou vide",
      );
    }
    if (screensRaw is! List || screensRaw.isEmpty) {
      throw const MenuConfigParseException(
        "Configuration invalide : champ 'screens' manquant ou vide",
      );
    }

    final screens = screensRaw
        .map((raw) => MenuScreen.fromJson(raw as Map<String, dynamic>))
        .toList(growable: false);

    return MenuConfig(
      appName: appNameRaw,
      defaultDwellTimeMs: dwellRaw,
      homeScreenId: homeIdRaw,
      screens: screens,
    );
  }

  /// Recherche un écran par [id].
  ///
  /// Lève [MenuConfigValidationException] si aucun écran ne correspond :
  /// à ce stade (après `validateMenuConfig` réussi), un `id` absent est
  /// un bug de logique appelante (ex. `ActionResolver` mal utilisé), pas un
  /// cas attendu à gérer silencieusement.
  MenuScreen screenById(String id) => screens.firstWhere(
        (screen) => screen.id == id,
        orElse: () => throw MenuConfigValidationException([
          "Écran '$id' introuvable dans la configuration",
        ]),
      );

  @override
  String toString() =>
      'MenuConfig(appName: $appName, defaultDwellTimeMs: $defaultDwellTimeMs, '
      'homeScreenId: $homeScreenId, screens: ${screens.length})';
}
