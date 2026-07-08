/// Échantillon brut produit par la couche de détection (étapes 1-2 de la
/// section 13.2 : caméra frontale → détection visage/iris → coordonnées
/// estimées du regard), avant toute calibration ou projection écran.
///
/// Type interne à `eyetracking` (section 13.1) : aucune couche en dehors du
/// pipeline détection → calibration/mapping → zones → dwell ne doit le
/// manipuler.
class RawGazeSample {
  /// `true` si un visage a été détecté dans l'image analysée.
  final bool faceDetected;

  /// Composante horizontale du vecteur de regard estimé, dérivée par la
  /// couche de détection (ex. combinaison position de l'iris dans l'oeil +
  /// orientation de la tête — voir `FaceDetectionTfliteGazeDetector`). Sans
  /// unité fixe : sa plage dépend du détecteur, c'est le rôle de la
  /// calibration ([CalibrationProfile]) de la convertir en coordonnées écran
  /// normalisées. `null` si aucun visage n'est détecté.
  final double? gazeVectorX;

  /// Composante verticale du vecteur de regard estimé. Mêmes remarques que
  /// [gazeVectorX].
  final double? gazeVectorY;

  /// Confiance de détection, de 0.0 à 1.0.
  final double confidence;

  final DateTime timestamp;

  const RawGazeSample({
    required this.faceDetected,
    required this.gazeVectorX,
    required this.gazeVectorY,
    required this.confidence,
    required this.timestamp,
  });

  /// Échantillon "aucun visage" pratique pour signaler une perte de
  /// détection ponctuelle ou une erreur d'inférence (voir
  /// `SignalQualityMonitor`).
  RawGazeSample.faceLost(DateTime timestamp)
      : this(
          faceDetected: false,
          gazeVectorX: null,
          gazeVectorY: null,
          confidence: 0.0,
          timestamp: timestamp,
        );
}
