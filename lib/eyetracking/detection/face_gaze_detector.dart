import 'package:eyevoice/eyetracking/models/raw_gaze_sample.dart';

/// Détection brute du regard (étapes 1-2 de la section 13.2 : caméra
/// frontale → détection visage/iris → coordonnées estimées du regard).
///
/// Interface volontairement minimale et indépendante de tout framework
/// (MediaPipe, TFLite, ML Kit...) pour que le reste du pipeline
/// (calibration, mapping, dwell, section 13.1) reste testable sans caméra ni
/// modèle réel — voir les fakes utilisés dans `test/eyetracking`.
abstract class FaceGazeDetector {
  /// Flux continu d'échantillons de regard brut. Doit continuer à émettre
  /// (avec `faceDetected: false`) même quand aucun visage n'est détecté,
  /// pour que `SignalQualityMonitor` puisse mesurer la durée de perte de
  /// signal (section 17.3) plutôt que de simplement cesser d'émettre.
  Stream<RawGazeSample> get samples;

  /// Démarre la capture caméra + l'inférence. Doit pouvoir être appelé de
  /// nouveau après [stop] (ex. redémarrage après mise en veille de l'écran).
  Future<void> start();

  /// Arrête la capture caméra sans libérer les ressources natives (voir
  /// [dispose] pour la libération complète).
  Future<void> stop();

  /// Libère les ressources (caméra, interpréteur TFLite). Le détecteur ne
  /// doit plus être utilisé après cet appel.
  Future<void> dispose();
}
