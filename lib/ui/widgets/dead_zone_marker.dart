import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Rendu **visuel uniquement** de la zone morte centrale
/// (SPECIFICATIONS_FONCTIONNELLES.md section 4.3).
///
/// Ce widget ne fait qu'illustrer, pour le patient et l'aidant, où se
/// trouve la zone de repos du regard : il n'intercepte aucun événement
/// ([IgnorePointer]) et ne déclenche jamais d'action, quel que soit ce qui
/// est posé dessus. Le calcul réel de la zone morte (mapping regard →
/// coordonnées → zone) appartient à la couche `eyetracking` ; ce widget ne
/// fait qu'en représenter la taille par défaut de façon discrète, pour ne
/// pas surcharger visuellement l'écran (section 10.3).
class DeadZoneMarker extends StatelessWidget {
  /// Part du plus petit côté de l'écran occupée par le marqueur, exprimée
  /// en fraction (ex. 0.18 = 18 %). Doit rester dans la fourchette
  /// attendue par les spécifications (15 à 25 %, voir `AppDefaults`), mais
  /// ce widget ne l'impose pas lui-même : c'est un simple repère visuel.
  final double sizeRatio;

  const DeadZoneMarker({super.key, this.sizeRatio = 0.18});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final diameter = constraints.biggest.shortestSide * sizeRatio;
            return Container(
              width: diameter,
              height: diameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.deadZoneMarker, width: 1.5),
              ),
            );
          },
        ),
      ),
    );
  }
}
