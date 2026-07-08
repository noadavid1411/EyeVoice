import 'package:eyevoice/eyetracking/models/gaze_point.dart';
import 'package:eyevoice/eyetracking/models/raw_gaze_sample.dart';

/// Transformation affine regard→écran obtenue par calibration
/// (`CalibrationSession`) ou profil par défaut non calibré.
///
/// ```text
/// screenX = clamp(aX * gazeX + bX * gazeY + cX, 0, 1)
/// screenY = clamp(aY * gazeX + bY * gazeY + cY, 0, 1)
/// ```
///
/// Un modèle affine (régression linéaire à 2 sorties) suffit pour le spike
/// de calibration de la Phase 1b (section 20.1/20.2 : le calibrage avancé
/// est explicitement reporté en v2/v3). Il capture mise à l'échelle,
/// cisaillement et décalage — suffisant pour un dwell time robuste sur une
/// grille 4 zones, sans complexité de modèle non-linéaire.
class CalibrationProfile {
  final double aX, bX, cX;
  final double aY, bY, cY;

  const CalibrationProfile({
    required this.aX,
    required this.bX,
    required this.cX,
    required this.aY,
    required this.bY,
    required this.cY,
  });

  /// Profil identité "non calibré" : suppose que le vecteur de regard brut
  /// est déjà à peu près centré/normalisé dans `[-1, 1]` (c'est le cas du
  /// détecteur par défaut, voir `FaceDetectionTfliteGazeDetector`). Permet à
  /// l'application de fonctionner en précision dégradée avant qu'une
  /// calibration explicite ait été effectuée — un patient de réanimation
  /// peut être trop fatigué pour suivre un flux de calibration ; l'app ne
  /// doit jamais bloquer l'eye-tracking en l'attendant.
  const CalibrationProfile.identity()
      : aX = 0.5,
        bX = 0.0,
        cX = 0.5,
        aY = 0.0,
        bY = 0.5,
        cY = 0.5;

  GazePoint apply(RawGazeSample sample) {
    final gx = sample.gazeVectorX ?? 0.0;
    final gy = sample.gazeVectorY ?? 0.0;
    final dx = (aX * gx + bX * gy + cX).clamp(0.0, 1.0);
    final dy = (aY * gx + bY * gy + cY).clamp(0.0, 1.0);
    return GazePoint(dx, dy);
  }
}
