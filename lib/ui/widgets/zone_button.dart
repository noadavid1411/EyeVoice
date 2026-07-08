import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'dwell_progress_border.dart';

/// Bouton de zone générique : brique de base réutilisée par [Grid4Screen]
/// et l'écran Oui/Non.
///
/// Affiche un libellé très grand (section 15.2), un fond haut contraste, et
/// délègue le retour visuel de sélection en cours à
/// [DwellProgressBorder]. Ne contient aucune logique de dwell time : il se
/// contente de refléter [dwellProgress], une valeur déjà calculée en amont
/// (mock en Phase 1c, `GazeState` réel en Phase 2).
///
/// [onTap] est prévu pour le mode dégradé tactile (section 17.3) et pour la
/// commodité des tests/du développement desktop : il n'implique aucune
/// logique de regard.
class ZoneButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color backgroundColor;
  final Color progressColor;
  final double dwellProgress;
  final bool isFixated;
  final VoidCallback? onTap;
  final TextStyle? labelStyle;

  const ZoneButton({
    super.key,
    required this.label,
    this.icon,
    this.backgroundColor = AppColors.surface,
    this.progressColor = AppColors.selectionGlow,
    this.dwellProgress = 0.0,
    this.isFixated = false,
    this.onTap,
    this.labelStyle,
  });

  static const double _borderRadius = 24;

  @override
  Widget build(BuildContext context) {
    final restBorderColor = isFixated ? progressColor.withValues(alpha: 0.6) : AppColors.border;

    return Padding(
      padding: const EdgeInsets.all(10),
      child: DwellProgressBorder(
        progress: dwellProgress,
        color: progressColor,
        borderRadius: _borderRadius,
        child: Material(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(_borderRadius),
          child: InkWell(
            borderRadius: BorderRadius.circular(_borderRadius),
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_borderRadius),
                border: Border.all(color: restBorderColor, width: 2),
              ),
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 56, color: AppColors.textPrimary),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: labelStyle ?? AppTextStyles.zoneLabel,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
