/// Pile d'historique de navigation logique entre écrans de
/// `menu-config.json`.
///
/// Permet à l'`ActionResolver` de résoudre les actions JSON `back` et
/// `home` (section 12) en un écran cible concret, sans que la couche `ui`
/// n'ait jamais à connaître ou manipuler elle-même une pile de navigation :
/// elle ne fait que déclencher un [NavigateAction] déjà résolu (voir
/// `action_result.dart`).
///
/// L'écran d'accueil ([homeScreenId]) reste toujours au fond de la pile et
/// n'est jamais retiré par [pop] : il n'y a donc pas de notion de "retour
/// depuis l'accueil" à gérer côté appelant.
class NavigationHistory {
  final String homeScreenId;
  final List<String> _stack;

  NavigationHistory({required this.homeScreenId}) : _stack = [homeScreenId];

  /// Écran actuellement affiché (sommet de la pile).
  String get current => _stack.last;

  /// Empile [screenId] comme nouvel écran courant (action `navigate`).
  void push(String screenId) {
    _stack.add(screenId);
  }

  /// Dépile l'écran courant et retourne le nouvel écran courant (action
  /// `back`).
  ///
  /// Si la pile ne contient déjà plus que l'écran d'accueil, ne fait rien :
  /// `back` depuis l'accueil reste sur l'accueil plutôt que de lever une
  /// erreur, pour rester cohérent avec un bouton retour qui ne doit jamais
  /// bloquer un patient déjà fatigué (section 2.3).
  String pop() {
    if (_stack.length > 1) {
      _stack.removeLast();
    }
    return current;
  }

  /// Réinitialise la pile à l'écran d'accueil uniquement (action `home`).
  String goHome() {
    _stack
      ..clear()
      ..add(homeScreenId);
    return current;
  }

  @override
  String toString() => 'NavigationHistory(stack: $_stack)';
}
