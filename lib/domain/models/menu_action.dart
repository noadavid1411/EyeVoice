import 'package:eyevoice/domain/actions/action_result.dart';
import 'package:eyevoice/domain/models/menu_config_exception.dart';

/// Vocabulaire d'actions autorisé pour un item de `menu-config.json`
/// (SPECIFICATIONS_FONCTIONNELLES.md section 12).
///
/// Les valeurs correspondent exactement aux chaînes JSON attendues (ex.
/// `"action": "navigate"`), ce qui permet un mapping direct dans
/// [MenuAction.fromJson] sans table de correspondance séparée à maintenir.
enum MenuAction {
  navigate,
  speak,
  back,
  home,
  openMode,
  settings,
  cancel;

  /// Parse la chaîne JSON `action` d'un item de menu.
  ///
  /// Lève [MenuConfigParseException] si [raw] ne correspond à aucune action
  /// connue — une faute de frappe dans `menu-config.json` doit échouer tôt
  /// et clairement plutôt que de silencieusement désactiver un bouton.
  static MenuAction fromJson(String raw) => switch (raw) {
        'navigate' => MenuAction.navigate,
        'speak' => MenuAction.speak,
        'back' => MenuAction.back,
        'home' => MenuAction.home,
        'openMode' => MenuAction.openMode,
        'settings' => MenuAction.settings,
        'cancel' => MenuAction.cancel,
        _ => throw MenuConfigParseException(
            "Action inconnue : '$raw' (attendu : navigate, speak, back, "
            'home, openMode, settings, cancel — section 12)',
          ),
      };
}

/// Parse la cible textuelle d'un item `openMode` (ex. `"target": "yes-no"`)
/// vers le mode applicatif [AppMode] correspondant (contrat Phase 0,
/// `lib/domain/actions/action_result.dart`).
///
/// Convention de nommage kebab-case retenue pour rester cohérente avec les
/// autres valeurs de chaîne du schéma (ex. zones `top-left`) : ce n'est pas
/// imposé par les spécifications fonctionnelles, qui ne fixent pas de
/// convention pour les cibles `openMode`. À faire valider par le chef de
/// projet/architecte si `menu-config.json` réel adopte une autre
/// convention.
AppMode appModeFromTarget(String raw) => switch (raw) {
      'yes-no' => AppMode.yesNo,
      'expert' => AppMode.expert,
      'settings' => AppMode.settings,
      _ => throw MenuConfigParseException(
          "Cible openMode inconnue : '$raw' (attendu : yes-no, expert, "
          'settings)',
        ),
    };
