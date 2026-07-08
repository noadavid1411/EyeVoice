import 'package:eyevoice/data/menu_config_repository.dart';
import 'package:eyevoice/domain/models/menu_action.dart';
import 'package:eyevoice/domain/models/menu_config_exception.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MenuConfigRepository', () {
    test('charge et valide le vrai asset assets/menu-config.json', () async {
      final repository = MenuConfigRepository();

      final config = await repository.load();

      expect(config.appName, 'La Voix du Regard');
      expect(config.homeScreenId, 'home');
      expect(config.screenById('home').items, hasLength(4));
      // La configuration chargée depuis l'asset est déjà passée par
      // `validateMenuConfig` (via `loadMenuConfig`) : aucun écran ne doit
      // dépasser la règle des 4 choix, ni référencer de cible `navigate`
      // inexistante — sinon `MenuConfigRepository.load` aurait déjà levé
      // une `MenuConfigValidationException` avant d'atteindre cette
      // assertion.
      for (final screen in config.screens) {
        expect(screen.items.length, lessThanOrEqualTo(4));
      }
    });

    test('conserve le flag requiresConfirmation lu depuis le JSON', () async {
      final repository = MenuConfigRepository();

      final config = await repository.load();

      final positionItem = config
          .screenById('physical')
          .items
          .firstWhere((item) => item.action == MenuAction.navigate && item.target == 'position');

      expect(positionItem.requiresConfirmation, isTrue);
    });
  });

  group('menuConfigProvider', () {
    test('résout un MenuConfig valide via le container Riverpod', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final config = await container.read(menuConfigProvider.future);

      expect(config.homeScreenId, 'home');
      expect(config.screens, isNotEmpty);
    });
  });

  group('MenuConfigRepository (asset invalide)', () {
    test('propage MenuConfigParseException pour un asset JSON mal formé', () async {
      final repository = MenuConfigRepository(bundle: _FakeAssetBundle('pas-du-json{{{'));

      expect(repository.load, throwsA(isA<FormatException>()));
    });

    test('propage MenuConfigValidationException pour un JSON structurellement valide mais incohérent', () async {
      final repository = MenuConfigRepository(
        bundle: _FakeAssetBundle('''
{
  "appName": "Test",
  "defaultDwellTimeMs": 1000,
  "homeScreenId": "introuvable",
  "screens": [
    {
      "id": "home",
      "type": "grid-4",
      "title": "Accueil",
      "items": []
    }
  ]
}
'''),
      );

      expect(
        repository.load,
        throwsA(isA<MenuConfigValidationException>()),
      );
    });
  });
}

/// [AssetBundle] minimal renvoyant toujours [_content], pour tester le
/// comportement de [MenuConfigRepository.load] sur un contenu contrôlé sans
/// dépendre de l'asset réel du dépôt.
class _FakeAssetBundle extends CachingAssetBundle {
  final String _content;

  _FakeAssetBundle(this._content);

  @override
  Future<String> loadString(String key, {bool cache = true}) async => _content;

  @override
  Future<ByteData> load(String key) {
    // Non utilisé par [MenuConfigRepository.load], qui ne passe que par
    // [loadString] : seule cette dernière méthode importe pour ces tests.
    throw UnimplementedError();
  }
}
