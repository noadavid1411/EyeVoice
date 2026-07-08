import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eyevoice/ui/theme/app_theme.dart';
import 'package:eyevoice/ui/widgets/confirmation_dialog.dart';

/// Tests widget pour [ConfirmationDialog] (section 17.2 — confirmation des
/// actions sensibles). Vérifie qu'il affiche bien le message fourni par
/// l'appelant (jamais de texte en dur) et que "Oui"/"Non"/l'affordance de
/// sortie déclenchent le bon callback, sans jamais les deux à la fois.
void main() {
  Widget wrap(Widget child) => MaterialApp(theme: AppTheme.dark, home: child);

  testWidgets('affiche le message fourni et les deux choix OUI/NON', (tester) async {
    await tester.pumpWidget(
      wrap(
        ConfirmationDialog(
          message: 'Confirmer : Changer de position ?',
          onConfirm: () {},
          onCancel: () {},
        ),
      ),
    );

    expect(find.text('Confirmer : Changer de position ?'), findsOneWidget);
    expect(find.text('OUI'), findsOneWidget);
    expect(find.text('NON'), findsOneWidget);
  });

  testWidgets('"OUI" déclenche onConfirm sans déclencher onCancel', (tester) async {
    var confirmed = false;
    var cancelled = false;
    await tester.pumpWidget(
      wrap(
        ConfirmationDialog(
          message: 'Confirmer ?',
          onConfirm: () => confirmed = true,
          onCancel: () => cancelled = true,
        ),
      ),
    );

    await tester.tap(find.text('OUI'));
    await tester.pump();

    expect(confirmed, isTrue);
    expect(cancelled, isFalse);
  });

  testWidgets('"NON" déclenche onCancel sans déclencher onConfirm', (tester) async {
    var confirmed = false;
    var cancelled = false;
    await tester.pumpWidget(
      wrap(
        ConfirmationDialog(
          message: 'Confirmer ?',
          onConfirm: () => confirmed = true,
          onCancel: () => cancelled = true,
        ),
      ),
    );

    await tester.tap(find.text('NON'));
    await tester.pump();

    expect(cancelled, isTrue);
    expect(confirmed, isFalse);
  });

  testWidgets(
    'l\'affordance de sortie discrète a le même effet qu\'un "Non" explicite',
    (tester) async {
      var cancelled = false;
      await tester.pumpWidget(
        wrap(
          ConfirmationDialog(
            message: 'Confirmer ?',
            onConfirm: () {},
            onCancel: () => cancelled = true,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();

      expect(cancelled, isTrue);
    },
  );
}
