import 'package:flutter/material.dart';

import '../../core/constants/app_defaults.dart';
import '../../core/models/screen_zone.dart';
import '../../eyetracking/models/gaze_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/dead_zone_marker.dart';
import '../widgets/degraded_signal_banner.dart';
import '../widgets/zone_button.dart';

/// Un choix affiché dans un quadrant de [Grid4Screen].
///
/// Réplique volontairement, en mémoire, la forme d'un item de
/// `menu-config.json` (section 11.2 : `zone`, `label`, `action`/`target`)
/// sans dépendre du futur modèle Dart de `domain` (Phase 1a, en cours en
/// parallèle) : [onActivated] joue ici le rôle générique de "l'action déjà
/// résolue", quelle que soit sa nature réelle une fois l'`ActionResolver`
/// branché en Phase 2.
@immutable
class Grid4Item {
  /// Quadrant occupé. Doit être l'une des 4 zones de la grille — jamais
  /// [ScreenZone.left], [ScreenZone.right] ni [ScreenZone.centerDeadZone].
  final ScreenZone zone;

  /// Libellé court affiché dans le bouton (section 10.2).
  final String label;

  /// Icône optionnelle (section 15.1 : "icônes simples").
  final IconData? icon;

  /// Couleur de fond du bouton. Par défaut une surface neutre ; à
  /// surcharger pour les cas prévus par les spécifications (ex. quadrant
  /// bas-droite = navigation, section 4.6).
  final Color backgroundColor;

  /// Appelée lorsque le choix est activé, que ce soit par validation du
  /// dwell time (progression de [GazeState] atteignant 1.0 sur [zone]) ou
  /// par un appui tactile direct (mode dégradé, section 17.3).
  final VoidCallback? onActivated;

  const Grid4Item({
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
          'Grid4Item.zone doit être un quadrant de la grille 4 zones '
          '(topLeft/topRight/bottomLeft/bottomRight) — left/right sont '
          'réservées au mode Oui/Non et centerDeadZone ne peut jamais '
          'porter de choix (section 4.3).',
        );
}

/// Écran générique en grille de 4 zones (SPECIFICATIONS_FONCTIONNELLES.md
/// section 4.1 — "règle du carré magique").
///
/// Consomme des [items] déjà résolus (mockés en Phase 1c, alimentés depuis
/// `menu-config.json` + `ActionResolver` en Phase 2) et un [gazeState] déjà
/// calculé par la couche `eyetracking` : ce widget ne fait qu'afficher
/// l'état qu'on lui donne, il ne détecte rien et ne calcule aucune
/// temporisation lui-même.
///
/// Si la zone fixée dans [gazeState] correspond à un item et que
/// `dwellProgress` atteint 1.0, [Grid4Item.onActivated] est déclenché une
/// seule fois (déclenchement sur front montant, pas à chaque frame).
class Grid4Screen extends StatefulWidget {
  /// Titre affiché en haut de l'écran (ex. "Physique"). `null` = pas de
  /// titre (écran d'accueil, section 6.2, qui n'a pas besoin d'en-tête).
  final String? title;

  /// Choix affichés, un par quadrant. Ne doit jamais dépasser
  /// `AppDefaults.maxChoicesPerScreen` (section 4.1 / 10.1).
  final List<Grid4Item> items;

  /// État de regard courant, déjà résolu par la couche `eyetracking`.
  /// Valeur par défaut [GazeState.idle] : aucune zone fixée.
  final GazeState gazeState;

  /// Affiche ou non le repère visuel de la zone morte centrale (section
  /// 4.3). Activé par défaut.
  final bool showDeadZoneMarker;

  const Grid4Screen({
    super.key,
    required this.items,
    this.title,
    this.gazeState = const GazeState.idle(),
    this.showDeadZoneMarker = true,
  }) : assert(
          items.length <= AppDefaults.maxChoicesPerScreen,
          'Un écran standard ne doit jamais dépasser '
          '${AppDefaults.maxChoicesPerScreen} choix (section 4.1).',
        );

  @override
  State<Grid4Screen> createState() => _Grid4ScreenState();
}

class _Grid4ScreenState extends State<Grid4Screen> {
  @override
  void didUpdateWidget(covariant Grid4Screen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeFireActivation(oldWidget.gazeState, widget.gazeState);
  }

  /// Déclenche `onActivated` sur front montant uniquement : on ne réagit
  /// que si la progression *vient d'atteindre* 1.0 sur une zone donnée,
  /// pour ne jamais déclencher deux fois la même sélection tant que le
  /// regard reste dessus.
  void _maybeFireActivation(GazeState previous, GazeState current) {
    final zone = current.zone;
    if (zone == null || zone == ScreenZone.centerDeadZone) return;
    if (current.dwellProgress < 1.0) return;

    final alreadyFired = previous.zone == zone && previous.dwellProgress >= 1.0;
    if (alreadyFired) return;

    final item = widget.items.where((i) => i.zone == zone).firstOrNull;
    item?.onActivated?.call();
  }

  Grid4Item? _itemFor(ScreenZone zone) =>
      widget.items.where((item) => item.zone == zone).firstOrNull;

  double _progressFor(ScreenZone zone) =>
      widget.gazeState.zone == zone ? widget.gazeState.dwellProgress : 0.0;

  bool _isFixated(ScreenZone zone) => widget.gazeState.zone == zone;

  Widget _buildCell(ScreenZone zone) {
    final item = _itemFor(zone);
    if (item == null) {
      // Quadrant volontairement vide : espace neutre, jamais interactif.
      return const SizedBox.expand();
    }
    return ZoneButton(
      label: item.label,
      icon: item.icon,
      backgroundColor: item.backgroundColor,
      dwellProgress: _progressFor(zone),
      isFixated: _isFixated(zone),
      onTap: item.onActivated,
    );
  }

  @override
  Widget build(BuildContext context) {
    assert(
      widget.items.length <= AppDefaults.maxChoicesPerScreen,
      'Un écran standard ne doit jamais dépasser '
      '${AppDefaults.maxChoicesPerScreen} choix (section 4.1).',
    );
    assert(
      widget.items.map((i) => i.zone).toSet().length == widget.items.length,
      'Deux items ne peuvent pas partager le même quadrant.',
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                DegradedSignalBanner(status: widget.gazeState.signalStatus),
                if (widget.title != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      widget.title!,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.screenTitle,
                    ),
                  ),
                Expanded(
                  child: Column(
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
                ),
              ],
            ),
            if (widget.showDeadZoneMarker) const DeadZoneMarker(),
          ],
        ),
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
