/// Sensibilité du mapping regard→écran (section 16 : réglage utilisateur
/// exposé plus tard dans les Réglages, valeur par défaut "Moyenne").
///
/// Agit comme un gain appliqué au vecteur de regard détecté avant
/// projection sur l'écran ([GazeToScreenMapper]) : une sensibilité plus
/// élevée amplifie de petits mouvements oculaires/de tête (utile pour un
/// patient à faible amplitude de mouvement, ex. très fatigué), une
/// sensibilité plus faible les atténue (plus stable, moins de faux
/// positifs pour un patient agité ou avec un signal caméra bruité).
enum GazeSensitivity {
  low,
  medium,
  high;

  /// Gain multiplicatif appliqué au vecteur de regard brut avant la
  /// projection écran. Valeurs choisies empiriquement pour le spike de
  /// calibration de la Phase 1b ; à affiner en Phase 2/3 avec de vrais
  /// patients (section 20.2 "meilleur calibrage eye-tracking").
  double get gain => switch (this) {
        GazeSensitivity.low => 0.7,
        GazeSensitivity.medium => 1.0,
        GazeSensitivity.high => 1.35,
      };
}