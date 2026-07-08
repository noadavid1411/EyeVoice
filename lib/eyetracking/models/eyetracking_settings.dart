import 'package:eyevoice/core/constants/app_defaults.dart';
import 'package:eyevoice/eyetracking/models/gaze_sensitivity.dart';

/// Paramètres configurables de la couche `eyetracking` (section 16).
///
/// Regroupe tout ce qui doit rester réglable — jamais codé en dur — dans le
/// pipeline caméra → [GazeState] : dwell time, taille de la zone morte,
/// sensibilité, et seuils utilisés pour détecter la dégradation du signal
/// (section 17.3). Les valeurs par défaut proviennent de [AppDefaults] et de
/// la section 16 des spécifications ; la Phase 3 branchera ces champs sur
/// l'écran de réglages utilisateur (hors du périmètre `eyetracking`).
class EyeTrackingSettings {
  /// Durée de fixation requise pour valider une zone (section 4.4,
  /// recommandé 1,2 à 1,5 s, défaut 1,3 s).
  final Duration dwellTime;

  /// Part du centre de l'écran réservée à la zone morte, en fraction de
  /// chaque dimension de l'écran (section 4.3/16 : 15 à 25 %).
  final double centerDeadZoneRatio;

  /// Sensibilité du mapping regard→écran (section 16, défaut "Moyenne").
  final GazeSensitivity sensitivity;

  /// Délai sans visage détecté au-delà duquel le signal passe à
  /// [GazeSignalStatus.lost] (mode dégradé, section 17.3).
  final Duration faceLostThreshold;

  /// Fenêtre glissante sur laquelle les changements de zone sont comptés
  /// pour détecter une instabilité (section 17.1 : "plusieurs zones
  /// détectées de manière instable").
  final Duration instabilityWindow;

  /// Nombre de changements de zone dans [instabilityWindow] au-delà duquel
  /// le signal est considéré [GazeSignalStatus.degraded].
  final int instabilityZoneChangeThreshold;

  const EyeTrackingSettings({
    this.dwellTime = AppDefaults.dwellTime,
    this.centerDeadZoneRatio =
        (AppDefaults.centerDeadZoneMinRatio + AppDefaults.centerDeadZoneMaxRatio) / 2,
    this.sensitivity = GazeSensitivity.medium,
    this.faceLostThreshold = const Duration(milliseconds: 1500),
    this.instabilityWindow = const Duration(milliseconds: 1000),
    this.instabilityZoneChangeThreshold = 3,
  }) : assert(
          centerDeadZoneRatio >= AppDefaults.centerDeadZoneMinRatio &&
              centerDeadZoneRatio <= AppDefaults.centerDeadZoneMaxRatio,
          'centerDeadZoneRatio doit rester dans la plage recommandée '
          '(section 4.3/16 : 15 à 25 %).',
        );

  EyeTrackingSettings copyWith({
    Duration? dwellTime,
    double? centerDeadZoneRatio,
    GazeSensitivity? sensitivity,
    Duration? faceLostThreshold,
    Duration? instabilityWindow,
    int? instabilityZoneChangeThreshold,
  }) {
    return EyeTrackingSettings(
      dwellTime: dwellTime ?? this.dwellTime,
      centerDeadZoneRatio: centerDeadZoneRatio ?? this.centerDeadZoneRatio,
      sensitivity: sensitivity ?? this.sensitivity,
      faceLostThreshold: faceLostThreshold ?? this.faceLostThreshold,
      instabilityWindow: instabilityWindow ?? this.instabilityWindow,
      instabilityZoneChangeThreshold:
          instabilityZoneChangeThreshold ?? this.instabilityZoneChangeThreshold,
    );
  }
}
