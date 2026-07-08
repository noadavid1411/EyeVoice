import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eyevoice/core/models/screen_zone.dart';
import 'package:eyevoice/data/menu_config_repository.dart';
import 'package:eyevoice/data/settings_repository.dart';
import 'package:eyevoice/domain/models/menu_action.dart';
import 'package:eyevoice/domain/models/menu_item.dart';
import 'package:eyevoice/domain/models/sample_menu_config.dart';
import 'package:eyevoice/services/tts_service.dart';
import 'package:eyevoice/ui/providers/menu_navigation_controller.dart';

/// Fausse implémentation de [TtsEngine], sur le même principe que
/// `test/services/tts_service_test.dart` : évite tout appel au vrai
/// `MethodChannel` de `flutter_tts` pendant ces tests de navigation.
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

MenuItem _itemLabeled(String screenId, String label) =>
    sampleMenuConfig.screenById(screenId).items.firstWhere((i) => i.label == label);

void main() {
  late _FakeTtsEngine engine;
  late ProviderContainer container;

  setUp(() async {
    engine = _FakeTtsEngine();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        ttsServiceProvider.overrideWithValue(TtsService(engine: engine)),
        sharedPreferencesProvider.overrideWithValue(prefs),
        // Fournit `sampleMenuConfig` de façon synchrone plutôt que de
        // dépendre du vrai asset `assets/menu-config.json` (couvert par
        // `test/data/menu_config_repository_test.dart`) : un `FutureOr`
        // renvoyé sans `Future` résout immédiatement (voir la doc de
        // `MenuNavigationController.build`), donc `menuNavigationProvider`
        // est utilisable sans aucun `pump`/`await` supplémentaire ici.
        menuConfigProvider.overrideWith((ref) => sampleMenuConfig),
      ],
    );
    addTearDown(container.dispose);
  });

  MenuNavigationController controller() => container.read(menuNavigationProvider.notifier);
  MenuNavigationState state() => container.read(menuNavigationProvider);

  group('MenuNavigationController — navigation effective (ActionResolver réel)', () {
    test('démarre sur l\'écran d\'accueil de sampleMenuConfig', () {
      expect(state().screen.id, sampleMenuConfig.homeScreenId);
      expect(state().uiMode, UiMode.grid);
    });

    test('navigate met à jour l\'écran courant vers la cible réelle', () async {
      await controller().activate(_itemLabeled('home', '🩺 PHYSIQUE'));

      expect(state().screen.id, 'physical');
      expect(state().uiMode, UiMode.grid);
    });

    test('back dépile via le vrai historique de navigation du domaine', () async {
      await controller().activate(_itemLabeled('home', '🩺 PHYSIQUE'));
      expect(state().screen.id, 'physical');

      await controller().activate(_itemLabeled('physical', 'Retour'));

      expect(state().screen.id, 'home');
    });

    test('home réinitialise la pile même après plusieurs navigations', () async {
      await controller().activate(_itemLabeled('home', '🩺 PHYSIQUE'));
      await controller().activate(_itemLabeled('physical', 'J’ai mal'));
      expect(state().screen.id, 'pain');

      const homeItem = MenuItem(
        zone: ScreenZone.bottomRight,
        label: 'Accueil',
        action: MenuAction.home,
      );
      await controller().activate(homeItem);

      expect(state().screen.id, sampleMenuConfig.homeScreenId);
    });
  });

  group('MenuNavigationController — TTS réel branché sur l\'action speak', () {
    test('speak transmet le texte de l\'item au vrai TtsService', () async {
      await controller().activate(_itemLabeled('home', '🩺 PHYSIQUE'));

      await controller().activate(_itemLabeled('physical', 'J’ai soif / faim'));

      expect(engine.spokenTexts, ['J’ai soif ou faim.']);
      expect(state().spokenPhrase?.text, 'J’ai soif ou faim.');
    });

    test('deux activations successives du même item incrémentent l\'id de spokenPhrase', () async {
      await controller().activate(_itemLabeled('home', '🩺 PHYSIQUE'));
      final item = _itemLabeled('physical', 'J’ai soif / faim');

      await controller().activate(item);
      final firstId = state().spokenPhrase!.id;
      await controller().activate(item);
      final secondId = state().spokenPhrase!.id;

      expect(secondId, greaterThan(firstId));
      expect(engine.spokenTexts, ['J’ai soif ou faim.', 'J’ai soif ou faim.']);
    });

    test('answerYes/answerNo (mode Oui/Non) parlent aussi via le vrai TtsService', () async {
      await controller().answerYes();
      await controller().answerNo();

      expect(engine.spokenTexts, ['Oui.', 'Non.']);
    });
  });

  group('MenuNavigationController — openMode / settings', () {
    test('openMode(yesNo) bascule uiMode sans toucher à l\'écran grid-4 courant', () async {
      await controller().activate(_itemLabeled('home', '⚙️ OPTIONS'));
      expect(state().screen.id, 'options');

      await controller().activate(_itemLabeled('options', 'Mode Oui / Non'));

      expect(state().uiMode, UiMode.yesNo);
      expect(state().screen.id, 'options');
    });

    test('exitYesNo retrouve l\'écran grid-4 précédent sans navigation supplémentaire', () async {
      await controller().activate(_itemLabeled('home', '⚙️ OPTIONS'));
      await controller().activate(_itemLabeled('options', 'Mode Oui / Non'));
      expect(state().uiMode, UiMode.yesNo);

      controller().exitYesNo();

      expect(state().uiMode, UiMode.grid);
      expect(state().screen.id, 'options');
    });

    test('openMode(expert) bascule uiMode vers UiMode.expert sans toucher à l\'écran grid-4 courant', () async {
      await controller().activate(_itemLabeled('home', '⚙️ OPTIONS'));
      expect(state().screen.id, 'options');

      await controller().activate(_itemLabeled('options', 'Mode expert'));

      expect(state().uiMode, UiMode.expert);
      expect(state().screen.id, 'options');
    });

    test('l\'action settings ouvre le vrai UiMode.settings (section 16)', () async {
      await controller().activate(_itemLabeled('home', '⚙️ OPTIONS'));

      await controller().activate(_itemLabeled('options', 'Réglages'));

      expect(state().uiMode, UiMode.settings);
      expect(state().screen.id, 'options');
    });

    test('exitSettings retrouve l\'écran grid-4 précédent sans navigation supplémentaire', () async {
      await controller().activate(_itemLabeled('home', '⚙️ OPTIONS'));
      await controller().activate(_itemLabeled('options', 'Réglages'));
      expect(state().uiMode, UiMode.settings);

      controller().exitSettings();

      expect(state().uiMode, UiMode.grid);
      expect(state().screen.id, 'options');
    });
  });

  group('MenuNavigationController — confirmation des actions sensibles (section 17.2)', () {
    test('un item requiresConfirmation ne résout pas l\'action, ouvre UiMode.confirmation', () async {
      await controller().activate(_itemLabeled('home', '🩺 PHYSIQUE'));
      final item = _itemLabeled('physical', 'Changer de position');
      expect(item.requiresConfirmation, isTrue);

      await controller().activate(item);

      // Toujours sur 'physical' : `resolve()` n'a pas été appelé.
      expect(state().screen.id, 'physical');
      expect(state().uiMode, UiMode.confirmation);
      expect(state().pendingConfirmation, item);
    });

    test('cancelPending n\'exécute jamais l\'action et revient à l\'écran courant', () async {
      await controller().activate(_itemLabeled('home', '🩺 PHYSIQUE'));
      await controller().activate(_itemLabeled('physical', 'Changer de position'));
      expect(state().uiMode, UiMode.confirmation);

      controller().cancelPending();

      expect(state().uiMode, UiMode.grid);
      expect(state().screen.id, 'physical');
      expect(state().pendingConfirmation, isNull);
    });

    test('confirmPending exécute réellement l\'action (navigate) une fois confirmée', () async {
      await controller().activate(_itemLabeled('home', '🩺 PHYSIQUE'));
      await controller().activate(_itemLabeled('physical', 'Changer de position'));
      expect(state().uiMode, UiMode.confirmation);

      await controller().confirmPending();

      expect(state().uiMode, UiMode.grid);
      expect(state().screen.id, 'position');
      expect(state().pendingConfirmation, isNull);
    });

    test('confirmPending ne fait rien si aucune confirmation n\'est en attente', () async {
      await controller().activate(_itemLabeled('home', '🩺 PHYSIQUE'));
      expect(state().uiMode, UiMode.grid);

      await controller().confirmPending();

      expect(state().uiMode, UiMode.grid);
      expect(state().screen.id, 'physical');
    });
  });
}
