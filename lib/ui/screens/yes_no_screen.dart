import 'package:flutter/material.dart';

import '../../core/models/screen_zone.dart';
import '../../eyetracking/models/gaze_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/zone_button.dart';

/// Écran du Niveau 1 — Mode Sécurité (SPECIFICATIONS_FONCTIONNELLES.md
/// section 5) : 2 zones verticales, OUI en vert à gauche, NON en rouge à
/// droite.
///
/// Contrairement à [Grid4Screen], le quadrant bas-droite n'est pas
/// disponible ici : le mode Oui/Non doit rester "extrêmement simple" et
/// sans "élément secondaire" qui distrairait le patient (section 5.3). La
/// sortie du mode (retour) est donc proposée via une petite affordance
/// discrète en haut de l'écran plutôt qu'une 3e grande zone.
class YesNoScreen extends StatefulWidget {
  /// Question posée au patient (ex. "Tu as mal ?"), fournie par l'appelant
  /// — jamais codée en dur ici (section 11.1 : le contenu vient des
  /// données, pas de l'UI).
  final String? question;

  /// État de regard courant, déjà résolu par la couche `eyetracking`.
  final GazeState gazeState;

  final VoidCallback? onYes;
  final VoidCallback? onNo;

  /// Sortie du mode Oui/Non (ex. retour au menu précédent). Optionnelle :
  /// si `null`, aucune affordance de sortie n'est affichée.
  final VoidCallback? onExit;

  const YesNoScreen({
    super.key,
    this.question,
    this.gazeState = const GazeState.idle(),
    this.onYes,
    this.onNo,
    this.onExit,
  });

  @override
  State<YesNoScreen> createState() => _YesNoScreenState();
}

class _YesNoScreenState extends State<YesNoScreen> {
  @override
  void didUpdateWidget(covariant YesNoScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeFireActivation(oldWidget.gazeState, widget.gazeState);
  }

  void _maybeFireActivation(GazeState previous, GazeState current) {
    final zone = current.zone;
    if (zone != ScreenZone.left && zone != ScreenZone.right) return;
    if (current.dwellProgress < 1.0) return;

    final alreadyFired = previous.zone == zone && previous.dwellProgress >= 1.0;
    if (alreadyFired) return;

    if (zone == ScreenZone.left) {
      widget.onYes?.call();
    } else {
      widget.onNo?.call();
    }
  }

  double _progressFor(ScreenZone zone) =>
      widget.gazeState.zone == zone ? widget.gazeState.dwellProgress : 0.0;

  bool _isFixated(ScreenZone zone) => widget.gazeState.zone == zone;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                if (widget.question != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                    child: Text(
                      widget.question!,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.spokenPhrase,
                    ),
                  ),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: ZoneButton(
                          label: 'OUI',
                          icon: Icons.check_circle_outline,
                          backgroundColor: AppColors.yes,
                          progressColor: AppColors.yesHighlight,
                          labelStyle: AppTextStyles.yesNoLabel,
                          dwellProgress: _progressFor(ScreenZone.left),
                          isFixated: _isFixated(ScreenZone.left),
                          onTap: widget.onYes,
                        ),
                      ),
                      Expanded(
                        child: ZoneButton(
                          label: 'NON',
                          icon: Icons.cancel_outlined,
                          backgroundColor: AppColors.no,
                          progressColor: AppColors.noHighlight,
                          labelStyle: AppTextStyles.yesNoLabel,
                          dwellProgress: _progressFor(ScreenZone.right),
                          isFixated: _isFixated(ScreenZone.right),
                          onTap: widget.onNo,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (widget.onExit != null)
              Positioned(
                top: 8,
                left: 8,
                child: SafeArea(
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.textMuted),
                    tooltip: 'Retour',
                    onPressed: widget.onExit,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
