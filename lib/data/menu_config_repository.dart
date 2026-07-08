import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:eyevoice/domain/models/menu_config.dart';
import 'package:eyevoice/domain/models/menu_config_validator.dart';

/// Chemin de l'asset `menu-config.json` déclaré dans `pubspec.yaml`
/// (section `flutter: assets:`).
///
/// Contenu attendu : SPECIFICATIONS_FONCTIONNELLES.md section 11.2. Le JSON
/// embarqué à ce chemin reprend fidèlement l'arborescence de
/// `lib/domain/models/sample_menu_config.dart` (fixture Dart en mémoire
/// conservée pour les tests), mais constitue désormais la vraie source de
/// données chargée au runtime — voir [MenuConfigRepository.load].
const String menuConfigAssetPath = 'assets/menu-config.json';

/// Couche de chargement du vrai `menu-config.json` depuis les assets de
/// l'application (SPECIFICATIONS_FONCTIONNELLES.md section 11.1 : le contenu
/// des menus doit venir d'un fichier de données, jamais être codé en dur
/// dans la logique applicative).
///
/// Placé dans `lib/data` par symétrie avec [SettingsRepository]
/// (`lib/data/settings_repository.dart`) : ce module fait de l'I/O (lit un
/// asset via `rootBundle`), alors que le parsing/la validation purs restent
/// dans `lib/domain/models` (`MenuConfig.fromJson`, `validateMenuConfig`,
/// réunis par `loadMenuConfig`). [MenuConfigRepository.load] ne fait que
/// l'enchaînement lecture asset → décodage JSON → `loadMenuConfig` ; toute
/// erreur de forme ou de cohérence se propage telle quelle
/// (`MenuConfigParseException`/`MenuConfigValidationException`,
/// `lib/domain/models/menu_config_exception.dart`) — ce module ne les avale
/// jamais, un `menu-config.json` invalide doit faire échouer bruyamment le
/// chargement plutôt que de démarrer l'application avec une configuration
/// dégradée silencieusement.
///
/// Ne remplace pas `sampleMenuConfig` : ce dernier reste un fixture Dart
/// utile aux tests unitaires qui n'ont pas besoin de charger un vrai asset
/// (`ActionResolver`, `MenuNavigationController`, etc.). C'est à la couche
/// `ui` de décider si/quand elle bascule sur [menuConfigProvider] pour son
/// câblage réel (hors périmètre de ce module).
class MenuConfigRepository {
  /// Bundle d'assets à utiliser pour charger [menuConfigAssetPath].
  ///
  /// Paramétrable (plutôt que d'appeler `rootBundle` directement) pour
  /// permettre aux tests d'injecter un `TestAssetBundle` si besoin ; par
  /// défaut, `rootBundle` (le bundle réel de l'application), suffisant en
  /// pratique car `flutter_test` sait déjà résoudre `rootBundle` vers les
  /// assets déclarés dans `pubspec.yaml` sous `TestWidgetsFlutterBinding`.
  final AssetBundle _bundle;

  /// `rootBundle` n'est pas une expression constante (c'est un `final`
  /// top-level, pas un `const`), donc ce constructeur ne peut pas être
  /// `const` malgré l'absence d'état mutable propre à cette classe.
  MenuConfigRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  /// Charge, décode et valide `menu-config.json`.
  ///
  /// Lève [MenuConfigParseException] si le JSON est mal formé,
  /// [MenuConfigValidationException] s'il est bien formé mais viole une
  /// règle métier globale (ex. règle des 4 choix, section 4.1) — voir
  /// `loadMenuConfig` (`lib/domain/models/menu_config_validator.dart`) pour
  /// le détail des règles vérifiées. Une erreur de décodage JSON brut
  /// (`FormatException`, ex. asset corrompu) se propage également telle
  /// quelle : contrairement à `SettingsRepository.load` (réglages
  /// utilisateur, tolérant par conception), la configuration des menus est
  /// une donnée structurante dont l'application ne doit jamais démarrer
  /// silencieusement sur une version dégradée.
  Future<MenuConfig> load() async {
    final raw = await _bundle.loadString(menuConfigAssetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return loadMenuConfig(decoded);
  }
}

/// Instance partagée de [MenuConfigRepository].
///
/// Contrairement à `sharedPreferencesProvider`
/// (`lib/data/settings_repository.dart`), pas besoin de surcharge
/// asynchrone au démarrage : [MenuConfigRepository] n'a pas de dépendance à
/// initialiser avant `runApp` (`rootBundle` est utilisable immédiatement).
final menuConfigRepositoryProvider = Provider<MenuConfigRepository>((ref) {
  return MenuConfigRepository();
});

/// [MenuConfig] réel, chargé de manière asynchrone depuis
/// `assets/menu-config.json` via [MenuConfigRepository.load].
///
/// Point d'entrée recommandé pour la couche `ui` : `ref.watch(menuConfigProvider)`
/// renvoie un `AsyncValue<MenuConfig>` (`loading`/`error`/`data`), à gérer par
/// exemple avec `.when(...)` — un écran de chargement le temps de la lecture
/// de l'asset, puis un écran d'erreur si `menu-config.json` est invalide
/// (`MenuConfigParseException`/`MenuConfigValidationException` capturées par
/// Riverpod dans l'état `error` de l'`AsyncValue`, sans traitement
/// particulier ici). Ce câblage visuel (loading/error) reste à la charge de
/// flutter-ui-engineer ; ce module ne fait qu'exposer la donnée résolue.
final menuConfigProvider = FutureProvider<MenuConfig>((ref) async {
  return ref.watch(menuConfigRepositoryProvider).load();
});
