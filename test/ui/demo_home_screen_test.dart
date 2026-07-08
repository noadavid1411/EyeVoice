import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eyevoice/eyetracking/detection/face_gaze_detector.dart';
import 'package:eyevoice/eyetracking/models/raw_gaze_sample.dart';
import 'package:eyevoice/services/tts_service.dart';
import 'package:eyevoice/ui/demo/demo_home_screen.dart';
import 'package:eyevoice/ui/providers/gaze_tracking_providers.dart';

/// Détecteur inerte : n'émet jamais d'échantillon. Utilisé à la place de
/// [FakeFaceGazeDetector] (`lib/ui/gaze/fake_face_gaze_detector.dart`) dans
/// ces tests widget pour que la navigation observée provienne uniquement du
/// mode dégradé tactile (`onTap`, section 17.3) — pas d'un dwell time
/// éventuellement déclenché par un `Timer` réel pendant le test.
class _NullFaceGazeDetector implements FaceGazeDetector {
  final _controller = StreamController<RawGazeSample>.broadcast();

  @override
  Stream<RawGazeSample> get samples => _controller.stream;
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

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

void main() {
  testWidgets(
    'appui tactile (mode dégradé) déclenche une navigation effective via le vrai ActionResolver',
    (tester) async {
      final engine = _FakeTtsEngine();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ttsServiceProvider.overrideWithValue(TtsService(engine: engine)),
            faceGazeDetectorProvider.overrideWithValue(_NullFaceGazeDetector()),
          ],
          child: const MaterialApp(home: DemoHomeScreen()),
        ),
      );
      await tester.pump();

      expect(find.text('🩺 PHYSIQUE'), findsOneWidget);

      await tester.tap(find.text('🩺 PHYSIQUE'));
      await tester.pump();

      // Écran réellement résolu par l'ActionResolver (titre de l'écran
      // 'physical' dans sampleMenuConfig), pas un aiguillage local.
      expect(find.text('Physique'), findsOneWidget);
      expect(find.text('J’ai soif / faim'), findsOneWidget);
    },
  );

  testWidgets(
    'un item speak appelle le vrai TtsService et affiche la phrase prononcée',
    (tester) async {
      final engine = _FakeTtsEngine();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ttsServiceProvider.overrideWithValue(TtsService(engine: engine)),
            faceGazeDetectorProvider.overrideWithValue(_NullFaceGazeDetector()),
          ],
          child: const MaterialApp(home: DemoHomeScreen()),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('🩺 PHYSIQUE'));
      await tester.pump();
      await tester.tap(find.text('J’ai soif / faim'));
      await tester.pump();

      expect(engine.spokenTexts, ['J’ai soif ou faim.']);
      expect(find.textContaining('J’ai soif ou faim.'), findsOneWidget);
    },
  );

  testWidgets(
    'openMode(yesNo) affiche le vrai YesNoScreen, et onExit revient à l\'écran grid-4 précédent',
    (tester) async {
      final engine = _FakeTtsEngine();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ttsServiceProvider.overrideWithValue(TtsService(engine: engine)),
            faceGazeDetectorProvider.overrideWithValue(_NullFaceGazeDetector()),
          ],
          child: const MaterialApp(home: DemoHomeScreen()),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('⚙️ OPTIONS'));
      await tester.pump();
      await tester.tap(find.text('Mode Oui / Non'));
      await tester.pump();

      expect(find.text('OUI'), findsOneWidget);
      expect(find.text('NON'), findsOneWidget);

      await tester.tap(find.text('OUI'));
      await tester.pump();
      expect(engine.spokenTexts, ['Oui.']);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();

      expect(find.text('Options'), findsOneWidget);
    },
  );
}
