import 'package:eyevoice/domain/expert/letter_group.dart';
import 'package:eyevoice/services/tts_service.dart';
import 'package:eyevoice/ui/providers/expert_mode_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

/// Tests unitaires (sans widget) pour [ExpertModeController], le câblage
/// Riverpod des fondations pures du mode expert (`lib/domain/expert`) —
/// SPECIFICATIONS_FONCTIONNELLES.md section 8.
void main() {
  late _FakeTtsEngine engine;
  late ProviderContainer container;

  setUp(() {
    engine = _FakeTtsEngine();
    container = ProviderContainer(
      overrides: [ttsServiceProvider.overrideWithValue(TtsService(engine: engine))],
    );
    addTearDown(container.dispose);
  });

  ExpertModeController controller() => container.read(expertModeProvider.notifier);
  ExpertModeState state() => container.read(expertModeProvider);

  test('état initial : étape groupe, texte vide, aucune suggestion', () {
    expect(state().step, ExpertStep.group);
    expect(state().text, '');
    expect(state().currentWord, '');
    expect(state().suggestions, isEmpty);
  });

  test('selectGroup bascule vers l\'étape lettres, page 0', () {
    controller().selectGroup(LetterGroup.aToF);

    expect(state().step, ExpertStep.letters);
    expect(state().selectedGroup, LetterGroup.aToF);
    expect(state().letterPageIndex, 0);
  });

  test('addLetter ajoute la lettre et revient à l\'étape groupe (section 8.4)', () {
    controller().selectGroup(LetterGroup.aToF);

    controller().addLetter('D');

    expect(state().text, 'd');
    expect(state().step, ExpertStep.group);
  });

  test(
    'nextLetterPageOrBackToGroups avance de page en page puis revient au groupe (section 8.4)',
    () {
      controller().selectGroup(LetterGroup.sToZ); // 8 lettres, pages de 3 -> 3 pages
      expect(state().letterPageIndex, 0);

      controller().nextLetterPageOrBackToGroups();
      expect(state().step, ExpertStep.letters);
      expect(state().letterPageIndex, 1);

      controller().nextLetterPageOrBackToGroups();
      expect(state().step, ExpertStep.letters);
      expect(state().letterPageIndex, 2);

      // Dernière page : retombe sur l'étape groupe plutôt que de boucler.
      controller().nextLetterPageOrBackToGroups();
      expect(state().step, ExpertStep.group);
    },
  );

  test('compose "do" lettre par lettre et propose douleur/dormir/docteur (exemple section 8.5)', () {
    controller().addLetter('D');
    controller().addLetter('O');

    expect(state().text, 'do');
    expect(state().suggestions, ['douleur', 'dormir', 'docteur']);
  });

  test('applySuggestion complète le mot en cours et ajoute un espace', () {
    controller().addLetter('I');
    controller().addLetter('N');
    controller().addLetter('F');
    expect(state().suggestions, ['infirmière']);

    controller().applySuggestion('infirmière');

    expect(state().text, 'infirmière ');
    expect(state().currentWord, '');
    expect(state().suggestions, isEmpty);
  });

  test('deleteLastLetter retire le dernier caractère', () {
    controller().addLetter('A');
    controller().addLetter('B');

    controller().deleteLastLetter();

    expect(state().text, 'a');
  });

  test('addSpace insère un espace terminant le mot courant', () {
    controller().addLetter('A');

    controller().addSpace();

    expect(state().text, 'a ');
    expect(state().currentWord, '');
  });

  test('validate transmet le texte composé au vrai TtsService puis réinitialise', () async {
    controller().addLetter('A');
    controller().addSpace();
    controller().addLetter('B');

    await controller().validate();

    expect(engine.spokenTexts, ['a b']);
    expect(state().text, '');
    expect(state().step, ExpertStep.group);
  });

  test('validate ne fait rien pour un texte vide (rien à prononcer)', () async {
    await controller().validate();

    expect(engine.spokenTexts, isEmpty);
  });

  test('reset efface la composition et revient à l\'étape groupe', () {
    controller().addLetter('A');
    controller().selectGroup(LetterGroup.gToL);

    controller().reset();

    expect(state().text, '');
    expect(state().step, ExpertStep.group);
    expect(state().selectedGroup, isNull);
  });

  test('openActions conserve le groupe/la page en cours', () {
    controller().selectGroup(LetterGroup.mToR);
    controller().nextLetterPageOrBackToGroups();
    expect(state().letterPageIndex, 1);

    controller().openActions();

    expect(state().step, ExpertStep.actions);
    expect(state().selectedGroup, LetterGroup.mToR);
    expect(state().letterPageIndex, 1);
  });
}
