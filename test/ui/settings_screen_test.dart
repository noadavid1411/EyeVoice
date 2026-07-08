import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eyevoice/data/settings_repository.dart';
import 'package:eyevoice/domain/models/app_settings.dart';
import 'package:eyevoice/ui/screens/settings_screen.dart';

/// Tests widget pour [SettingsScreen] (section 16 — réglages configurables).
///
/// Utilise un [ProviderContainer] explicite (plutôt qu'un simple
/// `ProviderScope` avec overrides) pour pouvoir relire directement
/// `settingsProvider` après interaction : ces tests vérifient que les
/// contrôles persistent réellement via [SettingsController], pas seulement
/// qu'ils s'affichent.
void main() {
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
  });

  Widget wrap(Widget child) => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: child),
      );

  /// [SettingsScreen] est une liste défilante (`ListView`) plus haute que la
  /// fenêtre de test par défaut (800×600) : au-delà du viewport + de la
  /// "cache extent" par défaut de la sliver list, les éléments les plus bas
  /// (section "Voix", "Mode d'accueil", bouton de réinitialisation) ne
  /// seraient tout simplement pas montés dans l'arbre de widgets, faisant
  /// échouer `find.text`/`tester.tap` sans rapport avec le comportement réel
  /// de l'écran. On agrandit donc la surface de test pour que tout le
  /// contenu tienne sans défilement, comme sur la tablette large visée par
  /// l'application.
  Future<void> pumpSettings(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrap(child));
    await tester.pump();
  }

  testWidgets('affiche le titre et les valeurs par défaut (section 16)', (tester) async {
    await pumpSettings(tester, const SettingsScreen());

    expect(find.text('Réglages'), findsOneWidget);
    expect(find.textContaining('1300 ms'), findsOneWidget); // dwell time par défaut
    expect(find.textContaining('Synthèse vocale activée'), findsOneWidget);
  });

  testWidgets('la flèche de retour appelle onClose', (tester) async {
    var closed = false;
    await pumpSettings(tester, SettingsScreen(onClose: () => closed = true));

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump();

    expect(closed, isTrue);
  });

  testWidgets(
    'désactiver la synthèse vocale met à jour et persiste settingsProvider immédiatement',
    (tester) async {
      await pumpSettings(tester, const SettingsScreen());
      expect(container.read(settingsProvider).tts.muted, isFalse);

      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();

      expect(container.read(settingsProvider).tts.muted, isTrue);
    },
  );

  testWidgets(
    '"Réinitialiser les réglages" demande confirmation (section 17.2) ; '
    '"Non" ne change rien, "Oui" réinitialise réellement',
    (tester) async {
      await pumpSettings(tester, const SettingsScreen());

      // Modifie un réglage avant de tester la réinitialisation.
      await container
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(fontSize: AppFontSize.large));
      await tester.pump();
      expect(container.read(settingsProvider).fontSize, AppFontSize.large);

      await tester.tap(find.text('Réinitialiser les réglages'));
      await tester.pumpAndSettle();

      expect(find.text('Réinitialiser tous les réglages ?'), findsOneWidget);

      await tester.tap(find.text('NON'));
      await tester.pumpAndSettle();

      // Annulé : le réglage modifié plus haut n'a pas été touché.
      expect(container.read(settingsProvider).fontSize, AppFontSize.large);

      await tester.tap(find.text('Réinitialiser les réglages'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OUI'));
      await tester.pumpAndSettle();

      expect(container.read(settingsProvider), const AppSettings());
    },
  );
}
