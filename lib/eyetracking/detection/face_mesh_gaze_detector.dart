import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:mediapipe_face_mesh/mediapipe_face_mesh.dart';

import 'package:eyevoice/eyetracking/detection/face_gaze_detector.dart';
import 'package:eyevoice/eyetracking/models/raw_gaze_sample.dart';

/// Implémentation de [FaceGazeDetector] adossée au package
/// `mediapipe_face_mesh` (modèles MediaPipe Face Mesh + Iris via un plugin
/// FFI classique — décision documentée dans `pubspec.yaml`, section
/// "Eye-tracking") et au flux caméra du package `camera`.
///
/// Responsabilité unique de ce fichier : transformer un flux `CameraImage`
/// en [RawGazeSample]. Toute la logique de calibration/mapping écran, zones
/// et dwell time vit dans d'autres fichiers de `eyetracking` qui n'importent
/// jamais `camera` ni `mediapipe_face_mesh` (section 13.1) — c'est le seul
/// fichier du pipeline qui connaît le framework de détection.
///
/// Stratégie d'estimation du regard (spike, à affiner en Phase 2/3 avec de
/// vrais patients) : décalage normalisé `[-1, 1]` du centre de l'iris par
/// rapport au centre de la boîte englobante des points de contour de
/// l'oeil, moyenné sur les deux yeux. `mediapipe_face_mesh` n'expose pas
/// d'angle de tête tout fait (contrairement à d'autres bibliothèques
/// équivalentes) : contrairement à `FaceDetectionTfliteGazeDetector`
/// initialement envisagé, ce détecteur ne combine donc pas d'indice de pose
/// de tête. Un patient de réanimation bougeant peu la tête (section 3.3 :
/// appareil fixe face au patient), l'indice iris seul est un point de
/// départ raisonnable ; l'essentiel de l'erreur d'échelle/décalage est de
/// toute façon absorbé par `CalibrationSession` en aval.
class FaceMeshGazeDetector implements FaceGazeDetector {
  FaceMeshGazeDetector({
    this.resolutionPreset = ResolutionPreset.medium,
    this.deviceOrientation = DeviceOrientation.portraitUp,
  });

  final ResolutionPreset resolutionPreset;

  /// Orientation supposée de l'appareil. Le patient cible (section 3.3) est
  /// installé face à une tablette fixe : on ne gère pas la rotation
  /// dynamique en Phase 1b (pas de lecture d'accéléromètre), seulement ce
  /// réglage explicite. Un raffinement futur pourra le brancher sur un
  /// capteur d'orientation si le besoin se confirme.
  final DeviceOrientation deviceOrientation;

  /// Points de contour utilisés pour délimiter chaque oeil (topologie
  /// MediaPipe Face Mesh à 468 points, indices canoniques — communs à toutes
  /// les bibliothèques implémentant ce modèle).
  static const List<int> _leftEyeIndices = [
    263, 466, 388, 387, 386, 385, 384, 398, //
    362, 382, 381, 380, 374, 373, 390, 249,
  ];
  static const List<int> _rightEyeIndices = [
    33, 246, 161, 160, 159, 158, 157, 173, //
    133, 155, 154, 153, 145, 144, 163, 7,
  ];

  /// Index des centres d'iris quand `enableIris: true` (478 landmarks au
  /// total : 0-467 mesh de base, 468-472 iris gauche, 473-477 iris droit —
  /// convention MediaPipe Iris standard).
  static const int _leftIrisCenterIndex = 468;
  static const int _rightIrisCenterIndex = 473;
  static const int _landmarkCountWithIris = 478;

  CameraController? _cameraController;
  FaceMeshProcessor? _faceMeshProcessor;
  final StreamController<RawGazeSample> _sampleController =
      StreamController<RawGazeSample>.broadcast();
  bool _busy = false;

  @override
  Stream<RawGazeSample> get samples => _sampleController.stream;

