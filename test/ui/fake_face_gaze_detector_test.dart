import 'package:flutter_test/flutter_test.dart';

import 'package:eyevoice/core/models/screen_zone.dart';
import 'package:eyevoice/eyetracking/gaze_tracking_pipeline.dart';
import 'package:eyevoice/eyetracking/models/eyetracking_settings.dart';
import 'package:eyevoice/eyetracking/models/gaze_state.dart';
import 'package:eyevoice/ui/gaze/fake_face_gaze_detector.dart';

/// Vérifie que [FakeFaceGazeDetector] — le détecteur de secours sans caméra
/// utilisé par `faceGazeDetectorProvider` en l'absence de matériel — produit
/// bien un flux de [RawGazeSample] exploitable par le **vrai**
/// [GazeTrackingPipeline] (mapping calibré, zones, dwell time réels, pas
/// une resimulation ad-hoc de `GazeState`).
///
/// Utilise des durées très courtes (par rapport aux valeurs par défaut de
/// production) pour que ce test tourne vite, en s'appuyant sur de vrais
/// `Timer`/`DateTime.now()` plutôt que sur `FakeAsync` (le pipeline s'appuie
/// sur des horodatages réels, pas sur `package:clock`).
void main() {
  test('le flux GazeState réel finit par valider une zone (dwellProgress == 1.0)', () async {
    final detector = FakeFaceGazeDetector(
      tickInterval: const Duration(milliseconds: 5),
      holdDuration: const Duration(milliseconds: 60),
      pauseDuration: const Duration(milliseconds: 10),
    );
    final pipeline = GazeTrackingPipeline(
      detector: detector,
      settings: const EyeTrackingSettings(dwellTime: Duration(milliseconds: 30)),
    );
    addTearDown(pipeline.dispose);

    await pipeline.start();

    final validated = await pipeline.states
        .firstWhere((s) => s.dwellProgress >= 1.0)
        .timeout(const Duration(seconds: 5));

    expect(validated.zone, isNotNull);
    expect(validated.zone, isNot(ScreenZone.centerDeadZone));
    expect(validated.signalStatus, isNot(GazeSignalStatus.lost));
  });
}
