import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_defaults.dart';
import '../../core/models/screen_zone.dart';
import '../../domain/actions/action_result.dart' show AppMode;
import '../../domain/models/menu_action.dart';
import '../../domain/models/menu_item.dart';
import '../../domain/models/menu_screen.dart';
import '../../domain/models/sample_menu_config.dart';
import '../../eyetracking/models/gaze_state.dart';
import '../screens/grid4_screen.dart';
import '../screens/yes_no_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Vitrine de démonstration de la Phase 1c.
///
/// Câble [Grid4Screen] et [YesNoScreen] sur `sampleMenuConfig` — la fixture
/// de menu-config en mémoire livrée en Phase 1a par domain-logic-engineer
/// (`lib/domain/models/sample_menu_config.dart`) — plutôt que sur des
/// données réinventées ici, et sur un [GazeState] **simulé** localement (un
/// timer qui fait automatiquement défiler la fixation d'une zone à l'autre)
/// afin de visualiser à l'écran l'indicateur de progression de sélection
/// sans dépendre de la couche `eyetracking` réelle (branchée en Phase 2).
///
/// La résolution d'action (navigate/speak/back/home/openMode/settings/
/// cancel) est ici un simple aiguillage local dans l'UI — pas un appel au
/// vrai `ActionResolver` du domaine : le vrai branchement de
/// l'`ActionResolver` sur la navigation effective est explicitement une
/// tâche de Phase 2 (TASKS.md). Ce fichier est un harnais de
/// démonstration/QA manuelle, pas une brique réutilisable par le reste de
/// l'application.
class DemoHomeScreen extends StatefulWidget {
  const DemoHomeScreen({super.key});

  @override
  State<DemoHomeScreen> createState() => _DemoHomeScreenState();
}

/// Mode d'affichage courant du harnais : navigation dans les écrans
/// `grid-4` de `sampleMenuConfig`, ou écran Oui/Non (section 5), qui n'est
/// pas un `MenuScreen` du schéma mais un mode dédié ouvert via `openMode`.
enum _DemoMode { menu, yesNo }

class _DemoHomeScreenState extends State<DemoHomeScreen> {
  final List<String> _stack = [sampleMenuConfig.homeScreenId];
  _DemoMode _mode = _DemoMode.menu;

  GazeState _gazeState = const GazeState.idle();
  Timer? _gazeTicker;

  static const _quadrantZones = [
    ScreenZone.topLeft,
    ScreenZone.topRight,
    ScreenZone.bottomLeft,
    ScreenZone.bottomRight,
  ];

  static const _yesNoZones = [ScreenZone.left, ScreenZone.right];

  @override
  void initState() {
    super.initState();
    _startGazeSimulation();
  }

  @override
  void dispose() {
    _gazeTicker?.cancel();
    super.dispose();
  }

  List<ScreenZone> get _simulatedZones =>
      _mode == _DemoMode.yesNo ? _yesNoZones : _quadrantZones;

  /// Simulation **de démonstration uniquement** : fixe successivement
  /// chaque zone de l'écran affiché pendant `AppDefaults.dwellTime`, avec
  /// une pause dans la zone morte entre deux zones (jamais d'action
  /// déclenchée depuis le centre, section 4.3). S'adapte au nombre de zones
  /// du mode courant (4 quadrants, ou 2 zones en mode Oui/Non) pour que
  /// l'indicateur de progression reste visible quel que soit l'écran.
  /// Aucune de ces valeurs n'a vocation à modéliser un vrai comportement de
  /// regard : c'est uniquement pour rendre l'indicateur de progression
  /// visible sans matériel de eye-tracking.
  void _startGazeSimulation() {
    var zoneIndex = 0;
    var inPause = false;
    final dwellMs = AppDefaults.dwellTime.inMilliseconds;
    var elapsedInStep = 0;
    const tickMs = 40;
    const pauseMs = 500;

    _gazeTicker = Timer.periodic(const Duration(milliseconds: tickMs), (_) {
      if (!mounted) return;
      elapsedInStep += tickMs;
      final zones = _simulatedZones;
      zoneIndex = zoneIndex % zones.length;

      if (inPause) {
        setState(() => _gazeState = const GazeState.idle());
        if (elapsedInStep >= pauseMs) {
          inPause = false;
          elapsedInStep = 0;
          zoneIndex = (zoneIndex + 1) % zones.length;
        }
        return;
      }

      final progress = (elapsedInStep / dwellMs).clamp(0.0, 1.0);
      setState(() {
        _gazeState = GazeState(
          zone: zones[zoneIndex],
          dwellProgress: progress,
          confidence: 1.0,
          signalStatus: GazeSignalStatus.ok,
        );
      });

      if (progress >= 1.0) {
        inPause = true;
        elapsedInStep = 0;
      }
    });
  }

  MenuScreen get _currentScreen => sampleMenuConfig.screenById(_stack.last);

  void _speak(String phrase) {
    if (!mounted) return;
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

  void _showComingSoon(String label) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceHighlight,
        content: Text('$label — bientôt disponible', style: AppTextStyles.caption),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Aiguillage local d'un [MenuItem] activé, équivalent minimal — côté UI
  /// uniquement — de ce que fera le vrai `ActionResolver` en Phase 2.
  void _handle(MenuItem item) {
    switch (item.action) {
      case MenuAction.navigate:
        setState(() => _stack.add(item.target!));
      case MenuAction.speak:
        _speak(item.text!);
      case MenuAction.back:
        setState(() {
          if (_stack.length > 1) _stack.removeLast();
        });
      case MenuAction.home:
        setState(() {
          _stack
            ..clear()
            ..add(sampleMenuConfig.homeScreenId);
        });
      case MenuAction.openMode:
        switch (item.mode!) {
          case AppMode.yesNo:
            setState(() => _mode = _DemoMode.yesNo);
          case AppMode.expert:
          case AppMode.settings:
            _showComingSoon(item.label);
        }
      case MenuAction.settings:
        _showComingSoon(item.label);
      case MenuAction.cancel:
        break;
    }
  }

  List<Grid4Item> _itemsFor(MenuScreen screen) => [
        for (final item in screen.items)
          Grid4Item(
            zone: item.zone,
            label: item.label,
            backgroundColor:
                item.action == MenuAction.back || item.action == MenuAction.home
                    ? AppColors.navigation
                    : AppColors.surface,
            onActivated: () => _handle(item),
          ),
      ];

  @override
  Widget build(BuildContext context) {
    if (_mode == _DemoMode.yesNo) {
      return YesNoScreen(
        question: 'Tu as mal ?',
        gazeState: _gazeState,
        onYes: () => _speak('Oui.'),
        onNo: () => _speak('Non.'),
        onExit: () => setState(() => _mode = _DemoMode.menu),
      );
    }

    final screen = _currentScreen;
    final isHome = screen.id == sampleMenuConfig.homeScreenId;
    return Grid4Screen(
      title: isHome ? null : screen.title,
      gazeState: _gazeState,
      items: _itemsFor(screen),
    );
  }
}
