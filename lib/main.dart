import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/settings_repository.dart';
import 'domain/models/app_settings.dart';
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
///
/// `main()` est désormais asynchrone (Phase 3, TASKS.md — "réglages
/// configurables") : `sharedPreferencesProvider`
/// (`lib/data/settings_repository.dart`) doit être surchargé avec une vraie
/// instance `SharedPreferences` *avant* `runApp`, une fois
/// `WidgetsFlutterBinding.ensureInitialized()` appelé (requis pour tout
/// appel de plugin — ici `SharedPreferences.getInstance()` — avant
/// `runApp`), suivant exactement le schéma documenté sur ce provider.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        if (_useRealGazeDetector)
          faceGazeDetectorProvider.overrideWithValue(FaceMeshGazeDetector()),
      ],
      child: const EyeVoiceApp(),
    ),
  );
}

/// Widget racine : `ConsumerWidget` (plutôt que `StatelessWidget`, Phase 1c)
/// depuis la Phase 3 car le thème effectif dépend désormais des réglages
/// utilisateur (section 16) — [AppSettings.contrastLevel] pour le niveau de
/// contraste ([AppTheme.themeFor]) et [AppSettings.fontSize] pour l'échelle
/// de police, appliquée globalement via `MediaQuery.textScaler` dans
/// `builder` plutôt qu'écran par écran (un seul point de câblage, cohérent
/// avec le reste de l'application qui ne doit jamais coder de taille de
/// police en dur en dehors de `lib/ui/theme`).
class EyeVoiceApp extends ConsumerWidget {
  const EyeVoiceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      title: 'La Voix du Regard',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeFor(settings.contrastLevel),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(settings.fontSize.scaleFactor),
        ),
        child: child!,
      ),
      home: const DemoHomeScreen(),
    );
  }
}
