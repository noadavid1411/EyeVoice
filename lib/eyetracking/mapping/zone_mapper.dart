import 'package:eyevoice/core/models/screen_zone.dart';
import 'package:eyevoice/eyetracking/models/gaze_point.dart';
import 'package:eyevoice/eyetracking/models/screen_layout_mode.dart';

/// Convertit un [GazePoint] (coordonnées écran normalisées, étape 3 de la
/// section 13.2) en [ScreenZone] logique, en tenant compte de la
/// disposition active ([ScreenLayoutMode]) et de la zone morte centrale
/// (section 4.3).
///
/// Fonction pure, sans état ni dépendance temporelle : toute la logique
/// d'annulation liée au temps (sortie de zone, instabilité, section 17.1)
/// vit dans `DwellTimeController` et `SignalQualityMonitor`, jamais ici.
class ZoneMapper {
  const ZoneMapper();

  ScreenZone map(
    GazePoint point, {
    required ScreenLayoutMode layout,
    required double centerDeadZoneRatio,
  }) {
    return switch (layout) {
      ScreenLayoutMode.quadrant => _mapQuadrant(point, centerDeadZoneRatio),
      ScreenLayoutMode.yesNo => _mapYesNo(point),
    };
  }

  ScreenZone _mapQuadrant(GazePoint point, double centerDeadZoneRatio) {
    final halfSize = centerDeadZoneRatio / 2;
    final withinDeadZone =
        (point.dx - 0.5).abs() <= halfSize && (point.dy - 0.5).abs() <= halfSize;
    if (withinDeadZone) return ScreenZone.centerDeadZone;

    final isTop = point.dy < 0.5;
    final isLeft = point.dx < 0.5;
    if (isTop && isLeft) return ScreenZone.topLeft;
    if (isTop && !isLeft) return ScreenZone.topRight;
    if (!isTop && isLeft) return ScreenZone.bottomLeft;
    return ScreenZone.bottomRight;
  }

  ScreenZone _mapYesNo(GazePoint point) {
    return point.dx < 0.5 ? ScreenZone.left : ScreenZone.right;
  }
}
