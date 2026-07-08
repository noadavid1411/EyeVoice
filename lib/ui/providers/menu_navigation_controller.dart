import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:eyevoice/domain/actions/action_resolver.dart';
import 'package:eyevoice/domain/actions/action_result.dart';
import 'package:eyevoice/domain/models/menu_item.dart';
import 'package:eyevoice/domain/models/menu_screen.dart';
import 'package:eyevoice/domain/models/sample_menu_config.dart';
import 'package:eyevoice/services/tts_service.dart';

/// Mode d'affichage courant, côté `ui`, résultant de la résolution des
/// actions par le vrai [ActionResolver].
///
/// Distinct des écrans `grid-4` de `menu-config.json` : [UiMode.yesNo] est
/// un mode dédié ouvert via l'action `openMode` (section 5), pas un
/// `MenuScreen` de la configuration.
enum UiMode { grid, yesNo }

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

  const MenuNavigationState({
    required this.screen,
    required this.uiMode,
    this.spokenPhrase,
    this.comingSoon,
  });

  MenuNavigationState copyWith({
    MenuScreen? screen,
    UiMode? uiMode,
    SpokenPhrase? spokenPhrase,
    ComingSoonEvent? comingSoon,
  }) {
    return MenuNavigationState(
      screen: screen ?? this.screen,
      uiMode: uiMode ?? this.uiMode,
      spokenPhrase: spokenPhrase ?? this.spokenPhrase,
      comingSoon: comingSoon ?? this.comingSoon,
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
/// Utilise toujours `sampleMenuConfig` (Phase 1a) : le chargement d'un vrai
/// `menu-config.json` depuis un fichier/asset reste hors périmètre de cette
/// phase (TASKS.md, Phase 2 ne couvre que le branchement de l'
/// `ActionResolver`, pas le chargement JSON réel).
class MenuNavigationController extends Notifier<MenuNavigationState> {
  late final ActionResolver _resolver;
  int _speechSeq = 0;
  int _comingSoonSeq = 0;

  @override
  MenuNavigationState build() {
    _resolver = ActionResolver(config: sampleMenuConfig);
    return MenuNavigationState(
      screen: _resolver.currentScreen,
      uiMode: UiMode.grid,
    );
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
  Future<void> activate(MenuItem item) async {
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
          case AppMode.expert:
          case AppMode.settings:
            // Mode expert et réglages : hors périmètre MVP de cette phase
            // (TASKS.md, Phase 3/Backlog). On reste sur l'écran courant et
            // on signale juste que ce n'est pas encore disponible.
            _announceComingSoon(item.label);
        }

      case SettingsAction():
        _announceComingSoon(item.label);

      case CancelAction():
        // Aucun effet de navigation (voir doc `CancelAction`) : rien à
        // faire tant que la confirmation des actions sensibles (Phase 3)
        // n'est pas branchée.
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
