import 'dart:async';

import 'package:eyevoice/eyetracking/detection/face_gaze_detector.dart';
import 'package:eyevoice/eyetracking/models/raw_gaze_sample.dart';

/// Implémentation de secours de [FaceGazeDetector], **sans aucun accès
/// caméra**, utilisée quand le vrai `FaceMeshGazeDetector`
/// (`lib/eyetracking/detection/face_mesh_gaze_detector.dart`) ne peut pas
/// tourner — pas de caméra/permission, environnement de développement
/// sandbox — afin que l'application reste démontrable et testable de bout
/// en bout sans matériel.
///
/// Différence clé avec l'ancienne simulation ad-hoc du widget de démo
/// (Phase 1c) : celle-ci fabriquait directement un `GazeState` local dans
/// `DemoHomeScreen`, court-circuitant tout le pipeline `eyetracking` réel.
/// [FakeFaceGazeDetector] ne simule que les étapes 1-2 de la section 13.2
/// (détection brute) : il produit un flux de [RawGazeSample] plausible qui
/// traverse ensuite le **vrai** `GazeTrackingPipeline` (mapping calibré,
/// zones, dwell time, qualité de signal — voir
/// `lib/eyetracking/gaze_tracking_pipeline.dart`). C'est la seule brique à
/// remplacer par `FaceMeshGazeDetector` (via `faceGazeDetectorProvider`,
/// `lib/ui/providers/gaze_tracking_providers.dart`) pour un déploiement sur
/// un appareil avec caméra frontale — le reste de l'architecture de
/// branchement (Riverpod → pipeline réel → `GazeState`) ne change pas.
///
/// Comportement simulé : balaie cycliquement les 4 coins de l'écran (assez
/// écartés pour couvrir aussi bien la grille 4 zones que le mode Oui/Non,
/// qui ne regarde que l'axe horizontal — voir `ZoneMapper`), avec un passage
/// par le centre entre deux cibles pour illustrer que la zone morte centrale
/// ne déclenche jamais de sélection (section 4.3).
class FakeFaceGazeDetector implements FaceGazeDetector {
  FakeFaceGazeDetector({
    this.tickInterval = const Duration(milliseconds: 40),
    this.holdDuration = const Duration(milliseconds: 1800),
    this.pauseDuration = const Duration(milliseconds: 500),
  });

  /// Cadence d'émission des échantillons simulés (ordre de grandeur d'une
  /// caméra à ~25 fps).
  final Duration tickInterval;

  /// Durée de fixation simulée sur chaque cible : volontairement plus
  /// longue que le dwell time par défaut (`AppDefaults.dwellTime`, 1,3 s)
  /// pour laisser le temps au lissage EMA de `GazeToScreenMapper` de
  /// converger avant la fin de la fixation.
  final Duration holdDuration;

  /// Durée du passage par le centre (zone morte) entre deux cibles.
  final Duration pauseDuration;

  /// Décalages `(x, y)` de regard brut simulés, dans la même convention que
  /// celle attendue par `CalibrationProfile.identity()` (`[-1, 1]`, centré
  /// sur `0`). `±0.6` projette, une fois le profil identité appliqué, vers
  /// les quadrants haut-gauche/haut-droite/bas-gauche/bas-droite (section
  /// 4.1) sans être clampé.
  static const List<(double, double)> _targets = [
    (-0.6, -0.6),
    (0.6, -0.6),
    (-0.6, 0.6),
    (0.6, 0.6),
  ];

  final StreamController<RawGazeSample> _controller =
      StreamController<RawGazeSample>.broadcast();
  Timer? _timer;
  int _targetIndex = 0;
  bool _inPause = false;
  Duration _elapsedInStep = Duration.zero;

  @override
  Stream<RawGazeSample> get samples => _controller.stream;

  @override
  Future<void> start() async {
    _timer?.cancel();
    _targetIndex = 0;
    _inPause = false;
    _elapsedInStep = Duration.zero;
    _timer = Timer.periodic(tickInterval, (_) => _tick());
  }

  void _tick() {
    if (_controller.isClosed) return;
    _elapsedInStep += tickInterval;

    if (_inPause) {
      _emit(0.0, 0.0);
      if (_elapsedInStep >= pauseDuration) {
        _inPause = false;
        _elapsedInStep = Duration.zero;
        _targetIndex = (_targetIndex + 1) % _targets.length;
      }
      return;
    }

    final target = _targets[_targetIndex];
    _emit(target.$1, target.$2);
    if (_elapsedInStep >= holdDuration) {
      _inPause = true;
      _elapsedInStep = Duration.zero;
    }
  }

  void _emit(double x, double y) {
    _controller.add(RawGazeSample(
      faceDetected: true,
      gazeVectorX: x,
      gazeVectorY: y,
      confidence: 1.0,
      timestamp: DateTime.now(),
    ));
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Future<void> dispose() async {
    await stop();
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }
}
