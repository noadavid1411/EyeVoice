import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/screen_zone.dart';
import '../../domain/expert/letter_group.dart';
import '../../eyetracking/models/gaze_state.dart';
import '../providers/expert_mode_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/degraded_signal_banner.dart';
import '../widgets/scanning_grid.dart';

/// Écran du Niveau 4 — Mode Expert (SPECIFICATIONS_FONCTIONNELLES.md
/// section 8) : saisie libre par balayage temporel, avec prédiction de
/// mots.
///
/// **Architecture d'écran retenue** (documentée ici car la section 8.6 liste
/// 5 fonctions minimales — ajouter une lettre, effacer, espace, valider,
/// retour menu — alors qu'un écran standard ne peut afficher que 4 choix,
/// section 4.1) : trois sous-écrans balayés en alternance
/// ([ExpertStep]), plus un en-tête de composition **toujours visible** au
/// dessus, quel que soit le sous-écran :
/// - [ExpertStep.group] : étape 1 (section 8.3), choix d'un [LetterGroup]
///   parmi les 4 zones — c'est l'écran "par défaut", celui sur lequel on
///   revient après n'importe quelle action (lettre ajoutée, espace,
///   effacement, suggestion appliquée, phrase validée) ;
/// - [ExpertStep.letters] : étape 2 (section 8.4), choix d'une lettre dans
///   le groupe choisi, présentée par pages de 3 lettres + 1 zone de
///   navigation (page suivante / retour aux groupes) ;
/// - [ExpertStep.actions] : les fonctions de la section 8.6 autres que
///   "ajouter une lettre" (déjà couverte par group→letters) : effacer,
///   espace, valider, retour au menu principal. Accessible de **deux**
///   façons complémentaires, jamais l'une au détriment de l'autre (mode
///   dégradé tactile toujours actif, section 17.3) :
///   - par appui tactile à tout moment sur le petit bouton "Fonctions" de
///     l'en-tête, à la manière du bouton retour discret de
///     `YesNoScreen`/`SettingsScreen` — raccourci direct, indépendant du
///     balayage ;
///   - par balayage temporel pur (regard ou tap), depuis [ExpertStep.group]
///     et [ExpertStep.letters] : ces deux écrans passent un
///     `ExtraScanTarget` "Fonctions" à leur `ScanningGrid`
///     (`lib/ui/widgets/scanning_grid.dart`), qui l'intègre comme 5e étape
///     temporelle rendue dans le quadrant bas-droite pendant sa fenêtre.
///     Indispensable pour un patient qui ne peut interagir que par le
///     regard (pas de tap manuel possible) : sans ce second chemin, ces 4
///     fonctions — y compris "Menu principal", seule sortie du mode expert
///     — lui seraient totalement inaccessibles.
///
/// L'en-tête de composition (texte + suggestions, section 8.5) affiche le
/// texte composé et jusqu'à 3 suggestions de `WordPredictor` ; taper une
/// suggestion l'applique immédiatement (raccourci, sans attendre le
/// balayage — voir `ExpertModeController.applySuggestion`).
class ExpertModeScreen extends ConsumerStatefulWidget {
  /// État de regard courant, déjà résolu par la couche `eyetracking`.
  final GazeState gazeState;

  /// Appelé lorsque le patient valide "Menu principal" à l'étape
  /// [ExpertStep.actions] (section 8.6 : "revenir au menu principal").
  ///
  /// Fourni par l'appelant (`DemoHomeScreen`) plutôt qu'implémenté ici :
  /// cet écran ne doit connaître ni `MenuNavigationController` ni la
  /// résolution `back`/`home` de l'`ActionResolver`, déjà gérée ailleurs
  /// (voir la doc de la tâche : "réutilise l'existant, ne réimplémente
  /// rien").
  final VoidCallback onExitToHome;

  const ExpertModeScreen({
    super.key,
    required this.onExitToHome,
    this.gazeState = const GazeState.idle(),
  });

  @override
  ConsumerState<ExpertModeScreen> createState() => _ExpertModeScreenState();
}

