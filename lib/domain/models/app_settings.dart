import 'package:eyevoice/core/constants/app_defaults.dart';
import 'package:eyevoice/eyetracking/models/eyetracking_settings.dart';
import 'package:eyevoice/eyetracking/models/gaze_sensitivity.dart';
import 'package:eyevoice/services/tts_settings.dart';

/// Taille de police (section 16 — "Taille de police", défaut "Très
/// grande") et section 10.4 (personnalisation par l'aidant).
///
/// [scaleFactor] est une indication numérique fournie à titre de contrat
/// pour la couche `ui` (`lib/ui/theme`) : c'est elle qui décide comment
/// l'appliquer concrètement (ex. `TextScaler.linear(scaleFactor)` ou
/// multiplication des tailles de `AppTextStyles`) — ce module ne fait que
/// transporter la préférence utilisateur.
enum AppFontSize {
  standard,
  large,
  extraLarge;

  double get scaleFactor => switch (this) {
        AppFontSize.standard => 1.0,
        AppFontSize.large => 1.25,
        AppFontSize.extraLarge => 1.5,
      };

  static AppFontSize fromName(String raw) => AppFontSize.values.firstWhere(
        (v) => v.name == raw,
        orElse: () => AppFontSize.extraLarge,
      );
}

/// Niveau de contraste visuel (section 10.4 — "le niveau de contraste" ;
/// section 16 — "Thème", défaut "Sombre haut contraste").
///
/// Le MVP (Phase 1c) n'expose pour l'instant qu'un seul thème effectif
/// (`AppTheme.dark`, déjà haut contraste) : ce réglage prépare le terrain
/// pour une future variante `standard` sans obliger `lib/ui/theme` à exister
/// dès cette phase. Défaut [high], cohérent avec le thème actuel.
enum AppContrastLevel {
  standard,
  high;

  static AppContrastLevel fromName(String raw) =>
      AppContrastLevel.values.firstWhere(
        (v) => v.name == raw,
        orElse: () => AppContrastLevel.high,
      );
}

/// Mode d'accueil par défaut au lancement de l'application (section 16 —
/// "Mode d'accueil", défaut "Besoins rapides").
///
/// [quickNeeds] correspond à l'écran d'accueil standard en grille 4 zones
/// (section 6.1, "Mode Besoins Rapides" — c'est le seul mode câblé au
/// lancement dans `MenuNavigationController`, Phase 2). [expert] correspond
/// au mode de saisie libre par balayage (section 8, hors périmètre MVP —
/// voir TASKS.md Phase 3/Backlog). Le câblage effectif de ce choix au
/// démarrage (quel écran/mode `MenuNavigationController.build()` ouvre en
/// premier) reste à faire côté `ui` : ce champ n'est qu'une préférence
/// persistée.
enum HomeMode {
  quickNeeds,
  expert;

  static HomeMode fromName(String raw) => HomeMode.values.firstWhere(
        (v) => v.name == raw,
        orElse: () => HomeMode.quickNeeds,
      );
}

/// Regroupement unifié de tous les réglages configurables de l'application
/// (SPECIFICATIONS_FONCTIONNELLES.md section 16, et section 10.4 pour la
/// partie personnalisable par l'aidant).
///
/// Composition plutôt que duplication : [eyeTracking] réutilise
/// [EyeTrackingSettings] tel quel (dwell time, zone morte centrale,
/// sensibilité — déjà défini par `eye-tracking-engineer`) et [tts] réutilise
/// [TtsSettings] tel quel (voix, vitesse, volume, muet — déjà défini par ce
/// même module en Phase 2). Seuls les réglages qui n'avaient pas encore de
/// foyer ([fontSize], [contrastLevel], [defaultHomeMode]) sont ajoutés ici.
/// Ce module ne redéfinit donc jamais deux fois la même notion de réglage.
///
/// Cette classe est un pur modèle de données (immutable, sans I/O) : la
/// persistance (`shared_preferences`) est assurée par `SettingsRepository`
/// (`lib/data/settings_repository.dart`), qui appelle [toJson]/[fromJson].
class AppSettings {
  /// Réglages du pipeline regard→écran (dwell time, zone morte,
  /// sensibilité). Voir [EyeTrackingSettings].
  final EyeTrackingSettings eyeTracking;

