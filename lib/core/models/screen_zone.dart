/// Zones logiques d'un écran de l'application.
///
/// Ce type est **partagé** entre la couche `domain` (zone cible d'un item
/// de `menu-config.json`) et la couche `eyetracking` (zone actuellement
/// fixée par le regard, exposée via `GazeState`). Il vit dans `core`
/// précisément pour qu'aucune des deux couches n'ait à dépendre de
/// l'autre : la séparation détection du regard / logique de menus doit
/// rester stricte (SPECIFICATIONS_FONCTIONNELLES.md section 13.1).
///
/// Voir section 13.3 pour la liste des zones attendues.
enum ScreenZone {
  /// Quadrant haut gauche (grille 4 zones — section 4.1).
  topLeft,

  /// Quadrant haut droite (grille 4 zones).
  topRight,

  /// Quadrant bas gauche (grille 4 zones).
  bottomLeft,

  /// Quadrant bas droite (grille 4 zones) — toujours réservé à la
  /// navigation/options, jamais à une action critique durable (section 4.6).
  bottomRight,

  /// Moitié gauche de l'écran, utilisée uniquement par le mode Oui/Non
  /// (section 5.2).
  left,

  /// Moitié droite de l'écran, utilisée uniquement par le mode Oui/Non.
  right,

  /// Zone morte centrale : ne doit jamais déclencher d'action, quelle que
  /// soit la durée de fixation (section 4.3).
  centerDeadZone,
}