class _ExpertModeScreenState extends ConsumerState<ExpertModeScreen> {
  @override
  void initState() {
    super.initState();
    // Nouvelle session du mode expert à chaque montage de cet écran (voir
    // la doc de `ExpertModeController` : le texte composé n'est pas
    // conservé d'une ouverture du mode expert à l'autre). Différé après la
    // frame en cours : on ne peut pas écrire dans un provider Riverpod
    // pendant `initState`/le tout premier build (même contrainte que
    // `Grid4Screen._maybeFireActivation`).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(expertModeProvider.notifier).reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(expertModeProvider);
    final controller = ref.read(expertModeProvider.notifier);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            DegradedSignalBanner(status: widget.gazeState.signalStatus),
            _CompositionHeader(
              text: state.text,
              suggestions: state.suggestions,
              onSuggestionTap: controller.applySuggestion,
              onOpenActions: controller.openActions,
            ),
            Expanded(child: _buildStep(state, controller)),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(ExpertModeState state, ExpertModeController controller) {
    switch (state.step) {
      case ExpertStep.group:
        return ScanningGrid(
          key: const ValueKey('expert-groups'),
          gazeState: widget.gazeState,
          items: [
            for (final group in LetterGroup.values)
              ScanChoice(
                zone: group.zone,
                label: '${group.letters.first}-${group.letters.last}',
                onActivated: () => controller.selectGroup(group),
              ),
          ],
          extraScanTarget: _functionsScanTarget(controller),
        );

      case ExpertStep.letters:
        final group = state.selectedGroup;
        // Garde défensive : ne devrait pas se produire (on n'entre dans cette
        // étape que via `selectGroup`, qui renseigne toujours le groupe),
        // mais un patient fatigué ne doit jamais se retrouver face à un
        // écran cassé — on retombe simplement sur l'étape 1.
        if (group == null) {
          return ScanningGrid(
            key: const ValueKey('expert-groups-fallback'),
            gazeState: widget.gazeState,
            items: [
              for (final g in LetterGroup.values)
                ScanChoice(
                  zone: g.zone,
                  label: '${g.letters.first}-${g.letters.last}',
                  onActivated: () => controller.selectGroup(g),
                ),
            ],
            extraScanTarget: _functionsScanTarget(controller),
          );
        }
        final pages = group.lettersPaged(pageSize: ExpertModeController.lettersPageSize);
        final pageIndex = state.letterPageIndex.clamp(0, pages.length - 1);
        final page = pages[pageIndex];
        final hasNextPage = pageIndex + 1 < pages.length;
        const letterZones = [ScreenZone.topLeft, ScreenZone.topRight, ScreenZone.bottomLeft];
        return ScanningGrid(
          key: ValueKey('expert-letters-${group.name}-$pageIndex'),
          gazeState: widget.gazeState,
          items: [
            for (var i = 0; i < page.length; i++)
              ScanChoice(
                zone: letterZones[i],
                label: page[i],
                onActivated: () => controller.addLetter(page[i]),
              ),
            ScanChoice(
              zone: ScreenZone.bottomRight,
              label: hasNextPage ? 'Suite ▸' : '◂ Groupes',
              backgroundColor: AppColors.navigation,
              onActivated: controller.nextLetterPageOrBackToGroups,
            ),
          ],
          extraScanTarget: _functionsScanTarget(controller),
        );

      case ExpertStep.actions:
        return ScanningGrid(
          key: const ValueKey('expert-actions'),
          gazeState: widget.gazeState,
          items: [
            ScanChoice(
              zone: ScreenZone.topLeft,
              label: 'Effacer',
              icon: Icons.backspace_outlined,
              onActivated: controller.deleteLastLetter,
            ),
            ScanChoice(
              zone: ScreenZone.topRight,
              label: 'Espace',
              icon: Icons.space_bar,
              onActivated: controller.addSpace,
            ),
            ScanChoice(
              zone: ScreenZone.bottomLeft,
              label: 'Valider',
              icon: Icons.volume_up,
              backgroundColor: AppColors.surfaceHighlight,
              onActivated: controller.validate,
            ),
            ScanChoice(
              zone: ScreenZone.bottomRight,
              label: 'Menu principal',
              icon: Icons.home_outlined,
              backgroundColor: AppColors.navigation,
              onActivated: widget.onExitToHome,
            ),
          ],
        );
    }
  }

  /// Cible additionnelle "Fonctions" (section 8.6), balayée comme 5e étape
  /// temporelle par les grilles de [ExpertStep.group] et
  /// [ExpertStep.letters] — voir la doc de classe. Non utilisée pour
  /// [ExpertStep.actions] lui-même : une fois cet écran atteint, y
  /// re-proposer "Fonctions" n'aurait aucun intérêt (`openActions` y est
  /// déjà un no-op visuel).
  ExtraScanTarget _functionsScanTarget(ExpertModeController controller) {
    return ExtraScanTarget(
      label: 'Fonctions',
      icon: Icons.build_outlined,
      onActivated: controller.openActions,
    );
  }
}

/// Zone de composition toujours visible (section 8.5) : texte composé +
/// suggestions de `WordPredictor`, plus l'accès tactile discret aux
/// fonctions de la section 8.6 (voir la doc d'[ExpertModeScreen]).
class _CompositionHeader extends StatelessWidget {
  final String text;
  final List<String> suggestions;
  final ValueChanged<String> onSuggestionTap;
  final VoidCallback onOpenActions;

  const _CompositionHeader({
    required this.text,
    required this.suggestions,
    required this.onSuggestionTap,
    required this.onOpenActions,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  text.isEmpty ? '…' : text,
                  style: AppTextStyles.spokenPhrase,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.build_outlined, color: AppColors.textMuted),
                tooltip: 'Fonctions : effacer, espace, valider, menu principal',
                onPressed: onOpenActions,
              ),
            ],
          ),
          if (suggestions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final suggestion in suggestions)
                    ActionChip(
                      label: Text(
                        suggestion,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                        ),
                      ),
                      backgroundColor: AppColors.surfaceHighlight,
                      side: const BorderSide(color: AppColors.border),
                      onPressed: () => onSuggestionTap(suggestion),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
