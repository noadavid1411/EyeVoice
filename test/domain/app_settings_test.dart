import 'package:eyevoice/core/constants/app_defaults.dart';
import 'package:eyevoice/domain/models/app_settings.dart';
import 'package:eyevoice/eyetracking/models/gaze_sensitivity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppSettings defaults', () {
    test('correspondent aux valeurs recommandées de la section 16', () {
      const settings = AppSettings();

      expect(settings.eyeTracking.dwellTime, AppDefaults.dwellTime);
      expect(
        settings.eyeTracking.centerDeadZoneRatio,
        inInclusiveRange(
          AppDefaults.centerDeadZoneMinRatio,
          AppDefaults.centerDeadZoneMaxRatio,
        ),
      );
      expect(settings.eyeTracking.sensitivity, GazeSensitivity.medium);
      expect(settings.tts.muted, isFalse);
      expect(settings.fontSize, AppFontSize.extraLarge);
      expect(settings.contrastLevel, AppContrastLevel.high);
      expect(settings.defaultHomeMode, HomeMode.quickNeeds);
    });
  });

  group('AppSettings.toJson / fromJson', () {
    test('round-trip conserve toutes les valeurs personnalisées', () {
      final original = const AppSettings().copyWith(
        fontSize: AppFontSize.large,
        contrastLevel: AppContrastLevel.standard,
        defaultHomeMode: HomeMode.expert,
        eyeTracking: const AppSettings().eyeTracking.copyWith(
              dwellTime: const Duration(milliseconds: 1800),
              centerDeadZoneRatio: 0.2,
              sensitivity: GazeSensitivity.low,
            ),
        tts: const AppSettings().tts.copyWith(
              language: 'en-US',
              speechRate: 0.6,
              volume: 0.8,
              pitch: 1.1,
              voiceName: 'Alice',
              muted: true,
            ),
      );

      final decoded = AppSettings.fromJson(original.toJson());

      expect(decoded, original);
      expect(decoded.eyeTracking.dwellTime, const Duration(milliseconds: 1800));
      expect(decoded.eyeTracking.centerDeadZoneRatio, 0.2);
      expect(decoded.eyeTracking.sensitivity, GazeSensitivity.low);
      expect(decoded.tts.voiceName, 'Alice');
      expect(decoded.tts.muted, isTrue);
      expect(decoded.fontSize, AppFontSize.large);
      expect(decoded.contrastLevel, AppContrastLevel.standard);
      expect(decoded.defaultHomeMode, HomeMode.expert);
    });

    test('retombe sur les valeurs par défaut pour un JSON vide', () {
      final decoded = AppSettings.fromJson(const {});

      expect(decoded, const AppSettings());
    });

    test('ignore un champ eyeTracking.sensitivity inconnu', () {
      final json = const AppSettings().toJson();
      (json['eyeTracking'] as Map<String, dynamic>)['sensitivity'] = 'ultra';

      final decoded = AppSettings.fromJson(json);

      expect(decoded.eyeTracking.sensitivity, const AppSettings().eyeTracking.sensitivity);
    });

    test('ignore un champ eyeTracking.centerDeadZoneRatio hors plage', () {
      final json = const AppSettings().toJson();
      (json['eyeTracking'] as Map<String, dynamic>)['centerDeadZoneRatio'] = 0.9;

      final decoded = AppSettings.fromJson(json);

      expect(
        decoded.eyeTracking.centerDeadZoneRatio,
        const AppSettings().eyeTracking.centerDeadZoneRatio,
      );
    });

    test('retombe sur fontSize par défaut si valeur JSON inconnue', () {
      final json = const AppSettings().toJson();
      json['fontSize'] = 'gigantesque';

      final decoded = AppSettings.fromJson(json);

      expect(decoded.fontSize, AppFontSize.extraLarge);
    });
  });
}
