import 'package:eyevoice/core/models/screen_zone.dart';
import 'package:eyevoice/domain/actions/action_resolver.dart';
import 'package:eyevoice/domain/actions/action_result.dart';
import 'package:eyevoice/domain/actions/navigation_history.dart';
import 'package:eyevoice/domain/models/menu_action.dart';
import 'package:eyevoice/domain/models/menu_config.dart';
import 'package:eyevoice/domain/models/menu_item.dart';
import 'package:eyevoice/domain/models/menu_screen.dart';
import 'package:eyevoice/domain/models/sample_menu_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NavigationHistory', () {
    test('commence sur l\'écran d\'accueil', () {
      final history = NavigationHistory(homeScreenId: 'home');

      expect(history.current, 'home');
    });

    test('push empile puis current reflète le sommet', () {
      final history = NavigationHistory(homeScreenId: 'home')
        ..push('physical')
        ..push('pain');

      expect(history.current, 'pain');
    });

    test('pop dépile vers l\'écran précédent', () {
      final history = NavigationHistory(homeScreenId: 'home')
        ..push('physical')
        ..push('pain');

      expect(history.pop(), 'physical');
      expect(history.pop(), 'home');
    });

    test('pop depuis l\'accueil reste sur l\'accueil', () {
      final history = NavigationHistory(homeScreenId: 'home');

      expect(history.pop(), 'home');
    });

    test('goHome réinitialise toute la pile', () {
      final history = NavigationHistory(homeScreenId: 'home')
        ..push('physical')
        ..push('pain');

      expect(history.goHome(), 'home');
      // Après goHome, un pop() doit rester sur l'accueil (pile vidée, pas
      // seulement un saut ponctuel).
      expect(history.pop(), 'home');
    });
  });

  group('ActionResolver sur sampleMenuConfig', () {
    late ActionResolver resolver;

    setUp(() {
      resolver = ActionResolver(config: sampleMenuConfig);
    });

    test('resolve(navigate) retourne NavigateAction et empile l\'écran', () {
      final homeScreen = resolver.currentScreen;
      final item = homeScreen.items.firstWhere(
        (i) => i.action == MenuAction.navigate && i.target == 'physical',
      );

      final result = resolver.resolve(item);

      expect(result, const NavigateAction('physical'));
      expect(resolver.currentScreen.id, 'physical');
    });

    test('resolve(speak) retourne SpeakAction avec le texte de l\'item', () {
      resolver.resolve(
        resolver.currentScreen.items.firstWhere((i) => i.target == 'physical'),
      );
      final speakItem = resolver.currentScreen.items.firstWhere(
        (i) => i.action == MenuAction.speak,
      );

      final result = resolver.resolve(speakItem);

      expect(result, isA<SpeakAction>());
      expect((result as SpeakAction).text, speakItem.text);
    });

    test('resolve(back) revient à l\'écran précédent', () {
      final navigateToPhysical = resolver.currentScreen.items.firstWhere(
        (i) => i.target == 'physical',
      );
      resolver.resolve(navigateToPhysical);
      expect(resolver.currentScreen.id, 'physical');

      final backItem = resolver.currentScreen.items.firstWhere(
        (i) => i.action == MenuAction.back,
      );
      final result = resolver.resolve(backItem);

      expect(result, const NavigateAction('home'));
      expect(resolver.currentScreen.id, 'home');
    });

    test('resolve(home) revient à l\'accueil depuis un écran profond', () {
      resolver.resolve(
        resolver.currentScreen.items.firstWhere((i) => i.target == 'physical'),
      );
      resolver.resolve(
        resolver.currentScreen.items.firstWhere((i) => i.target == 'pain'),
      );
      expect(resolver.currentScreen.id, 'pain');

      final homeItem = const MenuItem(
        zone: ScreenZone.bottomRight,
        label: 'Accueil',
        action: MenuAction.home,
      );
      final result = resolver.resolve(homeItem);

      expect(result, const NavigateAction('home'));
      expect(resolver.currentScreen.id, 'home');
    });

    test('resolve(openMode) retourne OpenModeAction avec le mode résolu', () {
      resolver.resolve(
        resolver.currentScreen.items.firstWhere((i) => i.target == 'options'),
      );
      final openModeItem = resolver.currentScreen.items.firstWhere(
        (i) => i.action == MenuAction.openMode && i.target == 'yes-no',
      );

      final result = resolver.resolve(openModeItem);

      expect(result, const OpenModeAction(AppMode.yesNo));
    });

    test('resolve(settings) retourne SettingsAction', () {
      resolver.resolve(
        resolver.currentScreen.items.firstWhere((i) => i.target == 'options'),
      );
      final settingsItem = resolver.currentScreen.items.firstWhere(
        (i) => i.action == MenuAction.settings,
      );

      expect(resolver.resolve(settingsItem), const SettingsAction());
    });

    test('resolve(cancel) retourne CancelAction sans changer d\'écran', () {
      const cancelItem = MenuItem(
        zone: ScreenZone.bottomRight,
        label: 'Annuler',
        action: MenuAction.cancel,
      );

      final result = resolver.resolve(cancelItem);

      expect(result, const CancelAction());
      expect(resolver.currentScreen.id, 'home');
    });
  });

  group('ActionResolver avec un NavigationHistory injecté', () {
    test('respecte un historique déjà positionné sur un écran non-accueil', () {
      const config = MenuConfig(
        appName: 'Test',
        defaultDwellTimeMs: 1300,
        homeScreenId: 'home',
        screens: [
          MenuScreen(id: 'home', type: 'grid-4', title: 'Accueil', items: []),
          MenuScreen(id: 'other', type: 'grid-4', title: 'Autre', items: []),
        ],
      );
      final history = NavigationHistory(homeScreenId: 'home')..push('other');
      final resolver = ActionResolver(config: config, history: history);

      expect(resolver.currentScreen.id, 'other');
    });
  });
}
