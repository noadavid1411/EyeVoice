import 'package:eyevoice/eyetracking/models/gaze_state.dart';
import 'package:eyevoice/services/tts_service.dart';
import 'package:eyevoice/ui/screens/expert_mode_screen.dart';
import 'package:eyevoice/ui/theme/app_theme.dart';
import 'package:eyevoice/ui/widgets/scanning_grid.dart' show kScanHighlightInterval;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Signal de regard "normal" (section 17.3), utilisé pour garder
/// `DegradedSignalBanner` masquée dans ces tests : ils portent sur la
/// composition, pas sur cette bannière (déjà couverte par
/// `test/ui/grid4_screen_test.dart`/`test/ui/yes_no_screen_test.dart`), et
/// son texte ("... avec l'aide d'un proche ...") contiendrait sinon
/// accidentellement "aide", entrant en collision avec les assertions sur le
/// mot composé.
const _okGazeState = GazeState(
  zone: null,
  dwellProgress: 0.0,
  confidence: 1.0,
  signalStatus: GazeSignalStatus.ok,
);

/// Fausse implémentation de [TtsEngine], même principe que
/// `test/services/tts_service_test.dart` : évite tout appel au vrai
/// `MethodChannel` de `flutter_tts` pendant ces tests.
class _FakeTtsEngine implements TtsEngine {
  final List<String> spokenTexts = [];

  @override
  Future<void> setLanguage(String language) async {}
  @override
  Future<void> setSpeechRate(double rate) async {}
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> setPitch(double pitch) async {}
  @override
  Future<void> setVoice(String name, String locale) async {}

  @override
  Future<void> speak(String text) async {
    spokenTexts.add(text);
  }

  @override
  Future<void> stop() async {}
}

