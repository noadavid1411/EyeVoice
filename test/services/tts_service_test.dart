import 'package:flutter_test/flutter_test.dart';
import 'package:eyevoice/services/tts_service.dart';
import 'package:eyevoice/services/tts_settings.dart';

/// Fausse implémentation de [TtsEngine] : enregistre les appels reçus sans
/// jamais toucher au vrai `MethodChannel` de `flutter_tts`, pour garder ces
/// tests indépendants de la plateforme.
class _FakeTtsEngine implements TtsEngine {
  final List<String> spokenTexts = [];
  int stopCount = 0;
  String? lastLanguage;
  double? lastSpeechRate;
  double? lastVolume;
  double? lastPitch;
  ({String name, String locale})? lastVoice;

  @override
  Future<void> setLanguage(String language) async {
    lastLanguage = language;
  }

  @override
  Future<void> setSpeechRate(double rate) async {
    lastSpeechRate = rate;
  }

  @override
  Future<void> setVolume(double volume) async {
    lastVolume = volume;
  }

  @override
  Future<void> setPitch(double pitch) async {
    lastPitch = pitch;
  }

  @override
  Future<void> setVoice(String name, String locale) async {
    lastVoice = (name: name, locale: locale);
  }

  @override
  Future<void> speak(String text) async {
    spokenTexts.add(text);
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }
}

void main() {
  group('TtsService', () {
    test('speak() applies settings once then forwards text to the engine', () async {
      final engine = _FakeTtsEngine();
      final service = TtsService(
        engine: engine,
        initialSettings: const TtsSettings(language: 'fr-FR', speechRate: 0.4, volume: 0.9),
      );

      await service.speak('Bonjour');

      expect(engine.spokenTexts, ['Bonjour']);
      expect(engine.lastLanguage, 'fr-FR');
      expect(engine.lastSpeechRate, 0.4);
      expect(engine.lastVolume, 0.9);
      expect(service.lastSpokenText, 'Bonjour');
    });

    test('speak() ignores empty or blank text', () async {
      final engine = _FakeTtsEngine();
      final service = TtsService(engine: engine);

      await service.speak('');
      await service.speak('   ');

      expect(engine.spokenTexts, isEmpty);
      expect(service.lastSpokenText, isNull);
    });

    test('speak() stays silent when muted but still remembers the text', () async {
      final engine = _FakeTtsEngine();
      final service = TtsService(
        engine: engine,
        initialSettings: const TtsSettings(muted: true),
      );

      await service.speak('Bonjour');

      expect(engine.spokenTexts, isEmpty);
      expect(service.lastSpokenText, 'Bonjour');
    });

    test('repeatLast() re-speaks the last spoken text', () async {
      final engine = _FakeTtsEngine();
      final service = TtsService(engine: engine);

      await service.speak('Bonjour');
      await service.repeatLast();

      expect(engine.spokenTexts, ['Bonjour', 'Bonjour']);
    });

    test('repeatLast() does nothing when nothing has been spoken yet', () async {
      final engine = _FakeTtsEngine();
      final service = TtsService(engine: engine);

      await service.repeatLast();

      expect(engine.spokenTexts, isEmpty);
    });

    test('setMuted(true) silences a subsequent speak() without clearing settings', () async {
      final engine = _FakeTtsEngine();
      final service = TtsService(engine: engine);

      await service.speak('Bonjour');
      service.setMuted(true);
      await service.speak('Au revoir');

      expect(engine.spokenTexts, ['Bonjour']);
      expect(service.lastSpokenText, 'Au revoir');
      expect(service.settings.muted, isTrue);
    });

    test('updateSettings() re-applies voice settings to the engine', () async {
      final engine = _FakeTtsEngine();
      final service = TtsService(engine: engine);

      await service.updateSettings(
        const TtsSettings(language: 'en-US', speechRate: 0.6, volume: 0.5, pitch: 1.2, voiceName: 'Alice'),
      );

      expect(engine.lastLanguage, 'en-US');
      expect(engine.lastSpeechRate, 0.6);
      expect(engine.lastVolume, 0.5);
      expect(engine.lastPitch, 1.2);
      expect(engine.lastVoice, (name: 'Alice', locale: 'en-US'));
    });

    test('stop() forwards to the engine', () async {
      final engine = _FakeTtsEngine();
      final service = TtsService(engine: engine);

      await service.stop();

      expect(engine.stopCount, 1);
    });
  });
}
