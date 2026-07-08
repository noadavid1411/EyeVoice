import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:eyevoice/data/menu_config_repository.dart';
import 'package:eyevoice/data/settings_repository.dart';
import 'package:eyevoice/domain/actions/action_resolver.dart';
import 'package:eyevoice/domain/actions/action_result.dart';
import 'package:eyevoice/domain/models/menu_item.dart';
import 'package:eyevoice/domain/models/menu_screen.dart';
import 'package:eyevoice/services/tts_service.dart';
import 'package:eyevoice/services/tts_settings.dart';

/// Mode d'affichage courant, côté `ui`, résultant de la résolution des
/// actions par le vrai [ActionResolver].
///
/// Distinct des écrans `grid-4` de `menu-config.json` : [UiMode.yesNo] est
/// un mode dédié ouvert via l'action `openMode` (section 5), pas un
/// `MenuScreen` de la configuration. [UiMode.confirmation] (section 17.2) et
/// [UiMode.settings] (section 16) suivent le même principe : ce sont des
/// écrans dédiés côté `ui`, jamais décrits dans `menu-config.json`.
enum UiMode { grid, yesNo, confirmation, settings }

/// Événement transitoire "une phrase vient d'être transmise au TTS".
///
/// Porte un [id] incrémental (plutôt qu'une simple égalité de [text]) pour
/// que la couche `ui` puisse détecter qu'une *nouvelle* occurrence de
/// synthèse vocale a eu lieu même si le texte prononcé est identique au
/// précédent (ex. le patient regarde deux fois de suite le même choix).
class SpokenPhrase {
  final String text;
  final int id;
  const SpokenPhrase(this.text, this.id);
}

/// Événement transitoire "un item non encore implémenté a été activé"
/// (ex. mode expert, réglages — hors périmètre MVP de la Phase 2, voir
/// TASKS.md Phase 3/Backlog). Même logique d'`id` incrémental que
/// [SpokenPhrase].
class ComingSoonEvent {
  final String label;
  final int id;
  const ComingSoonEvent(this.label, this.id);
}

/// État exposé par [MenuNavigationController] à la couche `ui`.
///
/// [screen] reflète toujours le dernier écran `grid-4` résolu par
/// l'[ActionResolver] (`ActionResolver.currentScreen`), y compris pendant
/// que [uiMode] vaut [UiMode.yesNo] : en sortant du mode Oui/Non, l'écran
/// grid-4 précédent doit être retrouvé sans navigation supplémentaire,
/// puisque `openMode` ne modifie pas la pile d'historique du domaine.
class MenuNavigationState {
  final MenuScreen screen;
  final UiMode uiMode;
  final SpokenPhrase? spokenPhrase;
  final ComingSoonEvent? comingSoon;

  /// `homeScreenId` du [MenuConfig] réellement chargé (`menuConfigProvider`).
  ///
  /// Exposé ici plutôt que relu directement par la couche `ui` depuis
  /// `menuConfigProvider` : [DemoHomeScreen] n'a besoin de connaître que
  /// l'écran d'accueil *tel que résolu par ce contrôleur*, pas la
  /// configuration entière — un seul point de vérité pour "quel est l'écran
  /// affiché en ce moment" ([screen]) et "quel écran est celui d'accueil"
  /// ([homeScreenId]).
  final String homeScreenId;

  /// Item en attente de confirmation (section 17.2), non-`null` seulement
  /// quand [uiMode] vaut [UiMode.confirmation]. Voir [MenuItem.requiresConfirmation]
  /// et [MenuNavigationController.activate]/[MenuNavigationController.confirmPending]/
  /// [MenuNavigationController.cancelPending].
  final MenuItem? pendingConfirmation;

  const MenuNavigationState({
    required this.screen,
    required this.uiMode,
    required this.homeScreenId,
    this.spokenPhrase,
    this.comingSoon,
    this.pendingConfirmation,
  });

  /// [clearPendingConfirmation] permet explicitement de ramener
  /// [pendingConfirmation] à `null` (le pattern `pendingConfirmation ?? this.pendingConfirmation`
  /// seul ne le permettrait jamais une fois posé).
  MenuNavigationState copyWith({
    MenuScreen? screen,
    UiMode? uiMode,
    SpokenPhrase? spokenPhrase,
    ComingSoonEvent? comingSoon,
    MenuItem? pendingConfirmation,
    bool clearPendingConfirmation = false,
  }) {
    return MenuNavigationState(
      screen: screen ?? this.screen,
      uiMode: uiMode ?? this.uiMode,
      homeScreenId: homeScreenId,
      spokenPhrase: spokenPhrase ?? this.spokenPhrase,
      comingSoon: comingSoon ?? this.comingSoon,
      pendingConfirmation: clearPendingConfirmation
          ? null
          : (pendingConfirmation ?? this.pendingConfirmation),
    );
  }
}

