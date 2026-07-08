import 'package:flutter_test/flutter_test.dart';

import 'package:eyevoice/core/models/screen_zone.dart';
import 'package:eyevoice/eyetracking/models/eyetracking_settings.dart';
import 'package:eyevoice/eyetracking/models/gaze_state.dart';
import 'package:eyevoice/eyetracking/signal/signal_quality_monitor.dart';

/// Tests pour [SignalQualityMonitor] (section 17.1 "plusieurs zones sont
/// détectées de manière instable" + section 17.3 "mode dégradé").
///
/// Ce composant n'avait aucune couverture de test avant l'audit QA de la
/// Phase 4, alors qu'il pilote directement la bascule vers le mode dégradé
/// tactile/manuel — un comportement de sécurité d'usage (section 17). Les
/// scénarios ci-dessous couvrent : l'état stable, la perte de visage
/// (immédiate et progressive), l'instabilité par alternance de zones, le
/// nettoyage de la fenêtre glissante, `reset()` et `updateSettings()`.
void main() {
  final base = DateTime(2026, 1, 1, 12, 0, 0);

  const settings = EyeTrackingSettings(
    faceLostThreshold: Duration(milliseconds: 1500),
    instabilityWindow: Duration(milliseconds: 1000),
    instabilityZoneChangeThreshold: 3,
  );

  group('SignalQualityMonitor — visage détecté, zone stable', () {
    test('reste ok tant que le visage est détecté et la zone stable', () {
      final monitor = SignalQualityMonitor(settings: settings);

      final first = monitor.update(faceDetected: true, zone: ScreenZone.topLeft, now: base);
      expect(first, GazeSignalStatus.ok);

      final second = monitor.update(
        faceDetected: true,
        zone: ScreenZone.topLeft,
        now: base.add(const Duration(milliseconds: 200)),
      );
      expect(second, GazeSignalStatus.ok);
    });

    test('une zone null (transition) avec visage détecté ne déclenche pas "lost"', () {
      final monitor = SignalQualityMonitor(settings: settings);

      monitor.update(faceDetected: true, zone: ScreenZone.topLeft, now: base);
      final result = monitor.update(
        faceDetected: true,
        zone: null,
        now: base.add(const Duration(milliseconds: 100)),
      );

      expect(result, isNot(GazeSignalStatus.lost));
    });
  });

  group('SignalQualityMonitor — perte de visage (section 17.3)', () {
    test('visage jamais détecté => lost dès le premier échantillon', () {
      final monitor = SignalQualityMonitor(settings: settings);

      final result = monitor.update(faceDetected: false, zone: null, now: base);

      expect(result, GazeSignalStatus.lost);
    });

    test('brève perte de visage sous le seuil reste ok', () {
      final monitor = SignalQualityMonitor(settings: settings);
      monitor.update(faceDetected: true, zone: ScreenZone.topLeft, now: base);

      final result = monitor.update(
        faceDetected: false,
        zone: null,
        now: base.add(const Duration(milliseconds: 500)),
      );

      expect(result, GazeSignalStatus.ok);
    });

    test('perte de visage prolongée au-delà du seuil bascule en lost', () {
      final monitor = SignalQualityMonitor(settings: settings);
      monitor.update(faceDetected: true, zone: ScreenZone.topLeft, now: base);

      final result = monitor.update(
        faceDetected: false,
        zone: null,
        now: base.add(const Duration(milliseconds: 1600)),
      );

      expect(result, GazeSignalStatus.lost);
    });

    test('le visage redétecté après une perte fait revenir à ok', () {
      final monitor = SignalQualityMonitor(settings: settings);
      monitor.update(faceDetected: true, zone: ScreenZone.topLeft, now: base);
      monitor.update(
        faceDetected: false,
        zone: null,
        now: base.add(const Duration(milliseconds: 1600)),
      );

      final result = monitor.update(
        faceDetected: true,
        zone: ScreenZone.topLeft,
        now: base.add(const Duration(milliseconds: 1700)),
      );

      expect(result, GazeSignalStatus.ok);
    });
  });

  group('SignalQualityMonitor — instabilité de zone (section 17.1)', () {
    test('une alternance rapide de zones au-delà du seuil devient degraded', () {
      final monitor = SignalQualityMonitor(settings: settings);

      monitor.update(faceDetected: true, zone: ScreenZone.topLeft, now: base);
      monitor.update(
        faceDetected: true,
        zone: ScreenZone.topRight,
        now: base.add(const Duration(milliseconds: 100)),
      );
      monitor.update(
        faceDetected: true,
        zone: ScreenZone.topLeft,
        now: base.add(const Duration(milliseconds: 200)),
      );
      // 4e changement de zone dans la fenêtre de 1000 ms : dépasse le seuil
      // (instabilityZoneChangeThreshold: 3), donc degraded.
      final result = monitor.update(
        faceDetected: true,
        zone: ScreenZone.topRight,
        now: base.add(const Duration(milliseconds: 300)),
      );

      expect(result, GazeSignalStatus.degraded);
    });

    test('rester fixé sur la même zone ne compte pas comme un changement', () {
      final monitor = SignalQualityMonitor(settings: settings);

      monitor.update(faceDetected: true, zone: ScreenZone.topLeft, now: base);
      for (var i = 1; i <= 5; i++) {
        final result = monitor.update(
          faceDetected: true,
          zone: ScreenZone.topLeft,
          now: base.add(Duration(milliseconds: 100 * i)),
        );
        expect(result, GazeSignalStatus.ok, reason: 'itération $i');
      }
    });

    test('les changements de zone sortis de la fenêtre glissante sont oubliés', () {
      final monitor = SignalQualityMonitor(settings: settings);

      monitor.update(faceDetected: true, zone: ScreenZone.topLeft, now: base);
      monitor.update(
        faceDetected: true,
        zone: ScreenZone.topRight,
        now: base.add(const Duration(milliseconds: 100)),
      );
      monitor.update(
        faceDetected: true,
        zone: ScreenZone.topLeft,
        now: base.add(const Duration(milliseconds: 200)),
      );
      final degraded = monitor.update(
        faceDetected: true,
        zone: ScreenZone.topRight,
        now: base.add(const Duration(milliseconds: 300)),
      );
      expect(degraded, GazeSignalStatus.degraded);

      // Longtemps après (> instabilityWindow), en restant fixé sur la même
      // zone : les anciens changements sortent de la fenêtre glissante et le
      // statut redevient ok, sans appel explicite à reset().
      final recovered = monitor.update(
        faceDetected: true,
        zone: ScreenZone.topRight,
        now: base.add(const Duration(milliseconds: 1400)),
      );
      expect(recovered, GazeSignalStatus.ok);
    });
  });

  group('SignalQualityMonitor — reset()', () {
    test('reset() efface l\'historique de détection de visage et de zones', () {
      final monitor = SignalQualityMonitor(settings: settings);
      monitor.update(faceDetected: true, zone: ScreenZone.topLeft, now: base);
      monitor.update(
        faceDetected: false,
        zone: null,
        now: base.add(const Duration(milliseconds: 1600)),
      );

      monitor.reset();

      // Après reset, le monitor se comporte comme une instance neuve : un
      // visage jamais détecté (aucun `_lastFaceDetectedAt`) redonne "lost"
      // immédiatement en cas d'absence de visage...
      final stillNoFace = monitor.update(
        faceDetected: false,
        zone: null,
        now: base.add(const Duration(milliseconds: 1650)),
      );
      expect(stillNoFace, GazeSignalStatus.lost);

      // ...et un visage à nouveau détecté redevient immédiatement ok, comme
      // pour un tout premier échantillon (pas de résidu de l'historique
      // d'instabilité précédent).
      final backToOk = monitor.update(
        faceDetected: true,
        zone: ScreenZone.topLeft,
        now: base.add(const Duration(milliseconds: 1700)),
      );
      expect(backToOk, GazeSignalStatus.ok);
    });
  });

  group('SignalQualityMonitor — updateSettings()', () {
    test('un seuil de perte de visage réduit à chaud s\'applique aux échantillons suivants', () {
      final monitor = SignalQualityMonitor(settings: settings);
      monitor.update(faceDetected: true, zone: ScreenZone.topLeft, now: base);

      // Avec le seuil par défaut (1500 ms), 600 ms d'absence resteraient ok.
      final beforeUpdate = monitor.update(
        faceDetected: false,
        zone: null,
        now: base.add(const Duration(milliseconds: 600)),
      );
      expect(beforeUpdate, GazeSignalStatus.ok);

      monitor.updateSettings(settings.copyWith(faceLostThreshold: const Duration(milliseconds: 200)));

      final afterUpdate = monitor.update(
        faceDetected: false,
        zone: null,
        now: base.add(const Duration(milliseconds: 900)),
      );
      expect(afterUpdate, GazeSignalStatus.lost);
    });
  });
}
