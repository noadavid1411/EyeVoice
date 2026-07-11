import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/screen_zone.dart';
import '../../eyetracking/models/gaze_state.dart';
import '../theme/app_colors.dart';
import 'dead_zone_marker.dart';
import 'zone_button.dart';

/// Durée par défaut de la fenêtre de surbrillance d'une zone lors d'un
/// balayage temporel (SPECIFICATIONS_FONCTIONNELLES.md section 8.2 : "Le
/// système met successivement chaque groupe en surbrillance. Le patient
/// valide le groupe souhaité en fixant la zone correspondante pendant la
/// période de surbrillance").
///
/// Constante locale à ce spike (mode expert, section 8) plutôt qu'ajoutée à
/// `AppDefaults` (`lib/core/constants/app_defaults.dart`, hors du périmètre
/// `lib/ui` de cette tâche) : contrairement au dwell time (section 4.4, une
/// durée de *fixation continue* mesurée par la couche `eyetracking`),
/// l'intervalle de balayage est une temporisation *automatique du système*,
/// conceptuellement distincte — c'est [ScanningGrid] qui la pilote, pas
/// `GazeState`. À faire remonter vers un réglage partagé si un second usage
/// (hors mode expert) apparaît.
const Duration kScanHighlightInterval = Duration(milliseconds: 1400);

/// Une cible additionnelle, **non spatiale**, balayée par [ScanningGrid]
/// comme une 5e étape temporelle, en plus des (au plus 4) zones de
/// [ScanningGrid.items].
///
/// Pensée pour l'accès aux fonctions du mode expert (section 8.6 :
/// effacer/espace/valider/menu principal) depuis les écrans "groupe" et
/// "lettres" (section 8.3/8.4, `ExpertModeScreen`) : ces écrans occupent
/// déjà leurs 4 zones avec des choix obligatoires (les 4 groupes de la
/// table 8.3, ou 3 lettres + navigation de page), donc aucune 5e
/// [ScanChoice] spatiale n'est possible sans en sacrifier une — voir la doc
/// de [ScanningGrid.extraScanTarget] pour où et comment cette cible est
/// rendue pendant sa fenêtre.
@immutable
class ExtraScanTarget {
  /// Libellé court affiché pendant la fenêtre de surbrillance de cette
  /// étape.
  final String label;

  final IconData? icon;

  /// Appelée lorsque cette étape est validée pendant sa fenêtre de
  /// surbrillance — par appui tactile ou par fixation du regard, exactement
  /// comme un [ScanChoice] (voir [ScanningGrid.extraScanTarget]).
  final VoidCallback? onActivated;

  const ExtraScanTarget({required this.label, this.icon, this.onActivated});
}

/// Un choix balayé automatiquement par [ScanningGrid].
///
/// Même forme qu'un `Grid4Item` (`lib/ui/screens/grid4_screen.dart`) :
/// [onActivated] joue le rôle d'action déjà résolue, indépendamment de la
/// façon dont elle a été validée (appui tactile ou fixation pendant la
/// fenêtre de surbrillance).
@immutable
class ScanChoice {
  /// Quadrant occupé. Doit être l'une des 4 zones de la grille — jamais
  /// [ScreenZone.left]/[ScreenZone.right] (réservées au mode Oui/Non) ni
  /// [ScreenZone.centerDeadZone] (section 4.3).
  final ScreenZone zone;

  /// Libellé court affiché dans le bouton (section 10.2).
  final String label;

  final IconData? icon;

  /// Couleur de fond du bouton au repos.
  final Color backgroundColor;

  /// Appelée lorsque ce choix est validé pendant sa fenêtre de
  /// surbrillance — par appui tactile ou par fixation du regard (voir la
  /// doc de [ScanningGrid]).
  final VoidCallback? onActivated;

  const ScanChoice({
    required this.zone,
    required this.label,
    this.icon,
    this.backgroundColor = AppColors.surface,
    this.onActivated,
  }) : assert(
          zone == ScreenZone.topLeft ||
              zone == ScreenZone.topRight ||
              zone == ScreenZone.bottomLeft ||
              zone == ScreenZone.bottomRight,
          'ScanChoice.zone doit être un quadrant de la grille 4 zones.',
        );
}

