import 'package:eyevoice/core/models/screen_zone.dart';
import 'package:eyevoice/eyetracking/models/gaze_state.dart';
import 'package:eyevoice/ui/theme/app_theme.dart';
import 'package:eyevoice/ui/widgets/scanning_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests widget pour [ScanningGrid] (saisie par balayage temporel, section
/// 8.2 des spécifications) : vérifie que la fenêtre de surbrillance avance
/// automatiquement dans le temps et qu'une activation (tactile ou par
/// regard) n'a d'effet que pendant cette fenêtre.
void main() {
  Widget wrap(Widget child) => MaterialApp(theme: AppTheme.dark, home: Scaffold(body: child));

  const interval = Duration(milliseconds: 200);

  List<ScanChoice> fourChoices({
    VoidCallback? onTopLeft,
    VoidCallback? onTopRight,
    VoidCallback? onBottomLeft,
    VoidCallback? onBottomRight,
  }) => [
        ScanChoice(zone: ScreenZone.topLeft, label: 'A-F', onActivated: onTopLeft),
        ScanChoice(zone: ScreenZone.topRight, label: 'G-L', onActivated: onTopRight),
        ScanChoice(zone: ScreenZone.bottomLeft, label: 'M-R', onActivated: onBottomLeft),
        ScanChoice(zone: ScreenZone.bottomRight, label: 'S-Z', onActivated: onBottomRight),
      ];

  testWidgets('affiche les libellés des 4 choix', (tester) async {
    await tester.pumpWidget(wrap(ScanningGrid(items: fourChoices(), interval: interval)));

    expect(find.text('A-F'), findsOneWidget);
    expect(find.text('G-L'), findsOneWidget);
    expect(find.text('M-R'), findsOneWidget);
    expect(find.text('S-Z'), findsOneWidget);
  });

  testWidgets('un appui sur la zone en surbrillance (haut-gauche au départ) la valide', (
    tester,
  ) async {
    var count = 0;
    await tester.pumpWidget(
      wrap(ScanningGrid(items: fourChoices(onTopLeft: () => count++), interval: interval)),
    );

    await tester.tap(find.text('A-F'));
    await tester.pump();

    expect(count, 1);
  });

  testWidgets('un appui hors de la zone en surbrillance n\'a aucun effet', (tester) async {
    var count = 0;
    await tester.pumpWidget(
      wrap(ScanningGrid(items: fourChoices(onTopRight: () => count++), interval: interval)),
    );

    // Au départ, c'est haut-gauche qui est en surbrillance, pas haut-droite.
    await tester.tap(find.text('G-L'));
    await tester.pump();

    expect(count, 0);
  });

  testWidgets(
    'la surbrillance avance automatiquement vers la zone suivante après [interval]',
    (tester) async {
      var topLeftCount = 0;
      var topRightCount = 0;
      await tester.pumpWidget(
        wrap(
          ScanningGrid(
            items: fourChoices(
              onTopLeft: () => topLeftCount++,
              onTopRight: () => topRightCount++,
            ),
            interval: interval,
          ),
        ),
      );

      // Fait avancer le balayage d'exactement une fenêtre : haut-gauche
      // n'est plus en surbrillance, haut-droite l'est désormais.
      await tester.pump(interval);

      await tester.tap(find.text('A-F'));
      await tester.pump();
      expect(topLeftCount, 0, reason: 'haut-gauche n\'est plus en surbrillance');

      await tester.tap(find.text('G-L'));
      await tester.pump();
      expect(topRightCount, 1, reason: 'haut-droite est maintenant en surbrillance');

      // Le timer périodique reste actif après le test : le widget doit être
      // proprement démonté pour éviter un timer en attente.
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'une fixation du regard sur la zone en surbrillance la valide aussi (bonus section 8.2)',
    (tester) async {
      var count = 0;
      Widget build(GazeState gazeState) => wrap(
            ScanningGrid(
              items: fourChoices(onTopLeft: () => count++),
              interval: interval,
              gazeState: gazeState,
            ),
          );

      await tester.pumpWidget(build(const GazeState.idle()));
      await tester.pumpWidget(
        build(
          const GazeState(
            zone: ScreenZone.topLeft,
            dwellProgress: 0.2,
            confidence: 1.0,
            signalStatus: GazeSignalStatus.ok,
          ),
        ),
      );

      expect(count, 1);
    },
  );

  testWidgets('une fixation sur une zone hors surbrillance n\'a aucun effet', (tester) async {
    var count = 0;
    Widget build(GazeState gazeState) => wrap(
          ScanningGrid(
            items: fourChoices(onBottomRight: () => count++),
            interval: interval,
            gazeState: gazeState,
          ),
        );

    await tester.pumpWidget(build(const GazeState.idle()));
    await tester.pumpWidget(
      build(
        const GazeState(
          zone: ScreenZone.bottomRight,
          dwellProgress: 0.5,
          confidence: 1.0,
          signalStatus: GazeSignalStatus.ok,
        ),
      ),
    );

    expect(count, 0, reason: 'bas-droite n\'est pas la zone en surbrillance au départ');
  });

  testWidgets('la zone morte centrale ne déclenche jamais d\'activation (section 4.3)', (
    tester,
  ) async {
    var count = 0;
    Widget build(GazeState gazeState) => wrap(
          ScanningGrid(
            items: fourChoices(onTopLeft: () => count++),
            interval: interval,
            gazeState: gazeState,
          ),
        );

    await tester.pumpWidget(build(const GazeState.idle()));
    await tester.pumpWidget(
      build(
        const GazeState(
          zone: ScreenZone.centerDeadZone,
          dwellProgress: 0.0,
          confidence: 1.0,
          signalStatus: GazeSignalStatus.ok,
        ),
      ),
    );

    expect(count, 0);
  });

  testWidgets('refuse plus de 4 choix (règle du carré magique, section 4.1)', (tester) async {
    expect(
      () => ScanningGrid(
        items: [
          ...fourChoices(),
          const ScanChoice(zone: ScreenZone.topLeft, label: 'Trop'),
        ],
      ),
      throwsA(isA<AssertionError>()),
    );
  });
}
