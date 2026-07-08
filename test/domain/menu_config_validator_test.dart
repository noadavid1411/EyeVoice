import 'package:eyevoice/domain/models/menu_config.dart';
import 'package:eyevoice/domain/models/menu_config_exception.dart';
import 'package:eyevoice/domain/models/menu_config_validator.dart';
import 'package:eyevoice/domain/models/sample_menu_config.dart';
import 'package:flutter_test/flutter_test.dart';

/// JSON minimal valide, servant de base clonable pour les cas d'erreur.
Map<String, dynamic> _validJson() => {
      'appName': 'La Voix du Regard',
      'defaultDwellTimeMs': 1300,
      'homeScreenId': 'home',
      'screens': [
        {
          'id': 'home',
          'type': 'grid-4',
          'title': 'Accueil',
          'items': [
            {
              'zone': 'top-left',
              'label': 'PHYSIQUE',
              'action': 'navigate',
              'target': 'physical',
            },
            {
              'zone': 'top-right',
              'label': 'CONVERSATION',
              'action': 'speak',
              'text': 'Bonjour',
            },
            {
              'zone': 'bottom-left',
              'label': 'Mode Oui/Non',
              'action': 'openMode',
              'target': 'yes-no',
            },
            {
              'zone': 'bottom-right',
              'label': 'Options',
              'action': 'settings',
            },
          ],
        },
        {
          'id': 'physical',
          'type': 'grid-4',
          'title': 'Physique',
          'items': [
            {
              'zone': 'bottom-right',
              'label': 'Retour',
              'action': 'back',
            },
          ],
        },
      ],
    };

void main() {
  group('MenuConfig.fromJson (parsing)', () {
    test('parse une configuration valide', () {
      final config = MenuConfig.fromJson(_validJson());

      expect(config.appName, 'La Voix du Regard');
      expect(config.homeScreenId, 'home');
      expect(config.screens, hasLength(2));
      expect(config.screens.first.items, hasLength(4));
    });

    test('rejette une action inconnue', () {
      final json = _validJson();
      (json['screens'] as List)[0]['items'][0]['action'] = 'teleport';

      expect(
        () => MenuConfig.fromJson(json),
        throwsA(isA<MenuConfigParseException>()),
      );
    });

    test('rejette une zone inconnue', () {
      final json = _validJson();
      (json['screens'] as List)[0]['items'][0]['zone'] = 'nowhere';

      expect(
        () => MenuConfig.fromJson(json),
        throwsA(isA<MenuConfigParseException>()),
      );
    });

    test('rejette un item openMode sans target', () {
      final json = _validJson();
      (json['screens'] as List)[0]['items'][2] = {
        'zone': 'bottom-left',
        'label': 'Mode Oui/Non',
        'action': 'openMode',
      };

      expect(
        () => MenuConfig.fromJson(json),
        throwsA(isA<MenuConfigParseException>()),
      );
    });

    test("rejette une configuration sans champ 'screens'", () {
      final json = _validJson()..remove('screens');

      expect(
        () => MenuConfig.fromJson(json),
        throwsA(isA<MenuConfigParseException>()),
      );
    });
  });

  group('validateMenuConfig', () {
    test('accepte une configuration valide sans lever d\'exception', () {
      final config = MenuConfig.fromJson(_validJson());

      expect(() => validateMenuConfig(config), returnsNormally);
    });

    test('accepte le sampleMenuConfig fourni pour les autres phases', () {
      expect(() => validateMenuConfig(sampleMenuConfig), returnsNormally);
    });

    test('rejette un écran de plus de 4 choix (règle du carré magique)', () {
      final json = _validJson();
      (json['screens'] as List)[0]['items'].add({
        'zone': 'left',
        'label': 'Cinquième choix',
        'action': 'cancel',
      });
      final config = MenuConfig.fromJson(json);

      expect(
        () => validateMenuConfig(config),
        throwsA(
          isA<MenuConfigValidationException>().having(
            (e) => e.errors.join(),
            'errors',
            contains('choix'),
          ),
        ),
      );
    });

    test('rejette homeScreenId introuvable', () {
      final json = _validJson();
      json['homeScreenId'] = 'inconnu';
      final config = MenuConfig.fromJson(json);

      expect(
        () => validateMenuConfig(config),
        throwsA(isA<MenuConfigValidationException>()),
      );
    });

    test('rejette une cible navigate inexistante', () {
      final json = _validJson();
      (json['screens'] as List)[0]['items'][0]['target'] = 'introuvable';
      final config = MenuConfig.fromJson(json);

      expect(
        () => validateMenuConfig(config),
        throwsA(isA<MenuConfigValidationException>()),
      );
    });

    test('rejette des identifiants d\'écran dupliqués', () {
      final json = _validJson();
      (json['screens'] as List)[1]['id'] = 'home';
      final config = MenuConfig.fromJson(json);

      expect(
        () => validateMenuConfig(config),
        throwsA(isA<MenuConfigValidationException>()),
      );
    });

    test('collecte plusieurs erreurs en une seule exception', () {
      final json = _validJson();
      json['homeScreenId'] = 'inconnu';
      (json['screens'] as List)[0]['items'][0]['target'] = 'introuvable';
      final config = MenuConfig.fromJson(json);

      try {
        validateMenuConfig(config);
        fail('devait lever MenuConfigValidationException');
      } on MenuConfigValidationException catch (e) {
        expect(e.errors.length, greaterThanOrEqualTo(2));
      }
    });
  });
}
