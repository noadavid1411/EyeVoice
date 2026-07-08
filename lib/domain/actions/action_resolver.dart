import 'package:eyevoice/domain/actions/action_result.dart';
import 'package:eyevoice/domain/actions/navigation_history.dart';
import 'package:eyevoice/domain/models/menu_action.dart';
import 'package:eyevoice/domain/models/menu_config.dart';
import 'package:eyevoice/domain/models/menu_item.dart';
import 'package:eyevoice/domain/models/menu_screen.dart';

/// Résout un [MenuItem] de `menu-config.json` en [ActionResult] concret,
/// prêt à être exécuté par la couche `ui`.
///
/// C'est le seul point du code métier qui interprète les chaînes d'action
/// JSON brutes (`navigate`, `speak`, `back`, `home`, `openMode`, `settings`,
/// `cancel` — section 12) et qui manipule l'historique de navigation. La
/// couche `ui` ne fait qu'appeler [resolve] avec l'item sélectionné (une
/// fois le dwell time atteint) et exécute le [ActionResult] renvoyé, sans
/// jamais avoir à connaître les chaînes JSON ni la pile de navigation.
///
/// Le [MenuConfig] fourni doit avoir été validé au préalable via
/// `validateMenuConfig` (`menu_config_validator.dart`) : ce resolver
/// suppose une configuration cohérente (cibles `navigate` existantes, etc.)
/// et ne revalide pas — toute incohérence résiduelle se traduirait par une
/// exception non gérée plutôt qu'un comportement dégradé silencieux.
class ActionResolver {
  final MenuConfig _config;
  final NavigationHistory _history;

  ActionResolver({required MenuConfig config, NavigationHistory? history})
      : _config = config,
        _history = history ?? NavigationHistory(homeScreenId: config.homeScreenId);

  /// Écran actuellement affiché, selon l'historique de navigation.
  MenuScreen get currentScreen => _config.screenById(_history.current);

  /// Résout [item] en [ActionResult].
  ///
  /// `navigate` empile l'écran cible et le retourne ; `back`/`home`
  /// dépilent/réinitialisent l'historique et retournent l'écran résultant :
  /// dans les trois cas, la couche `ui` ne reçoit qu'un [NavigateAction],
  /// sans distinction à faire entre navigation avant et arrière.
  ActionResult resolve(MenuItem item) {
    switch (item.action) {
      case MenuAction.navigate:
        final target = item.target!;
        _history.push(target);
        return NavigateAction(target);

      case MenuAction.speak:
        return SpeakAction(item.text!);

      case MenuAction.back:
        return NavigateAction(_history.pop());

      case MenuAction.home:
        return NavigateAction(_history.goHome());

      case MenuAction.openMode:
        return OpenModeAction(item.mode!);

      case MenuAction.settings:
        return const SettingsAction();

      case MenuAction.cancel:
        return const CancelAction();
    }
  }
}
