import 'package:flutter_test/flutter_test.dart';

import 'package:eyevoice/core/models/screen_zone.dart';
import 'package:eyevoice/eyetracking/dwell/dwell_time_controller.dart';

void main() {
  final base = DateTime(2026, 1, 1, 12, 0, 0);

  group('DwellTimeController', () {
    test('progresses from 0 to 1 over the configured dwell time', () {
      final controller = DwellTimeController(dwellTime: const Duration(milliseconds: 1000));

      final start = controller.update(ScreenZone.topLeft, base);
      expect(start.progress, 0.0);
      expect(start.justValidated, isFalse);

      final mid = controller.update(ScreenZone.topLeft, base.add(const Duration(milliseconds: 500)));
      expect(mid.progress, closeTo(0.5, 0.01));
      expect(mid.justValidated, isFalse);

      final done = controller.update(ScreenZone.topLeft, base.add(const Duration(milliseconds: 1000)));
      expect(done.progress, 1.0);
      expect(done.justValidated, isTrue);
    });

    test('resets progress when the gazed zone changes (section 17.1)', () {
      final controller = DwellTimeController(dwellTime: const Duration(milliseconds: 1000));

      controller.update(ScreenZone.topLeft, base);
      controller.update(ScreenZone.topLeft, base.add(const Duration(milliseconds: 700)));

      final switched = controller.update(ScreenZone.topRight, base.add(const Duration(milliseconds: 750)));
      expect(switched.progress, 0.0);

      // Progress for the new zone restarts from zero, not from where the
      // previous zone left off.
      final afterSwitch = controller.update(
        ScreenZone.topRight,
        base.add(const Duration(milliseconds: 950)),
      );
      expect(afterSwitch.progress, closeTo(0.2, 0.01));
    });

    test('resets progress when the zone becomes null (face lost)', () {
      final controller = DwellTimeController(dwellTime: const Duration(milliseconds: 1000));

      controller.update(ScreenZone.bottomLeft, base);
      controller.update(ScreenZone.bottomLeft, base.add(const Duration(milliseconds: 800)));

      final lost = controller.update(null, base.add(const Duration(milliseconds: 850)));
      expect(lost.progress, 0.0);
      expect(lost.justValidated, isFalse);
    });

    test('never progresses while gazing at the center dead zone (section 4.3)', () {
      final controller = DwellTimeController(dwellTime: const Duration(milliseconds: 1000));

      final result = controller.update(ScreenZone.centerDeadZone, base);
      expect(result.progress, 0.0);

      final later = controller.update(
        ScreenZone.centerDeadZone,
        base.add(const Duration(milliseconds: 2000)),
      );
      expect(later.progress, 0.0);
      expect(later.justValidated, isFalse);
    });

    test('holds at 1.0 without re-validating while the same zone stays fixated', () {
      final controller = DwellTimeController(dwellTime: const Duration(milliseconds: 1000));

      controller.update(ScreenZone.topRight, base);
      final firstValidation = controller.update(
        ScreenZone.topRight,
        base.add(const Duration(milliseconds: 1000)),
      );
      expect(firstValidation.justValidated, isTrue);

      final stillFixated = controller.update(
        ScreenZone.topRight,
        base.add(const Duration(milliseconds: 1500)),
      );
      expect(stillFixated.progress, 1.0);
      expect(stillFixated.justValidated, isFalse);
    });

    test('re-fires once the patient looks away and refixates the zone', () {
      final controller = DwellTimeController(dwellTime: const Duration(milliseconds: 1000));

      controller.update(ScreenZone.topRight, base);
      controller.update(ScreenZone.topRight, base.add(const Duration(milliseconds: 1000)));

      controller.update(null, base.add(const Duration(milliseconds: 1200)));

      controller.update(ScreenZone.topRight, base.add(const Duration(milliseconds: 1300)));
      final revalidated = controller.update(
        ScreenZone.topRight,
        base.add(const Duration(milliseconds: 2300)),
      );
      expect(revalidated.justValidated, isTrue);
    });

    test('updateDwellTime changes the effective duration for subsequent ticks', () {
      final controller = DwellTimeController(dwellTime: const Duration(milliseconds: 1000));
      controller.update(ScreenZone.topLeft, base);
      controller.updateDwellTime(const Duration(milliseconds: 500));

      final result = controller.update(ScreenZone.topLeft, base.add(const Duration(milliseconds: 500)));
      expect(result.progress, 1.0);
      expect(result.justValidated, isTrue);
    });
  });
}
