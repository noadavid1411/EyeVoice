/// Disposition de zones actuellement affichée par l'écran courant.
///
/// La couche `eyetracking` ne connaît pas le contenu des écrans
/// (`menu-config.json` est hors de son périmètre), mais elle a besoin de
/// savoir quelle disposition de zones interpréter pour convertir un point de
/// regard écran en [ScreenZone] : grille 4 zones + zone morte centrale
/// (écrans standards, section 4.1/4.3), ou 2 zones verticales gauche/droite
/// (mode Oui/Non, section 5.2).
///
/// C'est la couche appelante (`ui`/`domain`, au moment de naviguer vers un
/// écran) qui doit renseigner ce mode via
/// `GazeTrackingPipeline.setLayoutMode`. Il s'agit d'un petit ajout au
/// contrat *d'entrée* exposé par `eyetracking` (le contrat de *sortie*,
/// [GazeState], n'est pas modifié) : à signaler/valider avec l'architecte et
/// l'UI avant de le câbler côté navigation (voir résumé de fin de tâche
/// Phase 1b).
enum ScreenLayoutMode {
  /// Grille 4 zones (topLeft/topRight/bottomLeft/bottomRight) + zone morte
  /// centrale (section 4.1/4.3).
  quadrant,

  /// 2 zones verticales (left/right), mode Oui/Non (section 5.2).
  yesNo,
}
