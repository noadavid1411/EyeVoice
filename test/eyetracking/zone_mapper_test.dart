import 'package:flutter_test/flutter_test.dart';

import 'package:eyevoice/core/models/screen_zone.dart';
import 'package:eyevoice/eyetracking/mapping/zone_mapper.dart';
import 'package:eyevoice/eyetracking/models/gaze_point.dart';
import 'package:eyevoice/eyetracking/models/screen_layout_mode.dart';

void main() {
  const mapper = ZoneMapper();

  group('ZoneMapper — quadrant layout', () {
    test('maps each corner to its quadrant', () {
      expect(
        mapper.map(const GazePoint(0.1, 0.1), layout: ScreenLayoutMode.quadrant, centerDeadZoneRatio: 0.2),
        ScreenZone.topLeft,
      );
      expect(
        mapper.map(const GazePoint(0.9, 0.1), layout: ScreenLayoutMode.quadrant, centerDeadZoneRatio: 0.2),
        ScreenZone.topRight,
      );
      expect(
        mapper.map(const GazePoint(0.1, 0.9), layout: ScreenLayoutMode.quadrant, centerDeadZoneRatio: 0.2),
        ScreenZone.bottomLeft,
      );
      expect(
        mapper.map(const GazePoint(0.9, 0.9), layout: ScreenLayoutMode.quadrant, centerDeadZoneRatio: 0.2),
        ScreenZone.bottomRight,
      );
    });

    test('maps the exact screen center to the dead zone (section 4.3)', () {
      expect(
        mapper.map(const GazePoint(0.5, 0.5), layout: ScreenLayoutMode.quadrant, centerDeadZoneRatio: 0.2),
        ScreenZone.centerDeadZone,
      );
    });

    test('dead zone size respects the configured ratio', () {
      // With a 20% ratio, the dead zone spans [0.4, 0.6] on each axis.
      const ratio = 0.2;
      expect(
        mapper.map(const GazePoint(0.45, 0.5), layout: ScreenLayoutMode.quadrant, centerDeadZoneRatio: ratio),
        ScreenZone.centerDeadZone,
      );
      // dy = 0.3 is unambiguously in the top half (dy = 0.5 would sit exactly
      // on the quadrant boundary and isn't a useful assertion here).
      expect(
        mapper.map(const GazePoint(0.39, 0.3), layout: ScreenLayoutMode.quadrant, centerDeadZoneRatio: ratio),
        ScreenZone.topLeft,
      );
    });

    test('a larger centerDeadZoneRatio grows the dead zone (configurability, section 16)', () {
      // Offsets from center: dx = 0.08, dy = 0.05. At ratio 0.15 (half-size
      // 0.075) the dx offset alone falls outside the dead zone; at ratio 0.25
      // (half-size 0.125) both offsets fall inside it.
      const point = GazePoint(0.42, 0.45);
      expect(
        mapper.map(point, layout: ScreenLayoutMode.quadrant, centerDeadZoneRatio: 0.15),
        isNot(ScreenZone.centerDeadZone),
      );
      expect(
        mapper.map(point, layout: ScreenLayoutMode.quadrant, centerDeadZoneRatio: 0.25),
        ScreenZone.centerDeadZone,
      );
    });
  });

  group('ZoneMapper — yes/no layout (section 5.2)', () {
    test('left half maps to left, right half maps to right', () {
      expect(
        mapper.map(const GazePoint(0.1, 0.5), layout: ScreenLayoutMode.yesNo, centerDeadZoneRatio: 0.2),
        ScreenZone.left,
      );
      expect(
        mapper.map(const GazePoint(0.9, 0.5), layout: ScreenLayoutMode.yesNo, centerDeadZoneRatio: 0.2),
        ScreenZone.right,
      );
    });

    test('has no dead zone: the yes/no mode always resolves to a side', () {
      expect(
        mapper.map(const GazePoint(0.5, 0.5), layout: ScreenLayoutMode.yesNo, centerDeadZoneRatio: 0.2),
        ScreenZone.right,
      );
    });
  });
}
