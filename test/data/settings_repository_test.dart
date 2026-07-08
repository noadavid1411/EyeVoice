import 'package:eyevoice/data/settings_repository.dart';
import 'package:eyevoice/domain/models/app_settings.dart';
import 'package:eyevoice/eyetracking/models/gaze_sensitivity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsRepository', () {
    test('load() renvoie les valeurs par défaut quand rien n\'est stocké', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = SettingsRepository(prefs);

      final settings = repository.load();

      expect(settings, const AppSettings());
    });

    test('save() puis load() restitue les réglages persistés', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = SettingsRepository(prefs);

      final custom = const AppSettings().copyWith(
        fontSize: AppFontSize.large,
        defaultHomeMode: HomeMode.expert,
        eyeTracking: const AppSettings().eyeTracking.copyWith(
              sensitivity: GazeSensitivity.high,
            ),
      );

      await repository.save(custom);
      final reloaded = repository.load();

      expect(reloaded, custom);
    });

    test('load() retombe sur les valeurs par défaut si le stockage est corrompu', () async {
      SharedPreferences.setMockInitialValues({
        SettingsRepository.storageKey: 'pas-du-json-valide{{{',
      });
      final prefs = await SharedPreferences.getInstance();
      final repository = SettingsRepository(prefs);

      final settings = repository.load();

      expect(settings, const AppSettings());
    });

    test('reset() efface les réglages persistés', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = SettingsRepository(prefs);

      await repository.save(const AppSettings().copyWith(fontSize: AppFontSize.large));
      await repository.reset();
      final settings = repository.load();

      expect(settings, const AppSettings());
    });
  });
}
