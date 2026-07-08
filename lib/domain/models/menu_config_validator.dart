import 'package:eyevoice/core/constants/app_defaults.dart';
import 'package:eyevoice/core/models/screen_zone.dart';
import 'package:eyevoice/domain/models/menu_action.dart';
import 'package:eyevoice/domain/models/menu_config.dart';
import 'package:eyevoice/domain/models/menu_config_exception.dart';

/// Vérifie les règles métier globales d'un [MenuConfig] déjà parsé.
///
/// Contrairement au parsing (`MenuConfig.fromJson`), qui vérifie la forme du
/// JSON écran par écran, cette fonction vérifie la cohérence de
/// **l'ensemble** de la configuration : elle a besoin de voir tous les
/// écrans à la fois (ex. pour résoudre les cibles `navigate`).
///
/// Règles vérifiées (SPECIFICATIONS_FONCTIONNELLES.md) :
/// - section 4.1/10.1 : aucun écran ne dépasse
///   [AppDefaults.maxChoicesPerScreen] choix (règle du carré magique) ;
/// - identifiants d'écran uniques ;
/// - `homeScreenId` correspond à un écran existant ;
/// - une même zone n'est pas utilisée deux fois sur un même écran ;
/// - un item `navigate` a un `target` non vide qui référence un écran
///   existant ;
/// - un item `speak` a un `text` non vide (section 14.1 : toute phrase
///   finale doit pouvoir être prononcée).
///
/// Toutes les erreurs sont collectées avant de lever
/// [MenuConfigValidationException], plutôt que de s'arrêter à la première,
/// pour permettre de corriger `menu-config.json` en une seule passe.
void validateMenuConfig(MenuConfig config) {
  final errors = <String>[];
  final screenIds = <String>{};

  for (final screen in config.screens) {
    if (!screenIds.add(screen.id)) {
      errors.add("Identifiant d'écran dupliqué : '${screen.id}'");
    }
  }

  for (final screen in config.screens) {
    if (screen.items.length > AppDefaults.maxChoicesPerScreen) {
      errors.add(
        "Écran '${screen.id}' propose ${screen.items.length} choix "
        '(maximum autorisé : ${AppDefaults.maxChoicesPerScreen} — règle du '
        'carré magique, section 4.1)',
      );
    }

    final seenZones = <ScreenZone>{};
    for (final item in screen.items) {
      if (!seenZones.add(item.zone)) {
        errors.add(
          "Écran '${screen.id}' : la zone '${item.zone.name}' est utilisée "
          'par plusieurs items',
        );
      }

      switch (item.action) {
        case MenuAction.navigate:
          final target = item.target;
          if (target == null || target.isEmpty) {
            errors.add(
              "Écran '${screen.id}' : item '${item.label}' de type "
              "'navigate' sans 'target'",
            );
          } else if (!screenIds.contains(target)) {
            errors.add(
              "Écran '${screen.id}' : item '${item.label}' cible l'écran "
              "'$target', introuvable dans la configuration",
            );
          }
        case MenuAction.speak:
          final text = item.text;
          if (text == null || text.isEmpty) {
            errors.add(
              "Écran '${screen.id}' : item '${item.label}' de type "
              "'speak' sans 'text'",
            );
          }
        case MenuAction.back:
        case MenuAction.home:
        case MenuAction.settings:
        case MenuAction.cancel:
          break;
        case MenuAction.openMode:
          if (item.mode == null) {
            errors.add(
              "Écran '${screen.id}' : item '${item.label}' de type "
              "'openMode' sans mode résolu",
            );
          }
      }
    }
  }

  if (!screenIds.contains(config.homeScreenId)) {
    errors.add(
      "homeScreenId '${config.homeScreenId}' ne correspond à aucun écran "
      'de la configuration',
    );
  }

  if (errors.isNotEmpty) {
    throw MenuConfigValidationException(errors);
  }
}

/// Parse [json] en [MenuConfig] puis applique [validateMenuConfig].
///
/// Point d'entrée unique recommandé pour charger une configuration : lève
/// [MenuConfigParseException] si le JSON est mal formé, ou
/// [MenuConfigValidationException] s'il est bien formé mais incohérent.
MenuConfig loadMenuConfig(Map<String, dynamic> json) {
  final config = MenuConfig.fromJson(json);
  validateMenuConfig(config);
  return config;
}
