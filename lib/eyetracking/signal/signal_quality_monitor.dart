import 'package:eyevoice/core/models/screen_zone.dart';
import 'package:eyevoice/eyetracking/models/eyetracking_settings.dart';
import 'package:eyevoice/eyetracking/models/gaze_state.dart';

/// Calcule [GazeSignalStatus] à partir de l'historique récent de détection
/// (section 17.1 "plusieurs zones détectées de manière instable" + section
/// 17.3 mode dégradé).
///
/// Étape isolée de `DwellTimeController` : le dwell se réinitialise dès
/// qu'une zone change, peu importe la cause (section 17.1), alors que
/// [GazeSignalStatus] a une sémantique différente et plus tolérante — un
/// statut [GazeSignalStatus.degraded] ne bascule pas immédiatement en mode
/// tactile, seul un [GazeSignalStatus.lost] prolongé le fait (voir la
/// documentation de [GazeSignalStatus]).
class SignalQualityMonitor {
  SignalQualityMonitor({required EyeTrackingSettings settings}) : _settings = settings;

  EyeTrackingSettings _settings;
  DateTime? _lastFaceDetectedAt;
  final List<DateTime> _recentZoneChanges = [];
  ScreenZone? _lastZone;
  bool _sawFirstZone = false;

  void updateSettings(EyeTrackingSettings settings) => _settings = settings;

  /// Met à jour l'état à partir du dernier échantillon (au temps [now]) et
  /// retourne le [GazeSignalStatus] courant.
  GazeSignalStatus update({
    required bool faceDetected,
    required ScreenZone? zone,
    required DateTime now,
  }) {
    if (faceDetected) {
      _lastFaceDetectedAt = now;
    }

    if (!_sawFirstZone || zone != _lastZone) {
      _recentZoneChanges.add(now);
      _lastZone = zone;
      _sawFirstZone = true;
    }
    _recentZoneChanges.removeWhere((t) => now.difference(t) > _settings.instabilityWindow);

    final lastSeen = _lastFaceDetectedAt;
    if (!faceDetected) {
      final faceLostFor = lastSeen == null ? null : now.difference(lastSeen);
      if (lastSeen == null || faceLostFor! >= _settings.faceLostThreshold) {
        return GazeSignalStatus.lost;
      }
    }

    if (_recentZoneChanges.length > _settings.instabilityZoneChangeThreshold) {
      return GazeSignalStatus.degraded;
    }

    return GazeSignalStatus.ok;
  }

  void reset() {
    _lastFaceDetectedAt = null;
    _recentZoneChanges.clear();
    _lastZone = null;
    _sawFirstZone = false;
  }
}
