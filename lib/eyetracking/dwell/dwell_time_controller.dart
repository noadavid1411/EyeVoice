import 'package:eyevoice/core/models/screen_zone.dart';

/// Résultat d'une mise à jour de la state machine de dwell time.
class DwellTickResult {
  /// Progression 0.0-1.0 de la temporisation pour la zone passée à
  /// [DwellTimeController.update]. Vaut `0.0` si cette zone n'est pas
  /// sélectionnable (`null` ou [ScreenZone.centerDeadZone]).
  final double progress;

  /// `true` exactement au tick où le dwell time vient d'être atteint
  /// (transition progression < 1 → 1, un seul tick) : c'est le signal
  /// qu'une action doit être déclenchée par la couche appelante
  /// (`ActionResolver`, Phase 1a/2 — hors périmètre `eyetracking`).
  final bool justValidated;

  const DwellTickResult({required this.progress, required this.justValidated});
}

/// State machine de sélection par dwell time (section 4.4 + règles de
/// sécurité de la section 17.1).
///
/// Étape isolée et testable indépendamment de la détection/calibration : ne
/// connaît que des [ScreenZone] déjà résolues et des horodatages, jamais de
/// coordonnées brutes ni de framework de détection (section 13.1).
///
/// Règles (section 17.1) :
/// - la progression avance uniquement tant que la même zone, non-`null` et
///   différente de [ScreenZone.centerDeadZone], reste fixée en continu ;
/// - toute sortie de zone, perte de zone (`null` — ex. visage non détecté),
///   ou entrée en zone morte réinitialise la progression à 0 ;
/// - une alternance instable entre plusieurs zones se traduit
///   structurellement par des changements de zone répétés, donc par des
///   réinitialisations répétées : aucune logique d'instabilité dédiée n'est
///   nécessaire ici (elle vit dans `SignalQualityMonitor`, qui a une
///   sémantique différente : signaler la dégradation, pas seulement annuler
///   la sélection en cours) ;
/// - une fois la progression à 1.0 atteinte, elle est "verrouillée" à 1.0 et
///   ne redémarre que si le regard quitte puis refixe la zone : évite un
///   redéclenchement en boucle tant que le patient continue de fixer la
///   même zone après validation.
class DwellTimeController {
  DwellTimeController({required Duration dwellTime}) : _dwellTime = dwellTime;

  Duration _dwellTime;

  ScreenZone? _fixatedZone;
  DateTime? _fixationStart;
  bool _validated = false;

  void updateDwellTime(Duration dwellTime) => _dwellTime = dwellTime;

  /// Fait avancer la state machine avec la [zone] actuellement rapportée par
  /// le mapping (peut être `null` si aucune zone n'est exploitable) au temps
  /// [now]. À appeler à chaque nouvel échantillon de regard (cadence caméra).
  DwellTickResult update(ScreenZone? zone, DateTime now) {
    final isSelectable = zone != null && zone != ScreenZone.centerDeadZone;

    if (!isSelectable) {
      _reset();
      return const DwellTickResult(progress: 0.0, justValidated: false);
    }

    if (zone != _fixatedZone) {
      _fixatedZone = zone;
      _fixationStart = now;
      _validated = false;
    }

    if (_validated) {
      return const DwellTickResult(progress: 1.0, justValidated: false);
    }

    final elapsed = now.difference(_fixationStart!);
    if (elapsed >= _dwellTime) {
      _validated = true;
      return const DwellTickResult(progress: 1.0, justValidated: true);
    }

    final progress = _dwellTime.inMicroseconds == 0
        ? 1.0
        : elapsed.inMicroseconds / _dwellTime.inMicroseconds;
    return DwellTickResult(progress: progress.clamp(0.0, 1.0), justValidated: false);
  }

  /// Force l'annulation de la progression en cours (ex. changement d'écran,
  /// signal jugé instable par la couche appelante — section 17.1).
  /// Équivalent à appeler [update] avec `zone = null`, exposé séparément
  /// pour plus de clarté côté appelant (voir `GazeTrackingPipeline`).
  void cancel() => _reset();

  void _reset() {
    _fixatedZone = null;
    _fixationStart = null;
    _validated = false;
  }
}
