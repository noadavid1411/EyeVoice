import 'package:eyevoice/core/models/screen_zone.dart';
import 'package:eyevoice/domain/actions/action_result.dart';
import 'package:eyevoice/domain/models/menu_action.dart';
import 'package:eyevoice/domain/models/menu_config_exception.dart';

/// Un item sélectionnable au sein d'un [MenuScreen] (une entrée du tableau
/// `items` de `menu-config.json`, section 11.2).
///
/// Les champs [target]/[text]/[mode] sont mutuellement dépendants de
/// [action] (ex. `target` n'a de sens que pour `navigate`) plutôt que
/// modélisés en sous-classes scellées par action : cela reflète fidèlement
/// la forme plate du JSON source et évite une couche de mapping
/// supplémentaire. La cohérence (ex. `navigate` sans `target`) est vérifiée
/// par `validateMenuConfig`, pas par le type lui-même.
class MenuItem {
  /// Zone de l'écran occupée par cet item (section 4.1 et 13.3).
  final ScreenZone zone;

  /// Libellé affiché/prononcé pour cet item.
  final String label;

  /// Action déclenchée à la sélection (section 12).
  final MenuAction action;

  /// Identifiant de l'écran cible, requis si [action] == [MenuAction.navigate].
  final String? target;

  /// Texte à prononcer, requis si [action] == [MenuAction.speak].
  final String? text;

  /// Mode applicatif à ouvrir, requis si [action] == [MenuAction.openMode]
  /// (dérivé de `target` au parsing, voir [appModeFromTarget]).
  final AppMode? mode;

  /// Marque cet item comme une "action sensible" nécessitant une
  /// confirmation avant exécution (section 17.2 : quitter l'application,
  /// réinitialiser les réglages, supprimer une phrase personnalisée).
  ///
  /// **Contrat avec la couche `ui`** : ce champ est une simple donnée
  /// exposée par le domaine, jamais interprétée ici. C'est à la couche `ui`
  /// de lire `item.requiresConfirmation` **avant** d'appeler
  /// `ActionResolver.resolve(item)` et, si `true`, d'afficher un dialogue de
  /// confirmation (ex. "Oui, confirmer" / "Non, annuler") ; ce n'est
  /// qu'après validation explicite du patient/aidant que l'UI doit appeler
  /// `resolve(item)` pour obtenir l'[ActionResult] réel. Si l'utilisateur
  /// annule, l'UI n'appelle simplement jamais `resolve` — inutile de
  /// modéliser un `CancelAction` particulier pour ce cas, [CancelAction]
  /// existe déjà pour l'action JSON `cancel` elle-même.
  ///
  /// Volontairement **non pris en compte par `ActionResolver`** : ce
  /// dernier reste une fonction de résolution pure (item + état de
  /// navigation → résultat), sans notion de dialogue ni d'attente
  /// utilisateur — voir la doc de `ActionResolver`.
  ///
  /// Défaut `false` : la plupart des items (navigation, phrases) ne sont pas
  /// sensibles. Champ JSON optionnel `"requiresConfirmation": true/false`
  /// dans `menu-config.json` (extension de la section 11.2, non présente
  /// dans l'exemple de référence mais rétrocompatible : absent ⇒ `false`).
  final bool requiresConfirmation;

  const MenuItem({
    required this.zone,
    required this.label,
    required this.action,
    this.target,
    this.text,
    this.mode,
    this.requiresConfirmation = false,
  }) : assert(
          action != MenuAction.openMode || mode != null,
          "Un item 'openMode' doit avoir un champ 'mode' résolu (utiliser "
          'appModeFromTarget lors de constructions directes hors JSON, où '
          "'mode' n'est pas dérivé automatiquement de 'target')",
        );

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    final zoneRaw = json['zone'];
    final labelRaw = json['label'];
    final actionRaw = json['action'];

    if (zoneRaw is! String) {
      throw const MenuConfigParseException(
        "Item de menu invalide : champ 'zone' manquant ou non textuel",
      );
    }
    if (labelRaw is! String || labelRaw.isEmpty) {
      throw const MenuConfigParseException(
        "Item de menu invalide : champ 'label' manquant ou vide",
      );
    }
    if (actionRaw is! String) {
      throw const MenuConfigParseException(
        "Item de menu invalide : champ 'action' manquant ou non textuel",
      );
    }

    final zone = _zoneFromJson(zoneRaw);
    final action = MenuAction.fromJson(actionRaw);

    final targetRaw = json['target'];
    if (targetRaw != null && targetRaw is! String) {
      throw const MenuConfigParseException("Champ 'target' non textuel");
    }
    final textRaw = json['text'];
    if (textRaw != null && textRaw is! String) {
      throw const MenuConfigParseException("Champ 'text' non textuel");
    }

    AppMode? mode;
    if (action == MenuAction.openMode) {
      if (targetRaw == null) {
        throw const MenuConfigParseException(
          "Item 'openMode' sans champ 'target'",
        );
      }
      mode = appModeFromTarget(targetRaw as String);
    }

    final requiresConfirmationRaw = json['requiresConfirmation'];
    if (requiresConfirmationRaw != null && requiresConfirmationRaw is! bool) {
      throw const MenuConfigParseException(
        "Champ 'requiresConfirmation' non booléen",
      );
    }

    return MenuItem(
      zone: zone,
      label: labelRaw,
      action: action,
      target: targetRaw as String?,
      text: textRaw as String?,
      mode: mode,
      requiresConfirmation: requiresConfirmationRaw as bool? ?? false,
    );
  }

  @override
  String toString() =>
      'MenuItem(zone: $zone, label: $label, action: $action, '
      'target: $target, text: $text, mode: $mode, '
      'requiresConfirmation: $requiresConfirmation)';
}

/// Parse la chaîne JSON `zone` (section 13.3).
///
/// `center-dead-zone` est acceptée par symétrie avec [ScreenZone] mais ne
/// devrait normalement jamais apparaître dans `menu-config.json` : la zone
/// morte ne déclenche par définition aucune action (section 4.3). Le
/// validateur de schéma n'interdit pas explicitement ce cas pour l'instant
/// — un item placé dans cette zone serait simplement inatteignable par le
/// regard, ce qui n'est pas une erreur de structure.
ScreenZone _zoneFromJson(String raw) => switch (raw) {
      'top-left' => ScreenZone.topLeft,
      'top-right' => ScreenZone.topRight,
      'bottom-left' => ScreenZone.bottomLeft,
      'bottom-right' => ScreenZone.bottomRight,
      'left' => ScreenZone.left,
      'right' => ScreenZone.right,
      'center-dead-zone' => ScreenZone.centerDeadZone,
      _ => throw MenuConfigParseException(
          "Zone inconnue : '$raw' (attendu : top-left, top-right, "
          'bottom-left, bottom-right, left, right, center-dead-zone — '
          'section 13.3)',
        ),
    };
