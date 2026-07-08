import 'package:eyevoice/eyetracking/models/calibration_profile.dart';
import 'package:eyevoice/eyetracking/models/gaze_point.dart';
import 'package:eyevoice/eyetracking/models/gaze_sensitivity.dart';
import 'package:eyevoice/eyetracking/models/raw_gaze_sample.dart';

/// Projette un [RawGazeSample] en [GazePoint] écran, en appliquant le gain
/// de sensibilité (section 16) puis la transformation de calibration
/// ([CalibrationProfile]), et lisse le résultat pour réduire le bruit/jitter
/// caméra frame-à-frame.
///
/// Choix technique (lissage) : une simple moyenne mobile exponentielle
/// (EMA) suffit pour le spike de la Phase 1b — pas de filtre de Kalman ni de
/// prédiction de mouvement, reportés si le besoin se confirme lors de tests
/// avec de vrais patients. Le facteur de lissage dérive de
/// [GazeSensitivity] : une sensibilité élevée lisse moins (réactivité) au
/// prix de plus de bruit visuel, une sensibilité basse lisse plus
/// (stabilité) au prix de la réactivité — cohérent avec le réglage "moyen"
/// recommandé par défaut (section 16).
class GazeToScreenMapper {
  GazeToScreenMapper({
    CalibrationProfile? profile,
    GazeSensitivity sensitivity = GazeSensitivity.medium,
  })  : _profile = profile ?? const CalibrationProfile.identity(),
        _sensitivity = sensitivity;

  CalibrationProfile _profile;
  GazeSensitivity _sensitivity;
  GazePoint? _smoothed;

  void updateProfile(CalibrationProfile profile) => _profile = profile;

  void updateSensitivity(GazeSensitivity sensitivity) => _sensitivity = sensitivity;

  /// Poids donné au nouvel échantillon dans la moyenne mobile exponentielle
  /// (`smoothed = alpha * nouveau + (1 - alpha) * précédent`).
  double get _smoothingAlpha => switch (_sensitivity) {
        GazeSensitivity.low => 0.25,
        GazeSensitivity.medium => 0.4,
        GazeSensitivity.high => 0.6,
      };

  /// Réinitialise l'état de lissage (ex. après une perte de visage ou un
  /// changement de disposition d'écran) : on ne veut pas que le prochain
  /// point valide soit tiré vers une ancienne position sans rapport.
  void reset() => _smoothed = null;

  /// Retourne `null` si [sample] ne contient pas de regard exploitable
  /// (aucun visage détecté).
  GazePoint? map(RawGazeSample sample) {
    if (!sample.faceDetected || sample.gazeVectorX == null || sample.gazeVectorY == null) {
      return null;
    }

    final gain = _sensitivity.gain;
    final gainedSample = RawGazeSample(
      faceDetected: true,
      gazeVectorX: sample.gazeVectorX! * gain,
      gazeVectorY: sample.gazeVectorY! * gain,
      confidence: sample.confidence,
      timestamp: sample.timestamp,
    );

    final raw = _profile.apply(gainedSample);
    final previous = _smoothed;
    if (previous == null) {
      _smoothed = raw;
      return raw;
    }

    final alpha = _smoothingAlpha;
    final smoothed = GazePoint(
      previous.dx + alpha * (raw.dx - previous.dx),
      previous.dy + alpha * (raw.dy - previous.dy),
    );
    _smoothed = smoothed;
    return smoothed;
  }
}
