import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/screen_zone.dart';
import '../../domain/models/menu_action.dart';
import '../../domain/models/menu_item.dart';
import '../../domain/models/menu_screen.dart';
import '../../eyetracking/models/gaze_state.dart';
import '../../eyetracking/models/screen_layout_mode.dart';
import '../providers/gaze_tracking_providers.dart';
import '../providers/menu_navigation_controller.dart';
import '../screens/expert_mode_screen.dart';
import '../screens/grid4_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/yes_no_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/confirmation_dialog.dart';

/// Item synthétique "retour au menu principal", réutilisé pour
/// [ExpertModeScreen.onExitToHome] (section 8.6) : construit exactement
/// comme le ferait `menu-config.json` pour un item `home` (voir
/// `MenuAction.home`), puis résolu par le vrai [ActionResolver] via
/// `MenuNavigationController.activate` — aucune logique de navigation
/// nouvelle, conformément à la consigne "réutilise l'existant, ne
/// réimplémente rien" (section 8.6).
const _expertHomeItem = MenuItem(
  zone: ScreenZone.bottomRight,
  label: 'Accueil',
  action: MenuAction.home,
);

/// Écran d'accueil réel de l'application.
///
/// Câble [Grid4Screen] et [YesNoScreen] sur le vrai moteur de navigation :
/// - [menuNavigationProvider] (`lib/ui/providers/menu_navigation_controller.dart`),
///   lui-même adossé au vrai `ActionResolver` du domaine — plus aucune
///   résolution d'action (`navigate`/`speak`/`back`/`home`/`openMode`/
///   `settings`/`cancel`) n'a lieu dans cette couche `ui` ;
/// - [gazeStateProvider] (`lib/ui/providers/gaze_tracking_providers.dart`),
///   qui expose le flux de `GazeState` du vrai `GazeTrackingPipeline`
///   (détection → mapping → zones → dwell time), lui-même alimenté par
///   [FakeFaceGazeDetector] en l'absence de caméra dans cet environnement
///   (voir la doc de ce détecteur pour le point de bascule vers le vrai
///   `FaceMeshGazeDetector`).
///
/// N'est monté par [EyeVoiceApp] (`lib/main.dart`) qu'une fois le vrai
/// `menu-config.json` chargé avec succès (`menuConfigProvider`,
/// `lib/data/menu_config_repository.dart`) : voir la doc de
/// [MenuNavigationController] pour la justification de ce séquencement.
///
/// Phase 3 (TASKS.md) : affiche aussi [ConfirmationDialog] tant que
/// `uiMode == UiMode.confirmation` (section 17.2, actions sensibles),
/// [SettingsScreen] tant que `uiMode == UiMode.settings` (section 16,
/// réglages configurables), et [ExpertModeScreen] tant que
/// `uiMode == UiMode.expert` (section 8, Niveau 4 — Mode Expert) — trois
/// écrans dédiés côté `ui`, au même titre que [YesNoScreen], jamais décrits
/// dans `menu-config.json`.
class DemoHomeScreen extends ConsumerWidget {
  const DemoHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Garde le pipeline eyetracking synchronisé avec la disposition de
    // zones actuellement affichée (grille 4 zones vs Oui/Non) : la couche
    // `eyetracking` ne connaît pas menu-config.json, c'est à la couche
    // appelante de le lui indiquer (voir `GazeTrackingPipeline.setLayoutMode`
    // et la doc de `ScreenLayoutMode`). Appeler `ref.listen` à chaque build
    // est le pattern Riverpod standard pour ce genre d'effet de bord lié au
    // cycle de vie du widget.
    ref.listen<ScreenLayoutMode>(screenLayoutModeProvider, (previous, next) {
      ref.read(gazeTrackingPipelineProvider).setLayoutMode(next);
    });

    // Réagit à l'événement transitoire "phrase transmise au TTS" exposé par
    // le contrôleur de navigation en affichant un retour visuel ponctuel,
    // sans coupler cet événement à l'état persistant de l'écran affiché.
    ref.listen<MenuNavigationState>(menuNavigationProvider, (previous, next) {
      final spoken = next.spokenPhrase;
      if (spoken != null && spoken.id != previous?.spokenPhrase?.id) {
        _showSpokenPhrase(context, spoken.text);
      }
    });

    final navState = ref.watch(menuNavigationProvider);
    final gazeState = ref.watch(gazeStateProvider).value ?? const GazeState.idle();
    final controller = ref.read(menuNavigationProvider.notifier);

    if (navState.uiMode == UiMode.yesNo) {
      return YesNoScreen(
        question: 'Tu as mal ?',
        gazeState: gazeState,
        onYes: controller.answerYes,
        onNo: controller.answerNo,
        onExit: controller.exitYesNo,
      );
    }

    // Confirmation d'une action sensible (section 17.2) : `resolve()` n'a
    // volontairement pas encore été appelé pour `pendingConfirmation` (voir
    // `MenuNavigationController.activate`) — seul un "Oui" explicite du
    // patient/aidant déclenche réellement l'action.
    final pending = navState.pendingConfirmation;
    if (navState.uiMode == UiMode.confirmation && pending != null) {
      return ConfirmationDialog(
        message: 'Confirmer : ${pending.label} ?',
        gazeState: gazeState,
        onConfirm: controller.confirmPending,
        onCancel: controller.cancelPending,
      );
    }

    if (navState.uiMode == UiMode.settings) {
      return SettingsScreen(onClose: controller.exitSettings);
    }

    // Mode expert (section 8, Niveau 4) : "revenir au menu principal"
    // réutilise directement `activate` avec un item `home` synthétique —
    // exactement la même résolution `back`/`home` que n'importe quel item
    // de `menu-config.json` (voir la doc de `_expertHomeItem`).
    if (navState.uiMode == UiMode.expert) {
      return ExpertModeScreen(
        gazeState: gazeState,
        onExitToHome: () => controller.activate(_expertHomeItem),
      );
    }

    final screen = navState.screen;
    final isHome = screen.id == navState.homeScreenId;
    return Grid4Screen(
      title: isHome ? null : screen.title,
      gazeState: gazeState,
      items: _itemsFor(screen, controller),
    );
  }

  List<Grid4Item> _itemsFor(MenuScreen screen, MenuNavigationController controller) => [
        for (final item in screen.items)
          Grid4Item(
            zone: item.zone,
            label: item.label,
            backgroundColor:
                item.action == MenuAction.back || item.action == MenuAction.home
                    ? AppColors.navigation
                    : AppColors.surface,
            onActivated: () => controller.activate(item),
          ),
      ];

  static void _showSpokenPhrase(BuildContext context, String phrase) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceHighlight,
        content: Text(
          '🔊 $phrase',
          style: AppTextStyles.caption.copyWith(color: AppColors.textAccent),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
