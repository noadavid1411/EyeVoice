import 'package:eyevoice/core/models/screen_zone.dart';
import 'package:eyevoice/domain/models/menu_action.dart';
import 'package:eyevoice/domain/models/menu_config_exception.dart';
import 'package:eyevoice/domain/models/menu_item.dart';
import 'package:flutter_test/flutter_test.dart';

/// JSON minimal valide pour un item `cancel`, servant de base clonable pour
/// tester le champ optionnel `requiresConfirmation` (section 17.2).
Map<String, dynamic> _validJson() => {
      'zone': 'bottom-right',
      'label': 'Quitter',
      'action': 'cancel',
    };

void main() {
  group('MenuItem.requiresConfirmation (section 17.2)', () {
    test('vaut false par défaut quand le champ est absent du JSON', () {
      final item = MenuItem.fromJson(_validJson());

      expect(item.requiresConfirmation, isFalse);
    });

    test('vaut true quand explicitement présent dans le JSON', () {
      final json = _validJson()..['requiresConfirmation'] = true;
      final item = MenuItem.fromJson(json);

      expect(item.requiresConfirmation, isTrue);
    });

    test('vaut false quand explicitement false dans le JSON', () {
      final json = _validJson()..['requiresConfirmation'] = false;
      final item = MenuItem.fromJson(json);

      expect(item.requiresConfirmation, isFalse);
    });

    test('lève MenuConfigParseException si le champ est mal typé', () {
      final json = _validJson()..['requiresConfirmation'] = 'oui';

      expect(
        () => MenuItem.fromJson(json),
        throwsA(isA<MenuConfigParseException>()),
      );
    });

    test('reste false par défaut via le constructeur direct', () {
      const item = MenuItem(
        zone: ScreenZone.bottomRight,
        label: 'x',
        action: MenuAction.cancel,
      );
      expect(item.requiresConfirmation, isFalse);
    });
  });
}
