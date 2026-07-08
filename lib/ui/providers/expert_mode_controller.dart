import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/expert/expert_text_composer.dart';
import '../../domain/expert/letter_group.dart';
import '../../domain/expert/word_predictor.dart';
import '../../services/tts_service.dart';

/// Étape actuellement affichée par `ExpertModeScreen`
/// (`lib/ui/screens/expert_mode_screen.dart`) au sein du mode expert
/// (SPECIFICATIONS_FONCTIONNELLES.md section 8).
///
/// La zone de composition (texte + suggestions, section 8.5) reste visible
/// en permanence quelle que soit l'étape ([ExpertModeState.text]/
/// [ExpertModeState.suggestions]) : seule la grille balayée par
/// `ScanningGrid` (`lib/ui/widgets/scanning_grid.dart`) change selon [step].
enum ExpertStep {
  /// Étape 1 (section 8.3) : choix d'un groupe de lettres parmi les 4 zones
  /// de [LetterGroup]. Point de retour par défaut après toute autre action
  /// (lettre ajoutée, espace, effacement, suggestion appliquée, phrase
  /// validée) — voir la doc de [ExpertModeController].
  group,

  /// Étape 2 (section 8.4) : choix d'une lettre dans
  /// [ExpertModeState.selectedGroup], présentée par pages d'au plus
  /// [ExpertModeController.lettersPageSize] lettres
  /// ([ExpertModeState.letterPageIndex]).
  letters,

  /// Fonctions minimales du mode expert (section 8.6) autres que "ajouter
  /// une lettre" (déjà couverte par [group]/[letters]) : effacer la
  /// dernière lettre, insérer un espace, valider le mot/la phrase, revenir
  /// au menu principal.
  actions,
}

/// État exposé par [ExpertModeController] à la couche `ui`.
@immutable
class ExpertModeState {
  /// Texte composé courant (`ExpertTextComposer.text`).
  final String text;

  /// Mot en cours de saisie (`ExpertTextComposer.currentWord`), préfixe
  /// utilisé pour [suggestions].
  final String currentWord;

  /// Suggestions de mots courantes (section 8.5, `WordPredictor.suggest`).
  final List<String> suggestions;

  /// Étape actuellement affichée.
  final ExpertStep step;

  /// Groupe de lettres choisi à l'étape 1, non-`null` uniquement quand
  /// [step] vaut [ExpertStep.letters].
  final LetterGroup? selectedGroup;

  /// Page de lettres actuellement affichée au sein de [selectedGroup]
  /// (section 8.4 : "pages successives").
  final int letterPageIndex;

  const ExpertModeState({
    required this.text,
    required this.currentWord,
    required this.suggestions,
    required this.step,
    this.selectedGroup,
    this.letterPageIndex = 0,
  });
}

/// Câblage Riverpod des fondations pures du mode expert
/// (`ExpertTextComposer`/`WordPredictor`, `lib/domain/expert/` — aucune
/// dépendance Flutter) sur le modèle exact de `MenuNavigationController`
/// (`lib/ui/providers/menu_navigation_controller.dart`) : la couche `ui`
/// (`ExpertModeScreen`) ne lit et n'écrit que l'état exposé ici, elle ne
/// manipule jamais [ExpertTextComposer] directement.
///
/// **Durée de vie de la composition en cours** : l'instance
/// d'[ExpertTextComposer] est créée une seule fois dans [build] et vit tant
/// que ce provider reste observé (pas d'`autoDispose`, même choix que
/// `menuNavigationProvider`). Elle n'est réinitialisée explicitement que
/// dans deux cas :
/// - [reset] est appelé par `ExpertModeScreen` à chaque **entrée** dans le
///   mode expert (nouvelle "session" de communication) — un patient qui
///   bascule entre les sous-écrans internes groupe/lettres/actions ne perd
///   donc jamais son mot en cours, seule une sortie complète du mode
///   expert (retour au menu principal) puis une nouvelle entrée efface la
///   composition ;
/// - [validate] réinitialise le texte après l'avoir transmis au TTS, pour
///   repartir sur une phrase vierge (comportement symétrique de la section
///   7.3 : une phrase finale prononcée cède la place à un état neutre).
class ExpertModeController extends Notifier<ExpertModeState> {
  /// Nombre de lettres affichées par page à l'étape 2 (section 8.4).
  ///
  /// Volontairement 3 et non `AppDefaults.maxChoicesPerScreen` (4) : la 4e
  /// zone de l'écran de lettres est systématiquement réservée à la
  /// navigation ("page suivante" ou retour à l'étape 1), pour respecter le
  /// bas-droite dédié à la navigation autant que possible (section 4.6) —
  /// voir la doc de `LetterGroup.lettersPaged`, qui anticipe explicitement
  /// ce cas d'usage ("Une UI qui veut réserver un emplacement de page pour
  /// un item de navigation").
  static const int lettersPageSize = 3;

