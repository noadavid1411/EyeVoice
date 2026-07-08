// Test de fumée de l'application "La Voix du Regard".
//
// Vérifie que l'app démarre sur l'écran d'accueil (grille 4 zones, section
// 6.2) avec ses 4 libellés attendus, sans lever d'exception.

import 'package:eyevoice/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('EyeVoiceApp démarre sur l\'accueil en 4 quadrants', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: EyeVoiceApp()));

    expect(find.text('🩺 PHYSIQUE'), findsOneWidget);
    expect(find.text('💬 CONVERSATION'), findsOneWidget);
    expect(find.text('❤️ ÉMOTIONS / ÉTAT'), findsOneWidget);
    expect(find.text('⚙️ OPTIONS'), findsOneWidget);
  });
}