/// Écran (ou portion d'écran) en grille de 4 zones balayée automatiquement
/// dans le temps — saisie par balayage temporel du mode expert
/// (SPECIFICATIONS_FONCTIONNELLES.md section 8.2, Niveau 4 — Mode Expert).
///
/// Contrairement à `Grid4Screen` (sélection par dwell time : c'est le
/// patient qui prend l'initiative en fixant une zone, la validation dépend
/// de la durée de sa fixation continue), ici c'est **le système** qui prend
/// l'initiative : chaque zone occupée par un [ScanChoice] est mise en
/// surbrillance à tour de rôle, pendant [interval]. Le patient valide en
/// agissant *pendant* cette fenêtre :
/// - par un appui tactile (mode dégradé, section 17.3 — chemin principal de
///   ce spike, l'eye-tracking réel n'étant pas encore validé sur matériel,
///   voir `docs/validation-materielle.md`) ;
/// - en bonus, par simple présence du regard sur la zone en surbrillance au
///   moment voulu ([gazeState]) — pas besoin d'un dwell time additionnel
///   puisque c'est déjà la fenêtre de surbrillance qui joue ce rôle de
///   temporisation (section 8.2 : "valide [...] en fixant la zone [...]
///   pendant la période de surbrillance").
///
/// Un appui hors de la zone actuellement en surbrillance, ou une fixation
/// d'une autre zone, n'a strictement aucun effet. [ScanningGrid] ne fait
/// qu'illustrer et déclencher une action déjà prête
/// ([ScanChoice.onActivated]) : il ne connaît ni le contenu réel du mode
/// expert (lettres, groupes, prédiction), ni le calcul du regard lui-même.
///
/// Contrairement à `Grid4Screen`/`YesNoScreen` (écrans autonomes complets),
/// [ScanningGrid] n'affiche **pas** sa propre `DegradedSignalBanner`
/// (section 17.3) : il est pensé comme une portion d'écran, imbriquée dans
/// un écran appelant qui affiche déjà cette bannière une seule fois pour
/// l'ensemble de la page (voir `ExpertModeScreen`, qui alterne plusieurs
/// [ScanningGrid] au fil de la session sous une bannière commune).
///
/// ### Étape additionnelle non-spatiale ([extraScanTarget])
///
/// Quand [extraScanTarget] est fourni, le cycle de balayage comporte une 5e
/// étape temporelle, insérée après les zones occupées de [items]. Pendant
/// sa fenêtre, cette étape est rendue **dans le quadrant bas-droite**
/// (celui-ci redevient disponible pour son occupant habituel de [items],
/// s'il y en a un, dès l'étape suivante) : le bas-droite est par
/// construction "réservé à la navigation/options" (section 4.6), ce dont
/// relève l'accès aux fonctions du mode expert.
///
/// Ce choix — rendre la cible additionnelle *dans la grille* plutôt que de
/// se contenter d'exposer un simple booléen "en surbrillance" à un widget
/// externe (ex. l'icône d'en-tête `ExpertModeScreen._CompositionHeader`) —
/// est délibéré : [GazeState.zone] ne connaît que les quadrants de
/// [ScreenZone], pas la position d'une icône d'en-tête. Un widget hors
/// grille pourrait bien afficher une bordure lumineuse en synchronisation
/// avec cette étape, mais ne pourrait jamais être validé par fixation du
/// regard sans faire évoluer la couche `eyetracking` (mapping
/// coordonnées→zone), hors périmètre de ce widget. En réutilisant une zone
/// de la grille, la validation par regard fonctionne immédiatement avec
/// l'infrastructure [GazeState]/[ScreenZone] existante — c'est ce qui rend
/// cette étape réellement atteignable par un patient qui ne peut interagir
/// que par le regard, pas seulement par un appui tactile sur une icône.
class ScanningGrid extends StatefulWidget {
  /// Choix affichés, un par quadrant occupé. Ne doit jamais dépasser 4
  /// (section 4.1/10.1).
  final List<ScanChoice> items;

  /// Cible additionnelle balayée comme 5e étape temporelle, non liée à un
  /// quadrant de [items] — voir la doc de classe, section "Étape
  /// additionnelle non-spatiale". `null` (par défaut) : le cycle ne
  /// comporte que les zones occupées de [items].
  final ExtraScanTarget? extraScanTarget;

  /// Durée de la fenêtre de surbrillance de chaque zone.
  final Duration interval;

  /// État de regard courant, déjà résolu par la couche `eyetracking`.
  final GazeState gazeState;

  /// Affiche ou non le repère visuel de la zone morte centrale (section
  /// 4.3). Activé par défaut, comme `Grid4Screen`.
  final bool showDeadZoneMarker;

  const ScanningGrid({
    super.key,
    required this.items,
    this.extraScanTarget,
    this.interval = kScanHighlightInterval,
    this.gazeState = const GazeState.idle(),
    this.showDeadZoneMarker = true,
  }) : assert(
          items.length <= 4,
          'Un écran standard ne doit jamais dépasser 4 choix (section 4.1).',
        );

