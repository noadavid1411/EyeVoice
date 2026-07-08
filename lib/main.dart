import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/demo/demo_home_screen.dart';
import 'ui/theme/app_theme.dart';

/// Point d'entrée de "La Voix du Regard" (EyeVoice).
///
/// Le thème sombre haut contraste définitif (section 15.1 des
/// spécifications) est câblé via [AppTheme.dark] (Phase 1c,
/// `lib/ui/theme`). L'écran affiché est [DemoHomeScreen] : une vitrine qui
/// exerce `Grid4Screen` et `YesNoScreen` sur la fixture de menu-config du
/// domaine (`lib/domain/models/sample_menu_config.dart`, Phase 1a) avec un
/// `GazeState` simulé localement, en l'absence du vrai pipeline
/// `eyetracking` et du vrai `ActionResolver` (branchement réel prévu en
/// Phase 2, voir TASKS.md).
///
/// `ProviderScope` reste câblé dès maintenant car Riverpod est la solution
/// de gestion d'état verrouillée pour le projet (TASKS.md).
void main() {
  runApp(const ProviderScope(child: EyeVoiceApp()));
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
