import 'package:eyevoice/core/models/screen_zone.dart';
import 'package:eyevoice/eyetracking/models/gaze_state.dart';
import 'package:eyevoice/ui/screens/yes_no_screen.dart';
import 'package:eyevoice/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests widget basiques pour [YesNoScreen] (Niveau 1 — Mode Sécurité,
/// section 5). Vérifie les critères d'acceptation directement liés à ce
/// widget (section 19) : 2 zones simples, OUI/NON fonctionnels.
void main() {
  Widget wrap(Widget child) => MaterialApp(theme: AppTheme.dark, home: child);

  testWidgets('affiche OUI et NON', (tester) async {
    await tester.pumpWidget(wrap(const YesNoScreen()));

    expect(find.text('OUI'), findsOneWidget);
    expect(find.text('NON'), findsOneWidget);
  });

  testWidgets('affiche la question fournie par l\'appelant (pas de texte en dur)', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const YesNoScreen(question: 'Tu as mal ?')));

    expect(find.text('Tu as mal ?'), findsOneWidget);
  });

  testWidgets('un appui tactile sur OUI déclenche onYes', (tester) async {
    var yes = false;
    await tester.pumpWidget(wrap(YesNoScreen(onYes: () => yes = true)));

    await tester.tap(find.text('OUI'));
    await tester.pump();

    expect(yes, isTrue);
  });

  testWidgets('un appui tactile sur NON déclenche onNo', (tester) async {
    var no = false;
    await tester.pumpWidget(wrap(YesNoScreen(onNo: () => no = true)));

    await tester.tap(find.text('NON'));
    await tester.pump();

    expect(no, isTrue);
  });

  testWidgets('un dwellProgress de 1.0 sur la zone gauche valide OUI', (tester) async {
    var yesCount = 0;

    Widget build(GazeState gazeState) =>
        wrap(YesNoScreen(gazeState: gazeState, onYes: () => yesCount++));

    await tester.pumpWidget(build(const GazeState.idle()));
    await tester.pumpWidget(
      build(
        const GazeState(
          zone: ScreenZone.left,
          dwellProgress: 1.0,
          confidence: 1.0,
          signalStatus: GazeSignalStatus.ok,
        ),
      ),
    );

    expect(yesCount, 1);
  });

  testWidgets('sans onExit fourni, aucune affordance de sortie n\'est affichée', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const YesNoScreen()));

    expect(find.byIcon(Icons.arrow_back), findsNothing);
  });

  testWidgets(
    'affiche une bannière de mode dégradé quand le signal est instable (section 17.3)',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          const YesNoScreen(
            gazeState: GazeState(
              zone: null,
              dwellProgress: 0.0,
              confidence: 0.4,
              signalStatus: GazeSignalStatus.degraded,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    },
  );
}