  @override
  State<ScanningGrid> createState() => _ScanningGridState();
}

class _ScanningGridState extends State<ScanningGrid> {
  /// Granularité de mise à jour du retour visuel de progression au sein de
  /// la fenêtre de surbrillance courante. Volontairement plus fin que
  /// [ScanningGrid.interval] pour un remplissage visuel fluide (section 4.5).
  static const Duration _tick = Duration(milliseconds: 50);

  /// Quadrant de la grille dans lequel [ScanningGrid.extraScanTarget] est
  /// rendu pendant sa fenêtre de surbrillance — voir la doc de classe de
  /// [ScanningGrid], section "Étape additionnelle non-spatiale".
  static const ScreenZone _extraStepZone = ScreenZone.bottomRight;

  /// Ordre de balayage : les zones occupées de [ScanningGrid.items], puis
  /// `null` en dernière position si [ScanningGrid.extraScanTarget] est
  /// fourni (`null` représente cette étape non-spatiale, par opposition à
  /// une vraie [ScreenZone]).
  late List<ScreenZone?> _order;
  int _activeIndex = 0;
  Duration _elapsed = Duration.zero;
  Timer? _timer;
  bool _firedThisWindow = false;

  @override
  void initState() {
    super.initState();
    _order = _computeOrder();
    // Cycle de balayage *intentionnel* du mode expert (section 8.2) : ce
    // `Timer.periodic` est piloté uniquement par [ScanningGrid] lui-même,
    // indépendamment de `GazeState`/de la couche `eyetracking` (réelle ou
    // factice — voir `lib/eyetracking`). Il avance tout seul même si aucun
    // visage n'est détecté et même sans aucun signal de regard : ce n'est
    // PAS un comportement résiduel d'un détecteur de dwell factice, c'est
    // la temporisation du balayage lui-même, qui existerait à l'identique
    // avec un eye-tracking réel pleinement opérationnel (voir aussi la doc
    // de [kScanHighlightInterval]).
    _timer = Timer.periodic(_tick, (_) => _onTick());
  }

