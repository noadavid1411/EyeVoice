// Test de fumée de l'application "La Voix du Regard".
//
// Vérifie que l'app démarre sur l'écran d'accueil (grille 4 zones, section
// 6.2) avec ses 4 libellés attendus, sans lever d'exception.

import 'dart:async';

import 'package:eyevoice/data/settings_repository.dart';
import 'package:eyevoice/eyetracking/detection/face_gaze_detector.dart';
import 'package:eyevoice/eyetracking/models/raw_gaze_sample.dart';
import 'package:eyevoice/main.dart';
import 'package:eyevoice/ui/providers/gaze_tracking_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Détecteur inerte (n'émet jamais et ne démarre aucun `Timer`), substitué
/// au [FakeFaceGazeDetector] par défaut pour ce test de fumée : ce dernier
/// démarre un `Timer.periodic` réel dont l'annulation lors de la
/// destruction du pipeline (`GazeTrackingPipeline.dispose`, asynchrone) peut
/// ne pas être terminée avant la fin du test — non pertinent ici, ce test ne
/// vérifie que le premier rendu de l'écran d'accueil, pas le dwell time.
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

void main() {
  testWidgets('EyeVoiceApp démarre sur l\'accueil en 4 quadrants', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          faceGazeDetectorProvider.overrideWithValue(_NullFaceGazeDetector()),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const EyeVoiceApp(),
      ),
    );
    // `menuConfigProvider` (`lib/data/menu_config_repository.dart`) lit le
    // vrai asset `assets/menu-config.json` de façon asynchrone
    // (`rootBundle.loadString`) : ce test volontairement ne le surcharge pas
    // (contrairement à `test/ui/demo_home_screen_test.dart`), pour couvrir
    // aussi le chargement réel de bout en bout. `EyeVoiceApp` affiche donc
    // d'abord un écran de chargement le temps de cette lecture — un `pump`
    // supplémentaire est nécessaire pour laisser l'asset se résoudre avant
    // que l'accueil ne soit monté.
    await tester.pump();

    expect(find.text('🩺 PHYSIQUE'), findsOneWidget);
    expect(find.text('💬 CONVERSATION'), findsOneWidget);
    expect(find.text('❤️ ÉMOTIONS / ÉTAT'), findsOneWidget);
    expect(find.text('⚙️ OPTIONS'), findsOneWidget);
  });
}
