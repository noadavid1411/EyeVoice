import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:eyevoice/data/settings_repository.dart';
import 'package:eyevoice/eyetracking/detection/face_gaze_detector.dart';
import 'package:eyevoice/eyetracking/gaze_tracking_pipeline.dart';
import 'package:eyevoice/eyetracking/models/eyetracking_settings.dart';
import 'package:eyevoice/eyetracking/models/gaze_state.dart';
import 'package:eyevoice/eyetracking/models/screen_layout_mode.dart';

import '../gaze/fake_face_gaze_detector.dart';
import 'menu_navigation_controller.dart';

/// Détecteur de regard brut consommé par [gazeTrackingPipelineProvider].
///
/// Par défaut : [FakeFaceGazeDetector], une simulation sandbox-safe (aucun
/// accès caméra) qui alimente tout de même le vrai [GazeTrackingPipeline]
/// (mapping calibré, zones, dwell time, qualité de signal) avec un flux
/// d'échantillons plausible — voir la documentation de
/// [FakeFaceGazeDetector] pour la justification.
///
/// Pour un déploiement sur un appareil avec caméra frontale, ce provider
/// doit être surchargé avec le vrai détecteur :
/// ```dart
/// ProviderScope(
///   overrides: [
///     faceGazeDetectorProvider.overrideWithValue(FaceMeshGazeDetector()),
///   ],
///   child: const EyeVoiceApp(),
/// )
/// ```
/// Voir `lib/main.dart` (drapeau `EYEVOICE_USE_REAL_GAZE_DETECTOR`, passé
/// via `--dart-define`) pour un point de bascule concret. Le reste du
/// câblage (pipeline réel → `GazeState` → écrans) ne change pas : seule
/// cette brique de détection est remplacée.
final faceGazeDetectorProvider = Provider<FaceGazeDetector>((ref) {
  return FakeFaceGazeDetector();
});

/// Instance unique du vrai [GazeTrackingPipeline] pour toute la durée de vie
/// de l'application (au même titre que `ttsServiceProvider`), câblée sur
/// [faceGazeDetectorProvider].
///
/// Démarre la détection dès la première lecture du provider ; `start()` ne
/// lève jamais d'exception (voir sa doc) même si la caméra/le détecteur
/// réel échoue à démarrer — le flux [gazeStateProvider] reçoit alors un
/// `GazeState.idle()` plutôt que de bloquer l'UI.
///
/// Câblé sur [settingsProvider] (Phase 3, réglages configurables — section
/// 16) : la valeur initiale de [EyeTrackingSettings] (dwell time, zone
/// morte, sensibilité) vient des réglages persistés/par défaut de
/// l'utilisateur, et tout changement ultérieur (écran de réglages,
/// `lib/ui/screens/settings_screen.dart`) est répercuté à chaud via
/// `GazeTrackingPipeline.updateSettings` — sans jamais recréer le pipeline
/// (qui redémarrerait inutilement la caméra/le détecteur). `ref.listen` est
/// utilisé ici plutôt que `ref.watch` précisément pour ça : seul un
/// changement de valeur déclenche une mise à jour incrémentale, la lecture
/// initiale ne recrée jamais ce provider.
final gazeTrackingPipelineProvider = Provider<GazeTrackingPipeline>((ref) {
  final detector = ref.watch(faceGazeDetectorProvider);
  final initialSettings = ref.read(settingsProvider).eyeTracking;
  final pipeline = GazeTrackingPipeline(detector: detector, settings: initialSettings);
  pipeline.start();
  ref.listen<EyeTrackingSettings>(
    settingsProvider.select((s) => s.eyeTracking),
    (previous, next) => pipeline.updateSettings(next),
  );
  ref.onDispose(pipeline.dispose);
  return pipeline;
});

/// Flux de [GazeState] réel à consommer par les écrans (`Grid4Screen`,
/// `YesNoScreen`) : remplace toute simulation locale de `GazeState` dans un
/// widget (Phase 2, TASKS.md — "UI branchée sur `GazeState` réel").
final gazeStateProvider = StreamProvider<GazeState>((ref) {
  return ref.watch(gazeTrackingPipelineProvider).states;
});

/// Disposition de zones à signaler à [GazeTrackingPipeline.setLayoutMode],
/// déduite du [UiMode] courant.
///
/// La couche `eyetracking` ne connaît pas le contenu de `menu-config.json`
/// (section 13.1) : c'est à la couche `ui`, seule à savoir si l'écran
/// affiché est une grille 4 zones ou le mode Oui/Non, de faire cette
/// traduction (voir la doc de [ScreenLayoutMode]).
final screenLayoutModeProvider = Provider<ScreenLayoutMode>((ref) {
  final uiMode = ref.watch(menuNavigationProvider.select((s) => s.uiMode));
  // Le dialogue de confirmation des actions sensibles (section 17.2,
  // `lib/ui/widgets/confirmation_dialog.dart`) réutilise le layout à 2 zones
  // du mode Oui/Non — même disposition gauche/droite à interpréter côté
  // `eyetracking`. L'écran de réglages ([UiMode.settings]) est une liste
  // défilante sans zones de regard : le mode importe peu tant qu'aucun
  // `ZoneButton` n'y est affiché, `quadrant` reste donc un défaut neutre.
  return switch (uiMode) {
    UiMode.yesNo || UiMode.confirmation => ScreenLayoutMode.yesNo,
    UiMode.grid || UiMode.settings => ScreenLayoutMode.quadrant,
  };
});
