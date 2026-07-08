import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eyevoice/domain/models/app_settings.dart';

/// Couche de persistance locale des réglages utilisateur (section 16 des
/// spécifications fonctionnelles, section 10.4 pour la personnalisation par
/// l'aidant).
///
/// Placé dans `lib/data` plutôt que `lib/domain` : [SettingsRepository] fait
/// de l'I/O (lit/écrit `shared_preferences`), alors que
/// `lib/domain/models/app_settings.dart` (le modèle [AppSettings] lui-même)
/// reste un module de données pur, sans dépendance à une plateforme de
/// stockage — cohérent avec la séparation de dossiers déjà posée en Phase 0
/// (`lib/data` prévu pour la persistance, `lib/domain` pour la logique
/// métier/les modèles). `ttsServiceProvider`/`TtsService`
/// (`lib/services/tts_service.dart`) suivent une logique similaire mais
/// restent dans `lib/services` car ils encapsulent un moteur externe
/// (`flutter_tts`), pas un stockage de données — ce n'est pas la même
/// famille de responsabilité.
class SettingsRepository {
  /// Clé unique de stockage. Suffixée `.v1` pour permettre une migration de
  /// schéma future sans collision silencieuse avec une version antérieure
  /// du format JSON de [AppSettings].
  static const String storageKey = 'eyevoice.app_settings.v1';

  final SharedPreferences _prefs;

  const SettingsRepository(this._prefs);

  /// Charge les réglages persistés, ou [AppSettings] par défaut si aucun
  /// réglage n'a encore été sauvegardé — ou si la valeur stockée est
  /// corrompue/illisible (voir la doc de [AppSettings.fromJson] : le
  /// parsing des réglages est volontairement tolérant, contrairement à
  /// celui de `menu-config.json`).
  AppSettings load() {
    final raw = _prefs.getString(storageKey);
    if (raw == null) return const AppSettings();

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return const AppSettings();
      return AppSettings.fromJson(decoded);
    } on FormatException {
      // JSON malformé (ex. écriture interrompue) : on retombe sur les
      // valeurs par défaut plutôt que de faire planter le démarrage de
      // l'application pour un problème de stockage local.
      return const AppSettings();
    }
  }

  /// Persiste [settings]. Écrase toute valeur précédemment stockée.
  Future<void> save(AppSettings settings) {
    return _prefs.setString(storageKey, jsonEncode(settings.toJson()));
  }

  /// Efface les réglages persistés, ramenant [load] à [AppSettings] par
  /// défaut au prochain appel.
  ///
  /// Utilisé par l'action sensible "réinitialiser les réglages" (section
  /// 17.2) : la couche `ui` doit avoir obtenu confirmation de l'utilisateur
  /// (voir `MenuItem.requiresConfirmation`) avant d'appeler cette méthode.
  Future<void> reset() => _prefs.remove(storageKey);
}

/// Instance [SharedPreferences] partagée par l'application.
///
/// **Doit être surchargée** (`overrideWithValue`) dans `main()` avant
/// `runApp`, une fois `await SharedPreferences.getInstance()` résolu — le
/// même schéma que `faceGazeDetectorProvider`
/// (`lib/ui/providers/gaze_tracking_providers.dart`) pour une dépendance
/// asynchrone à l'initialisation. Exemple d'intégration (Phase 3b,
/// flutter-ui-engineer) :
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   final prefs = await SharedPreferences.getInstance();
///   runApp(
///     ProviderScope(
///       overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
///       child: const EyeVoiceApp(),
///     ),
///   );
/// }
/// ```
/// Non surchargé, ce provider lève délibérément une erreur explicite plutôt
/// que de retourner une valeur factice qui masquerait un oubli de câblage.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider doit être surchargé via overrideWithValue '
    'dans main(), après un premier `await SharedPreferences.getInstance()` '
    '(voir la documentation de ce provider).',
  );
});

/// [SettingsRepository] câblé sur [sharedPreferencesProvider].
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(sharedPreferencesProvider));
});

/// État réactif des réglages utilisateur, consommable par la couche `ui`
/// (écran de réglages, Phase 3b).
///
/// Suit le même patron que `MenuNavigationController`
/// (`lib/ui/providers/menu_navigation_controller.dart`) : un [Notifier]
/// expose l'état courant en lecture réactive (`ref.watch(settingsProvider)`)
/// et une méthode de mise à jour ([update]) qui persiste immédiatement via
/// [SettingsRepository.save] — la couche `ui` n'a jamais besoin d'appeler
/// [SettingsRepository] directement.
class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    return ref.read(settingsRepositoryProvider).load();
  }

  /// Applique [updater] à l'état courant, met à jour l'état exposé, puis
  /// persiste le résultat.
  ///
  /// Exemple : `ref.read(settingsProvider.notifier).update((s) =>
  /// s.copyWith(fontSize: AppFontSize.large));`
  Future<void> update(AppSettings Function(AppSettings current) updater) async {
    final next = updater(state);
    state = next;
    await ref.read(settingsRepositoryProvider).save(next);
  }

  /// Réinitialise les réglages à leurs valeurs par défaut (action sensible
  /// "réinitialiser les réglages", section 17.2). L'appelant (`ui`) doit
  /// avoir déjà obtenu confirmation avant d'appeler cette méthode.
  Future<void> resetToDefaults() async {
    const defaults = AppSettings();
    state = defaults;
    await ref.read(settingsRepositoryProvider).reset();
  }
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);
