import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Point d'entrée de "La Voix du Regard" (EyeVoice).
///
/// Ce fichier est un squelette minimal de Phase 0 : l'écran d'accueil réel
/// (grille 4 zones), le thème sombre haut contraste définitif (section 15.1
/// des spécifications) et le routing entre écrans seront construits par
/// flutter-ui-engineer (Phase 1c / Phase 2), à partir des contrats
/// `ActionResult` (lib/domain/actions/action_result.dart) et `GazeState`
/// (lib/eyetracking/models/gaze_state.dart) définis en Phase 0.
///
/// `ProviderScope` est câblé dès maintenant car Riverpod est la solution de
/// gestion d'état verrouillée pour le projet (TASKS.md) : toute la suite du
/// développement en dépend, ce n'est pas un choix d'UI.
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
      // Thème provisoire uniquement : le thème sombre haut contraste
      // définitif est construit en Phase 1c par flutter-ui-engineer.
      theme: ThemeData.dark(),
      home: const _PlaceholderHome(),
    );
  }
}

class _PlaceholderHome extends StatelessWidget {
  const _PlaceholderHome();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('La Voix du Regard — en construction'),
      ),
    );
  }
}