/// Point de câblage central entre la couche `ui` et le vrai moteur de
/// menus du domaine.
///
/// Remplace l'aiguillage d'actions local et provisoire qu'exposait
/// auparavant `DemoHomeScreen` (Phase 1c) : toute résolution d'action
/// (`navigate`/`speak`/`back`/`home`/`openMode`/`settings`/`cancel`) passe
/// désormais par le vrai [ActionResolver] (`lib/domain/actions`), et toute
/// phrase finale par le vrai [TtsService]
/// (`ref.read(ttsServiceProvider).speak(...)`). La couche `ui` n'appelle
/// plus que [activate] avec le [MenuItem] sélectionné (dwell time atteint
/// ou appui tactile en mode dégradé) et réagit à l'état exposé — elle
/// n'interprète plus aucune chaîne d'action JSON elle-même.
///
/// Construit sur le vrai `menu-config.json`, chargé via [menuConfigProvider]
/// (`lib/data/menu_config_repository.dart`) — comblement de la réserve du
/// critère 8 d'ACCEPTANCE_CHECKLIST.md.
///
/// [menuConfigProvider] est asynchrone (lecture d'asset) alors que
/// [ActionResolver] a besoin d'un `MenuConfig` synchrone à la construction.
/// Plutôt que de transformer ce contrôleur en `AsyncNotifier` — ce qui
/// aurait propagé un `AsyncValue<MenuNavigationState>` jusqu'à la moindre
/// lecture d'état dans toute la couche `ui` (`DemoHomeScreen`,
/// `gazeTrackingPipelineProvider`, tous les tests existants) pour un
/// provider qui n'est jamais censé rester en `loading`/`error` au-delà du
/// tout premier écran — le chargement est géré une seule fois, en amont,
/// au niveau racine de l'application : [EyeVoiceApp] (`lib/main.dart`)
/// n'affiche [DemoHomeScreen] (et donc ne construit ce `Notifier`) qu'une
/// fois `menuConfigProvider` résolu en `AsyncData`, via `.when(loading:,
/// error:, data:)`. `ref.watch(menuConfigProvider).requireValue` ci-dessous
/// est donc sûr : par construction, ce `build()` n'est jamais atteint tant
/// que la config n'est pas chargée avec succès. Cette même garantie doit
/// être reproduite par tout test qui construit ce contrôleur/`DemoHomeScreen`
/// hors de [EyeVoiceApp] — voir `menuConfigProvider.overrideWith(...)` dans
/// `test/ui/menu_navigation_controller_test.dart` et
/// `test/ui/demo_home_screen_test.dart`, qui fournissent `sampleMenuConfig`
/// de façon synchrone (voir la doc de [menuConfigProvider] : un
/// `FutureOr<MenuConfig>` renvoyé de façon non-`Future` résout
/// immédiatement, sans détour asynchrone, donc sans risque de flakiness).
class MenuNavigationController extends Notifier<MenuNavigationState> {
  late final ActionResolver _resolver;
  int _speechSeq = 0;
  int _comingSoonSeq = 0;

  @override
  MenuNavigationState build() {
    final config = ref.watch(menuConfigProvider).requireValue;
    _resolver = ActionResolver(config: config);
    // Réglages de synthèse vocale (section 16, `lib/ui/screens/settings_screen.dart`)
    // : appliqués immédiatement au vrai `TtsService` dès qu'ils changent,
    // sans attendre la prochaine phrase prononcée. `ref.listen` (plutôt que
    // `ref.watch`) car ce provider n'a pas besoin de se reconstruire quand
    // les réglages changent — seul le service TTS doit être mis à jour, à
    // la même échelle de durée de vie que le pipeline eye-tracking (voir
    // `gazeTrackingPipelineProvider`, `lib/ui/providers/gaze_tracking_providers.dart`).
    ref.listen<TtsSettings>(
      settingsProvider.select((s) => s.tts),
      (previous, next) => ref.read(ttsServiceProvider).updateSettings(next),
    );
    return MenuNavigationState(
      screen: _resolver.currentScreen,
      uiMode: UiMode.grid,
      homeScreenId: config.homeScreenId,
    );
  }

  /// Point d'entrée de la couche `ui` pour activer [item] (dwell time
  /// atteint ou appui tactile en mode dégradé).
  ///
  /// Lit `item.requiresConfirmation` **avant** toute résolution (section
  /// 17.2 : quitter l'application, réinitialiser les réglages, supprimer une
  /// phrase personnalisée) — voir la doc de [MenuItem.requiresConfirmation].
  /// Si `true`, [item] est mémorisé dans `state.pendingConfirmation` et
  /// [uiMode] bascule sur [UiMode.confirmation] : c'est
  /// `lib/ui/widgets/confirmation_dialog.dart` (affiché par la couche `ui`
  /// tant que ce mode est actif) qui appelle ensuite [confirmPending] ou
  /// [cancelPending] selon le choix du patient/aidant. [resolve] n'est donc
  /// **jamais** appelé pour un item sensible avant confirmation explicite.
  Future<void> activate(MenuItem item) async {
    if (item.requiresConfirmation) {
      state = state.copyWith(uiMode: UiMode.confirmation, pendingConfirmation: item);
      return;
    }
    await _resolveAndApply(item);
  }

