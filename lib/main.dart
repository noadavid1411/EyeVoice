import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'eyetracking/detection/face_mesh_gaze_detector.dart';
import 'ui/demo/demo_home_screen.dart';
import 'ui/providers/gaze_tracking_providers.dart';
import 'ui/theme/app_theme.dart';

/// Bascule vers le vrai détecteur caméra ([FaceMeshGazeDetector]) au lieu du
/// [FakeFaceGazeDetector] par défaut (voir sa doc,
/// `lib/ui/gaze/fake_face_gaze_detector.dart`).
///
/// `false` par défaut : cet environnement de développement (et tout appareil
/// sans caméra frontale/permission) ne peut pas faire tourner le vrai
/// pipeline MediaPipe. Pour un déploiement réel, compiler avec
/// `flutter run --dart-define=EYEVOICE_USE_REAL_GAZE_DETECTOR=true`.
const bool _useRealGazeDetector = bool.fromEnvironment(
  'EYEVOICE_USE_REAL_GAZE_DETECTOR',
);

/// Point d'entrée de "La Voix du Regard" (EyeVoice).
///
/// Le thème sombre haut contraste définitif (section 15.1 des
/// spécifications) est câblé via [AppTheme.dark] (Phase 1c,
/// `lib/ui/theme`). L'écran affiché est [DemoHomeScreen], désormais câblé
/// sur le vrai moteur de navigation (`ActionResolver` du domaine, via
/// `lib/ui/providers/menu_navigation_controller.dart`) et le vrai
/// `GazeTrackingPipeline` (via `lib/ui/providers/gaze_tracking_providers.dart`)
/// — Phase 2, voir TASKS.md. La fixture de menu-config en mémoire
/// (`lib/domain/models/sample_menu_config.dart`, Phase 1a) reste utilisée
/// tant que le chargement d'un vrai `menu-config.json` n'est pas branché.
///
/// `ProviderScope` reste câblé dès maintenant car Riverpod est la solution
/// de gestion d'état verrouillée pour le projet (TASKS.md).
void main() {
  runApp(
    ProviderScope(
      overrides: [
        if (_useRealGazeDetector)
          faceGazeDetectorProvider.overrideWithValue(FaceMeshGazeDetector()),
      ],
      child: const EyeVoiceApp(),
    ),
  );
}

class EyeVoiceApp extends StatelessWidget {
  const EyeVoiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'La Voix du Regard',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const DemoHomeScreen(),
    );
  }
}