  @override
  Future<void> start() async {
    await _teardownCameraAndDetector();

    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    final processor = await FaceMeshProcessor.create(enableIris: true);
    _faceMeshProcessor = processor;

    final controller = CameraController(
      frontCamera,
      resolutionPreset,
      enableAudio: false,
    );
    await controller.initialize();
    _cameraController = controller;

    await controller.startImageStream(_onFrame);
  }

  Future<void> _onFrame(CameraImage image) async {
    final processor = _faceMeshProcessor;
    final controller = _cameraController;
    // Laisse tomber la frame si l'inférence précédente n'est pas terminée :
    // la caméra livre les images plus vite que l'inférence (synchrone, FFI)
    // ne les consomme, mieux vaut une cadence de sortie réduite qu'une file
    // qui s'accumule et fait dériver la latence. Une isolation sur isolate
    // dédié est une optimisation possible en Phase 2 si le thread UI en
    // souffre.
    if (processor == null || controller == null || _busy) return;
    _busy = true;
    try {
      final nv21 = _toNv21(image);
      if (nv21 == null) {
        _sampleController.add(RawGazeSample.faceLost(DateTime.now()));
        return;
      }

      final rotation = _rotationDegreesFor(controller.description.sensorOrientation);
      final result = processor.processNv21(nv21, rotationDegrees: rotation);
      _sampleController.add(_toSample(result));
    } catch (_) {
      // Une erreur d'inférence ponctuelle ne doit jamais faire planter le
      // pipeline (contrainte "pas de crash", section 17.3) : elle est
      // traduite en échantillon "visage non détecté", laissant
      // SignalQualityMonitor gérer la dégradation si elle persiste.
      _sampleController.add(RawGazeSample.faceLost(DateTime.now()));
    } finally {
      _busy = false;
    }
  }

  /// Convertit une frame `CameraImage` en image NV21 attendue par
  /// `mediapipe_face_mesh`. Gère les deux formes usuelles livrées par le
  /// package `camera` : 3 plans séparés Y/U/V (Android, YUV420) ou 2 plans
  /// Y + chroma entrelacé (iOS, bi-planaire 4:2:0).
  ///
  /// Sur iOS, l'ordre de chrominance natif (CbCr, "UV") est réutilisé tel
  /// quel comme "VU" attendu par NV21 — inversion non corrigée pour ce
  /// spike (section 20.1/20.2 : à affiner avec des tests sur appareil réel).
  /// Cette approximation affecte la normalisation colorimétrique interne du
  /// modèle, pas la géométrie des landmarks, qui reste la donnée exploitée
  /// ici.
  FaceMeshNv21Image? _toNv21(CameraImage image) {
    if (image.planes.length >= 3) {
      return FaceMeshNv21Image.tryFromYuv420Planes(
        width: image.width,
        height: image.height,
        yPlane: _toPlane(image.planes[0]),
        uPlane: _toPlane(image.planes[1]),
        vPlane: _toPlane(image.planes[2]),
      );
    }
    if (image.planes.length == 2) {
      return FaceMeshNv21Image.tryFromYAndInterleavedVuPlanes(
        width: image.width,
        height: image.height,
        yPlane: _toPlane(image.planes[0]),
        vuPlane: _toPlane(image.planes[1]),
      );
    }
    return null;
  }

  FaceMeshImagePlane _toPlane(Plane plane) => FaceMeshImagePlane(
        bytes: plane.bytes,
        bytesPerRow: plane.bytesPerRow,
        bytesPerPixel: plane.bytesPerPixel,
      );

  /// Rotation à appliquer pour présenter la frame droite au modèle,
  /// équivalente en substance à l'algorithme documenté par les bibliothèques
  /// de MediaPipe pour la caméra frontale Android (formule symétrique par
  /// rapport à la caméra arrière). Sur iOS, `camera` pré-tourne déjà le flux
  /// pour une utilisation portrait fixe (section 3.3) : aucune rotation
  /// supplémentaire n'est appliquée.
  int _rotationDegreesFor(int sensorOrientation) {
    if (Platform.isIOS) return 0;
    if (!Platform.isAndroid) return 0;

    final deviceRotation = switch (deviceOrientation) {
      DeviceOrientation.portraitUp => 0,
      DeviceOrientation.landscapeLeft => 90,
      DeviceOrientation.portraitDown => 180,
      DeviceOrientation.landscapeRight => 270,
    };
    return (sensorOrientation + deviceRotation) % 360;
  }

