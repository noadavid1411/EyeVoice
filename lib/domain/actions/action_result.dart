/// Contrat de sortie du futur `ActionResolver` (Phase 1a,
/// domain-logic-engineer).
///
/// [ActionResult] représente une intention **déjà résolue**, prête à être
/// exécutée telle quelle par la couche `ui`. L'UI ne doit jamais interpréter
/// les chaînes d'action brutes de `menu-config.json` (`navigate`, `back`,
/// `home`, `openMode`, `settings`, `cancel` — section 12) ni connaître la
/// pile d'historique de navigation : c'est le rôle de l'`ActionResolver` de
/// transformer un item de menu + l'état de navigation courant en une valeur
/// de ce type.
///
/// En particulier, `back` et `home` sont résolus par l'`ActionResolver` en
/// [NavigateAction] pointant vers l'écran cible déterminé via la pile de
/// navigation : l'UI n'a donc à gérer qu'un seul cas de figure pour tout
/// changement d'écran, qu'il s'agisse d'une navigation avant ou arrière.
///
/// Utiliser un `sealed class` (plutôt qu'un enum + payload générique)
/// permet à la couche `ui` de traiter les cas par un `switch` exhaustif
/// vérifié statiquement par l'analyseur Dart, ce qui évite d'oublier un cas
/// lorsqu'une nouvelle action sera ajoutée.
///
/// Voir SPECIFICATIONS_FONCTIONNELLES.md section 12.
sealed class ActionResult {
  const ActionResult();
}

/// Affiche l'écran identifié par [screenId] (doit correspondre à un `id` de
/// `menu-config.json`).
///
/// Couvre, une fois résolues par l'`ActionResolver` : l'action JSON
/// `navigate` (cible explicite), `back` (écran précédent dans la pile de
/// navigation) et `home` (écran d'accueil, `homeScreenId`).
final class NavigateAction extends ActionResult {
  final String screenId;

  const NavigateAction(this.screenId);

  @override
  bool operator ==(Object other) =>
      other is NavigateAction && other.screenId == screenId;

  @override
  int get hashCode => screenId.hashCode;

  @override
  String toString() => 'NavigateAction(screenId: $screenId)';
}

/// Fait prononcer [text] par le service de synthèse vocale (action `speak`,
/// section 14).
final class SpeakAction extends ActionResult {
  final String text;

  const SpeakAction(this.text);

  @override
  bool operator ==(Object other) => other is SpeakAction && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'SpeakAction(text: $text)';
}

/// Ouvre un mode applicatif dédié [mode] (action `openMode`) : Oui/Non,
/// Expert, ou Réglages. Distinct d'un [NavigateAction] car ces modes ne
/// sont pas nécessairement des écrans génériques `grid-4` décrits dans
/// `menu-config.json`, mais des routes/écrans dédiés côté `ui`.
final class OpenModeAction extends ActionResult {
  final AppMode mode;

  const OpenModeAction(this.mode);

  @override
  bool operator ==(Object other) => other is OpenModeAction && other.mode == mode;

  @override
  int get hashCode => mode.hashCode;

  @override
  String toString() => 'OpenModeAction(mode: $mode)';
}

/// Ouvre l'écran des réglages (action `settings`).
///
/// Conservée distincte de `OpenModeAction(AppMode.settings)` pour refléter
/// fidèlement la section 12 des spécifications, qui liste `openMode` et
/// `settings` comme deux actions séparées dans le vocabulaire JSON. Le
/// choix entre les deux formulations équivalentes revient à l'auteur de
/// `menu-config.json` ; l'`ActionResolver` les mappe chacune vers son
/// propre [ActionResult].
final class SettingsAction extends ActionResult {
  const SettingsAction();

  @override
  bool operator ==(Object other) => other is SettingsAction;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'SettingsAction()';
}

/// Annule la sélection/action en cours, sans effet de navigation (action
/// `cancel`). Sert notamment de socle pour la confirmation des actions
/// sensibles (section 17.2, Phase 3) : un écran de confirmation peut
/// résoudre son choix "Non" en [CancelAction].
final class CancelAction extends ActionResult {
  const CancelAction();

  @override
  bool operator ==(Object other) => other is CancelAction;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'CancelAction()';
}

/// Modes applicatifs dédiés ouvrables via [OpenModeAction].
enum AppMode {
  /// Écran Oui/Non à 2 zones (section 5, Niveau 1 — Mode Sécurité).
  yesNo,

  /// Mode expert de saisie libre par balayage (section 8, Niveau 4).
  expert,

  /// Écran de réglages (section 16).
  settings,
}
