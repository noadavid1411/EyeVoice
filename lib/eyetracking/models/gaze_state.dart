import 'package:eyevoice/core/models/screen_zone.dart';

/// Contrat de sortie de la couche `eyetracking`, consommé par la couche
/// `ui` (indicateur de progression, bascule vers le mode dégradé) et
/// potentiellement par `domain` (déclenchement d'action une fois le dwell
/// time atteint).
///
/// [GazeState] est le point de jonction unique entre la détection brute du
/// regard (caméra, MediaPipe, mapping en coordonnées écran — étapes 1 à 3
/// de la section 13.2) et tout le reste de l'application. Aucune couche en
/// dehors de `eyetracking` ne doit connaître les coordonnées brutes, le
/// framework de détection utilisé, ni les seuils de stabilité internes.
///
/// Voir SPECIFICATIONS_FONCTIONNELLES.md section 13.
class GazeState {
  /// Zone actuellement fixée, ou `null` si aucune zone n'est fixée de façon
  /// exploitable (visage non détecté, transition entre zones, signal trop
  /// instable pour trancher).
  ///
  /// Peut valoir [ScreenZone.centerDeadZone] : dans ce cas [dwellProgress]
  /// doit toujours être 0.0 (section 4.3 — la zone morte ne déclenche
  /// jamais aucune action).
  final ScreenZone? zone;

  /// Progression de la temporisation de fixation (dwell time) pour [zone],
  /// de `0.0` (début de fixation) à `1.0` (seuil de validation atteint).
  ///
  /// Invariant : vaut `0.0` si [zone] est `null` ou
  /// [ScreenZone.centerDeadZone]. C'est la couche `eyetracking` (state
  /// machine dwell time, Phase 1b) qui garantit cet invariant ; les
  /// couches consommatrices peuvent s'y fier sans le revérifier.
  final double dwellProgress;

  /// Confiance de la détection courante, de `0.0` (aucune confiance) à
  /// `1.0` (confiance maximale). Reflète la qualité du signal caméra/modèle
  /// (ex. éclairage, angle du visage), indépendamment de la simple
  /// présence ou absence d'un visage détecté.
  final double confidence;

  /// Statut de dégradation du signal de suivi du regard.
  ///
  /// Permet à `ui`/`domain` de réagir (ex. proposer le mode dégradé
  /// tactile, section 17.3) sans avoir à interpréter [confidence] ou
  /// l'historique de détection eux-mêmes.
  final GazeSignalStatus signalStatus;

  const GazeState({
    required this.zone,
    required this.dwellProgress,
    required this.confidence,
    required this.signalStatus,
  });

  /// État initial/de repos : aucune zone fixée, aucune progression, signal
  /// considéré perdu tant que la détection n'a pas démarré.
  const GazeState.idle()
      : zone = null,
        dwellProgress = 0.0,
        confidence = 0.0,
        signalStatus = GazeSignalStatus.lost;

  @override
  bool operator ==(Object other) =>
      other is GazeState &&
      other.zone == zone &&
      other.dwellProgress == dwellProgress &&
      other.confidence == confidence &&
      other.signalStatus == signalStatus;

  @override
  int get hashCode => Object.hash(zone, dwellProgress, confidence, signalStatus);

  @override
  String toString() =>
      'GazeState(zone: $zone, dwellProgress: $dwellProgress, '
      'confidence: $confidence, signalStatus: $signalStatus)';
}

/// Qualité du signal de suivi du regard.
///
/// Sert de base au mode dégradé tactile (section 17.3) : un passage
/// prolongé à [degraded] ou [lost] doit permettre à l'UI de proposer une
/// sélection manuelle, indépendamment du dwell time normal.
enum GazeSignalStatus {
  /// Visage détecté, signal stable : fonctionnement normal.
  ok,

  /// Visage détecté mais signal instable (bruit, plusieurs zones
  /// détectées en alternance, confiance fluctuante). Les sélections en
  /// cours doivent être annulées (section 17.1), mais l'eye-tracking reste
  /// actif : pas de bascule immédiate vers le mode dégradé.
  degraded,

  /// Visage non détecté ou signal indisponible depuis un délai jugé
  /// significatif par la couche `eyetracking`. L'UI doit proposer/activer
  /// le mode dégradé tactile (section 17.3).
  lost,
}
