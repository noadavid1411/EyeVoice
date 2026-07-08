import 'package:eyevoice/eyetracking/models/calibration_profile.dart';
import 'package:eyevoice/eyetracking/models/gaze_point.dart';
import 'package:eyevoice/eyetracking/models/raw_gaze_sample.dart';

/// Un point de référence de calibration : une cible affichée à l'écran
/// (ex. les 4 coins + le centre) et les échantillons de regard brut
/// collectés pendant que le patient la fixe.
class CalibrationPoint {
  final GazePoint target;
  final List<RawGazeSample> samples;

  CalibrationPoint({required this.target, List<RawGazeSample>? samples})
      : samples = samples ?? [];

  void addSample(RawGazeSample sample) {
    if (sample.faceDetected && sample.gazeVectorX != null && sample.gazeVectorY != null) {
      samples.add(sample);
    }
  }

  /// Moyenne des échantillons valides collectés pour ce point (réduit le
  /// bruit d'un unique échantillon caméra).
  (double, double)? get averagedGazeVector {
    if (samples.isEmpty) return null;
    var sx = 0.0, sy = 0.0;
    for (final s in samples) {
      sx += s.gazeVectorX!;
      sy += s.gazeVectorY!;
    }
    return (sx / samples.length, sy / samples.length);
  }
}

/// Spike de calibration (section 13.2, étape "mapping vers zone écran") :
/// collecte quelques points de référence (typiquement les 4 coins + le
/// centre de l'écran) puis calcule un [CalibrationProfile] par régression
/// linéaire (moindres carrés).
///
/// Volontairement minimal pour la Phase 1b : pas de détection de qualité de
/// calibration, pas de re-calibration incrémentale, pas d'UI (l'écran de
/// calibration lui-même est hors périmètre `eyetracking`, voir
/// `flutter-ui-engineer`). Ces raffinements sont explicitement prévus en
/// version suivante/avancée (spécifications section 20.2 "meilleur
/// calibrage", 20.3 "calibration personnalisée").
class CalibrationSession {
  final List<CalibrationPoint> _points = [];

  /// Déclare un nouveau point cible à calibrer (ex. un des 4 coins ou le
  /// centre de l'écran) et retourne l'objet à alimenter via
  /// [CalibrationPoint.addSample] pendant que le patient le fixe.
  CalibrationPoint startPoint(GazePoint target) {
    final point = CalibrationPoint(target: target);
    _points.add(point);
    return point;
  }

  /// Calcule le profil de calibration à partir des points collectés.
  ///
  /// Nécessite au moins 3 points non colinéaires pour que la régression
  /// soit déterminée (3 inconnues par axe : gain X, gain Y, décalage).
  /// Retourne [CalibrationProfile.identity] si la calibration n'a pas assez
  /// de données exploitables plutôt que de lancer une exception : un échec
  /// de calibration ne doit jamais bloquer l'usage de l'application (le
  /// patient reste utilisable en précision dégradée, section 17.3).
  CalibrationProfile finish() {
    final usable = _points.where((p) => p.averagedGazeVector != null).toList();
    if (usable.length < 3) {
      return const CalibrationProfile.identity();
    }

    final gx = <double>[], gy = <double>[], tx = <double>[], ty = <double>[];
    for (final p in usable) {
      final (avgX, avgY) = p.averagedGazeVector!;
      gx.add(avgX);
      gy.add(avgY);
      tx.add(p.target.dx);
      ty.add(p.target.dy);
    }

    final xCoeffs = _leastSquaresFit(gx, gy, tx);
    final yCoeffs = _leastSquaresFit(gx, gy, ty);
    if (xCoeffs == null || yCoeffs == null) {
      return const CalibrationProfile.identity();
    }

    return CalibrationProfile(
      aX: xCoeffs.$1,
      bX: xCoeffs.$2,
      cX: xCoeffs.$3,
      aY: yCoeffs.$1,
      bY: yCoeffs.$2,
      cY: yCoeffs.$3,
    );
  }

  /// Résout `target = a*gx + b*gy + c` par moindres carrés (équations
  /// normales) pour une des deux dimensions écran. Retourne `null` si le
  /// système est singulier (points colinéaires/dégénérés).
  (double, double, double)? _leastSquaresFit(
    List<double> gx,
    List<double> gy,
    List<double> target,
  ) {
    final n = gx.length;
    double sxx = 0, sxy = 0, sx = 0, syy = 0, sy = 0, sxt = 0, syt = 0, st = 0;
    for (var i = 0; i < n; i++) {
      sxx += gx[i] * gx[i];
      sxy += gx[i] * gy[i];
      sx += gx[i];
      syy += gy[i] * gy[i];
      sy += gy[i];
      sxt += gx[i] * target[i];
      syt += gy[i] * target[i];
      st += target[i];
    }

    // Système normal 3x3 :
    // [Σgx²  Σgxgy Σgx ] [a]   [Σgx*t]
    // [Σgxgy Σgy²  Σgy ] [b] = [Σgy*t]
    // [Σgx   Σgy   n   ] [c]   [Σt   ]
    final m = [
      [sxx, sxy, sx],
      [sxy, syy, sy],
      [sx, sy, n.toDouble()],
    ];
    final v = [sxt, syt, st];
    final solved = _solve3x3(m, v);
    if (solved == null) return null;
    return (solved[0], solved[1], solved[2]);
  }

  /// Résolution d'un système linéaire 3x3 par élimination de Gauss avec
  /// pivot partiel. Retourne `null` si la matrice est (quasi) singulière.
  List<double>? _solve3x3(List<List<double>> a, List<double> b) {
    final m = [for (final row in a) [...row]];
    final rhs = [...b];
    const epsilon = 1e-9;

    for (var col = 0; col < 3; col++) {
      var pivotRow = col;
      for (var row = col + 1; row < 3; row++) {
        if (m[row][col].abs() > m[pivotRow][col].abs()) pivotRow = row;
      }
      if (m[pivotRow][col].abs() < epsilon) return null;

      if (pivotRow != col) {
        final tmpRow = m[col];
        m[col] = m[pivotRow];
        m[pivotRow] = tmpRow;
        final tmpVal = rhs[col];
        rhs[col] = rhs[pivotRow];
        rhs[pivotRow] = tmpVal;
      }

      for (var row = col + 1; row < 3; row++) {
        final factor = m[row][col] / m[col][col];
        for (var k = col; k < 3; k++) {
          m[row][k] -= factor * m[col][k];
        }
        rhs[row] -= factor * rhs[col];
      }
    }

    final result = List<double>.filled(3, 0.0);
    for (var row = 2; row >= 0; row--) {
      var sum = rhs[row];
      for (var k = row + 1; k < 3; k++) {
        sum -= m[row][k] * result[k];
      }
      result[row] = sum / m[row][row];
    }
    return result;
  }
}