/// Tests widget pour [ExpertModeScreen] (Niveau 4 — Mode Expert, section 8) :
/// vérifie l'enchaînement complet 8.3 → 8.6 — choix de groupe, choix de
/// lettre paginé, suggestion de mot, fonctions minimales (effacer, espace,
/// valider, retour au menu principal).
void main() {
  /// Fait avancer le balayage temporel de [steps] fenêtres de surbrillance
  /// (section 8.2) sur le `ScanningGrid` actuellement affiché.
  Future<void> advanceScan(WidgetTester tester, [int steps = 1]) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(kScanHighlightInterval);
    }
  }

  testWidgets(
    'compose "aide" lettre par lettre puis via suggestion, efface, espace, '
    'valide (déclenche le TTS) et revient au menu principal',
    (tester) async {
      final engine = _FakeTtsEngine();
      var exitedToHome = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [ttsServiceProvider.overrideWithValue(TtsService(engine: engine))],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: ExpertModeScreen(
              gazeState: _okGazeState,
              onExitToHome: () => exitedToHome = true,
            ),
          ),
        ),
      );
      // Laisse le `reset()` différé (postFrameCallback de `initState`)
      // s'exécuter avant les assertions.
      await tester.pump();

      // Composition vide au départ (section 8.5 : zone de composition
      // toujours visible, même en l'absence de tout texte saisi).
      expect(find.text('…'), findsOneWidget);

      // Étape 1 (section 8.3) : le groupe A-F occupe le haut-gauche, en
      // surbrillance dès le départ (premier élément balayé).
      expect(find.text('A-F'), findsOneWidget);
      await tester.tap(find.text('A-F'));
      await tester.pump();

      // Étape 2 (section 8.4) : 1re page du groupe A-F (A, B, C), 'A' en
      // surbrillance dès le départ.
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
      await tester.tap(find.text('A'));
      await tester.pump();

      // Retour à l'étape 1 (section 8.4 : "répétition pour lettre
      // suivante") : le texte composé affiche désormais 'a', et la seule
      // suggestion du vocabulaire commençant par 'a' ("aide") apparaît
      // (section 8.5).
      expect(find.text('a'), findsOneWidget);
      expect(find.text('aide'), findsOneWidget);

      // Raccourci section 8.5 : appui direct sur la suggestion, sans
      // attendre le balayage — complète "aide" et ajoute un espace.
      await tester.tap(find.text('aide'));
      await tester.pump();
      expect(find.textContaining('aide'), findsOneWidget);

      // Ouvre les fonctions minimales (section 8.6) via le bouton discret,
      // tactile uniquement, de l'en-tête de composition.
      await tester.tap(find.byIcon(Icons.build_outlined));
      await tester.pump();
      expect(find.text('Effacer'), findsOneWidget);

      // 'Effacer' occupe le haut-gauche, en surbrillance dès le départ :
      // retire l'espace final laissé par applySuggestion.
      await tester.tap(find.text('Effacer'));
      await tester.pump();
      // Le texte composé ("aide") et sa propre suggestion de complétion
      // (préfixe "aide" ⊆ "aide") sont désormais tous deux affichés.
      expect(find.text('aide'), findsNWidgets(2));

      // Réouvre les fonctions pour insérer un espace ('Espace' est la 2e
      // zone balayée, haut-droite).
      await tester.tap(find.byIcon(Icons.build_outlined));
      await tester.pump();
      await advanceScan(tester, 1);
      await tester.tap(find.text('Espace'));
      await tester.pump();

      // Réouvre les fonctions pour valider ('Valider' est la 3e zone
      // balayée, bas-gauche) : déclenche la synthèse vocale.
      await tester.tap(find.byIcon(Icons.build_outlined));
      await tester.pump();
      await advanceScan(tester, 2);
      await tester.tap(find.text('Valider'));
      await tester.pump();

      expect(engine.spokenTexts, ['aide']);
      // Composition réinitialisée après validation (comportement symétrique
      // de la section 7.3 : repartir sur une phrase vierge).
      expect(find.text('…'), findsOneWidget);

      // Réouvre les fonctions pour revenir au menu principal ('Menu
      // principal' est la 4e zone balayée, bas-droite — section 8.6).
      await tester.tap(find.byIcon(Icons.build_outlined));
      await tester.pump();
      await advanceScan(tester, 3);
      await tester.tap(find.text('Menu principal'));
      await tester.pump();

      expect(exitedToHome, isTrue);
    },
  );

  testWidgets(
    'chemin complet groupe → lettres → Fonctions (balayé) → Menu principal (balayé), '
    'sans jamais taper sur l\'icône Fonctions de l\'en-tête (patient qui ne peut interagir '
    'que par le regard — reproduction du bug corrigé)',
    (tester) async {
      final engine = _FakeTtsEngine();
      var exitedToHome = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [ttsServiceProvider.overrideWithValue(TtsService(engine: engine))],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: ExpertModeScreen(
              gazeState: _okGazeState,
              onExitToHome: () => exitedToHome = true,
            ),
          ),
        ),
      );
      await tester.pump();

      // Le raccourci tactile direct de l'en-tête reste présent (section
      // 17.3), mais n'est jamais utilisé dans ce test : seule la
      // validation "dans la fenêtre de surbrillance active" (tap ou
      // regard, indifféremment côté ScanningGrid) est employée, exactement
      // ce dont dépend un patient qui ne peut pas taper une icône précise.
      expect(find.byIcon(Icons.build_outlined), findsOneWidget);

      // Étape 1 (section 8.3) : le groupe A-F est en surbrillance dès le
      // départ, validé pendant sa fenêtre.
      expect(find.text('A-F'), findsOneWidget);
      await tester.tap(find.text('A-F'));
      await tester.pump();

      // Étape 2 (section 8.4) : 1re page du groupe A-F (A, B, C) + 'Suite'
      // en bas-droite. La cible "Fonctions" (section 8.6) n'apparaît qu'en
      // 5e position du balayage de cet écran, après les 4 zones.
      expect(find.text('A'), findsOneWidget);
      expect(find.text('Fonctions'), findsNothing);
      await advanceScan(tester, 4);
      expect(find.text('Fonctions'), findsOneWidget);

      await tester.tap(find.text('Fonctions'));
      await tester.pump();

      // Bascule vers l'écran des fonctions minimales (section 8.6) : les 4
      // zones balayées sont désormais Effacer/Espace/Valider/Menu
      // principal, sans qu'aucun tap n'ait jamais touché l'icône de
      // l'en-tête.
      expect(find.text('Effacer'), findsOneWidget);
      expect(find.text('Menu principal'), findsOneWidget);

      // 'Menu principal' est la 4e zone balayée (bas-droite) : 3 fenêtres
      // pour l'atteindre depuis 'Effacer', en surbrillance au départ.
      await advanceScan(tester, 3);
      await tester.tap(find.text('Menu principal'));
      await tester.pump();

      expect(exitedToHome, isTrue);
      expect(engine.spokenTexts, isEmpty, reason: 'aucune validation n\'a eu lieu dans ce parcours');
    },
  );

  testWidgets(
    'un appui hors de la zone en surbrillance ne modifie pas la composition',
    (tester) async {
      final engine = _FakeTtsEngine();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [ttsServiceProvider.overrideWithValue(TtsService(engine: engine))],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: ExpertModeScreen(gazeState: _okGazeState, onExitToHome: () {}),
          ),
        ),
      );
      await tester.pump();

      // Au départ, seul le groupe A-F (haut-gauche) est en surbrillance :
      // un appui sur un autre groupe est ignoré (section 8.2).
      await tester.tap(find.text('S-Z'));
      await tester.pump();

      expect(find.text('A-F'), findsOneWidget, reason: 'toujours à l\'étape 1');
      expect(find.text('…'), findsOneWidget, reason: 'aucune composition n\'a démarré');
    },
  );
}
