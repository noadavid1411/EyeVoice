import 'package:flutter/material.dart';

import '../../eyetracking/models/gaze_state.dart';
import '../screens/yes_no_screen.dart';
import '../theme/app_colors.dart';

/// Confirmation d'une action sensible (SPECIFICATIONS_FONCTIONNELLES.md
/// section 17.2 : quitter l'application, réinitialiser les réglages,
/// supprimer une phrase personnalisée).
///
/// Réutilise entièrement [YesNoScreen] (même grandes zones OUI/NON, même
/// pilotage par dwell time ou appui tactile) plutôt que de dupliquer un
/// second écran à 2 zones : la confirmation d'une action sensible *est*,
/// visuellement et fonctionnellement, une question Oui/Non comme une autre
/// — seule la couleur du message change (rouge d'alerte plutôt que jaune)
/// pour signaler qu'il s'agit d'une action à conséquence, conformément à
/// [AppColors.danger].
///
/// Deux points d'usage prévus :
/// - piloté par le regard, intégré au flux principal quand
///   `MenuItem.requiresConfirmation` est vrai (voir
///   `MenuNavigationController.activate`/`confirmPending`/`cancelPending`,
///   affiché par `DemoHomeScreen` tant que `uiMode == UiMode.confirmation`) ;
/// - poussé via `Navigator.push` pour une action locale à un écran qui
///   n'est pas un `MenuItem` de `menu-config.json` (ex. le bouton
///   "Réinitialiser les réglages" de `lib/ui/screens/settings_screen.dart`),
///   auquel cas [gazeState] reste à sa valeur par défaut ([GazeState.idle])
///   et seul l'appui tactile est pertinent (écran de réglages orienté
///   aidant, section 10.4).
class ConfirmationDialog extends StatelessWidget {
  /// Message posé au patient/aidant (ex. "Confirmer : Quitter ?"). Fourni
  /// par l'appelant, jamais codé en dur ici (section 11.1).
  final String message;

  /// État de regard courant, déjà résolu par la couche `eyetracking`. Reste
  /// à [GazeState.idle] par défaut pour un usage purement tactile (voir la
  /// doc de la classe).
  final GazeState gazeState;

  /// Appelé quand l'utilisateur confirme ("Oui").
  final VoidCallback onConfirm;

  /// Appelé quand l'utilisateur annule ("Non").
  final VoidCallback onCancel;

  const ConfirmationDialog({
    super.key,
    required this.message,
    required this.onConfirm,
    required this.onCancel,
    this.gazeState = const GazeState.idle(),
  });

  @override
  Widget build(BuildContext context) {
    return YesNoScreen(
      question: message,
      questionColor: AppColors.danger,
      gazeState: gazeState,
      onYes: onConfirm,
      onNo: onCancel,
      // "Non" annule déjà l'action sensible (contrat de
      // `MenuItem.requiresConfirmation` : ne jamais résoudre l'action sans
      // confirmation explicite) ; l'affordance de sortie discrète en haut
      // d'écran doit avoir le même effet qu'un "Non" explicite plutôt que
      // de laisser un état de confirmation sans issue.
      onExit: onCancel,
    );
  }
}
