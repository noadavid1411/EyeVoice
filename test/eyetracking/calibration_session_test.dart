import 'package:flutter_test/flutter_test.dart';

import 'package:eyevoice/eyetracking/calibration/calibration_session.dart';
import 'package:eyevoice/eyetracking/models/gaze_point.dart';
import 'package:eyevoice/eyetracking/models/raw_gaze_sample.dart';

RawGazeSample _sample(double x, double y) => RawGazeSample(
      faceDetected: true,
      gazeVectorX: x,
      gazeVectorY: y,
      confidence: 0.9,
      timestamp: DateTime(2026, 1, 1),
    );

void main() {
  group('CalibrationSession', () {
    test('falls back to the identity profile with fewer than 3 usable points', () {
      final session = CalibrationSession();
      final point = session.startPoint(const GazePoint(0.5, 0.5));
      point.addSample(_sample(0.0, 0.0));

      final profile = session.finish();
      // Identity profile maps a raw (0,0) vector to the exact screen center.
      final mapped = profile.apply(_sample(0.0, 0.0));
      expect(mapped.dx, closeTo(0.5, 1e-9));
      expect(mapped.dy, closeTo(0.5, 1e-9));
    });

    test('recovers a simple linear mapping from 5 reference points', () {
      final session = CalibrationSession();

      // Ground truth used to generate the synthetic samples below:
      // screenX = 0.5 + 0.4 * gazeX ; screenY = 0.5 + 0.4 * gazeY.
      final targets = <GazePoint, (double, double)>{
        const GazePoint(0.5, 0.5): (0.0, 0.0),
        const GazePoint(0.1, 0.1): (-1.0, -1.0),
        const GazePoint(0.9, 0.1): (1.0, -1.0),
        const GazePoint(0.1, 0.9): (-1.0, 1.0),
        const GazePoint(0.9, 0.9): (1.0, 1.0),
      };

      for (final entry in targets.entries) {
        final point = session.startPoint(entry.key);
        final (gx, gy) = entry.value;
        // Multiple samples per point, averaged internally.
        point.addSample(_sample(gx, gy));
        point.addSample(_sample(gx, gy));
      }

      final profile = session.finish();
      final mapped = profile.apply(_sample(0.5, -0.5));
      expect(mapped.dx, closeTo(0.7, 0.02));
      expect(mapped.dy, closeTo(0.3, 0.02));
    });

    test('ignores samples where no face was detected', () {
      final session = CalibrationSession();
      final point = session.startPoint(const GazePoint(0.2, 0.2));
      point.addSample(RawGazeSample.faceLost(DateTime(2026, 1, 1)));

      expect(point.samples, isEmpty);
      expect(point.averagedGazeVector, isNull);
    });
  });
}