  late final ExpertTextComposer _composer;
  late final WordPredictor _predictor;

  @override
  ExpertModeState build() {
    _composer = ExpertTextComposer();
    _predictor = const WordPredictor();
    return _snapshot(step: ExpertStep.group);
  }

  /// Réinitialise la composition (nouvelle session du mode expert). Appelé
  /// par `ExpertModeScreen` à chaque montage de l'écran — voir la doc de
  /// cette classe.
  void reset() {
    _composer.reset();
    state = _snapshot(step: ExpertStep.group);
  }

  /// Étape 1 → 2 (section 8.3 → 8.4) : mémorise le groupe choisi et affiche
  /// sa première page de lettres.
  void selectGroup(LetterGroup group) {
    state = _snapshot(step: ExpertStep.letters, selectedGroup: group, letterPageIndex: 0);
  }

  /// Avance à la page de lettres suivante du groupe courant ; revient à
  /// l'étape 1 si la page courante est la dernière (section 8.4 : "pages
  /// successives"). Ne fait rien si aucun groupe n'est sélectionné (garde
  /// défensive, ne devrait pas se produire si l'UI n'affiche cette action
  /// que depuis [ExpertStep.letters]).
  void nextLetterPageOrBackToGroups() {
    final group = state.selectedGroup;
    if (group == null) return;
    final pages = group.lettersPaged(pageSize: lettersPageSize);
    final nextIndex = state.letterPageIndex + 1;
    if (nextIndex >= pages.length) {
      state = _snapshot(step: ExpertStep.group);
    } else {
      state = _snapshot(step: ExpertStep.letters, selectedGroup: group, letterPageIndex: nextIndex);
    }
  }

  /// Ajoute [letter] au texte composé (section 8.6 : "ajouter une lettre"),
  /// puis revient à l'étape 1 pour la lettre suivante (section 8.4 :
  /// "répétition pour lettre suivante").
  void addLetter(String letter) {
    _composer.addLetter(letter);
    state = _snapshot(step: ExpertStep.group);
  }

  /// Ouvre l'écran des fonctions minimales (section 8.6, hors "ajouter une
  /// lettre" déjà couverte par [selectGroup]/[addLetter]).
  void openActions() {
    state = _snapshot(
      step: ExpertStep.actions,
      selectedGroup: state.selectedGroup,
      letterPageIndex: state.letterPageIndex,
    );
  }

  /// Efface la dernière lettre ou le dernier espace du texte composé
  /// (section 8.6), puis revient à l'étape 1.
  void deleteLastLetter() {
    _composer.deleteLastLetter();
    state = _snapshot(step: ExpertStep.group);
  }

  /// Insère un espace pour terminer le mot courant (section 8.6), puis
  /// revient à l'étape 1.
  void addSpace() {
    _composer.addSpace();
    state = _snapshot(step: ExpertStep.group);
  }

  /// Complète le mot en cours avec une [suggestion] de [WordPredictor]
  /// (section 8.5), puis revient à l'étape 1.
  ///
  /// Raccourci accessible par appui direct depuis l'en-tête de composition
  /// (`ExpertModeScreen`), sans attendre le balayage temporel — ce n'est
  /// volontairement pas un [ScanChoice] balayé : la spec présente la
  /// prédiction de mots comme une zone de suggestions à part, pas une étape
  /// supplémentaire du balayage (section 8.5).
  void applySuggestion(String suggestion) {
    _composer.applySuggestion(suggestion);
    state = _snapshot(step: ExpertStep.group);
  }

  /// Valide le mot ou la phrase composée (section 8.6 : "valider le mot ou
  /// la phrase") : transmet le texte au vrai [TtsService], sur le même
  /// chemin que `MenuNavigationController._speak` pour un `SpeakAction`
  /// (`ref.read(ttsServiceProvider).speak(...)`), puis réinitialise la
  /// composition pour repartir sur une phrase vierge.
  ///
  /// Ignore silencieusement un texte vide (rien à valider).
  Future<void> validate() async {
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    await ref.read(ttsServiceProvider).speak(text);
    _composer.reset();
    state = _snapshot(step: ExpertStep.group);
  }

  ExpertModeState _snapshot({
    required ExpertStep step,
    LetterGroup? selectedGroup,
    int letterPageIndex = 0,
  }) {
    return ExpertModeState(
      text: _composer.text,
      currentWord: _composer.currentWord,
      suggestions: _predictor.suggest(_composer.currentWord),
      step: step,
      selectedGroup: selectedGroup,
      letterPageIndex: letterPageIndex,
    );
  }
}

final expertModeProvider = NotifierProvider<ExpertModeController, ExpertModeState>(
  ExpertModeController.new,
);
