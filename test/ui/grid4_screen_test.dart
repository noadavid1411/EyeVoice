import 'package:eyevoice/core/models/screen_zone.dart';
import 'package:eyevoice/eyetracking/models/gaze_state.dart';
import 'package:eyevoice/ui/screens/grid4_screen.dart';
import 'package:eyevoice/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests widget basiques pour [Grid4Screen] (Phase 1c). Vérifie les
/// critères d'acceptation directement liés à ce widget (section 19) :
/// jamais plus de 4 choix, retour visuel de sélection, zone morte non
/// interactive.
void main() {
  Widget wrap(Widget child) => MaterialApp(theme: AppTheme.dark, home: child);

  List<Grid4Item> fourItems({
    VoidCallback? onTopLeft,
    VoidCallback? onBottomRight,
  }) => [
        Grid4Item(zone: ScreenZone.topLeft, label: 'Physique', onActivated: onTopLeft),
        const Grid4Item(zone: ScreenZone.topRight, label: 'Conversation'),
        const Grid4Item(zone: ScreenZone.bottomLeft, label: 'Émotions'),
        Grid4Item(zone: ScreenZone.bottomRight, label: 'Retour', onActivated: onBottomRight),
      ];

  testWidgets('affiche les 4 libellés de la grille', (tester) async {
    await tester.pumpWidget(wrap(Grid4Screen(items: fourItems())));

    expect(find.text('Physique'), findsOneWidget);
    expect(find.text('Conversation'), findsOneWidget);
    expect(find.text('Émotions'), findsOneWidget);
    expect(find.text('Retour'), findsOneWidget);
  });

  testWidgets('un appui tactile sur une zone déclenche onActivated (mode dégradé)', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      wrap(Grid4Screen(items: fourItems(onTopLeft: () => tapped = true))),
    );

    await tester.tap(find.text('Physique'));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('un dwellProgress de 1.0 sur une zone déclenche onActivated une seule fois', (
    tester,
  ) async {
    var activationCount = 0;

    Widget build(GazeState gazeState) => wrap(
          Grid4Screen(
            items: fourItems(onBottomRight: () => activationCount++),
            gazeState: gazeState,
          ),
        );

    await tester.pumpWidget(build(const GazeState.idle()));
    await tester.pumpWidget(
      build(
        const GazeState(
          zone: ScreenZone.bottomRight,
          dwellProgress: 1.0,
          confidence: 1.0,
          signalStatus: GazeSignalStatus.ok,
        ),
      ),
    );

    expect(activationCount, 1);

    // Le regard reste fixé, dwellProgress toujours à 1.0 : pas de second
    // déclenchement tant qu'il n'y a pas eu de front descendant (section
    // 4.4 — validation une seule fois par fixation).
    await tester.pumpWidget(
      build(
        const GazeState(
          zone: ScreenZone.bottomRight,
          dwellProgress: 1.0,
          confidence: 1.0,
          signalStatus: GazeSignalStatus.ok,
        ),
      ),
    );

    expect(activationCount, 1);
  });

  testWidgets('refuse plus de 4 choix (règle du carré magique, section 4.1)', (tester) async {
    expect(
      () => Grid4Screen(
        items: [
          ...fourItems(),
          const Grid4Item(zone: ScreenZone.topLeft, label: 'Trop'),
        ],
      ),
      throwsA(isA<AssertionError>()),
    );
  });

  testWidgets('affiche un repère visuel de zone morte non interactif par défaut', (
    tester,
  ) async {
    var deadZoneTapped = false;
    await tester.pumpWidget(
      wrap(
        Grid4Screen(
          items: fourItems(onTopLeft: () => deadZoneTapped = true),
        ),
      ),
    );

    // La zone morte est centrée et ignore les événements pointeur : un tap
    // au centre de l'écran ne doit déclencher aucune activation (section
    // 4.3).
    await tester.tapAt(tester.getCenter(find.byType(Grid4Screen)));
    await tester.pump();

    expect(deadZoneTapped, isFalse);
  });
}