  /// Réglages de synthèse vocale (voix, vitesse, volume, muet). Voir
  /// [TtsSettings].
  final TtsSettings tts;

  /// Taille de police préférée (section 16, défaut "Très grande").
  final AppFontSize fontSize;

  /// Niveau de contraste préféré (section 10.4/16, défaut haut contraste).
  final AppContrastLevel contrastLevel;

  /// Mode d'accueil au lancement (section 16, défaut "Besoins rapides").
  final HomeMode defaultHomeMode;

  const AppSettings({
    this.eyeTracking = const EyeTrackingSettings(),
    this.tts = const TtsSettings(),
    this.fontSize = AppFontSize.extraLarge,
    this.contrastLevel = AppContrastLevel.high,
    this.defaultHomeMode = HomeMode.quickNeeds,
  });

  AppSettings copyWith({
    EyeTrackingSettings? eyeTracking,
    TtsSettings? tts,
    AppFontSize? fontSize,
    AppContrastLevel? contrastLevel,
    HomeMode? defaultHomeMode,
  }) {
    return AppSettings(
      eyeTracking: eyeTracking ?? this.eyeTracking,
      tts: tts ?? this.tts,
      fontSize: fontSize ?? this.fontSize,
      contrastLevel: contrastLevel ?? this.contrastLevel,
      defaultHomeMode: defaultHomeMode ?? this.defaultHomeMode,
    );
  }

  /// Sérialise vers une structure prête pour `jsonEncode` (utilisé par
  /// `SettingsRepository.save`).
  ///
  /// [EyeTrackingSettings] et [TtsSettings] n'ont pas leur propre
  /// `toJson`/`fromJson` (hors périmètre de ce module, qui ne doit pas les
  /// modifier) : leurs champs pertinents sont sérialisés/désérialisés
  /// directement ici. Seuls les 3 réglages eye-tracking réellement exposés
  /// par la section 16 (dwell time, zone morte, sensibilité) sont persistés
  /// — [EyeTrackingSettings.faceLostThreshold],
  /// [EyeTrackingSettings.instabilityWindow] et
  /// [EyeTrackingSettings.instabilityZoneChangeThreshold] sont des réglages
  /// de tuning interne du signal (section 17.1), pas des préférences
  /// utilisateur : ils gardent leur valeur par défaut au rechargement.
  Map<String, dynamic> toJson() => {
        'eyeTracking': {
          'dwellTimeMs': eyeTracking.dwellTime.inMilliseconds,
          'centerDeadZoneRatio': eyeTracking.centerDeadZoneRatio,
          'sensitivity': eyeTracking.sensitivity.name,
        },
        'tts': {
          'language': tts.language,
          'speechRate': tts.speechRate,
          'volume': tts.volume,
          'pitch': tts.pitch,
          'voiceName': tts.voiceName,
          'muted': tts.muted,
        },
        'fontSize': fontSize.name,
        'contrastLevel': contrastLevel.name,
        'defaultHomeMode': defaultHomeMode.name,
      };

  /// Reconstruit un [AppSettings] depuis [json] (produit par [toJson]).
  ///
  /// Volontairement tolérant : un champ manquant, mal typé, ou une donnée
  /// persistée par une version antérieure de l'application retombe
  /// silencieusement sur la valeur par défaut correspondante plutôt que de
  /// faire échouer le chargement des réglages (contrairement au parsing
  /// strict de `menu-config.json`, qui doit échouer tôt sur une erreur
  /// d'auteur — ici la source est le stockage local de l'appareil, pas un
  /// fichier édité à la main).
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    const defaults = AppSettings();

