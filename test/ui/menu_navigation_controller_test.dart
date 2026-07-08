import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eyevoice/core/models/screen_zone.dart';
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

  setUp(() {
    engine = _FakeTtsEngine();
    container = ProviderContainer(
      overrides: [
        ttsServiceProvider.overrideWithValue(TtsService(engine: engine)),
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

    test(
        'openMode(expert) et settings restent sur l\'écran courant et signalent "bientôt disponible"',
        () async {
      await controller().activate(_itemLabeled('home', '⚙️ OPTIONS'));

      await controller().activate(_itemLabeled('options', 'Mode expert'));
      expect(state().uiMode, UiMode.grid);
      expect(state().comingSoon?.label, 'Mode expert');

      await controller().activate(_itemLabeled('options', 'Réglages'));
      expect(state().uiMode, UiMode.grid);
      expect(state().comingSoon?.label, 'Réglages');
    });
  });
}
