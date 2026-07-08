import 'package:flutter/material.dart';

/// Retour visuel obligatoire pendant une sélection par dwell time
/// (SPECIFICATIONS_FONCTIONNELLES.md section 4.5).
///
/// Dessine une bordure lumineuse dont le tracé se remplit progressivement
/// autour du widget enfant, de 0 (rien) à 1 (contour complet) — combinant
/// deux des exemples suggérés par les spécifications ("bordure lumineuse"
/// et "remplissage progressif") en un seul indicateur continu, plutôt qu'un
/// cercle de progression séparé qui détournerait le regard du bouton
/// lui-même.
///
/// Ce widget est purement visuel : il ne calcule ni ne connaît de dwell
/// time, il se contente d'illustrer une valeur [progress] déjà calculée par
/// la couche `eyetracking` (voir `GazeState.dwellProgress`).
class DwellProgressBorder extends StatelessWidget {
  /// Progression de 0.0 (aucune sélection en cours) à 1.0 (validée).
  final double progress;

  /// Couleur du tracé de progression.
  final Color color;

  /// Rayon des coins, doit correspondre à celui du widget enfant pour un
  /// alignement visuel propre.
  final double borderRadius;

  /// Épaisseur du tracé de progression.
  final double strokeWidth;

  final Widget child;

  const DwellProgressBorder({
    super.key,
    required this.progress,
    required this.child,
    this.color = const Color(0xFF29B6F6),
    this.borderRadius = 24,
    this.strokeWidth = 6,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);
    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        if (clamped > 0)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _ProgressBorderPainter(
                  progress: clamped,
                  color: color,
                  radius: borderRadius,
                  strokeWidth: strokeWidth,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ProgressBorderPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double radius;
  final double strokeWidth;

  _ProgressBorderPainter({
    required this.progress,
    required this.color,
    required this.radius,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final fullPath = Path()..addRRect(rrect);

    final metric = fullPath.computeMetrics().first;
    final extractLength = metric.length * progress;
    final drawPath = metric.extractPath(0, extractLength);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    canvas.drawPath(drawPath, paint);
  }

  @override
  bool shouldRepaint(covariant _ProgressBorderPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.radius != radius ||
      oldDelegate.strokeWidth != strokeWidth;
}
