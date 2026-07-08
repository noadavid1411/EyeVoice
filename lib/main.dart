import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/menu_config_repository.dart';
import 'data/settings_repository.dart';
import 'domain/models/app_settings.dart';
import 'domain/models/menu_config_exception.dart';
import 'eyetracking/detection/face_mesh_gaze_detector.dart';
import 'ui/demo/demo_home_screen.dart';
import 'ui/providers/gaze_tracking_providers.dart';
import 'ui/theme/app_colors.dart';
import 'ui/theme/app_text_styles.dart';
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
/// — Phase 2, voir TASKS.md.
///
/// [DemoHomeScreen] n'est monté qu'une fois le vrai `menu-config.json`
/// chargé avec succès depuis les assets (`menuConfigProvider`,
/// `lib/data/menu_config_repository.dart` — comble la réserve du critère 8
/// d'ACCEPTANCE_CHECKLIST.md, la fixture en mémoire
/// `lib/domain/models/sample_menu_config.dart` restant réservée aux tests) :
/// [EyeVoiceApp.build] observe `menuConfigProvider` et affiche un écran de
/// chargement ([_MenuConfigLoadingScreen]) le temps de la lecture de
/// l'asset (bref, l'asset est petit), ou un écran d'erreur clair
/// ([_MenuConfigErrorScreen]) si le JSON est invalide
/// (`MenuConfigParseException`/`MenuConfigValidationException`) plutôt que
/// de laisser l'application planter silencieusement.
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
    final menuConfigAsync = ref.watch(menuConfigProvider);

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
      // `.when` plutôt qu'un simple `menuConfigAsync.value` : un
      // `menu-config.json` invalide (`MenuConfigParseException`/
      // `MenuConfigValidationException`, voir la doc de [MenuConfigRepository.load])
      // doit produire un écran d'erreur explicite, jamais un crash silencieux
      // ni un écran vide.
      home: menuConfigAsync.when(
        loading: () => const _MenuConfigLoadingScreen(),
        error: (error, stackTrace) => _MenuConfigErrorScreen(error: error),
        data: (_) => const DemoHomeScreen(),
      ),
    );
  }
}

/// Écran affiché le temps du chargement de `menu-config.json`
/// (`menuConfigProvider`), avant que [DemoHomeScreen] ne puisse être monté.
///
/// Bref en pratique (l'asset est petit), mais indispensable : sans lui,
/// [EyeVoiceApp] afficherait un écran blanc/un flash le temps de la lecture
/// asynchrone de l'asset.
class _MenuConfigLoadingScreen extends StatelessWidget {
  const _MenuConfigLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.selectionGlow),
      ),
    );
  }
}

/// Écran affiché si `menu-config.json` n'a pas pu être chargé ou est
/// invalide (`MenuConfigParseException`/`MenuConfigValidationException`,
/// `lib/domain/models/menu_config_exception.dart` — propagées telles
/// quelles par `menuConfigProvider`, voir sa doc).
///
/// Un `menu-config.json` structurant et invalide ne doit jamais faire
/// démarrer l'application sur une configuration dégradée silencieuse
/// (`lib/data/menu_config_repository.dart`) : ce cas doit donc rester
/// visible et compréhensible, y compris pour un aidant/soignant non
/// développeur qui aurait modifié le fichier (section 10.4).
class _MenuConfigErrorScreen extends StatelessWidget {
  final Object error;

  const _MenuConfigErrorScreen({required this.error});

  String get _message => switch (error) {
        MenuConfigParseException(:final message) =>
          'Le fichier de configuration des menus est mal formé.\n\n$message',
        MenuConfigValidationException(:final errors) =>
          'Le fichier de configuration des menus contient des erreurs :\n\n'
              '${errors.map((e) => '• $e').join('\n')}',
        _ => 'Une erreur inattendue est survenue pendant le chargement de '
            'la configuration des menus.\n\n$error',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: AppColors.danger, size: 64),
                const SizedBox(height: 24),
                Text(
                  'Impossible de démarrer l\'application',
                  style: AppTextStyles.screenTitle,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  _message,
                  style: AppTextStyles.caption,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