  @override
  void didUpdateWidget(covariant ScanningGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeFireFromGaze();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Ordre de balayage fixe (haut-gauche, haut-droite, bas-gauche,
  /// bas-droite), restreint aux zones effectivement occupées par un
  /// [ScanChoice] — une zone vide n'est jamais mise en surbrillance — puis
  /// une dernière étape `null` (l'étape non-spatiale de
  /// [ScanningGrid.extraScanTarget]) si celle-ci est fournie.
  List<ScreenZone?> _computeOrder() {
    const fixedOrder = [
      ScreenZone.topLeft,
      ScreenZone.topRight,
      ScreenZone.bottomLeft,
      ScreenZone.bottomRight,
    ];
    final present = widget.items.map((i) => i.zone).toSet();
    final zones = fixedOrder.where(present.contains).toList();
    return [
      ...zones,
      if (widget.extraScanTarget != null) null,
    ];
  }

  /// `true` si l'étape actuellement en surbrillance est
  /// [ScanningGrid.extraScanTarget] (représentée par `null` dans [_order]),
  /// plutôt qu'une zone de [ScanningGrid.items].
  bool get _isExtraStepActive => _order.isNotEmpty && _order[_activeIndex] == null;

  /// Zone de grille actuellement en surbrillance pour un [ScanChoice], ou
  /// `null` si aucune zone n'est occupée ou si c'est l'étape
  /// [ScanningGrid.extraScanTarget] qui est active (voir
  /// [_isExtraStepActive] — dans ce cas c'est [_extraStepZone] qui porte la
  /// surbrillance visuelle, pas une zone de [ScanningGrid.items]).
  ScreenZone? get _activeZone {
    if (_order.isEmpty || _isExtraStepActive) return null;
    return _order[_activeIndex];
  }

  void _onTick() {
    if (!mounted || _order.isEmpty) return;
    setState(() {
      _elapsed += _tick;
      if (_elapsed >= widget.interval) {
        _elapsed = Duration.zero;
        _activeIndex = (_activeIndex + 1) % _order.length;
        _firedThisWindow = false;
      }
    });
  }

  /// Résout le callback à déclencher pour un appui/une fixation sur [zone],
  /// selon l'étape courante :
  /// - pendant la fenêtre de [ScanningGrid.extraScanTarget] (rendue dans
  ///   [_extraStepZone]), seule cette zone déclenche
  ///   [ExtraScanTarget.onActivated] ;
  /// - sinon, seule la zone en surbrillance ([_activeZone]) déclenche le
  ///   [ScanChoice] correspondant.
  ///
  /// Toute autre zone ne renvoie aucun callback (contrat du balayage
  /// temporel, section 8.2 : hors fenêtre active, aucun effet).
  VoidCallback? _activatedCallbackFor(ScreenZone zone) {
    if (_isExtraStepActive) {
      if (zone != _extraStepZone) return null;
      return widget.extraScanTarget?.onActivated;
    }
    if (zone != _activeZone) return null;
    return _itemFor(zone)?.onActivated;
  }

  /// Bonus (section 8.2) : valide la zone en surbrillance si le regard s'y
  /// trouve, sans exiger de dwell time supplémentaire — voir la doc de la
  /// classe. Ignore explicitement la zone morte centrale (section 4.3).
  ///
  /// Différé après la frame en cours (`addPostFrameCallback`) : appelée
  /// depuis [didUpdateWidget], donc en plein milieu de la construction du
  /// widget tree — `onActivated` écrit typiquement dans un provider
  /// Riverpod (`ExpertModeController`), ce que Riverpod interdit tant qu'un
  /// build est en cours (même contrainte que
  /// `Grid4Screen._maybeFireActivation`).
  void _maybeFireFromGaze() {
    final zone = widget.gazeState.zone;
    if (zone == null || zone == ScreenZone.centerDeadZone || _firedThisWindow) return;
    final callback = _activatedCallbackFor(zone);
    if (callback == null) return;
    _firedThisWindow = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => callback());
  }

  /// Appelée depuis le callback `onTap` d'un [ZoneButton] : un gestionnaire
  /// d'événement, jamais en plein build, donc `onActivated` peut être
  /// invoqué de façon synchrone — même principe que
  /// `Grid4Item.onActivated`/`ZoneButton.onTap` (pas de report nécessaire).
  void _handleTap(ScreenZone zone) {
    // Hors fenêtre de surbrillance active : aucun effet (contrat explicite
    // de la tâche, cohérent avec le principe du balayage temporel).
    if (_firedThisWindow) return;
    final callback = _activatedCallbackFor(zone);
    if (callback == null) return;
    _firedThisWindow = true;
    callback();
  }

  double _progressFor(ScreenZone zone) {
    if (widget.interval.inMilliseconds == 0) return 0.0;
    final isActiveHere = _isExtraStepActive ? zone == _extraStepZone : zone == _activeZone;
    if (!isActiveHere) return 0.0;
    return (_elapsed.inMilliseconds / widget.interval.inMilliseconds).clamp(0.0, 1.0);
  }

  ScanChoice? _itemFor(ScreenZone zone) => widget.items.where((i) => i.zone == zone).firstOrNull;

  Widget _buildCell(ScreenZone zone) {
    // Étape [ScanningGrid.extraScanTarget] active : ce quadrant (toujours
    // bas-droite, voir [_extraStepZone]) affiche temporairement cette cible
    // à la place de son occupant habituel de [ScanningGrid.items] — voir la
    // doc de classe, section "Étape additionnelle non-spatiale". Celui-ci
    // réapparaîtra dès l'étape suivante du cycle.
    if (_isExtraStepActive && zone == _extraStepZone && widget.extraScanTarget != null) {
      final extra = widget.extraScanTarget!;
      return ZoneButton(
        label: extra.label,
        icon: extra.icon,
        backgroundColor: AppColors.navigation,
        dwellProgress: _progressFor(zone),
        isFixated: true,
        onTap: () => _handleTap(zone),
      );
    }
    final item = _itemFor(zone);
    if (item == null) {
      // Quadrant volontairement vide : espace neutre, jamais interactif.
      return const SizedBox.expand();
    }
    final highlighted = !_isExtraStepActive && zone == _activeZone;
    return ZoneButton(
      label: item.label,
      icon: item.icon,
      backgroundColor: item.backgroundColor,
      dwellProgress: _progressFor(zone),
      isFixated: highlighted,
      onTap: () => _handleTap(zone),
    );
  }

  @override
  Widget build(BuildContext context) {
    assert(
      widget.items.length <= 4,
      'Un écran standard ne doit jamais dépasser 4 choix (section 4.1).',
    );
    assert(
      widget.items.map((i) => i.zone).toSet().length == widget.items.length,
      'Deux choix ne peuvent pas partager le même quadrant.',
    );

    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildCell(ScreenZone.topLeft)),
                  Expanded(child: _buildCell(ScreenZone.topRight)),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildCell(ScreenZone.bottomLeft)),
                  Expanded(child: _buildCell(ScreenZone.bottomRight)),
                ],
              ),
            ),
          ],
        ),
        if (widget.showDeadZoneMarker) const DeadZoneMarker(),
      ],
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
