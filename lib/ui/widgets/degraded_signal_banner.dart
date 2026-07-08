import 'package:flutter/material.dart';

import '../../eyetracking/models/gaze_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Indication visuelle du mode dégradé tactile/manuel
/// (SPECIFICATIONS_FONCTIONNELLES.md section 17.3).
///
/// Purement visuelle : elle ne fait qu'illustrer [GazeSignalStatus], déjà
/// calculé par la couche `eyetracking` (`SignalQualityMonitor`, via
/// `GazeState.signalStatus`) — elle ne détecte rien et ne décide de rien
/// elle-même. La sélection tactile de secours fonctionne nativement sur
/// [Grid4Screen]/[YesNoScreen] (`ZoneButton.onTap`) indépendamment de
/// l'affichage de cette bannière : celle-ci informe seulement le patient/
/// l'aidant que ce mode de secours ("au toucher", "avec l'aide d'un
/// proche", "sélection manuelle" — section 17.3) reste disponible quand le
/// signal du regard est [GazeSignalStatus.degraded] ou [GazeSignalStatus.lost].
///
/// N'affiche rien pour [GazeSignalStatus.ok] (fonctionnement normal, pas
/// besoin de surcharger visuellement l'écran — section 10.3).
class DegradedSignalBanner extends StatelessWidget {
  final GazeSignalStatus status;

  const DegradedSignalBanner({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    if (status == GazeSignalStatus.ok) {
      return const SizedBox.shrink();
    }

    final isLost = status == GazeSignalStatus.lost;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isLost ? AppColors.danger.withValues(alpha: 0.85) : AppColors.navigationHighlight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isLost ? Icons.touch_app : Icons.visibility_off_outlined,
            color: AppColors.textPrimary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isLost
                  ? 'Suivi du regard indisponible : touchez l’écran pour choisir '
                      '(avec l’aide d’un proche si besoin).'
                  : 'Signal du regard instable : la sélection tactile reste disponible.',
              style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
