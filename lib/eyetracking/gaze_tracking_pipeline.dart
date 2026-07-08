import 'dart:async';

import 'package:eyevoice/eyetracking/calibration/calibration_session.dart';
import 'package:eyevoice/eyetracking/detection/face_gaze_detector.dart';
import 'package:eyevoice/eyetracking/dwell/dwell_time_controller.dart';
import 'package:eyevoice/eyetracking/mapping/gaze_to_screen_mapper.dart';
import 'package:eyevoice/eyetracking/mapping/zone_mapper.dart';
import 'package:eyevoice/eyetracking/models/calibration_profile.dart';
import 'package:eyevoice/eyetracking/models/eyetracking_settings.dart';
import 'package:eyevoice/eyetracking/models/gaze_state.dart';
import 'package:eyevoice/eyetracking/models/raw_gaze_sample.dart';
import 'package:eyevoice/eyetracking/models/screen_layout_mode.dart';
import 'package:eyevoice/eyetracking/signal/signal_quality_monitor.dart';

/// Point d'entrée unique de la couche `eyetracking` pour le reste de
/// l'application : consomme un [FaceGazeDetector] (détection brute) et
/// expose un flux de [GazeState] déjà résolu (zone, progression dwell,
/// confiance, statut du signal), conformément au flux fonctionnel décrit en
/// section 13.2 :
///
/// ```text
/// Caméra frontale → Détection visage/iris → Coordonnées du regard
///   → Mapping vers zone écran → Vérification zone morte
///   → Démarrage dwell time → GazeState (ce fichier)
/// ```
///
/// Rôle d'orchestration uniquement : chaque étape (mapping calibré, zones,
/// dwell, qualité de signal) reste dans sa propre classe testable
/// séparément ([GazeToScreenMapper], [ZoneMapper], [DwellTimeController],
/// [SignalQualityMonitor]) — voir section 13.1 et la contrainte "pas de
/// fonction monolithique caméra→action".
///
/// Invariant du contrat [GazeState] (documenté sur [GazeState.dwellProgress])
/// garanti structurellement ici : [DwellTimeController.update] ne renvoie
/// une progression `> 0` que pour une zone sélectionnable (non-`null`, non
/// [ScreenZone.centerDeadZone]) — voir sa doc pour le détail des règles de
/// sécurité de la section 17.1 qu'il applique.
class GazeTrackingPipeline {
  GazeTrackingPipeline({
    required FaceGazeDetector detector,
    EyeTrackingSettings settings = const EyeTrackingSettings(),
    CalibrationProfile? calibrationProfile,
  })  : _detector = detector,
        _settings = settings,
        _mapper = GazeToScreenMapper(
          profile: calibrationProfile,
          sensitivity: settings.sensitivity,
        ),
        _zoneMapper = const ZoneMapper(),
        _dwell = DwellTimeController(dwellTime: settings.dwellTime),
        _signal = SignalQualityMonitor(settings: settings);

  final FaceGazeDetector _detector;
  EyeTrackingSettings _settings;
  final GazeToScreenMapper _mapper;
  final ZoneMapper _zoneMapper;
  final DwellTimeController _dwell;
  final SignalQualityMonitor _signal;

  ScreenLayoutMode _layoutMode = ScreenLayoutMode.quadrant;
  StreamSubscription<RawGazeSample>? _subscription;
  final StreamController<GazeState> _stateController =
      StreamController<GazeState>.broadcast();

  /// Flux de [GazeState] à consommer par `ui`/`domain`. C'est la *seule*
  /// sortie que ces couches doivent observer (section 13.1) : aucune
  /// coordonnée brute, aucun type spécifique au framework de détection n'y
  /// transite.
  Stream<GazeState> get states => _stateController.stream;

  /// Disposition de zones à interpréter (grille 4 zones ou Oui/Non). À
  /// appeler par la couche appelante à chaque changement d'écran.
  ///
  /// Ajout minimal au contrat *d'entrée* de `eyetracking` (le contrat de
  /// *sortie*, [GazeState], reste inchangé) : `eyetracking` ne connaît pas
  /// le contenu de `menu-config.json` et ne peut donc pas déduire seul
  /// quelle disposition de zones est affichée. À valider avec l'architecte
  /// et l'UI avant le branchement réel (Phase 2).
  void setLayoutMode(ScreenLayoutMode mode) {
    if (_layoutMode == mode) return;
    _layoutMode = mode;
    _mapper.reset();
    _dwell.cancel();
  }

  /// Met à jour les réglages (dwell time, zone morte, sensibilité...) à
  /// chaud, ex. depuis l'écran de réglages (Phase 3, hors périmètre
  /// `eyetracking`).
  void updateSettings(EyeTrackingSettings settings) {
    _settings = settings;
    _dwell.updateDwellTime(settings.dwellTime);
    _mapper.updateSensitivity(settings.sensitivity);
    _signal.updateSettings(settings);
  }

  /// Applique un profil de calibration fraîchement calculé (voir
  /// [startCalibration]).
  void applyCalibration(CalibrationProfile profile) {
    _mapper.updateProfile(profile);
    _mapper.reset();
  }

  /// Démarre une nouvelle session de calibration (spike, section 13.2). La
  /// couche appelante pilote l'affichage des cibles et appelle
  /// [applyCalibration] avec le résultat de [CalibrationSession.finish].
  CalibrationSession startCalibration() => CalibrationSession();

  /// Démarre la détection. Ne lance jamais d'exception : un échec (caméra
  /// indisponible, permission refusée, modèle non chargé...) est traduit en
  /// [GazeState.idle] ([GazeSignalStatus.lost]) pour que l'UI puisse
  /// proposer le mode dégradé tactile/manuel (section 17.3) au lieu de
  /// bloquer ou planter l'application.
  Future<void> start() async {
    try {
      await _detector.start();
    } catch (_) {
      _stateController.add(const GazeState.idle());
      return;
    }
    _subscription = _detector.samples.listen(_onSample);
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    await _detector.stop();
    _dwell.cancel();
    _mapper.reset();
    _signal.reset();
  }

  Future<void> dispose() async {
    await stop();
    await _detector.dispose();
    await _stateController.close();
  }

  void _onSample(RawGazeSample sample) {
    final now = sample.timestamp;
    final point = _mapper.map(sample);
    final zone = point == null
        ? null
        : _zoneMapper.map(
            point,
            layout: _layoutMode,
            centerDeadZoneRatio: _settings.centerDeadZoneRatio,
          );

    final signalStatus = _signal.update(
      faceDetected: sample.faceDetected,
      zone: zone,
      now: now,
    );
    final dwellResult = _dwell.update(zone, now);

    _stateController.add(GazeState(
      zone: zone,
      dwellProgress: dwellResult.progress,
      confidence: sample.confidence,
      signalStatus: signalStatus,
    ));
  }
}
