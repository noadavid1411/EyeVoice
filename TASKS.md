# Suivi des tâches — La Voix du Regard (EyeVoice)

Ce fichier suit l'avancement des tâches définies lors du brainstorm technique, phase par phase. Chaque tâche est cochée une fois validée par le chef de projet.

Décisions techniques verrouillées : Flutter, Riverpod (state management), MediaPipe (eye-tracking), flutter_tts (TTS), shared_preferences (persistance MVP).

## Phase 0 — Fondations (software-architect)

- [x] Structure de dossiers (`lib/core`, `lib/data`, `lib/domain`, `lib/eyetracking`, `lib/ui`, `lib/services`) — ajout de `lib/core/models`, `lib/core/constants`, `lib/domain/actions`, `lib/domain/models`, `lib/eyetracking/models`
- [x] Contrat `ActionResult` (résultat de résolution d'action) — `lib/domain/actions/action_result.dart`
- [x] Contrat `GazeState` (zone, progression dwell, confiance, signal dégradé) — `lib/eyetracking/models/gaze_state.dart` (+ `lib/core/models/screen_zone.dart` partagé)
- [x] `pubspec.yaml` initial (riverpod, flutter_tts, shared_preferences, dépendance MediaPipe) — ajout de `mediapipe_face_mesh` (à revalider par eye-tracking-engineer en Phase 1b)

## Phase 1a — Moteur de données (domain-logic-engineer)

- [x] Modèles Dart typés pour `menu-config.json` — `lib/domain/models/menu_config.dart`, `menu_screen.dart`, `menu_item.dart`, `menu_action.dart`, `menu_config_exception.dart`
- [x] Validateur de schéma (rejette un écran à plus de 4 choix) — `lib/domain/models/menu_config_validator.dart` (`validateMenuConfig`, `loadMenuConfig`)
- [x] `ActionResolver` (navigate/speak/back/home/openMode/settings/cancel) sur données mockées — `lib/domain/actions/action_resolver.dart` (+ fixture `lib/domain/models/sample_menu_config.dart`)
- [x] Historique de navigation (pile back/home) — `lib/domain/actions/navigation_history.dart`

## Phase 1b — Eye-tracking (eye-tracking-engineer)

- [x] Intégration MediaPipe (détection visage/iris, caméra frontale) — `mediapipe_face_mesh` revalidé (voir `pubspec.yaml`), wrapper `lib/eyetracking/detection/face_mesh_gaze_detector.dart` derrière l'interface `FaceGazeDetector`
- [x] Spike calibration (collecte points de référence, mapping regard→écran) — `lib/eyetracking/calibration/calibration_session.dart` (régression linéaire) + `lib/eyetracking/models/calibration_profile.dart`
- [x] Mapping vers zones logiques + zone morte centrale (15-25 %, réglable) — `lib/eyetracking/mapping/zone_mapper.dart` + `lib/eyetracking/models/eyetracking_settings.dart`
- [x] State machine dwell time (défaut 1300 ms, annulation sortie zone/perte visage/instabilité) — `lib/eyetracking/dwell/dwell_time_controller.dart`
- [x] Exposition `GazeState` + signal de dégradation (mode tactile de secours) — `lib/eyetracking/gaze_tracking_pipeline.dart` (orchestrateur) + `lib/eyetracking/signal/signal_quality_monitor.dart`

## Phase 1c — Interface (flutter-ui-engineer)

- [x] Thème sombre haut contraste — `lib/ui/theme/app_colors.dart`, `app_text_styles.dart`, `app_theme.dart` (branché dans `lib/main.dart`)
- [x] Widget `Grid4Screen` générique (données mockées) — `lib/ui/screens/grid4_screen.dart`, données mockées via `lib/domain/models/sample_menu_config.dart` dans `lib/ui/demo/demo_home_screen.dart`
- [x] Indicateur de progression de sélection (consomme `GazeState`) — `lib/ui/widgets/dwell_progress_border.dart` + `lib/ui/widgets/zone_button.dart` (consomment `GazeState.dwellProgress`)
- [x] Écran Oui/Non (2 zones, vert/rouge) — `lib/ui/screens/yes_no_screen.dart`

## Phase 2 — Intégration

- [ ] UI branchée sur `ActionResolver` réel (navigation effective)
- [ ] UI branchée sur `GazeState` réel (dwell effectif)
- [ ] Service TTS (flutter_tts) branché sur action `speak`

## Phase 3 — Complétude MVP

- [ ] Confirmation des actions sensibles (quitter, reset, suppression phrase)
- [ ] Mode dégradé tactile/manuel
- [ ] Réglages configurables (dwell time, sensibilité, contraste, voix)

## Phase 4 — Qualité & documentation

- [ ] Tests unitaires : parsing/validation JSON, `ActionResolver`, state machine dwell time, mapping zone
- [ ] Tests widget : `Grid4Screen`, écran Oui/Non
- [ ] Checklist critères d'acceptation (section 19 des spécifications)
- [ ] ADRs des décisions structurantes (Riverpod, structure dossiers, MediaPipe)
- [ ] Documentation des contrats `ActionResult` / `GazeState` / schéma JSON
- [ ] Guide de personnalisation aidant/soignant

## Backlog (versions suivantes / avancées)

- [ ] Mode expert par balayage temporel + prédiction de mots
- [ ] Personnalisation des phrases/menus dans l'application
- [ ] Profils patients, export/import de configuration, calibration personnalisée