  RawGazeSample _toSample(FaceMeshResult result) {
    final now = DateTime.now();
    if (result.landmarks.isEmpty) {
      return RawGazeSample.faceLost(now);
    }

    final gazeVector = _irisOffset(result.landmarks);
    if (gazeVector == null) {
      // Visage détecté mais aucun repère d'iris exploitable (yeux fermés,
      // mesh incomplet) : on reporte un visage détecté avec confiance
      // réduite plutôt que de traiter l'échantillon comme une perte totale
      // de signal — laisse SignalQualityMonitor décider si ça persiste.
      return RawGazeSample(
        faceDetected: true,
        gazeVectorX: 0.0,
        gazeVectorY: 0.0,
        confidence: result.score * 0.3,
        timestamp: now,
      );
    }

    return RawGazeSample(
      faceDetected: true,
      gazeVectorX: gazeVector.$1,
      gazeVectorY: gazeVector.$2,
      confidence: result.score,
      timestamp: now,
    );
  }

  /// Décalage normalisé `(-1..1, -1..1)` du centre de l'iris par rapport au
  /// centre de la boîte englobante du contour de l'oeil, moyenné sur les
  /// deux yeux quand les deux sont exploitables. `null` si aucune donnée
  /// d'iris n'est disponible (résultat sans les 478 landmarks, ex.
  /// `enableIris: false` ou mesh incomplet).
  (double, double)? _irisOffset(List<FaceMeshLandmark> landmarks) {
    if (landmarks.length < _landmarkCountWithIris) return null;

    final offsets = <(double, double)>[];
    final left = _eyeOffset(landmarks, _leftEyeIndices, _leftIrisCenterIndex);
    if (left != null) offsets.add(left);
    final right = _eyeOffset(landmarks, _rightEyeIndices, _rightIrisCenterIndex);
    if (right != null) offsets.add(right);

    if (offsets.isEmpty) return null;
    final avgX = offsets.map((o) => o.$1).reduce((a, b) => a + b) / offsets.length;
    final avgY = offsets.map((o) => o.$2).reduce((a, b) => a + b) / offsets.length;
    return (avgX, avgY);
  }

  (double, double)? _eyeOffset(
    List<FaceMeshLandmark> landmarks,
    List<int> eyeIndices,
    int irisCenterIndex,
  ) {
    if (irisCenterIndex >= landmarks.length) return null;

    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    for (final index in eyeIndices) {
      if (index >= landmarks.length) return null;
      final p = landmarks[index];
      minX = math.min(minX, p.x);
      maxX = math.max(maxX, p.x);
      minY = math.min(minY, p.y);
      maxY = math.max(maxY, p.y);
    }

    final width = maxX - minX;
    final height = maxY - minY;
    if (width <= 0 || height <= 0) return null;

    final cx = (minX + maxX) / 2;
    final cy = (minY + maxY) / 2;
    final iris = landmarks[irisCenterIndex];
    final nx = ((iris.x - cx) / (width / 2)).clamp(-1.0, 1.0);
    final ny = ((iris.y - cy) / (height / 2)).clamp(-1.0, 1.0);
    return (nx, ny);
  }

  @override
  Future<void> stop() async {
    final controller = _cameraController;
    if (controller != null && controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }
  }

  @override
  Future<void> dispose() async {
    await _teardownCameraAndDetector();
    await _sampleController.close();
  }

  Future<void> _teardownCameraAndDetector() async {
    await stop();
    await _cameraController?.dispose();
    _faceMeshProcessor?.close();
    _cameraController = null;
    _faceMeshProcessor = null;
  }
}