    final eyeTrackingRaw = json['eyeTracking'];
    var eyeTracking = defaults.eyeTracking;
    if (eyeTrackingRaw is Map<String, dynamic>) {
      final dwellMs = eyeTrackingRaw['dwellTimeMs'];
      final deadZone = eyeTrackingRaw['centerDeadZoneRatio'];
      final sensitivityRaw = eyeTrackingRaw['sensitivity'];
      eyeTracking = eyeTracking.copyWith(
        dwellTime: dwellMs is int ? Duration(milliseconds: dwellMs) : null,
        centerDeadZoneRatio: deadZone is num &&
                deadZone >= AppDefaults.centerDeadZoneMinRatio &&
                deadZone <= AppDefaults.centerDeadZoneMaxRatio
            ? deadZone.toDouble()
            : null,
        sensitivity:
            sensitivityRaw is String ? _parseSensitivity(sensitivityRaw) : null,
      );
    }

    final ttsRaw = json['tts'];
    var tts = defaults.tts;
    if (ttsRaw is Map<String, dynamic>) {
      tts = tts.copyWith(
        language: ttsRaw['language'] is String ? ttsRaw['language'] as String : null,
        speechRate: ttsRaw['speechRate'] is num ? (ttsRaw['speechRate'] as num).toDouble() : null,
        volume: ttsRaw['volume'] is num ? (ttsRaw['volume'] as num).toDouble() : null,
        pitch: ttsRaw['pitch'] is num ? (ttsRaw['pitch'] as num).toDouble() : null,
        voiceName: ttsRaw['voiceName'] is String ? ttsRaw['voiceName'] as String : null,
        muted: ttsRaw['muted'] is bool ? ttsRaw['muted'] as bool : null,
      );
    }

    final fontSizeRaw = json['fontSize'];
    final contrastLevelRaw = json['contrastLevel'];
    final defaultHomeModeRaw = json['defaultHomeMode'];

    return AppSettings(
      eyeTracking: eyeTracking,
      tts: tts,
      fontSize: fontSizeRaw is String ? AppFontSize.fromName(fontSizeRaw) : defaults.fontSize,
      contrastLevel: contrastLevelRaw is String
          ? AppContrastLevel.fromName(contrastLevelRaw)
          : defaults.contrastLevel,
      defaultHomeMode: defaultHomeModeRaw is String
          ? HomeMode.fromName(defaultHomeModeRaw)
          : defaults.defaultHomeMode,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.eyeTracking.dwellTime == eyeTracking.dwellTime &&
      other.eyeTracking.centerDeadZoneRatio == eyeTracking.centerDeadZoneRatio &&
      other.eyeTracking.sensitivity == eyeTracking.sensitivity &&
      other.tts == tts &&
      other.fontSize == fontSize &&
      other.contrastLevel == contrastLevel &&
      other.defaultHomeMode == defaultHomeMode;

  @override
  int get hashCode => Object.hash(
        eyeTracking.dwellTime,
        eyeTracking.centerDeadZoneRatio,
        eyeTracking.sensitivity,
        tts,
        fontSize,
        contrastLevel,
        defaultHomeMode,
      );

  @override
  String toString() =>
      'AppSettings(eyeTracking.dwellTime: ${eyeTracking.dwellTime}, '
      'eyeTracking.centerDeadZoneRatio: ${eyeTracking.centerDeadZoneRatio}, '
      'eyeTracking.sensitivity: ${eyeTracking.sensitivity}, tts: $tts, '
      'fontSize: $fontSize, contrastLevel: $contrastLevel, '
      'defaultHomeMode: $defaultHomeMode)';
}

/// Résout [raw] en [GazeSensitivity] connu, ou `null` s'il ne correspond à
/// aucune valeur (donnée persistée corrompue/obsolète — voir
/// [AppSettings.fromJson]).
GazeSensitivity? _parseSensitivity(String raw) {
  for (final value in GazeSensitivity.values) {
    if (value.name == raw) return value;
  }
  return null;
}
