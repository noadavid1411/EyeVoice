/// Point de regard projeté sur l'écran, normalisé dans `[0.0, 1.0]` sur
/// chaque axe (`0,0` = coin haut-gauche, `1,1` = coin bas-droite).
///
/// Résultat de la calibration/mapping (`GazeToScreenMapper`) appliquée à un
/// [RawGazeSample] ; entrée du `ZoneMapper`. Type interne à `eyetracking`
/// (section 13.1).
class GazePoint {
  final double dx;
  final double dy;

  const GazePoint(this.dx, this.dy);

  @override
  bool operator ==(Object other) =>
      other is GazePoint && other.dx == dx && other.dy == dy;

  @override
  int get hashCode => Object.hash(dx, dy);

  @override
  String toString() => 'GazePoint($dx, $dy)';
}