  /// Confirme l'item actuellement en attente (`state.pendingConfirmation`,
  /// posé par [activate]) et l'exécute réellement via [_resolveAndApply].
  /// Ne fait rien si aucune confirmation n'est en attente (double-appel,
  /// ex. double frappe tactile).
  Future<void> confirmPending() async {
    final item = state.pendingConfirmation;
    if (item == null) return;
    state = state.copyWith(uiMode: UiMode.grid, clearPendingConfirmation: true);
    await _resolveAndApply(item);
  }

  /// Annule l'item actuellement en attente : conformément au contrat de
  /// [MenuItem.requiresConfirmation], `resolve` n'est jamais appelé dans ce
  /// cas — on revient simplement à l'écran grid-4 courant sans aucun effet
  /// de navigation ni d'action.
  void cancelPending() {
    state = state.copyWith(uiMode: UiMode.grid, clearPendingConfirmation: true);
  }

  /// Quitte l'écran de réglages ([UiMode.settings], section 16), ouvert via
  /// l'action `settings`/`openMode(settings)`. Même logique qu'[exitYesNo] :
  /// aucune pile de navigation à dépiler, on retrouve directement le dernier
  /// écran grid-4 connu.
  void exitSettings() {
    state = state.copyWith(uiMode: UiMode.grid);
  }

  /// Résout [item] via le vrai [ActionResolver] et réagit selon le type
  /// concret d'[ActionResult] renvoyé — un `switch` exhaustif garanti
  /// statiquement par le `sealed class` (voir `action_result.dart`).
  ///
  /// Retourne un `Future` (complet une fois l'éventuel appel TTS terminé)
  /// uniquement pour permettre aux tests d'attendre la fin de la synthèse
  /// vocale de façon déterministe ; la couche `ui` (callbacks `onActivated`
  /// synchrones des boutons de zone) n'a pas à l'attendre — parler ne doit
  /// jamais bloquer l'affichage ou la navigation (section 14.1).
  ///
  /// Appelé directement par [activate] pour un item non sensible, ou par
  /// [confirmPending] une fois la confirmation explicite obtenue pour un
  /// item sensible — jamais par [cancelPending].
  Future<void> _resolveAndApply(MenuItem item) async {
    final result = _resolver.resolve(item);
    switch (result) {
      case NavigateAction():
        // `back`/`home` sont déjà résolus en écran cible par
        // l'ActionResolver : la pile de navigation est déjà à jour ici, il
        // suffit de relire l'écran courant.
        state = state.copyWith(screen: _resolver.currentScreen, uiMode: UiMode.grid);

      case SpeakAction(:final text):
        await _speak(text);

      case OpenModeAction(:final mode):
        switch (mode) {
          case AppMode.yesNo:
            state = state.copyWith(uiMode: UiMode.yesNo);
          case AppMode.settings:
            state = state.copyWith(uiMode: UiMode.settings);
          case AppMode.expert:
            // Mode expert : hors périmètre MVP (TASKS.md, Backlog). On
            // reste sur l'écran courant et on signale juste que ce n'est
            // pas encore disponible.
            _announceComingSoon(item.label);
        }

      case SettingsAction():
        state = state.copyWith(uiMode: UiMode.settings);

      case CancelAction():
        // Aucun effet de navigation (voir doc `CancelAction`).
        break;
    }
  }

  /// Réponse fixe "Oui" du mode Sécurité (section 5) : ce texte n'est pas
  /// un [MenuItem] de `menu-config.json` (l'écran Oui/Non n'est pas décrit
  /// dans la configuration, c'est un mode dédié — voir [UiMode.yesNo]), mais
  /// la phrase finale doit tout de même passer par le même chemin
  /// TTS + affichage que toute autre phrase (section 14.1).
  Future<void> answerYes() => _speak('Oui.');

  /// Réponse fixe "Non", symétrique de [answerYes].
  Future<void> answerNo() => _speak('Non.');

  /// Quitte le mode Oui/Non. N'a jamais modifié la pile de navigation du
  /// domaine (`openMode` ne pousse rien dans l'historique), donc il n'y a
  /// rien à dépiler : on retrouve directement le dernier écran grid-4 connu.
  void exitYesNo() {
    state = state.copyWith(uiMode: UiMode.grid);
  }

  Future<void> _speak(String text) async {
    await ref.read(ttsServiceProvider).speak(text);
    state = state.copyWith(spokenPhrase: SpokenPhrase(text, _speechSeq++));
  }

  void _announceComingSoon(String label) {
    state = state.copyWith(comingSoon: ComingSoonEvent(label, _comingSoonSeq++));
  }
}

final menuNavigationProvider =
    NotifierProvider<MenuNavigationController, MenuNavigationState>(
  MenuNavigationController.new,
);
